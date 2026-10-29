"""Independent official source-to-App-pack roster, axis XML and Index audit."""
import argparse,json,re,sqlite3,tempfile
from pathlib import Path
from lxml import etree as ET
from .package import verify,code_key
from .adapters import source_files,xml_root,text
from .spreadsheets import mapped_records


def audit(package,source_dir,profile):
    with tempfile.TemporaryDirectory() as td:
        manifest=verify(package,Path(td)); db=sqlite3.connect(Path(td)/'content.sqlite')
        paths=[source_dir/n for n in profile['inputs']]
        mode=profile['output_type']; mismatches=[]
        if mode=='pcs_app':
            files=source_files(paths)
            raw_order=next(raw for n,raw in files if re.search(r'icd10pcs_order_\d{4}\.txt$',n))
            expected={}
            for line in raw_order.decode('utf-8-sig').splitlines():
                if line.strip():expected[line[6:13].strip()]=(int(line[14]),line[77:])
            actual={code:(billable,title) for code,billable,title in db.execute("SELECT code,billable,title_en FROM code_nodes WHERE code!=''")}
            if actual!=expected:mismatches.append('order code/state/long title')
            expected_tables={}; source_index={}; expected_docs={}
            for name,raw in files:
                if not name.endswith('.xml'):continue
                root=xml_root(raw); expected_docs[name]=raw.decode('utf-8-sig')
                if root.tag=='ICD10PCS.tabular':
                    for table in root.findall('pcsTable'):
                        prefix=''.join(table.find(f"axis[@pos='{p}']/label").get('code') for p in (1,2,3))
                        expected_tables[prefix]=ET.tostring(table,encoding='unicode')
                if root.tag=='ICD10PCS.index':
                    def walk(e,path=()):
                        current=(*path,text(e.find('title')))
                        targets=[child for c in e if c.tag in ('codes','tab') for child in [c]]
                        targets+= [x for c in e if c.tag in ('see','use') for x in c if x.tag in ('codes','tab')]
                        # Preserve the projection's documented first explicit target policy.
                        preferred=e.findall('./codes')+e.findall('./tab')+e.findall('./see/codes')+e.findall('./see/tab')+e.findall('./use/codes')+e.findall('./use/tab')
                        source_index[name+':'+root.getroottree().getpath(e)]=(' > '.join(current),text(preferred[0]) if preferred else None)
                        for child in e.findall('term'):walk(child,current)
                    for term in root.findall('./letter/mainTerm'):walk(term)
            actual_tables={code:raw for code,raw in db.execute("SELECT n.code,t.raw_xml FROM notes t JOIN code_nodes n ON n.id=t.owner_node_id WHERE t.note_type='pcs_table'")}
            actual_index={ref:(path,target) for ref,path,target in db.execute('SELECT source_reference,term_path,target_code FROM index_entries')}
            actual_docs=dict(db.execute("SELECT source_reference,raw_xml FROM notes WHERE note_type='pcs_source_document'"))
            if actual_tables!=expected_tables:mismatches.append('complete table XML / row grouping / axes')
            if actual_index!=source_index:mismatches.append('Index path / source node / explicit target')
            if actual_docs!=expected_docs:mismatches.append('full original source XML documents')
            report={'source_order_rows':len(expected),'complete_codes':sum(x[0] for x in expected.values()),'source_tables':len(expected_tables),'source_index_entries':len(source_index),'original_xml_documents':len(expected_docs)}
        elif mode=='nhi_pcs_app':
            cols=profile['translation']['columns']; count=0
            expected={}
            for line,row in mapped_records(paths[0],cols):
                expected[row[cols['code']]]=(row[cols['title_en']],int(row[cols['use']]),row[cols['title_zh_tw']],row)
            actual={}
            for code,title,billable,zh,status,base,raw in db.execute("SELECT n.code,n.title_en,n.billable,t.title_zh_tw,t.mapping_status,t.base_package_id,s.note_text FROM code_nodes n JOIN translations t ON t.code_normalized=n.code_normalized JOIN notes s ON s.owner_node_id=n.id AND s.note_type='nhi_source_columns'"):
                actual[code]=(title,billable,zh,json.loads(raw))
                if status!='exact_edition' or base!=manifest['package_id']:mismatches.append('NHI same-edition mapping')
            if actual!=expected:mismatches.append('NHI PCS original English/Chinese/USE/all source columns')
            report={'source_bilingual_rows':len(expected),'package_bilingual_rows':len(actual),'us_cross_release_compatibility_claim':False}
        else:raise ValueError('Expected PCS App profile')
        db.close()
        return report|{'package_sha256':manifest['archive_sha256'],'classification':manifest['classification'],'edition':manifest['edition'],'mismatches':mismatches,'passed':not mismatches}

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--package',type=Path,required=True);p.add_argument('--source-dir',type=Path,required=True);p.add_argument('--profile',type=Path,required=True)
    a=p.parse_args(); result=audit(a.package,a.source_dir,json.loads(a.profile.read_text(encoding='utf-8')))
    print(json.dumps(result,ensure_ascii=False,indent=2));raise SystemExit(0 if result['passed'] else 1)
