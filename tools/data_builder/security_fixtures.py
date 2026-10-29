"""Reproducible malicious archives for negative tests, no executable payloads."""
import json
from pathlib import Path
import sqlite3
import tempfile
import zipfile
from .package import digest, json_bytes, verify

def generate(source: Path, target: Path):
    target.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(source) as z: original={n:z.read(n) for n in z.namelist()}
    for kind in ['traversal','duplicate','symlink','bomb','checksum','schema','db','trigger','cycle','duplicate-json']:
        files=original.copy()
        if kind=='traversal': files['../escape']=b'test only'
        if kind=='bomb': files['content.sqlite']=b'0'*(2*1024*1024)
        if kind=='checksum': files['content.sqlite']+=b'tampered'
        if kind=='duplicate-json': files['manifest.json']=b'{"format":"bad",'+files['manifest.json'][1:]
        if kind in ['schema','db','trigger','cycle']:
            m=json.loads(files['manifest.json'])
            if kind=='schema':m['schema_version']='9.0.0'
            elif kind=='db':files['content.sqlite']=b'not sqlite'
            else:
                with tempfile.TemporaryDirectory() as td:
                    path=Path(td)/'db.sqlite';path.write_bytes(files['content.sqlite']);db=sqlite3.connect(path)
                    db.execute('CREATE TRIGGER evil AFTER INSERT ON notes BEGIN DELETE FROM notes; END' if kind=='trigger' else 'UPDATE code_nodes SET parent_id=4 WHERE id=1');db.commit();db.close();files['content.sqlite']=path.read_bytes()
            m['content_sha256']=digest(files['content.sqlite']);files['manifest.json']=json_bytes(m)
            files['checksums.sha256']=''.join(f'{digest(files[n])}  {n}\n' for n in ['content.sqlite','manifest.json']).encode()
        with zipfile.ZipFile(target/f'{kind}.icdpack','w',zipfile.ZIP_DEFLATED) as z:
            for name,data in files.items():
                info=zipfile.ZipInfo(name,(2026,1,1,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED
                if kind=='symlink' and name=='content.sqlite':info.external_attr=0o120777<<16
                z.writestr(info,data)
            if kind=='duplicate':z.writestr('content.sqlite',b'duplicate test only')
