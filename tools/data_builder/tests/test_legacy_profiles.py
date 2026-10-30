"""Synthetic alternate-row fixtures; never copied official names/content."""
import copy
import json
import sqlite3
import pytest
from tools.data_builder.build import build, catalog
from tools.data_builder.package import PackageError, verify
from tools.data_builder.nhi_legacy import read_legacy
from tools.data_builder.audit_nhi_legacy import audit
from tools.data_builder.gui import profile_purpose
from tools.data_builder.tests.test_official_sources import ods, sheet, row


def fixture(tmp_path, *, pcs=False, body=None, extra=''):
    p=json.loads(__import__('pathlib').Path('docs/source_profiles/nhi2014-'+('pcs' if pcs else 'cm')+'-app.json').read_text(encoding='utf-8'))
    m=p['metadata'];pid='sample-legacy-'+('pcs' if pcs else 'cm')
    m.update(package_id=pid,compatible_base_package_ids=[pid],is_sample=True,source_organization='SAMPLE / NOT FOR CLINICAL CODING')
    name='0-2' if pcs else 'Chapter_1'
    p['legacy_layout']=dict(sheets=[name],reference_sheets=['修正說明'],inert_formula_columns={name:[5,6]} if pcs else {})
    if body is None:
        body=row('0016070' if pcs else 'I50','SAMPLE heart bypass' if pcs else 'SAMPLE heart failure')+row('','合成中譯')
    source=ods(tmp_path/'SAMPLE.ods',sheet(row('SAMPLE heading')+row('代碼','英/中文名稱')+body,name)+sheet(row('代碼','英/中文名稱','說明')+row('SAMPLE','reference only','合成修訂'),'修正說明')+extra)
    p.update(inputs=[source.name],input_sha256={})
    path=tmp_path/'profile.json';path.write_text(json.dumps(p,ensure_ascii=False),encoding='utf-8')
    return path,p


@pytest.mark.parametrize('pcs',[False,True])
def test_legacy_package_all_original_rows_and_unknown_status(tmp_path,pcs):
    path,p=fixture(tmp_path,pcs=pcs);out=tmp_path/'legacy.icdpack';build(tmp_path,path,out)
    m=verify(out,tmp_path/'data');assert m['required_app_schema_min']=='1.2.0'
    db=sqlite3.connect(tmp_path/'data/content.sqlite')
    assert db.execute("SELECT billable,state FROM code_nodes WHERE code!=''").fetchall()==[(0,'nonbillable')]
    assert db.execute('SELECT mapping_status,base_package_id FROM translations').fetchall()==[('exact_edition',m['package_id'])]
    assert db.execute('SELECT count(*) FROM index_entries').fetchone()[0]==0
    assert db.execute("SELECT code FROM code_search_fts WHERE code_search_fts MATCH 'heart'").fetchall()
    assert db.execute("SELECT count(*) FROM zh_ngrams WHERE ngram='中譯'").fetchone()[0]==1
    db.close();assert audit(out,tmp_path,p)['passed']
    assert '未提供USE' in profile_purpose(path)
    original=out.read_bytes()
    with pytest.raises(FileExistsError):build(tmp_path,path,out)
    assert out.read_bytes()==original


def test_explicit_source_missing_translation_omitted_not_invented(tmp_path):
    path,p=fixture(tmp_path,body=row('I50','SAMPLE parent')+row('I50.9','SAMPLE child')+row('','合成子碼'))
    with pytest.raises(PackageError,match='Missing Chinese'):build(tmp_path,path,tmp_path/'bad.icdpack')
    p['legacy_layout']['missing_translation_codes']=['I50'];path.write_text(json.dumps(p),encoding='utf-8')
    out=tmp_path/'ok.icdpack';build(tmp_path,path,out);m=verify(out)
    assert m['row_counts']['translations']==1
    assert audit(out,tmp_path,p)['passed']


@pytest.mark.parametrize('body',[
    row('I50','SAMPLE')+row('I50.9','SAMPLE')+row('','合成'),
    row('','orphan'),
    row('0016070','wrong classification')+row('','合成'),
    row('I50','SAMPLE')+row('','合成')+row('I50','duplicate')+row('','合成'),
])
def test_invalid_legacy_pairs_never_publish(tmp_path,body):
    path,p=fixture(tmp_path,body=body)
    with pytest.raises(PackageError):build(tmp_path,path,tmp_path/'bad.icdpack')
    assert not (tmp_path/'bad.icdpack').exists()


def test_auxiliary_formula_preserved_inert_only_and_other_content_rejected(tmp_path):
    formula='<table:table-row>'+''.join('<table:table-cell><text:p>'+v+'</text:p></table:table-cell>' for v in ['0016070','SAMPLE','',''])+'<table:table-cell table:formula="of:=1+1"><text:p>2</text:p></table:table-cell></table:table-row>'
    path,p=fixture(tmp_path,pcs=True,body=formula+row('','合成'))
    out=tmp_path/'ok.icdpack';build(tmp_path,path,out);assert audit(out,tmp_path,p)['passed']
    records,_,_=read_legacy(tmp_path/'SAMPLE.ods',p)
    assert 'NOT EVALUATED' in records[0]['source_rows'][0]['cells'][4]
    from tools.data_builder.spreadsheets import ods_rows
    with pytest.raises(PackageError,match='formulas prohibited'):list(ods_rows(tmp_path/'SAMPLE.ods'))
    p['legacy_layout']['inert_formula_columns']={};path.write_text(json.dumps(p))
    with pytest.raises(PackageError):build(tmp_path,path,tmp_path/'bad.icdpack')


@pytest.mark.parametrize('attack',[
    '<table:table-cell table:formula="of:=1+1"><text:p>0016070</text:p></table:table-cell><table:table-cell><text:p>SAMPLE</text:p></table:table-cell>',
    '<table:table-cell><text:p>0016070</text:p></table:table-cell><table:table-cell table:formula="of:=1+1"><text:p>SAMPLE</text:p></table:table-cell>',
    '<table:table-cell><text:p><text:a xlink:href="https://invalid.example/">external</text:a></text:p></table:table-cell>',
])
def test_legacy_main_cells_and_external_links_still_rejected(tmp_path,attack):
    path,p=fixture(tmp_path,pcs=True,body='<table:table-row>'+attack+'</table:table-row>'+row('','合成'))
    with pytest.raises(PackageError):build(tmp_path,path,tmp_path/'bad.icdpack')
    assert not (tmp_path/'bad.icdpack').exists()


def test_shipped_profiles_hash_complete_release_isolated_and_catalog(tmp_path):
    from pathlib import Path
    profiles=[json.loads(p.read_text(encoding='utf-8')) for p in Path('docs/source_profiles').glob('*.json')]
    assert len(profiles)==21
    for p in profiles:
        assert set(p['inputs'])==set(p['input_sha256'])
    for cl in ['cm','pcs']:
        octp=next(p for p in profiles if p['metadata'].get('package_id')==f'icd10{cl}-us-fy2025-oct-en')
        aprp=next(p for p in profiles if p['metadata'].get('package_id')==f'icd10{cl}-us-fy2025-apr-en')
        assert octp['metadata']['effective_to']<'2025-04-01'
        assert aprp['metadata']['effective_from']=='2025-04-01'
        assert set(octp['inputs']).isdisjoint(aprp['inputs'])
    assert len(catalog(tmp_path)['profiles'])==21
