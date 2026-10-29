import json
from pathlib import Path
import sqlite3
import pytest
from tools.data_builder.package import verify, PackageError, check_manifest
from tools.data_builder.pcs_pack import sample_pcs, import_nhi_pcs_app
from tools.data_builder.adapters import new_database
from tools.data_builder.tests.test_official_sources import ods,sheet,row


def test_pcs_app_common_contract_reproducible(tmp_path):
    p=tmp_path/'pcs.icdpack';q=tmp_path/'other.icdpack'
    sample_pcs(p);sample_pcs(q);assert p.read_bytes()==q.read_bytes()
    manifest=verify(p,tmp_path/'data')
    assert manifest['classification']=='ICD-10-PCS' and manifest['required_app_schema_min']=='1.1.0'
    db=sqlite3.connect(tmp_path/'data/content.sqlite')
    assert db.execute("SELECT billable,state FROM code_nodes WHERE code='001'").fetchone()==(0,'incomplete')
    assert db.execute('SELECT target_code FROM index_entries WHERE parent_id IS NULL').fetchone()[0]=='001'
    assert db.execute("SELECT code FROM code_search_fts WHERE code_search_fts MATCH 'Bypass'").fetchall()
    assert db.execute("SELECT count(*) FROM notes WHERE note_type='pcs_table'").fetchone()[0]==1
    assert db.execute('SELECT count(*) FROM index_crossrefs').fetchone()[0]==2
    assert db.execute("SELECT count(*) FROM notes WHERE note_type='pcs_source_document'").fetchone()[0]==3
    db.close()
    changed=manifest|{'classification':'ICD-10-CM'}
    changed.pop('archive_sha256')
    with pytest.raises(PackageError):check_manifest(changed)


def test_nhi_pcs_bilingual_only_same_source_edition(tmp_path):
    source=ods(tmp_path/'nhi.ods',sheet(row('code','USE','English','中文')+row('0016070','1','SAMPLE Bypass','合成繞道術'),'ICD-10-PCS'))
    db=new_database(tmp_path/'nhi.sqlite')
    m=dict(package_id='sample-pcs-tw',effective_from='2025-01-01',effective_to='9999-12-31',translation_edition='SAMPLE2023',translation_revision='test')
    columns=dict(sheet='ICD-10-PCS',code='code',use='USE',title_en='English',title_zh_tw='中文')
    assert import_nhi_pcs_app(db,source,columns,m)['same_edition_bilingual_rows']==1
    assert db.execute('SELECT mapping_status,base_package_id FROM translations').fetchone()==('exact_edition','sample-pcs-tw')
    assert db.execute('SELECT count(*) FROM zh_ngrams').fetchone()[0]>0
    db.close()
