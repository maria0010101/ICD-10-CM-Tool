import json
import sqlite3
import pytest
from tools.data_builder.build import build
from tools.data_builder.package import PackageError, verify
from tools.data_builder.audit_nhi_cm import audit
from tools.data_builder.gui import profile_purpose
from tools.data_builder.tests.test_official_sources import ods, sheet, row


def profile(tmp_path, extra=''):
    source=ods(tmp_path/'SAMPLE.ods',sheet(row('code','USE','English','中文')+row('I50','0','SAMPLE heart failure','合成心臟衰竭')+row('I50.9','1','SAMPLE heart failure unspecified','合成心臟衰竭未明示'))+extra)
    metadata=dict(package_id='sample-nhi-cm',package_version='1.0.0',kind='icd10cm_combined',classification='ICD-10-CM',jurisdiction='SAMPLE',edition='SAMPLE-2023-CM',release_id='SAMPLE',effective_from='2025-01-01',effective_to='9999-12-31',language='en+zh-TW',source_organization='SAMPLE / NOT FOR CLINICAL CODING',source_urls=['sample://synthetic-nhi'],created_at='2026-10-29T00:00:00Z',is_sample=True,translation_edition='SAMPLE-2023',translation_revision='test',mapping_policy='exact_edition',compatible_base_package_ids=['sample-nhi-cm'])
    profile=dict(metadata=metadata,inputs=[source.name],output_type='nhi_cm_app',translation=dict(file=source.name,columns=dict(sheet='ICD-10-CM',code='code',use='USE',title_en='English',title_zh_tw='中文')))
    path=tmp_path/'profile.json';path.write_text(json.dumps(profile));return path,profile


def test_standalone_cm_original_row_search_and_no_us_overlay(tmp_path):
    p,source=profile(tmp_path);out=tmp_path/'cm.icdpack';build(tmp_path,p,out)
    manifest=verify(out,tmp_path/'data')
    assert manifest['kind']=='icd10cm_combined' and manifest['row_counts']['translations']==2
    db=sqlite3.connect(tmp_path/'data/content.sqlite')
    assert db.execute("SELECT p.code,n.code,n.billable,n.is_leaf FROM code_nodes n JOIN code_nodes p ON p.id=n.parent_id WHERE n.code='I50.9'").fetchone()==('I50','I50.9',1,1)
    assert db.execute("SELECT code FROM code_search_fts WHERE code_search_fts MATCH 'failure'").fetchall()
    assert db.execute('SELECT DISTINCT mapping_status,base_package_id FROM translations').fetchall()==[('exact_edition','sample-nhi-cm')]
    db.close()
    assert audit(out,tmp_path,source)['passed']
    assert '可單獨啟用' in profile_purpose(p)
    old=out.read_bytes()
    with pytest.raises(FileExistsError):build(tmp_path,p,out)
    assert out.read_bytes()==old


def test_cm_standalone_rejects_us_compatibility_claim(tmp_path):
    p,m=profile(tmp_path);m['metadata']['compatible_base_package_ids']=['fy2027-us'];p.write_text(json.dumps(m))
    with pytest.raises(PackageError,match='same-edition'):build(tmp_path,p,tmp_path/'bad.icdpack')
    assert not (tmp_path/'bad.icdpack').exists()


def test_cm_standalone_bad_other_sheet_never_publishes(tmp_path):
    bad=sheet('<table:table-row><table:table-cell table:formula="of:=1+1"/></table:table-row>','other')
    p,m=profile(tmp_path,bad)
    with pytest.raises(PackageError):build(tmp_path,p,tmp_path/'bad.icdpack')
    assert not (tmp_path/'bad.icdpack').exists()
