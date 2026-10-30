"""Reusable, version-explicit build entry point for CLI and desktop profiles."""
from __future__ import annotations
import json
from pathlib import Path
import tempfile
from .adapters import new_database, import_cdc, import_nhi, fill_search
from .package import PackageError, digest, json_bytes, write_package


def profile_inputs(source_dir: Path, profile: dict):
    paths = [source_dir / name for name in profile['inputs']]
    if not all(p.resolve().is_relative_to(source_dir.resolve()) for p in paths):
        raise PackageError('profile input outside source-dir')
    for name, path in zip(profile['inputs'], paths):
        if not path.is_file(): raise PackageError('Missing official source: ' + name)
        expected = profile.get('input_sha256', {}).get(name)
        if expected and digest(path.read_bytes()) != expected:
            raise PackageError('Source SHA256 differs from reviewed profile: ' + name)
    return paths


def build(source_dir: Path, profile_path: Path, output: Path):
    if output.exists(): raise FileExistsError('Existing artifact preserved: ' + str(output))
    report_path = output.with_suffix('.build-report.json')
    if report_path.exists(): raise FileExistsError('Existing report preserved: ' + str(report_path))
    profile = json.loads(profile_path.read_text(encoding='utf-8'))
    paths = profile_inputs(source_dir, profile)
    meta = dict(profile['metadata'])
    meta['source_files'] = [{'name':p.name, 'sha256':digest(p.read_bytes())} for p in paths]
    mode = profile.get('output_type', 'icdpack')
    if mode == 'nhi_legacy_app':
        from .nhi_legacy import import_legacy
        if len(paths) != 1: raise PackageError('One explicit NHI 2014 ODS required')
        with tempfile.TemporaryDirectory() as td:
            db_path = Path(td)/'content.sqlite'; db = new_database(db_path)
            try:
                report = {'projection':import_legacy(db,paths[0],profile,meta)}
                fill_search(db)
            finally: db.close()
            result = write_package(db_path,meta,output)
    elif mode == 'nhi_cm_app':
        from .nhi_cm_pack import import_nhi_cm_app
        if len(paths) != 1: raise PackageError('One explicit NHI source required')
        with tempfile.TemporaryDirectory() as td:
            db_path = Path(td)/'content.sqlite'; db = new_database(db_path)
            try:
                report = {'projection':import_nhi_cm_app(db,paths[0],profile['translation']['columns'],meta)}
                fill_search(db)
            finally: db.close()
            result = write_package(db_path,meta,output)
    elif mode in ('pcs_app','nhi_pcs_app'):
        from .pcs_pack import build_pcs_pack
        result, report = build_pcs_pack(paths,meta,output,mode,profile)
    elif mode != 'icdpack':
        from .source_tables import build_source_tables
        result, report = build_source_tables(paths, meta, output, mode)
    else:
        if meta.get('classification') != 'ICD-10-CM': raise PackageError('Only CM belongs in an App .icdpack; PCS uses separate SQLite tables')
        report = {}
        with tempfile.TemporaryDirectory() as td:
            db_path = Path(td) / 'content.sqlite'; db = new_database(db_path)
            try:
                if meta['kind'] != 'icd10cm_zh_tw': report['cdc'] = import_cdc(db, paths, meta)
                if profile.get('translation'):
                    translation = profile['translation']; path = source_dir / translation['file']
                    if path not in paths: raise PackageError('Translation file must be listed in inputs')
                    report['nhi'] = import_nhi(db, path, translation['columns'], meta)
                fill_search(db)
            finally: db.close()
            result = write_package(db_path, meta, output)
    report['profile_sha256'] = digest(profile_path.read_bytes())
    report['source_files'] = meta['source_files']
    report_path.write_bytes(json_bytes(report))
    return result


def catalog(source_dir: Path):
    from .package import ROOT
    found = []
    for profile_path in sorted((ROOT / 'docs/source_profiles').glob('*.json')):
        profile = json.loads(profile_path.read_text(encoding='utf-8'))
        missing = [name for name in profile['inputs'] if not (source_dir / name).is_file()]
        found.append({'profile':profile_path.name, 'label':profile['label'],
                      'output_type':profile.get('output_type', 'icdpack'), 'missing_files':missing,
                      'ready':not missing, 'inputs':profile['inputs']})
    return {'profiles':found, 'notice':'Select one explicit release; filenames alone are not proof of edition. Build checks pinned source hashes.'}
