"""Synthetic Index guidance/pagination fixture. Never official coding content."""
from pathlib import Path
import tempfile
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from tools.data_builder.adapters import new_database, add_node, fill_search
from tools.data_builder.package import write_package


def sample(output):
    meta=dict(package_id='sample-index-guidance-v1',package_version='1.0.0',classification='ICD-10-CM',
              kind='icd10cm_en',jurisdiction='SAMPLE',edition='SAMPLE-FY2025',release_id='SAMPLE',
              effective_from='2024-10-01',effective_to='2025-09-30',language='en',
              source_organization='SAMPLE / NOT FOR CLINICAL CODING',source_urls=['sample://index-guidance'],
              source_files=[dict(name='synthetic-inline',sha256='0'*64)],created_at='2026-10-31T00:00:00Z',is_sample=True)
    with tempfile.TemporaryDirectory() as td:
        path=Path(td)/'content.sqlite';db=new_database(path)
        for i,(code,title) in enumerate([('E10.21','SAMPLE Type 1 diabetes with diabetic nephropathy'),('E11.9','SAMPLE Type 2 diabetes without complications'),('E11.44','SAMPLE Type 2 diabetes amyotrophy'),('I50.9','SAMPLE heart failure')]):
            add_node(db,code,code,None,'subcategory',title,1,1,'billable',i,'SAMPLE',meta)
        order=0
        def term(title,parent=None,target=None,kind='alphabetic'):
            nonlocal order
            main,path=(title,title) if parent is None else db.execute('SELECT main_term,term_path FROM index_entries WHERE id=?',(parent,)).fetchone()
            if parent is not None:path+=' > '+title
            order+=1
            return db.execute('INSERT INTO index_entries(parent_id,main_term,sub_term,term_path,target_code,entry_type,display_order,source_reference) VALUES (?,?,?,?,?,?,?,?)',
                (parent,main,title if parent is not None else None,path,target,kind,order,'SAMPLE:row:'+str(order))).lastrowid
        root=term('Diabetes, diabetic (SAMPLE)',target='E11.9');with_=term('with',root)
        term('amyotrophy SAMPLE',with_,'E11.44');term('chronic kidney disease SAMPLE',with_,'E11.9')
        for i in range(110):term(f'SAMPLE modifier {i:03}',with_,'E11.9')
        for num in (1,2):
            t=term(f'type {num}',root);term('with',t);term('SAMPLE complication',t,'E11.9')
        failure=term('Failure, failed (SAMPLE)');term('heart SAMPLE',failure,'I50.9')
        ref=term('Reference-only SAMPLE')
        db.execute('INSERT INTO index_crossrefs(index_entry_id,ref_type,target_term,display_order) VALUES (?,?,?,?)',(ref,'see','Diabetes, diabetic (SAMPLE)',0))
        term('drug SAMPLE',kind='drugs');term('fall SAMPLE',kind='external')
        fill_search(db);db.close()
        return write_package(path,meta,output)

if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();sample(a.output)
