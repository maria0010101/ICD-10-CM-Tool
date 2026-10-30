"""All-row source audit, including bilingual row provenance and inert auxiliary text."""
import json
from pathlib import Path
import re
import sqlite3
import tempfile
from .package import code_key, verify
from .spreadsheets import ods_rows


def audit(package, source_dir, profile):
    spec=profile['legacy_layout']; source=source_dir/profile['inputs'][0]
    expected={}; original={}; refs=[]; headings={}; previous=None
    for sheet,num,row in ods_rows(source,inert_formula_columns=spec.get('inert_formula_columns')):
        ref=source.name+':'+sheet+':row:'+str(num)
        item={'reference':ref,'cells':row}
        if sheet in spec['reference_sheets']:
            refs.append(item);continue
        if num==1:headings[ref]=item;continue
        if num==2:continue
        if row[0].strip():
            key=code_key(row[0].strip());expected[key]=[row[0].strip(),row[1],None,ref,None]
            original[key]=[item];previous=key
        else:
            expected[previous][2]=row[1];expected[previous][4]=ref;original[previous].append(item)
    with tempfile.TemporaryDirectory() as td:
        manifest=verify(package,Path(td));db=sqlite3.connect(Path(td)/'content.sqlite')
        try:
            actual={key:[code,en,zh,ref,tr] for key,code,en,zh,ref,tr in db.execute('SELECT n.code_normalized,n.code,n.title_en,t.title_zh_tw,n.source_reference,t.source_reference FROM code_nodes n LEFT JOIN translations t ON t.code_normalized=n.code_normalized WHERE n.code!=\'\'')}
            raw={key:json.loads(body) for key,body in db.execute("SELECT n.code_normalized,s.note_text FROM code_nodes n JOIN notes s ON s.owner_node_id=n.id WHERE s.note_type='nhi_source_rows'")}
            reference=[json.loads(r[0]) for r in db.execute("SELECT note_text FROM notes WHERE note_type='nhi_revision_reference' ORDER BY display_order")]
            actual_headings={ref:json.loads(body) for ref,body in db.execute("SELECT source_reference,note_text FROM notes WHERE note_type='nhi_source_heading'")}
            mismatches=[]
            for label,e,a in [('code/en/zh/references',expected,actual),('all source cells',original,raw),('separate revision rows',refs,reference),('sheet headings',headings,actual_headings)]:
                if e!=a:mismatches.append(label)
            if db.execute('SELECT count(*) FROM code_nodes WHERE billable!=0').fetchone()[0]:mismatches.append('invented billability')
            if manifest.get('code_status_policy')!='not_provided':mismatches.append('missing unknown state policy')
            if manifest.get('compatible_base_package_ids')!=[manifest['package_id']]:mismatches.append('cross-edition claim')
            if db.execute("SELECT count(*) FROM translations WHERE mapping_status!='exact_edition' OR base_package_id!=?",(manifest['package_id'],)).fetchone()[0]:mismatches.append('translation edition')
            if db.execute('SELECT count(*) FROM index_entries').fetchone()[0]:mismatches.append('unprovided Index')
            return dict(passed=not mismatches,mismatches=mismatches,source_codes=len(expected),package_codes=len(actual),
                        source_translations=sum(r[2] is not None for r in expected.values()),reference_rows=len(refs),
                        all_original_cells_checked=True,package_sha256=manifest['archive_sha256'],edition=manifest['edition'])
        finally:db.close()
