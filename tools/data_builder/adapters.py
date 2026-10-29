"""Explicit CDC XML/order and NHI column-mapped spreadsheet adapters.

No HTTP client. Downloading official releases is a separate manual step.
"""
from __future__ import annotations
import csv
import json
import io
from pathlib import Path
import re
import sqlite3
import zipfile
from lxml import etree as ET
from openpyxl import load_workbook
from .package import PackageError, ROOT, code_key, digest, grams, normalized, safe_entries, MAX_ARCHIVE

NOTES = {'includes','excludes1','excludes2','codeFirst','useAdditionalCode','codeAlso','sevenChrNote','sevenChrDef','inclusionTerm','notes','visualImpairment'}
TABULAR_TAGS = NOTES | {'ICD10CM.tabular','version','introduction','introSection','title','instruction','note','chapter','name','desc','sectionIndex','sectionRef','section','diag','extension','heading','visCategory','visRange','visMax','visMin','value'}
INDEX_TAGS = {'ICD10CM.index','version','title','letter','mainTerm','term','code','see','seeAlso','nemod','manif','subcat','seecat','indexHeading','head','cell'}

def xml_root(raw: bytes):
    if len(raw) > 128*1024*1024:
        raise PackageError('XML size limit')
    parser = ET.XMLParser(resolve_entities=False,load_dtd=False,no_network=True,huge_tree=False)
    root = ET.fromstring(raw,parser)
    if root.getroottree().docinfo.doctype or any(isinstance(n,ET._Entity) for n in root.iter()):
        raise PackageError('DTD/entities prohibited')
    return root

def text(e):
    return '' if e is None else ''.join(e.itertext())

def check_tags(root, allowed):
    unknown = {e.tag for e in root.iter() if isinstance(e.tag,str)} - allowed
    if unknown: raise PackageError('Unrecognized XML tags; update adapter: '+repr(unknown))

def source_files(paths):
    out=[]
    for p in paths:
        if p.stat().st_size > MAX_ARCHIVE: raise PackageError('Source file size limit')
        if p.suffix.lower()=='.zip':
            with zipfile.ZipFile(p) as z:
                for info in safe_entries(z,package=False):
                    if not info.is_dir() and Path(info.filename).suffix.lower() in ('.xml','.txt'):
                        out.append((p.name+'!'+info.filename,z.read(info)))
        else:
            out.append((p.name,p.read_bytes()))
    return out

def new_database(path):
    db=sqlite3.connect(path)
    db.executescript((ROOT/'schemas/content.sql').read_text())
    return db

def add_node(db, key, code, parent, kind, title, billable, leaf, state, order, source, meta):
    return db.execute('INSERT INTO code_nodes(node_key,code,code_normalized,parent_id,node_type,title_en,billable,is_leaf,state,valid_from,valid_to,sort_order,source_reference) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)',
        (key,code,code_key(code) if code else key,parent,kind,title,billable,leaf,state,meta['effective_from'],meta['effective_to'],order,source)).lastrowid

def fill_search(db):
    db.execute("INSERT INTO code_search_fts(rowid,code,title_en,synonyms) SELECT id,code,title_en,'' FROM code_nodes")
    db.execute('INSERT INTO index_search_fts(rowid,term_path) SELECT id,term_path FROM index_entries')
    db.commit()

def parse_order(raw):
    result={}
    for line in raw.decode('utf-8-sig').splitlines():
        if not line.strip(): continue
        if not re.match(r'^\d{5} [A-Z][A-Z0-9 ]{6} [01] ',line) or len(line)<78:
            raise PackageError('Expected CDC order fixed-width TXT, not codes/addenda')
        code=line[6:13].strip()
        if code in result: raise PackageError('Duplicate order code')
        result[code]=(int(line[14]),line[77:],int(line[:5]))
    return result

def import_cdc(db, paths, meta):
    sources=source_files(paths)
    xmls=[]; order={}; report={'input_files':{},'xml_counts':{}}
    for name,raw in sources:
        report['input_files'][name]=digest(raw)
        if name.lower().endswith('.xml'):
            root=xml_root(raw)
            if text(root.find('version')) != meta['edition'].removeprefix('FY'):
                raise PackageError('XML version differs from metadata edition')
            xmls.append((name,root))
        elif re.search(r'order[-_]\d{4}\.txt$',name):
            if order: raise PackageError('Multiple order files')
            order=parse_order(raw)
    tabular=[(n,r) for n,r in xmls if r.tag=='ICD10CM.tabular']
    if len(tabular)!=1 or not order: raise PackageError('One Tabular XML and one CDC order TXT required')
    name,root=tabular[0]; check_tags(root,TABULAR_TAGS)
    report['xml_counts']['tabular_diag']=len(root.findall('.//diag'))
    note_count=0
    def node(e,parent=None):
        nonlocal note_count
        kind={'chapter':'chapter','section':'block','diag':'category' if len(text(e.find('name')).replace('.',''))==3 else 'subcategory'}[e.tag]
        code=text(e.find('name')) if e.tag=='diag' else ''
        key=code_key(code) if code else '@'+e.tag+':'+(text(e.find('name')) or e.get('id',''))
        code_order=order.get(code_key(code))
        billable=code_order[0] if code_order else 0
        leaf=not len(e.findall('diag'))
        state='billable' if billable else ('requires_extension' if leaf else 'incomplete')
        src=name+':'+e.getroottree().getpath(e)
        ident=add_node(db,key,code,parent,kind,text(e.find('desc')),billable,int(leaf),state,db.execute('SELECT count(*) FROM code_nodes').fetchone()[0],src,meta)
        for pos,ch in enumerate(e):
            if ch.tag in NOTES:
                children=list(ch) if ch.tag!='visualImpairment' else [ch]
                if not children: children=[ch]
                for seq,n in enumerate(children):
                    display=text(n)
                    if n.tag=='extension': display=n.get('char','')+' — '+display
                    db.execute('INSERT INTO notes(owner_node_id,note_type,note_text,display_order,source_element,source_reference,raw_xml) VALUES (?,?,?,?,?,?,?)',
                        (ident,ch.tag,display,pos*10000+seq,ch.tag,src+'/'+ch.tag,ET.tostring(n,encoding='unicode')))
                    note_count+=1
            elif ch.tag in ('chapter','section','diag'): node(ch,ident)
            elif ch.tag not in ('name','desc','sectionIndex'): raise PackageError('Unhandled tabular child '+str(ch.tag))
    intro=root.find('introduction')
    if intro is not None:
        ident=add_node(db,'@introduction','',None,'chapter','Instructional Notations (source introduction)',0,1,'nonbillable',-1,name+':/introduction',meta)
        for pos,e in enumerate(intro):
            db.execute('INSERT INTO notes(owner_node_id,note_type,note_text,display_order,source_element,source_reference,raw_xml) VALUES (?,?,?,?,?,?,?)',(ident,'introduction',text(e),pos,e.tag,name+':/introduction',ET.tostring(e,encoding='unicode')))
    for e in root.findall('chapter'): node(e)
    # CDC tabular omits enumerated 7th-character leaves. Order file is the authoritative billable roster.
    existing={r[0]:r[1] for r in db.execute("SELECT code_normalized,id FROM code_nodes WHERE code!=''")}
    for key,(billable,title,pos) in order.items():
        if key in existing:
            row=db.execute('SELECT title_en,billable FROM code_nodes WHERE id=?',(existing[key],)).fetchone()
            if row[1]!=billable: raise PackageError('Billable mismatch')
            continue
        parent=next((existing[key[:length]] for length in range(len(key)-1,2,-1) if key[:length] in existing),None)
        if parent is None: raise PackageError('Order leaf missing tabular ancestor: '+key)
        code=key[:3]+'.'+key[3:] if len(key)>3 else key
        ident=add_node(db,key,code,parent,'subcategory',title,billable,1,'billable' if billable else 'incomplete',pos,'CDC order:'+key,meta)
        existing[key]=ident
        db.execute('UPDATE code_nodes SET is_leaf=0 WHERE id=?',(parent,))
    report['xml_counts']['instruction_notes']=note_count
    report['order_count']=len(order)
    report['expanded_order_nodes']=len(existing)-report['xml_counts']['tabular_diag']
    for name,root in xmls:
        if root.tag=='ICD10CM.tabular': continue
        if root.tag!='ICD10CM.index': raise PackageError('Unknown XML root')
        check_tags(root,INDEX_TAGS)
        typ='drugs' if 'drug' in name.lower() else 'neoplasm' if 'neoplasm' in name.lower() else 'external' if 'eindex' in name.lower() else 'alphabetic'
        heads={h.get('col'):text(h) for h in root.findall('./indexHeading/head')}
        before=db.execute('SELECT count(*) FROM index_entries').fetchone()[0]
        def term(e,parent=None,path=(),main=None):
            title=text(e.find('title')); main=title if main is None else main
            p=(*path,title)
            ident=db.execute('INSERT INTO index_entries(parent_id,main_term,sub_term,term_path,target_code,entry_type,display_order,source_reference) VALUES (?,?,?,?,?,?,?,?)',
                (parent,main,None if parent is None else title,' > '.join(p),text(e.find('code')) or None,typ,db.execute('SELECT count(*) FROM index_entries').fetchone()[0],name+':'+e.getroottree().getpath(e))).lastrowid
            for pos,ch in enumerate(e):
                if ch.tag=='term': term(ch,ident,p,main)
                elif ch.tag in ('see','seeAlso','manif','subcat','seecat'):
                    db.execute('INSERT INTO index_crossrefs(index_entry_id,ref_type,target_term,display_order) VALUES (?,?,?,?)',(ident,ch.tag,text(ch),pos))
                elif ch.tag=='cell':
                    if ch.get('col') not in heads: raise PackageError('Unmapped table column')
                    db.execute('INSERT INTO table_cells(index_entry_id,column_label,target_code,display_order) VALUES (?,?,?,?)',(ident,heads[ch.get('col')],text(ch),pos))
                elif ch.tag not in ('title','code'): raise PackageError('Unhandled Index child '+str(ch.tag))
        for e in root.findall('./letter/mainTerm'): term(e)
        after=db.execute('SELECT count(*) FROM index_entries').fetchone()[0]
        expected=len(root.findall('.//mainTerm'))+len(root.findall('.//term'))
        if after-before!=expected: raise PackageError('Index count mismatch')
        report['xml_counts'][typ]=expected
    if not {'alphabetic','external','neoplasm','drugs'} <= report['xml_counts'].keys():
        raise PackageError('Full CDC release requires all four Index/table XMLs')
    db.commit()
    return report

def import_nhi(db, path: Path, columns: dict, metadata: dict):
    from .spreadsheets import mapped_records
    if columns.get('sheet') and columns['sheet'] != 'ICD-10-CM' and path.suffix.lower() == '.ods':
        raise PackageError('CM overlay requires the ICD-10-CM sheet, never PCS or deleted-code sheets')
    count = 0
    db.execute('SAVEPOINT nhi_import')
    try:
        for line, row in mapped_records(path, columns):
            code = row[columns['code']].strip(); title = row[columns['title_zh_tw']]
            if code.startswith(('=', '+', '@')) or title.startswith(('=', '+', '@')):
                raise PackageError('Formula-like value prohibited')
            if not re.fullmatch(r'[A-Z][A-Z0-9]{2}(?:\.?[A-Z0-9]{1,4})?', code.upper()) or not title.strip():
                raise PackageError('Invalid translation row ' + str(line))
            status = metadata['mapping_policy']; base = metadata.get('compatible_base_package_ids', [])
            if status != 'unresolved' and len(base) != 1: raise PackageError('Reviewed mapping needs exactly one base')
            reference = path.name + (':' + columns['sheet'] if columns.get('sheet') else '') + ':row:' + str(line)
            ident = db.execute('INSERT INTO translations(code_normalized,title_zh_tw,search_normalized,translation_edition,translation_revision,source_reference,mapping_status,base_package_id,notes) VALUES (?,?,?,?,?,?,?,?,?)',
                (code_key(code), title, normalized(title), metadata['translation_edition'], metadata['translation_revision'], reference, status, base[0] if base else None,
                 json.dumps({'mapping_decision':'Explicit source profile; not inferred by code equality','source_columns':row}, ensure_ascii=False))).lastrowid
            db.executemany('INSERT INTO zh_ngrams VALUES (?,?,?)', [(g, code_key(code), ident) for g in sorted(grams(title))])
            count += 1
        if not count: raise PackageError('Empty translation table')
        db.execute('RELEASE nhi_import'); db.commit()
    except Exception:
        db.execute('ROLLBACK TO nhi_import'); db.execute('RELEASE nhi_import'); raise
    return {'translation_rows':count, 'columns':columns, 'source_sha256':digest(path.read_bytes())}
