"""Small, synthetic fixtures. NOT official data, NOT FOR CLINICAL CODING."""
from pathlib import Path
import json
from .adapters import new_database, add_node, fill_search
from .package import digest, grams, normalized, write_package

def sample(output: Path, revision=1):
    import tempfile
    metadata={
        'package_id':f'sample-demo-v{revision}','package_version':'1.0.0','kind':'icd10cm_combined',
        'classification':'ICD-10-CM','jurisdiction':'SAMPLE','edition':f'SAMPLE-{revision}',
        'release_id':'2026-10-29','effective_from':'2026-10-01','effective_to':'2027-09-30',
        'language':'en+zh-TW','source_organization':'SAMPLE / NOT FOR CLINICAL CODING',
        'source_urls':['sample://synthetic-fixture'],
        'source_files':[{'name':'sample.py','sha256':digest(Path(__file__).read_bytes())}],
        'created_at':'2026-10-29T00:00:00Z','is_sample':True,
        'translation_edition':'SAMPLE-TW','translation_revision':'2026-10-29',
        'mapping_policy':'exact_edition','compatible_base_package_ids':[f'sample-demo-v{revision}']}
    with tempfile.TemporaryDirectory() as td:
        path=Path(td)/'content.sqlite'; db=new_database(path)
        rows=[('@chapter','','chapter','SAMPLE Chapter',None,0,'nonbillable'),('@block','','block','SAMPLE Block',1,0,'nonbillable'),
              ('I50','I50','category','Heart failure',2,0,'incomplete'),('I509','I50.9','subcategory','Heart failure, unspecified' if revision==1 else 'SAMPLE revised heart failure title',3,1,'billable'),
              ('N17','N17','category','Acute kidney failure',2,0,'incomplete'),('N179','N17.9','subcategory','Acute kidney failure, unspecified',5,1,'billable'),
              ('S00','S00','category','SAMPLE injury category',2,0,'requires_extension'),('S000','S00.0','subcategory','SAMPLE placeholder requires seventh character',7,0,'requires_extension')]
        for i,(key,code,kind,title,parent,billable,state) in enumerate(rows,1):
            add_node(db,key,code,parent,kind,title,billable,int(i in (4,6,8)),state,i,'SAMPLE:node:'+str(i),metadata)
        for owner,typ,body,pos in [(1,'includes','SAMPLE chapter note',0),(2,'excludes1','SAMPLE excludes text; verify Tabular',0),(3,'codeFirst','SAMPLE code-first instruction',0),(3,'excludes2','SAMPLE excludes2 instruction',1),(4,'useAdditionalCode','SAMPLE local additional-code note',0),(7,'sevenChrDef','SAMPLE A — initial encounter',0),(8,'placeholder','SAMPLE X placeholder instruction',0)]:
            db.execute('INSERT INTO notes(owner_node_id,note_type,note_text,display_order,source_element,source_reference,raw_xml) VALUES (?,?,?,?,?,?,?)',(owner,typ,body,pos,typ,'SAMPLE:note',f'<note>{body}</note>'))
        entries=[(1,None,'Failure',None,'Failure',None,'alphabetic'),(2,1,'Failure','heart','Failure > heart','I50.9','alphabetic'),(3,2,'Failure','unspecified','Failure > heart > unspecified','I50.9','alphabetic'),(4,None,'SAMPLE injury',None,'SAMPLE injury','S00-S09','external'),(5,None,'SAMPLE neoplasm',None,'SAMPLE neoplasm',None,'neoplasm'),(6,None,'SAMPLE substance',None,'SAMPLE substance',None,'drugs')]
        for i,parent,main,sub,term_path,target,typ in entries:
            db.execute('INSERT INTO index_entries VALUES (?,?,?,?,?,?,?,?,?)',(i,parent,main,sub,term_path,target,typ,i,'SAMPLE:index'))
        db.execute("INSERT INTO index_crossrefs VALUES (1,1,'see','Failure > heart',0)")
        db.execute("INSERT INTO index_crossrefs VALUES (2,2,'seeAlso','SAMPLE injury',1)")
        db.execute("INSERT INTO table_cells VALUES (1,5,'SAMPLE benign','D00-D09',0)")
        db.execute("INSERT INTO table_cells VALUES (2,6,'SAMPLE adverse effect','T00-',0)")
        for i,code,title,status,base in [(1,'I509','心臟衰竭','exact_edition',metadata['package_id']),(2,'N179','腎衰竭','exact_edition',metadata['package_id']),(3,'S000','未確認跨版翻譯','unresolved',None)]:
            db.execute('INSERT INTO translations VALUES (?,?,?,?,?,?,?,?,?,?)',(i,code,title,normalized(title),'SAMPLE-TW','2026-10-29','SAMPLE:translation',status,base,'Synthetic translation'))
            db.executemany('INSERT INTO zh_ngrams VALUES (?,?,?)',[(g,code,i) for g in sorted(grams(title))])
        fill_search(db); db.close()
        return write_package(path,metadata,output)
