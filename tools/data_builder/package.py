"""The v1 package contract. All untrusted archives are bounded before inflation."""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import sqlite3
import stat
import tempfile
import unicodedata
import zipfile
from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parents[2]
TABLES = ('code_nodes','notes','index_entries','index_crossrefs','table_cells','translations','zh_ngrams')
MAX_TOTAL = 512 * 1024 * 1024
MAX_ARCHIVE = 256 * 1024 * 1024
MAX_RATIO = 200
FILES = {'manifest.json', 'content.sqlite', 'checksums.sha256'}

class PackageError(ValueError):
    pass

def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def normalized(value: str) -> str:
    return unicodedata.normalize('NFKC', value).strip().casefold()

def code_key(code: str) -> str:
    return normalized(code).upper().replace('.', '')

def grams(value: str) -> set[str]:
    value = normalized(value)
    return set(value) | {value[i:i+2] for i in range(len(value)-1)}

def json_bytes(value) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + '\n').encode()

def contract():
    db = sqlite3.connect(':memory:')
    db.executescript((ROOT/'schemas/content.sql').read_text())
    objects = dict(db.execute("SELECT name,sql FROM sqlite_master WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%'"))
    db.close()
    return objects

def check_manifest(m):
    schema = json.loads((ROOT/'schemas/manifest.schema.json').read_text())
    errors = sorted(Draft202012Validator(schema).iter_errors(m), key=lambda e: str(e.path))
    if errors:
        raise PackageError('manifest: ' + errors[0].message)
    if m['effective_to'] < m['effective_from']:
        raise PackageError('invalid effective date interval')
    if m['schema_version'] != '1.0.0' or m['required_app_schema_min'] != '1.0.0':
        raise PackageError('Unsupported schema: upgrade App/builder')
    if m['kind'] == 'icd10cm_zh_tw' and not m.get('compatible_base_package_ids'):
        raise PackageError('overlay needs explicit base package IDs')
    if m['is_sample'] and 'SAMPLE' not in m['source_organization']:
        raise PackageError('sample must be visibly labelled')

def validate_db(path: Path, m: dict):
    db = sqlite3.connect(path.resolve().as_uri()+'?mode=ro', uri=True)
    try:
        db.execute('PRAGMA trusted_schema=OFF')
        db.execute('PRAGMA query_only=ON')
        actual = dict(db.execute("SELECT name,sql FROM sqlite_master WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%'"))
        if actual != contract():
            raise PackageError('SQLite schema differs from v1 allowlist (views/triggers/extensions prohibited)')
        if db.execute('PRAGMA user_version').fetchone()[0] != 10000:
            raise PackageError('SQLite schema version')
        if db.execute('PRAGMA integrity_check').fetchall() != [('ok',)]:
            raise PackageError('SQLite integrity_check')
        if db.execute('PRAGMA foreign_key_check').fetchall():
            raise PackageError('SQLite foreign keys')
        meta = dict(db.execute('SELECT key,value FROM package_meta'))
        if meta != {'package_id': m['package_id'], 'schema_version': m['schema_version']}:
            raise PackageError('SQLite metadata mismatch')
        for table in TABLES:
            count = db.execute(f'SELECT count(*) FROM {table}').fetchone()[0]
            if count != m['row_counts'][table]:
                raise PackageError('Row count: '+table)
        # Both hierarchies must be acyclic, regardless of otherwise-valid foreign keys.
        for table in ('code_nodes','index_entries'):
            parents = dict(db.execute(f'SELECT id,parent_id FROM {table}'))
            checked = set()
            for node in parents:
                seen = set()
                current = node
                while current is not None and current not in checked:
                    if current in seen:
                        raise PackageError('hierarchy cycle: '+table)
                    seen.add(current)
                    current = parents[current]
                checked.update(seen)
        # Compare postings, not just row counts. Rebuilding is safe only on a validation copy.
        for fts, table, cols in [('code_search_fts','code_nodes',('code','title_en')), ('index_search_fts','index_entries',('term_path',))]:
            left = db.execute(f'SELECT rowid,{",".join(cols)} FROM {fts} ORDER BY rowid').fetchall()
            right = db.execute(f'SELECT id,{",".join(cols)} FROM {table} ORDER BY id').fetchall()
            if left != right:
                raise PackageError('FTS content mismatch')
        expected = {(g,c,i) for i,c,text in db.execute('SELECT id,code_normalized,search_normalized FROM translations') for g in grams(text)}
        if expected != set(db.execute('SELECT * FROM zh_ngrams')):
            raise PackageError('Chinese ngram mismatch')
        for c,title,search,status,base in db.execute('SELECT code_normalized,title_zh_tw,search_normalized,mapping_status,base_package_id FROM translations'):
            if search != normalized(title) or (status != 'unresolved' and base not in m.get('compatible_base_package_ids',[m['package_id']])):
                raise PackageError('Translation lineage/normalization mismatch')
        if m['kind'] != 'icd10cm_zh_tw' and not m['row_counts']['code_nodes']:
            raise PackageError('Empty English dictionary')
    finally:
        db.close()
    # FTS internal integrity command needs write access; NEVER use it on installed content.
    with tempfile.TemporaryDirectory() as td:
        copy = Path(td)/'check.sqlite'
        shutil.copyfile(path, copy)
        scratch = sqlite3.connect(copy)
        try:
            for fts in ('code_search_fts','index_search_fts'):
                scratch.execute(f"INSERT INTO {fts}({fts}) VALUES ('integrity-check')")
        finally:
            scratch.close()

def safe_entries(z: zipfile.ZipFile, *, package=True):
    infos = z.infolist()
    if len(infos) > (3 if package else 1000):
        raise PackageError('ZIP entry count limit')
    names = set()
    total = 0
    for info in infos:
        name = info.filename
        if name in names or '\\' in name or name.startswith('/') or ':' in name or '..' in name.split('/') or stat.S_ISLNK(info.external_attr >> 16) or info.flag_bits & 1:
            raise PackageError('Unsafe/duplicate ZIP entry: '+name)
        names.add(name)
        total += info.file_size
        if info.file_size > MAX_TOTAL or total > MAX_TOTAL or info.file_size > max(info.compress_size,1)*MAX_RATIO:
            raise PackageError('ZIP resource limit')
        if info.compress_type not in (zipfile.ZIP_STORED,zipfile.ZIP_DEFLATED):
            raise PackageError('Unsupported ZIP compression')
    if package and names != FILES:
        raise PackageError('Package must contain exactly three contract files')
    return infos

def verify(package: Path, destination: Path | None = None) -> dict:
    if package.stat().st_size > MAX_ARCHIVE:
        raise PackageError('Archive too large')
    with tempfile.TemporaryDirectory() as td:
        stage = Path(td)
        try:
            with zipfile.ZipFile(package) as z:
                infos = safe_entries(z)
                for info in infos:
                    if info.filename != 'content.sqlite' and info.file_size > 1024*1024:
                        raise PackageError('Metadata too large')
                    with z.open(info) as src, (stage/info.filename).open('xb') as dst:
                        shutil.copyfileobj(src,dst,1024*1024)
        except (zipfile.BadZipFile, RuntimeError) as e:
            raise PackageError(str(e)) from e
        raw_manifest = (stage/'manifest.json').read_bytes()
        def unique(pairs):
            d = {}
            for k,v in pairs:
                if k in d: raise PackageError('Duplicate JSON key')
                d[k] = v
            return d
        m = json.loads(raw_manifest, object_pairs_hook=unique)
        check_manifest(m)
        hashes = {'manifest.json':digest(raw_manifest), 'content.sqlite':digest((stage/'content.sqlite').read_bytes())}
        expected = ''.join(f'{hashes[n]}  {n}\n' for n in sorted(hashes))
        if (stage/'checksums.sha256').read_text() != expected or hashes['content.sqlite'] != m['content_sha256']:
            raise PackageError('SHA256 mismatch')
        validate_db(stage/'content.sqlite',m)
        if destination:
            destination.mkdir(parents=True,exist_ok=True)
            for name in FILES:
                shutil.copyfile(stage/name,destination/name)
        return m | {'archive_sha256':digest(package.read_bytes())}

def write_package(db_path: Path, metadata: dict, output: Path):
    m = dict(metadata)
    db = sqlite3.connect(db_path)
    db.executemany('INSERT INTO package_meta VALUES (?,?)', [('package_id',m['package_id']),('schema_version','1.0.0')])
    m['row_counts'] = {t:db.execute(f'SELECT count(*) FROM {t}').fetchone()[0] for t in TABLES}
    db.commit()
    db.execute('VACUUM')
    db.close()
    m.update(format='icdpack',schema_version='1.0.0',required_app_schema_min='1.0.0',content_filename='content.sqlite',content_sha256=digest(db_path.read_bytes()))
    check_manifest(m)
    validate_db(db_path,m)
    raw = json_bytes(m)
    content = db_path.read_bytes()
    checks = f'{digest(content)}  content.sqlite\n{digest(raw)}  manifest.json\n'.encode()
    # Reproducible archive headers; never overwrite an existing release artifact.
    output.parent.mkdir(parents=True,exist_ok=True)
    temp = output.with_suffix(output.suffix+'.staging')
    owned_temp = False
    try:
        stream = temp.open('xb')
        owned_temp = True
        with stream, zipfile.ZipFile(stream,'w',zipfile.ZIP_DEFLATED) as z:
            for name,data in [('manifest.json',raw),('content.sqlite',content),('checksums.sha256',checks)]:
                zi = zipfile.ZipInfo(name,(2026,1,1,0,0,0)); zi.compress_type=zipfile.ZIP_DEFLATED; zi.external_attr=0o100644<<16
                z.writestr(zi,data)
        verify(temp)
        # link is atomic no-replace on Windows/POSIX; output must not already exist.
        os.link(temp,output)
    finally:
        if owned_temp: temp.unlink(missing_ok=True)
    return m
