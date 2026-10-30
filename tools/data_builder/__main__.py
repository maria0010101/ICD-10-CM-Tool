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
    p=argparse.ArgumentParser(description='Offline ICD package builder 0.2.3')
    sub=p.add_subparsers(dest='command',required=True)
    sub.add_parser('gui',help='Open local desktop builder')
    a=sub.add_parser('sample'); a.add_argument('--output',type=Path,required=True); a.add_argument('--revision',type=int,default=1)
    a=sub.add_parser('verify'); a.add_argument('--package',type=Path,required=True)
    a=sub.add_parser('validate-source'); a.add_argument('--input',type=Path,required=True)
    a=sub.add_parser('catalog'); a.add_argument('--source-dir',type=Path,required=True)
    a=sub.add_parser('inspect-sheet'); a.add_argument('--input',type=Path,required=True)
    a=sub.add_parser('build'); a.add_argument('--source-dir',type=Path,required=True); a.add_argument('--profile',type=Path,required=True); a.add_argument('--output',type=Path,required=True)
    args=p.parse_args()
    if args.command=='gui':
        from .gui import main as gui_main
        return gui_main()
    if args.command=='sample': result=sample(args.output,args.revision)
    elif args.command=='verify': result=verify(args.package)
    elif args.command=='validate-source':
        files=source_files([args.input]); result={'files':[{'name':n,'sha256':digest(raw),'bytes':len(raw),'xml_root':xml_root(raw).tag if n.endswith('.xml') else None} for n,raw in files]}
    elif args.command=='catalog':
        from .build import catalog
        result=catalog(args.source_dir)
    elif args.command=='inspect-sheet':
        from .spreadsheets import ods_rows
        result={'sheets':{}}
        for sheet,number,row in ods_rows(args.input):
            item=result['sheets'].setdefault(sheet, {'header':row,'nonempty_rows':0})
            item['nonempty_rows']+=1
    else:
        from .build import build
        result=build(args.source_dir,args.profile,args.output)
    print(json.dumps(result,ensure_ascii=False,indent=2))

if __name__=='__main__':
    try: main()
    except Exception as e:
        print(f'ERROR: {type(e).__name__}: {e}',file=sys.stderr); sys.exit(1)
