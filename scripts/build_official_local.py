"""Build reviewed profiles from local official files; no HTTP, no overwrites."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from tools.data_builder.build import build
from tools.data_builder.audit import audit
from tools.data_builder.audit_nhi import audit as audit_nhi

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-dir',type=Path,required=True)
    parser.add_argument('--output-dir',type=Path,required=True)
    parser.add_argument('--profile',action='append',help='Profile basename without .json; omit for all')
    args=parser.parse_args()
    paths=sorted((ROOT/'docs/source_profiles').glob('*.json'))
    if args.profile:
        names={p.stem for p in paths}
        if not set(args.profile)<=names: parser.error('Unknown profile')
        paths=[p for p in paths if p.stem in args.profile]
    for path in paths:
        profile=json.loads(path.read_text(encoding='utf-8'))
        extension='.icdpack' if profile.get('output_type','icdpack') in ('icdpack','pcs_app','nhi_pcs_app','nhi_cm_app','nhi_legacy_app') else '.sqlite'
        output=args.output_dir/(path.stem+extension)
        if output.exists() or output.with_suffix('.build-report.json').exists():
            raise FileExistsError('Existing output preserved: '+str(output))
    report={}
    for path in paths:
        profile=json.loads(path.read_text(encoding='utf-8'));kind=profile.get('output_type','icdpack')
        output=args.output_dir/(path.stem+('.icdpack' if kind in ('icdpack','pcs_app','nhi_pcs_app','nhi_cm_app','nhi_legacy_app') else '.sqlite'))
        print('BUILD '+path.stem,flush=True)
        result=build(args.source_dir,path,output)
        audit_result=None
        if kind in ('icdpack','pcs_app','nhi_pcs_app','nhi_cm_app','nhi_legacy_app'):
            if kind == 'nhi_legacy_app':
                from tools.data_builder.audit_nhi_legacy import audit as audit_legacy
                audit_result=audit_legacy(output,args.source_dir,profile)
            elif kind == 'nhi_cm_app':
                from tools.data_builder.audit_nhi_cm import audit as audit_cm
                audit_result=audit_cm(output,args.source_dir,profile)
            elif kind in ('pcs_app','nhi_pcs_app'):
                from tools.data_builder.audit_pcs import audit as audit_pcs
                audit_result=audit_pcs(output,args.source_dir,profile)
            elif profile['metadata']['kind']=='icd10cm_en':
                audit_result=audit(output,[args.source_dir/name for name in profile['inputs']])
            else:
                translation=profile['translation'];cols=translation['columns']
                audit_result=audit_nhi(output,args.source_dir/translation['file'],cols['code'],cols['title_zh_tw'],cols.get('sheet'))
            if not audit_result['passed']: raise ValueError('Source audit failed: '+path.stem)
            output.with_suffix('.audit.json').write_text(json.dumps(audit_result,ensure_ascii=False,indent=2)+'\n')
        report[path.stem]={'file':output.name,'sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'bytes':output.stat().st_size,'row_counts':result['row_counts'],'source_audit':audit_result}
        print('PASS '+path.stem+' '+str(result['row_counts']),flush=True)
    destination=args.output_dir/('batch-'+('-'.join(args.profile) if args.profile else 'all')+'.json')
    with destination.open('x',encoding='utf-8') as f:json.dump(report,f,ensure_ascii=False,indent=2)
