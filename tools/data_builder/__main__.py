from __future__ import annotations
import argparse
import json
from pathlib import Path
import sys
import tempfile
from .adapters import new_database, import_cdc, import_nhi, fill_search, source_files, xml_root
from .package import PackageError, digest, json_bytes, verify, write_package
from .sample import sample

def main():
    p=argparse.ArgumentParser(description='Offline ICD package builder 0.1.1')
    sub=p.add_subparsers(dest='command',required=True)
    sub.add_parser('gui',help='Open local desktop builder')
    a=sub.add_parser('sample'); a.add_argument('--output',type=Path,required=True); a.add_argument('--revision',type=int,default=1)
    a=sub.add_parser('verify'); a.add_argument('--package',type=Path,required=True)
    a=sub.add_parser('validate-source'); a.add_argument('--input',type=Path,required=True)
    a=sub.add_parser('build'); a.add_argument('--source-dir',type=Path,required=True); a.add_argument('--profile',type=Path,required=True); a.add_argument('--output',type=Path,required=True)
    args=p.parse_args()
    if args.command=='gui':
        from .gui import main as gui_main
        return gui_main()
    if args.command=='sample': result=sample(args.output,args.revision)
    elif args.command=='verify': result=verify(args.package)
    elif args.command=='validate-source':
        files=source_files([args.input]); result={'files':[{'name':n,'sha256':digest(raw),'bytes':len(raw),'xml_root':xml_root(raw).tag if n.endswith('.xml') else None} for n,raw in files]}
    else:
        profile=json.loads(args.profile.read_text(encoding='utf-8'))
        meta=profile['metadata']; inputs=profile['inputs']
        paths=[args.source_dir/x for x in inputs]
        if not all(p.resolve().is_relative_to(args.source_dir.resolve()) for p in paths): raise PackageError('profile input outside source-dir')
        meta['source_files']=[{'name':p.name,'sha256':digest(p.read_bytes())} for p in paths]
        report={}
        with tempfile.TemporaryDirectory() as td:
            db_path=Path(td)/'content.sqlite'; db=new_database(db_path)
            if meta['kind']!='icd10cm_zh_tw': report['cdc']=import_cdc(db,paths,meta)
            if profile.get('translation'):
                translation=profile['translation']; path=args.source_dir/translation['file']
                if path not in paths: raise PackageError('Translation file must be listed in inputs')
                report['nhi']=import_nhi(db,path,translation['columns'],meta)
            fill_search(db); db.close()
            result=write_package(db_path,meta,args.output)
        args.output.with_suffix('.build-report.json').write_bytes(json_bytes(report))
    print(json.dumps(result,ensure_ascii=False,indent=2))

if __name__=='__main__':
    try: main()
    except Exception as e:
        print(f'ERROR: {type(e).__name__}: {e}',file=sys.stderr); sys.exit(1)
