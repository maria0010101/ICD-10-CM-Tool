"""Synthetic fixtures only: no official full data in source control or CI."""
import hashlib
import json
from pathlib import Path
import sqlite3
import zipfile
import pytest
from tools.data_builder.adapters import import_nhi, new_database
from tools.data_builder.build import build, catalog, profile_inputs
from tools.data_builder.package import PackageError, verify
from tools.data_builder.source_tables import build_source_tables
from tools.data_builder.spreadsheets import ods_rows, mapped_records, spreadsheet_rows

NS='xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" xmlns:xlink="http://www.w3.org/1999/xlink"'
def row(*values):
    return '<table:table-row>'+''.join('<table:table-cell><text:p>'+v+'</text:p></table:table-cell>' for v in values)+'</table:table-row>'
def ods(path, body, prefix=''):
    with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED) as z:
        z.writestr('mimetype','application/vnd.oasis.opendocument.spreadsheet')
        z.writestr('content.xml',prefix+f'<office:document-content {NS}><office:body><office:spreadsheet>'+body+'</office:spreadsheet></office:body></office:document-content>')
    return path
def sheet(body,name='ICD-10-CM'):return f'<table:table table:name="{name}">'+body+'</table:table>'
COLS={'sheet':'ICD-10-CM','code':'code','title_zh_tw':'中文'}
META={'mapping_policy':'unresolved','translation_edition':'SAMPLE-2023','translation_revision':'test'}

def test_ods_rich_text_and_sparse_repetitions(tmp_path):
    rich='<text:span>心</text:span><text:s text:c="2"/>臟<text:tab/>衰<text:line-break/>竭'
    body=row('code','中文')+row('I50.9',rich)
    body+='<table:table-row table:number-rows-repeated="1000000"><table:table-cell table:number-columns-repeated="16384"/></table:table-row>'
    path=ods(tmp_path/'source.ods',sheet(body)+sheet(row('code','中文')+row('0016070','PCS only'),'ICD-10-PCS'))
    records=list(mapped_records(path,COLS))
    assert records==[(2,{'code':'I50.9','中文':'心  臟\t衰\n竭'})]
    db=new_database(tmp_path/'db.sqlite')
    try:
        assert import_nhi(db,path,COLS,META)['translation_rows']==1
        assert db.execute('SELECT code_normalized,mapping_status FROM translations').fetchall()==[('I509','unresolved')]
        with pytest.raises(PackageError,match='never PCS'):import_nhi(db,path,COLS|{'sheet':'ICD-10-PCS'},META)
    finally:db.close()

@pytest.mark.parametrize('attack',[
 '<table:table-cell table:formula="of:=1+1"><text:p>cached</text:p></table:table-cell>',
 '<table:table-cell><text:p><text:a xlink:href="https://invalid.example/">url</text:a></text:p></table:table-cell>',
 '<table:table-cell><office:script/></table:table-cell>',
 '<table:table-cell table:number-columns-repeated="999999999"/>',
])
def test_ods_rejects_active_or_huge_cells_even_in_other_sheet(tmp_path,attack):
    path=ods(tmp_path/'bad.ods',sheet(row('code','中文')+row('I50.9','心臟'))+sheet('<table:table-row>'+attack+'</table:table-row>','other'))
    db=new_database(tmp_path/'db.sqlite')
    try:
        with pytest.raises(PackageError):import_nhi(db,path,COLS,META)
        assert db.execute('SELECT count(*) FROM translations').fetchone()[0]==0
    finally:db.close()

def test_ods_dtd_and_expansion_rejected(tmp_path):
    path=ods(tmp_path/'xxe.ods',sheet(row('code','中文')), '<!DOCTYPE office:document-content [<!ENTITY x SYSTEM "file:///etc/passwd">]>')
    with pytest.raises(PackageError,match='DTD'):list(ods_rows(path))
    path=ods(tmp_path/'repeat.ods',sheet('<table:table-row table:number-rows-repeated="500001"><table:table-cell><text:p>x</text:p></table:table-cell></table:table-row>'))
    with pytest.raises(PackageError,match='resource'):list(ods_rows(path))

def test_ods_explicit_sheet_duplicate_and_column_mapping(tmp_path):
    path=ods(tmp_path/'source.ods',sheet(row('code','中文')+row('I50.9','心臟')))
    with pytest.raises(PackageError,match='explicit sheet'):list(spreadsheet_rows(path))
    with pytest.raises(PackageError,match='not found'):list(mapped_records(path,COLS|{'sheet':'missing'}))
    with pytest.raises(PackageError,match='column missing'):list(mapped_records(path,COLS|{'code':'wrong'}))
    duplicate=ods(tmp_path/'duplicate.ods',sheet(row('a'))+sheet(row('b')))
    with pytest.raises(PackageError,match='duplicate'):list(ods_rows(duplicate))

def pcs_inputs(tmp_path, *, year='2027', mismatch=False):
    tab='<ICD10PCS.tabular><version>'+year+'</version><pcsTable>'
    for p,c in enumerate('001',1):tab+=f'<axis pos="{p}" values="1"><title>SAMPLE axis</title><label code="{c}">SAMPLE</label></axis>'
    tab+='<pcsRow codes="1">'
    for p,c in enumerate('6070',4):tab+=f'<axis pos="{p}" values="1"><title>SAMPLE axis</title><label code="{c}">SAMPLE</label></axis>'
    tab+='</pcsRow></pcsTable></ICD10PCS.tabular>'
    source=tmp_path/'pcs.zip'
    code='0016071' if mismatch else '0016070'
    with zipfile.ZipFile(source,'w',zipfile.ZIP_DEFLATED) as z:
        z.writestr('icd10pcs_tables_2027.xml',tab)
        z.writestr('icd10pcs_index_2027.xml',f'<ICD10PCS.index><version>{year}</version><letter><mainTerm><title>SAMPLE</title><term><title>child</title><see>term<codes>0016</codes></see></term></mainTerm></letter></ICD10PCS.index>')
        z.writestr('icd10pcs_definitions_2027.xml',f'<ICD10PCS.definitions><version>{year}</version><section code="0"><axis pos="3"><terms><title>SAMPLE</title><definition>Original</definition><explanation>detail</explanation><includes>example</includes></terms></axis></section></ICD10PCS.definitions>')
        z.writestr('icd10pcs_order_2027.txt',f'00001 {code:7s} 1 {"SAMPLE short":60s} SAMPLE long\n')
        z.writestr('icd10pcs_codes_2027.txt',code+' SAMPLE long\n')
    return [source]

def test_pcs_separate_sqlite_roster_axes_index_and_no_overwrite(tmp_path):
    paths=pcs_inputs(tmp_path);out=tmp_path/'pcs.sqlite'
    result,report=build_source_tables(paths,{'classification':'ICD-10-PCS','edition':'FY2027'},out,'pcs_tables')
    assert result['app_import_supported'] is False and report['table_roster_exact_match']
    db=sqlite3.connect(out)
    assert db.execute('SELECT code,billable FROM pcs_codes').fetchall()==[('0016070',1)]
    assert db.execute('SELECT count(*) FROM pcs_axis_labels').fetchone()[0]==7
    assert db.execute('SELECT count(*) FROM pcs_index_entries').fetchone()[0]==2
    assert db.execute('SELECT target_text FROM pcs_index_refs').fetchone()[0]=='term0016'
    assert db.execute('SELECT count(*) FROM source_documents').fetchone()[0]==3
    assert db.execute('PRAGMA integrity_check').fetchone()[0]=='ok';db.close()
    before=out.read_bytes()
    with pytest.raises(FileExistsError):build_source_tables(paths,{'classification':'ICD-10-PCS','edition':'FY2027'},out,'pcs_tables')
    assert out.read_bytes()==before
    with pytest.raises(PackageError,match='not .icdpack'):build_source_tables(paths,{},tmp_path/'bad.icdpack','pcs_tables')

@pytest.mark.parametrize('mode',['year','codes'])
def test_pcs_mixed_release_or_axis_mismatch_never_published(tmp_path,mode):
    paths=pcs_inputs(tmp_path,year='2026' if mode=='year' else '2027',mismatch=mode=='codes')
    out=tmp_path/'bad.sqlite'
    with pytest.raises(PackageError):build_source_tables(paths,{'classification':'ICD-10-PCS','edition':'FY2027'},out,'pcs_tables')
    assert not out.exists()

def test_nhi_source_tables_keep_cm_pcs_and_deleted_separate(tmp_path):
    header=row('code','USE','英文','中文','狀態','修訂日期')
    path=ods(tmp_path/'all.ods',sheet(header+row('I50.9','1','SAMPLE','心臟','',''))+sheet(header+row('0016070','1','SAMPLE PCS','繞道','',''),'ICD-10-PCS')+sheet(row('deleted code')+row('OLD'),'2014_cm代碼刪除'))
    output=tmp_path/'all.sqlite';result,report=build_source_tables([path],{},output,'nhi_source_tables')
    db=sqlite3.connect(output)
    assert db.execute('SELECT classification,code,mapping_status FROM nhi_codes ORDER BY classification').fetchall()==[('ICD-10-CM','I50.9','unresolved'),('ICD-10-PCS','0016070','unresolved')]
    assert result['row_counts']['spreadsheet_rows']==3 and report['deleted_code_sheets_merged'] is False
    db.close()

def test_profile_hash_path_and_classification_gate(tmp_path):
    source=tmp_path/'source.txt';source.write_text('SAMPLE')
    profile={'inputs':['source.txt'],'input_sha256':{'source.txt':'0'*64},'metadata':{'classification':'ICD-10-PCS'}}
    with pytest.raises(PackageError,match='SHA256'):profile_inputs(tmp_path,profile)
    with pytest.raises(PackageError,match='outside'):profile_inputs(tmp_path,{'inputs':['../outside']})
    profile['input_sha256']['source.txt']=hashlib.sha256(source.read_bytes()).hexdigest()
    p=tmp_path/'p.json';p.write_text(json.dumps(profile))
    with pytest.raises(PackageError,match='Only CM'):build(tmp_path,p,tmp_path/'bad.icdpack')
    assert all(not x['ready'] for x in catalog(tmp_path)['profiles'])
