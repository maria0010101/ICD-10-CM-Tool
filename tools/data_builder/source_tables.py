"""Separate source-data SQLite exports. These are NOT CM App .icdpack files."""
from __future__ import annotations
import itertools
import json
import os
from pathlib import Path
import re
import sqlite3
import tempfile
from lxml import etree as ET
from .adapters import source_files, xml_root, text
from .package import PackageError, digest, json_bytes
from .spreadsheets import ods_rows

SCHEMA = '''
PRAGMA foreign_keys=ON;
CREATE TABLE source_metadata(key TEXT PRIMARY KEY,value_json TEXT NOT NULL);
CREATE TABLE source_documents(id INTEGER PRIMARY KEY,source_reference TEXT UNIQUE,root_tag TEXT,sha256 TEXT,raw_xml BLOB NOT NULL);
CREATE TABLE pcs_codes(code TEXT PRIMARY KEY,billable INTEGER NOT NULL CHECK(billable IN(0,1)),short_title TEXT NOT NULL,long_title TEXT NOT NULL,display_order INTEGER,source_reference TEXT);
CREATE TABLE pcs_tables(id INTEGER PRIMARY KEY,prefix TEXT NOT NULL,raw_xml TEXT NOT NULL,source_reference TEXT);
CREATE TABLE pcs_rows(id INTEGER PRIMARY KEY,table_id INTEGER REFERENCES pcs_tables(id),display_order INTEGER,declared_codes INTEGER);
CREATE TABLE pcs_axis_labels(id INTEGER PRIMARY KEY,table_id INTEGER REFERENCES pcs_tables(id),row_id INTEGER REFERENCES pcs_rows(id),position INTEGER,title TEXT,code TEXT,label TEXT,definition TEXT,source_reference TEXT);
CREATE INDEX pcs_axis_lookup ON pcs_axis_labels(table_id,row_id,position);
CREATE TABLE pcs_index_entries(id INTEGER PRIMARY KEY,parent_id INTEGER REFERENCES pcs_index_entries(id),title TEXT,term_path TEXT,display_order INTEGER,source_reference TEXT,raw_xml TEXT NOT NULL);
CREATE TABLE pcs_index_refs(id INTEGER PRIMARY KEY,entry_id INTEGER REFERENCES pcs_index_entries(id),ref_type TEXT,target_text TEXT,display_order INTEGER,raw_xml TEXT NOT NULL);
CREATE TABLE pcs_definitions(id INTEGER PRIMARY KEY,section_code TEXT,axis_position TEXT,title TEXT,definition TEXT,explanation TEXT,includes_text TEXT,source_reference TEXT,raw_xml TEXT NOT NULL);
CREATE TABLE spreadsheet_sheets(name TEXT PRIMARY KEY,headers_json TEXT NOT NULL);
CREATE TABLE spreadsheet_rows(sheet TEXT REFERENCES spreadsheet_sheets(name),row_number INTEGER,source_columns_json TEXT NOT NULL,PRIMARY KEY(sheet,row_number));
CREATE TABLE nhi_codes(classification TEXT,edition TEXT,code TEXT,title_en TEXT,title_zh_tw TEXT,use_flag TEXT,status TEXT,revision TEXT,mapping_status TEXT,source_reference TEXT,PRIMARY KEY(classification,code));
'''


def _pcs_order(raw, reference):
    result = []
    for line in raw.decode('utf-8-sig').splitlines():
        if not line.strip(): continue
        if len(line) < 78 or not re.match(r'^\d{5} [0-9A-HJ-NP-Z ]{7} [01] ', line):
            raise PackageError('Expected PCS order fixed-width TXT')
        code = line[6:13].strip(); billable = int(line[14])
        if len(code) not in (3,7) or (billable and len(code)!=7): raise PackageError('PCS order code length/state')
        result.append((code,billable,line[16:76].rstrip(),line[77:],int(line[:5]),reference))
    if not result or len({r[0] for r in result}) != len(result): raise PackageError('Empty/duplicate PCS order codes')
    return result


def import_pcs(db, paths, metadata):
    year = metadata['edition'].removeprefix('FY'); roots = {}; order = None; roster = None
    report = {'input_members':{}, 'ignored_members':[]}
    for name, raw in source_files(paths):
        report['input_members'][name] = digest(raw)
        if name.endswith('.xml'):
            root = xml_root(raw)
            if not root.tag.startswith('ICD10PCS.') or text(root.find('version')) != year:
                raise PackageError('PCS XML classification/year mismatch')
            if root.tag in roots: raise PackageError('Duplicate PCS XML role')
            roots[root.tag] = (name, root)
            db.execute('INSERT INTO source_documents(source_reference,root_tag,sha256,raw_xml) VALUES (?,?,?,?)', (name,root.tag,digest(raw),raw))
        elif re.search(r'icd10pcs_order_' + year + r'\.txt$', name):
            if order is not None: raise PackageError('Multiple PCS order files')
            order = _pcs_order(raw,name)
        elif re.search(r'icd10pcs_codes_' + year + r'\.txt$', name):
            if roster is not None: raise PackageError('Multiple PCS code files')
            roster = {}
            for line in raw.decode('utf-8-sig').splitlines():
                if not line.strip(): continue
                if not re.match(r'^[0-9A-HJ-NP-Z]{7} ', line): raise PackageError('Invalid PCS code list')
                if line[:7] in roster: raise PackageError('Duplicate PCS roster code')
                roster[line[:7]] = line[8:]
        else: report['ignored_members'].append(name)
    if set(roots) != {'ICD10PCS.tabular','ICD10PCS.index','ICD10PCS.definitions'} or order is None or roster is None:
        raise PackageError('PCS needs matching tables/index/definitions XML, codes TXT and order TXT')
    actual = {code:title for code,billable,short,title,pos,ref in order if billable}
    if actual != roster: raise PackageError('PCS order/code roster or long titles mismatch; do not mix releases')
    db.executemany('INSERT INTO pcs_codes VALUES (?,?,?,?,?,?)', order)
    name, root = roots['ICD10PCS.tabular']; generated = set()
    for table in root.findall('pcsTable'):
        shared = {int(a.get('pos')):a for a in table.findall('axis')}
        if set(shared) != {1,2,3}: raise PackageError('PCS table requires axes 1/2/3')
        prefix = ''.join(text(shared[p].find('label')) and shared[p].find('label').get('code') or '' for p in (1,2,3))
        ident = db.execute('INSERT INTO pcs_tables(prefix,raw_xml,source_reference) VALUES (?,?,?)', (prefix,ET.tostring(table,encoding='unicode'),name+':'+root.getroottree().getpath(table))).lastrowid
        def axis(a, row_id):
            labels = a.findall('label')
            if len(labels) != int(a.get('values',len(labels))): raise PackageError('PCS axis value count mismatch')
            for label in labels:
                if not re.fullmatch('[0-9A-HJ-NP-Z]', label.get('code','')): raise PackageError('Invalid PCS axis character')
                db.execute('INSERT INTO pcs_axis_labels(table_id,row_id,position,title,code,label,definition,source_reference) VALUES (?,?,?,?,?,?,?,?)',
                    (ident,row_id,int(a.get('pos')),text(a.find('title')),label.get('code'),text(label),text(a.find('definition')),name+':'+root.getroottree().getpath(label)))
        for a in shared.values(): axis(a,None)
        for pos,row in enumerate(table.findall('pcsRow')):
            local = {int(a.get('pos')):a for a in row.findall('axis')}
            if set(local) != {4,5,6,7}: raise PackageError('PCS row requires axes 4/5/6/7')
            row_id = db.execute('INSERT INTO pcs_rows(table_id,display_order,declared_codes) VALUES (?,?,?)',(ident,pos,int(row.get('codes')))).lastrowid
            for a in local.values(): axis(a,row_id)
            axes = shared | local
            combos = {''.join(c) for c in itertools.product(*[[l.get('code') for l in axes[p].findall('label')] for p in range(1,8)])}
            if len(combos) != int(row.get('codes')) or generated & combos: raise PackageError('PCS row code count/duplicate combination')
            generated.update(combos)
    if generated != set(roster): raise PackageError('PCS table combinations differ from official codes; missing='+str(len(set(roster)-generated))+', extra='+str(len(generated-set(roster))))
    name, root = roots['ICD10PCS.index']
    def term(e, parent=None, path=()):
        title = text(e.find('title')); current = (*path,title)
        ident = db.execute('INSERT INTO pcs_index_entries(parent_id,title,term_path,display_order,source_reference,raw_xml) VALUES (?,?,?,?,?,?)',
            (parent,title,' > '.join(current),db.execute('SELECT count(*) FROM pcs_index_entries').fetchone()[0],name+':'+root.getroottree().getpath(e),ET.tostring(e,encoding='unicode'))).lastrowid
        for pos,ch in enumerate(e):
            if ch.tag == 'term': term(ch,ident,current)
            elif ch.tag != 'title': db.execute('INSERT INTO pcs_index_refs(entry_id,ref_type,target_text,display_order,raw_xml) VALUES (?,?,?,?,?)',(ident,ch.tag,text(ch),pos,ET.tostring(ch,encoding='unicode')))
    for e in root.findall('./letter/mainTerm'): term(e)
    name, root = roots['ICD10PCS.definitions']
    for section in root.findall('section'):
        for axis in section.findall('axis'):
            for entry in axis.findall('terms'):
                db.execute('INSERT INTO pcs_definitions(section_code,axis_position,title,definition,explanation,includes_text,source_reference,raw_xml) VALUES (?,?,?,?,?,?,?,?)',
                    (section.get('code'),axis.get('pos'),text(entry.find('title')),text(entry.find('definition')),text(entry.find('explanation')),text(entry.find('includes')),name+':'+root.getroottree().getpath(entry),ET.tostring(entry,encoding='unicode')))
    report.update(billable_codes=len(roster),order_rows=len(order),table_generated_codes=len(generated),table_roster_exact_match=True,
                  source_index_entries=sum(len(r.findall('.//mainTerm'))+len(r.findall('.//term')) for n,r in [roots['ICD10PCS.index']]),
                  source_definition_terms=len(roots['ICD10PCS.definitions'][1].findall('.//terms')))
    if report['source_index_entries'] != db.execute('SELECT count(*) FROM pcs_index_entries').fetchone()[0]: raise PackageError('PCS Index count mismatch')
    if report['source_definition_terms'] != db.execute('SELECT count(*) FROM pcs_definitions').fetchone()[0]: raise PackageError('PCS definition count mismatch')
    return report


def import_ods_tables(db, path):
    headers = {}; counts = {}; seen_codes = {}
    for sheet, number, values in ods_rows(path):
        if sheet not in headers:
            if len(set(values)) != len(values): raise PackageError('Duplicate ODS table headers')
            headers[sheet] = values; counts[sheet] = 0
            db.execute('INSERT INTO spreadsheet_sheets VALUES (?,?)', (sheet,json.dumps(values,ensure_ascii=False)))
            continue
        header = headers[sheet]
        if len(values)>len(header): raise PackageError('Unexpected ODS source columns')
        row = dict(zip(header,values+['']*len(header)))
        db.execute('INSERT INTO spreadsheet_rows VALUES (?,?,?)',(sheet,number,json.dumps(row,ensure_ascii=False)))
        counts[sheet] += 1
        if sheet in ('ICD-10-CM','ICD-10-PCS'):
            if len(header)!=6 or header[1]!='USE': raise PackageError('NHI layout changed; update explicit adapter')
            cells = list(row.values()); code=cells[0]
            pattern = r'[A-Z][A-Z0-9]{2}(?:\.?[A-Z0-9]{1,4})?' if sheet=='ICD-10-CM' else r'[0-9A-HJ-NP-Z]{7}'
            if not re.fullmatch(pattern,code) or not cells[3].strip(): raise PackageError('Invalid NHI '+sheet+' row '+str(number))
            db.execute('INSERT INTO nhi_codes VALUES (?,?,?,?,?,?,?,?,?,?)',(sheet,'NHI-2023',code,cells[2],cells[3],cells[1],cells[4],cells[5],'unresolved',path.name+':'+sheet+':row:'+str(number)))
    if not {'ICD-10-CM','ICD-10-PCS'} <= set(headers): raise PackageError('Expected separate NHI CM/PCS sheets')
    return {'source_sheet_rows':counts,'mapping_status':'unresolved','deleted_code_sheets_merged':False}


def build_source_tables(paths, metadata, output, mode):
    if output.suffix.lower() != '.sqlite': raise PackageError('Source tables use .sqlite, not .icdpack; App CM schema is unchanged')
    if mode not in ('pcs_tables','nhi_source_tables'): raise PackageError('Unknown source table output type')
    if mode=='pcs_tables' and metadata.get('classification')!='ICD-10-PCS': raise PackageError('PCS classification required')
    output.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.icd-tables-',dir=output.parent) as td:
        stage=Path(td)/'content.sqlite'; db=sqlite3.connect(stage)
        try:
            db.executescript(SCHEMA)
            for key,value in (metadata | {'output_type':mode,'app_import_supported':False,'schema_version':'source-tables-1'}).items():
                db.execute('INSERT INTO source_metadata VALUES (?,?)',(key,json.dumps(value,ensure_ascii=False)))
            if mode=='pcs_tables': report=import_pcs(db,paths,metadata)
            else:
                if len(paths)!=1: raise PackageError('One explicit NHI ODS required')
                report=import_ods_tables(db,paths[0])
            db.commit(); db.execute('VACUUM')
            assert db.execute('PRAGMA integrity_check').fetchall()==[('ok',)]
            if db.execute('PRAGMA foreign_key_check').fetchall(): raise PackageError('Source-table foreign keys')
            names=[r[0] for r in db.execute("SELECT name FROM sqlite_master WHERE type='table'")]
            counts={name:db.execute('SELECT count(*) FROM '+name).fetchone()[0] for name in names}
        finally: db.close()
        os.link(stage,output)  # atomic, no-replace, same filesystem
    result={'output':output.name,'sha256':digest(output.read_bytes()),'bytes':output.stat().st_size,'row_counts':counts,'app_import_supported':False,'integrity_check':'ok'}
    return result, report | result
