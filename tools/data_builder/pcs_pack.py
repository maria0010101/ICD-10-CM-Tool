"""PCS projection into the shared v1 SQLite shape; requires classification API 1.1.

Rich axis rows and raw source XML are retained as typed notes, not CM notes.
"""
from __future__ import annotations
import json
from pathlib import Path
import sqlite3
import tempfile
from lxml import etree as ET
from .adapters import add_node, new_database, fill_search, text, xml_root
from .source_tables import SCHEMA, import_pcs
from .spreadsheets import mapped_records
from .package import PackageError, code_key, grams, normalized, write_package


def _note(db, owner, kind, body, reference, raw='', order=0):
    db.execute('INSERT INTO notes(owner_node_id,note_type,note_text,display_order,source_element,source_reference,raw_xml) VALUES (?,?,?,?,?,?,?)',
               (owner,kind,body,order,kind,reference,raw))


def import_pcs_app(db, source, meta):
    """Source is our freshly parsed/validated PCS scratch DB, never external SQL."""
    sections={}; systems={}; operations={}; count=0
    def node(key,code,parent,kind,title,billable,leaf,state,ref):
        nonlocal count
        count+=1
        return add_node(db,key,code,parent,kind,title,billable,leaf,state,count,ref,meta)
    order={r[0]:r[1:] for r in source.execute('SELECT code,billable,short_title,long_title,display_order,source_reference FROM pcs_codes')}
    for ident,prefix,raw,reference in source.execute('SELECT id,prefix,raw_xml,source_reference FROM pcs_tables ORDER BY id'):
        table=xml_root(raw.encode()); shared={int(a.get('pos')):a for a in table.findall('axis')}
        section=prefix[0]; system=prefix[:2]
        if section not in sections:
            sections[section]=node('@pcs-section:'+section,'',None,'chapter',text(shared[1].find('label')),0,0,'nonbillable',reference+'/axis[1]')
        if system not in systems:
            systems[system]=node('@pcs-system:'+system,'',sections[section],'block',text(shared[2].find('label')),0,0,'nonbillable',reference+'/axis[2]')
        heading=order.get(prefix)
        if heading is None or heading[0]!=0: raise PackageError('PCS table has no nonbillable official order heading')
        operation=node(prefix,prefix,systems[system],'category',heading[2],0,0,'incomplete',heading[4]+':'+prefix)
        operations[prefix]=operation
        def axis(a):
            return {'position':int(a.get('pos')),'title':text(a.find('title')),'definition':text(a.find('definition')),
                    'labels':[{'code':l.get('code'),'label':text(l)} for l in a.findall('label')]}
        body={'prefix':prefix,'axes':[axis(shared[p]) for p in (1,2,3)],
              'rows':[{'order':i,'codes':int(r.get('codes')),'axes':[axis(a) for a in r.findall('axis')]} for i,r in enumerate(table.findall('pcsRow'))]}
        _note(db,operation,'pcs_table',json.dumps(body,ensure_ascii=False),reference,raw)
    for code,(billable,short,long,pos,ref) in order.items():
        if not billable: continue
        parent=operations.get(code[:3])
        if parent is None: raise PackageError('PCS full code missing table')
        ident=node(code,code,parent,'subcategory',long,1,1,'billable',ref+':'+code)
        _note(db,ident,'pcs_short_title',short,ref+':'+code)
    main_terms = {}
    for ident,parent,title,path,pos,ref,raw in source.execute('SELECT * FROM pcs_index_entries ORDER BY id'):
        root=xml_root(raw.encode()); targets=root.findall('./codes')+root.findall('./tab')+root.findall('./see/codes')+root.findall('./see/tab')+root.findall('./use/codes')+root.findall('./use/tab')
        target=text(targets[0]) if targets else None
        main_terms[ident] = title if parent is None else main_terms[parent]
        db.execute('INSERT INTO index_entries VALUES (?,?,?,?,?,?,?,?,?)',(ident,parent,main_terms[ident],title if parent else None,path,target,'alphabetic',pos,ref))
    for ident,entry,kind,target,pos,raw in source.execute('SELECT * FROM pcs_index_refs ORDER BY id'):
        db.execute('INSERT INTO index_crossrefs VALUES (?,?,?,?,?)',(ident,entry,kind,target,pos))
    source_owner=node('@pcs-source-documents','',None,'chapter','官方 PCS 原始來源（非處置碼）',0,1,'nonbillable','CMS source documents')
    for ident,section,axis,title,definition,explanation,includes,ref,raw in source.execute('SELECT * FROM pcs_definitions ORDER BY id'):
        owner=sections.get(section,source_owner)
        _note(db,owner,'pcs_definition',' — '.join(x for x in (title,definition,explanation,includes) if x),ref,raw,ident)
    # Source documents are in a separate root, NOT ancestors of every code.
    for ident,ref,tag,sha,raw in source.execute('SELECT * FROM source_documents ORDER BY id'):
        _note(db,source_owner,'pcs_source_document',ref+' · SHA256 '+sha,ref,raw.decode('utf-8-sig'),ident)
    return {'complete_codes':sum(r[0] for r in order.values()),'order_rows':len(order),'source_tables':len(operations),'source_index_entries':source.execute('SELECT count(*) FROM pcs_index_entries').fetchone()[0]}


def import_nhi_pcs_app(db,path,columns,meta):
    if columns.get('sheet')!='ICD-10-PCS': raise PackageError('NHI PCS requires explicit ICD-10-PCS sheet')
    root=add_node(db,'@nhi-pcs-source','',None,'chapter','健保署2023 PCS 中英對照（前綴導覽，非美國七軸表）',0,0,'nonbillable',0,path.name,meta)
    _note(db,root,'source_scope','此包僅含健保署2023同版中英代碼對照、USE與來源欄位；沒有美國FY2027七軸、Index或跨版相容聲明。',path.name)
    groups={}; count=0
    for line,row in mapped_records(path,columns):
        code=row[columns['code']]; en=row[columns['title_en']]; zh=row[columns['title_zh_tw']]; use=row[columns['use']]
        import re
        if not re.fullmatch(r'[0-9A-HJ-NP-Z]{7}',code) or use not in ('0','1') or not en or not zh: raise PackageError('Invalid NHI PCS source row '+str(line))
        prefix=code[:3]; ref=path.name+':ICD-10-PCS:row:'+str(line)
        if prefix not in groups:
            groups[prefix]=add_node(db,'@nhi-pcs-prefix:'+prefix,'',root,'category',prefix+'（前綴分組，非官方階層名稱）',0,0,'nonbillable',count,ref,meta)
        billable=int(use)
        node=add_node(db,code,code,groups[prefix],'subcategory',en,billable,1,'billable' if billable else 'nonbillable',count,ref,meta)
        _note(db,node,'nhi_source_columns',json.dumps(row,ensure_ascii=False),ref)
        ident=db.execute('INSERT INTO translations(code_normalized,title_zh_tw,search_normalized,translation_edition,translation_revision,source_reference,mapping_status,base_package_id,notes) VALUES (?,?,?,?,?,?,?,?,?)',
            (code,zh,normalized(zh),meta['translation_edition'],meta['translation_revision'],ref,'exact_edition',meta['package_id'],'NHI same-edition bilingual source row, not a US cross-release mapping')).lastrowid
        db.executemany('INSERT INTO zh_ngrams VALUES (?,?,?)',[(g,code,ident) for g in sorted(grams(zh))]);count+=1
    if not count: raise PackageError('Empty NHI PCS sheet')
    return {'same_edition_bilingual_rows':count,'no_us_fy2027_compatibility_claim':True}


def build_pcs_pack(paths,meta,output,mode,profile):
    with tempfile.TemporaryDirectory() as td:
        content=Path(td)/'content.sqlite'; db=new_database(content)
        try:
            if mode=='pcs_app':
                source=sqlite3.connect(Path(td)/'pcs.sqlite')
                try:
                    source.executescript(SCHEMA);report={'source':import_pcs(source,paths,meta)}
                    report['projection']=import_pcs_app(db,source,meta)
                finally:source.close()
            else:
                if len(paths)!=1: raise PackageError('One explicit NHI ODS required')
                report={'projection':import_nhi_pcs_app(db,paths[0],profile['translation']['columns'],meta)}
            fill_search(db)
        finally:db.close()
        result=write_package(content,meta,output)
    return result,report


def sample_pcs(output):
    """Small synthetic PCS fixture; not official and not for clinical coding."""
    import zipfile
    from .package import digest
    with tempfile.TemporaryDirectory() as td:
        source=Path(td)/'SAMPLE-pcs.zip'
        def axis(pos, chars):
            return f'<axis pos="{pos}" values="{len(chars)}"><title>SAMPLE axis {pos}</title>'+''.join(f'<label code="{c}">SAMPLE {c}</label>' for c in chars)+'</axis>'
        table='<ICD10PCS.tabular><version>2027</version><pcsTable>'+''.join(axis(p,c) for p,c in enumerate('001',1))+'<pcsRow codes="2">'+''.join(axis(p,c) for p,c in [(4,'6'),(5,'0'),(6,'7'),(7,'01')])+'</pcsRow></pcsTable></ICD10PCS.tabular>'
        index='<ICD10PCS.index><version>2027</version><letter><mainTerm><title>SAMPLE Bypass</title><term><title>ventricle</title><codes>0016070</codes></term><see>SAMPLE reference<tab>001</tab></see></mainTerm></letter></ICD10PCS.index>'
        definitions='<ICD10PCS.definitions><version>2027</version><section code="0"><axis pos="3"><terms><title>SAMPLE operation</title><definition>SAMPLE definition</definition></terms></axis></section></ICD10PCS.definitions>'
        entries={'icd10pcs_tables_2027.xml':table,'icd10pcs_index_2027.xml':index,'icd10pcs_definitions_2027.xml':definitions,
                 'icd10pcs_order_2027.txt':''.join(f'{i:05d} {code:7s} {billable} {"SAMPLE short":60s} {title}\n' for i,(code,billable,title) in enumerate([('001',0,'SAMPLE incomplete heading'),('0016070',1,'SAMPLE Bypass ventricle'),('0016071',1,'SAMPLE Bypass second target')],1)),
                 'icd10pcs_codes_2027.txt':'0016070 SAMPLE Bypass ventricle\n0016071 SAMPLE Bypass second target\n'}
        with zipfile.ZipFile(source,'w') as archive:
            for name,body in entries.items():archive.writestr(zipfile.ZipInfo(name,(2026,1,1,0,0,0)),body)
        meta=dict(package_id='sample-pcs-v1',package_version='1.0.0',kind='icd10pcs_en',classification='ICD-10-PCS',jurisdiction='SAMPLE',edition='FY2027 SAMPLE PCS',release_id='SAMPLE',effective_from='2026-10-01',effective_to='2027-03-31',language='en',source_organization='SAMPLE / NOT FOR CLINICAL CODING',source_urls=['sample://synthetic-pcs'],created_at='2026-10-29T00:00:00Z',is_sample=True,source_files=[{'name':source.name,'sha256':digest(source.read_bytes())}])
        # The parser's source edition is 2027; visibly mark the package as SAMPLE.
        meta['edition']='FY2027'
        return build_pcs_pack([source],meta,output,'pcs_app',{})[0]
