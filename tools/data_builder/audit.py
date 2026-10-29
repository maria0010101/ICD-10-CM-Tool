"""Independent source-to-package counts/content audit for the CDC v2027 adapter.

Run only with actual local official ZIPs; writes evidence, never fetches sources.
"""
import json
from pathlib import Path
import sqlite3
import tempfile
import zipfile
from lxml import etree as ET
from .package import verify
from .adapters import source_files, parse_order, text, NOTES

def audit(package: Path, inputs: list[Path]):
    with tempfile.TemporaryDirectory() as td:
        target=Path(td); manifest=verify(package,target);db=sqlite3.connect(target/'content.sqlite')
        files=source_files(inputs);roots={n:ET.fromstring(raw) for n,raw in files if n.endswith('.xml')}
        order=next(parse_order(raw) for n,raw in files if 'order-2027.txt' in n)
        actual={r[0]:(r[1],r[2]) for r in db.execute("SELECT code_normalized,billable,title_en FROM code_nodes WHERE code!=''")}
        missing=sorted(set(order)-set(actual));extra=sorted(set(actual)-set(order))
        billable=[c for c,(b,t,s) in order.items() if c in actual and actual[c][0]!=b]
        desc=[c for c,(b,t,s) in order.items() if c in actual and actual[c][1]!=t]
        idx_counts={};refs=0;cells=0;expected_notes=[];node_count=0
        for name,root in roots.items():
            if root.tag=='ICD10CM.tabular':
                node_count=len(root.findall('.//chapter'))+len(root.findall('.//section'))+len(root.findall('.//diag'))
                for i in root.findall('./introduction/introSection'):expected_notes.append((name+':/introduction','introduction',text(i)))
                for owner in root.iter():
                    if owner.tag not in ('chapter','section','diag'):continue
                    for child in owner:
                        if child.tag in NOTES:
                            for item in ([child] if child.tag=='visualImpairment' or not len(child) else list(child)):
                                display=text(item)
                                if item.tag=='extension':display=item.get('char','')+' — '+display
                                expected_notes.append((name+':'+root.getroottree().getpath(owner)+'/'+child.tag,child.tag,display))
            else:
                kind='drugs' if 'drug' in name else 'neoplasm' if 'neoplasm' in name else 'external' if 'eindex' in name else 'alphabetic'
                idx_counts[kind]=len(root.findall('.//term'))+len(root.findall('.//mainTerm'))
                refs+=sum(len(root.findall('.//'+tag)) for tag in ['see','seeAlso','manif','subcat','seecat'])
                cells+=len(root.findall('.//cell'))
        actual_notes=db.execute('SELECT source_reference,note_type,note_text FROM notes ORDER BY id').fetchall()
        actual_idx=dict(db.execute('SELECT entry_type,count(*) FROM index_entries GROUP BY entry_type'))
        report={'package_sha256':manifest['archive_sha256'],'edition':manifest['edition'],'source_order_codes':len(order),'package_codes':len(actual),'missing_codes':missing,'extra_codes':extra,'billable_mismatch':billable,'description_differences_tabular_vs_order':desc,'source_tabular_nodes':node_count,'source_notes':len(expected_notes),'notes_exact_order_and_text_match':sorted(expected_notes)==sorted(actual_notes),'source_index_counts':idx_counts,'package_index_counts':actual_idx,'source_crossrefs':refs,'package_crossrefs':db.execute('SELECT count(*) FROM index_crossrefs').fetchone()[0],'source_table_cells':cells,'package_table_cells':db.execute('SELECT count(*) FROM table_cells').fetchone()[0]}
        from collections import defaultdict
        groups_a=defaultdict(list);groups_b=defaultdict(list)
        for source,kind,body in expected_notes:groups_a[(source,kind)].append(body)
        for source,kind,body in actual_notes:groups_b[(source,kind)].append(body)
        report['notes_exact_order_and_text_match']=dict(groups_a)==dict(groups_b)
        report['description_difference_policy']='Preserve Tabular title verbatim; use Order titles only for generated seventh-character leaves. No search normalization changes displayed source text.'
        report['passed']=not(missing or extra or billable) and report['notes_exact_order_and_text_match'] and idx_counts==actual_idx and refs==report['package_crossrefs'] and cells==report['package_table_cells']
        db.close();return report

if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser();p.add_argument('--package',type=Path,required=True);p.add_argument('--input',type=Path,action='append',required=True)
    args=p.parse_args();result=audit(args.package,args.input);print(json.dumps(result,ensure_ascii=False,indent=2));raise SystemExit(0 if result['passed'] else 1)
