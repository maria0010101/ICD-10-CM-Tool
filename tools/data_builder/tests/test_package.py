import json
from pathlib import Path
import sqlite3
import stat
import zipfile
import pytest
from tools.data_builder.package import PackageError, contract, digest, json_bytes, verify, validate_db
from tools.data_builder.sample import sample
from tools.data_builder.adapters import xml_root, import_nhi, new_database, parse_order
from openpyxl import Workbook

@pytest.fixture
def pack(tmp_path):
    p=tmp_path/'sample.icdpack'; sample(p); return p

def unpack(pack,tmp_path):
    out=tmp_path/'unpacked'; verify(pack,out); return out

def repack(folder,target):
    m=json.loads((folder/'manifest.json').read_text()); m['content_sha256']=digest((folder/'content.sqlite').read_bytes())
    (folder/'manifest.json').write_bytes(json_bytes(m))
    (folder/'checksums.sha256').write_text(''.join(f'{digest((folder/n).read_bytes())}  {n}\n' for n in ['content.sqlite','manifest.json']))
    with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED) as z:
        for n in ['content.sqlite','manifest.json','checksums.sha256']: z.write(folder/n,n)
    return target

def test_reproducible_pack(pack,tmp_path):
    other=tmp_path/'other.icdpack'; sample(other)
    assert pack.read_bytes()==other.read_bytes()
    m=verify(pack); assert m['is_sample']; assert m['row_counts']['code_nodes']==8

def test_data_search_notes_and_versions(pack,tmp_path):
    folder=unpack(pack,tmp_path); db=sqlite3.connect(folder/'content.sqlite')
    assert db.execute("SELECT code FROM code_nodes WHERE code_normalized='I509'").fetchone()==('I50.9',)
    for query in ['heart AND failure','failure AND heart','hear*']:
        assert 'I50.9' in [r[0] for r in db.execute('SELECT code FROM code_search_fts WHERE code_search_fts MATCH ?',(query,))]
    assert db.execute("SELECT title_zh_tw FROM translations WHERE code_normalized='I509' AND mapping_status='exact_edition'").fetchone()==('心臟衰竭',)
    ancestors=db.execute('WITH RECURSIVE a(id,parent_id) AS (SELECT id,parent_id FROM code_nodes WHERE id=4 UNION ALL SELECT n.id,n.parent_id FROM code_nodes n JOIN a ON n.id=a.parent_id) SELECT note_type FROM notes JOIN a ON a.id=owner_node_id ORDER BY owner_node_id,display_order').fetchall()
    assert ancestors==[('includes',),('excludes1',),('codeFirst',),('excludes2',),('useAdditionalCode',)]
    assert db.execute('SELECT term_path FROM index_entries WHERE id=3').fetchone()==('Failure > heart > unspecified',)
    assert db.execute('SELECT count(*) FROM index_crossrefs').fetchone()[0]==2
    assert db.execute("SELECT billable,state FROM code_nodes WHERE code='I50'").fetchone()==(0,'incomplete')
    db.close()

@pytest.mark.parametrize('name',['../evil','/evil','C:\\evil','content.sqlite','unknown.exe'])
def test_unsafe_zip_names(tmp_path,name):
    p=tmp_path/'bad.icdpack'
    with zipfile.ZipFile(p,'w') as z:
        z.writestr('content.sqlite',b'x'); z.writestr(name,b'y'); z.writestr('manifest.json',b'{}')
    with pytest.raises((PackageError,zipfile.BadZipFile)): verify(p)

def test_bomb(tmp_path):
    p=tmp_path/'bomb.icdpack'
    with zipfile.ZipFile(p,'w',zipfile.ZIP_DEFLATED) as z:
        z.writestr('content.sqlite',b'0'*(2*1024*1024)); z.writestr('manifest.json',b'{}');z.writestr('checksums.sha256',b'x')
    with pytest.raises(PackageError,match='resource'): verify(p)

def test_symlink(tmp_path):
    p=tmp_path/'symlink.icdpack'
    with zipfile.ZipFile(p,'w') as z:
        info=zipfile.ZipInfo('content.sqlite');info.external_attr=(stat.S_IFLNK|0o777)<<16
        z.writestr(info,'/etc/passwd');z.writestr('manifest.json','{}');z.writestr('checksums.sha256','')
    with pytest.raises(PackageError,match='Unsafe'): verify(p)

@pytest.mark.parametrize('kind',['checksum','new-schema','cycle','trigger','counts','fts','ngram','lineage','corrupt','duplicate-json'])
def test_reject_tampering(pack,tmp_path,kind):
    f=unpack(pack,tmp_path); p=tmp_path/'bad.icdpack'
    if kind=='checksum':
        with zipfile.ZipFile(pack) as z,zipfile.ZipFile(p,'w') as dst:
            for n in z.namelist(): dst.writestr(n,z.read(n)+(b'x' if n=='content.sqlite' else b''))
    elif kind in ['new-schema','counts','duplicate-json']:
        m=json.loads((f/'manifest.json').read_text())
        if kind=='new-schema': m['schema_version']='9.0.0'
        elif kind=='counts': m['row_counts']['notes']=999
        else:
            (f/'manifest.json').write_text('{"format":"bad",'+(f/'manifest.json').read_text()[1:])
            with zipfile.ZipFile(p,'w') as z:
                for n in ['content.sqlite','manifest.json','checksums.sha256']: z.write(f/n,n)
        if kind!='duplicate-json': (f/'manifest.json').write_bytes(json_bytes(m));repack(f,p)
    else:
        if kind=='corrupt': (f/'content.sqlite').write_bytes(b'invalid sqlite')
        else:
            db=sqlite3.connect(f/'content.sqlite')
            sql={'cycle':'UPDATE code_nodes SET parent_id=4 WHERE id=1','trigger':'CREATE TRIGGER evil AFTER INSERT ON notes BEGIN DELETE FROM code_nodes; END','fts':"UPDATE code_search_fts SET title_en='wrong' WHERE rowid=4",'ngram':"DELETE FROM zh_ngrams WHERE ngram='心臟'",'lineage':"UPDATE translations SET base_package_id='other' WHERE id=1"}[kind]
            db.execute(sql);db.commit();db.close()
        repack(f,p)
    with pytest.raises((PackageError,sqlite3.DatabaseError,ValueError)): verify(p)

@pytest.mark.parametrize('raw',[b'<!DOCTYPE x [<!ENTITY e SYSTEM "file:///etc/passwd">]><x>&e;</x>',b'<!DOCTYPE x SYSTEM "https://invalid.example/evil.dtd"><x/>'])
def test_xml_xxe(raw):
    with pytest.raises(PackageError,match='DTD'): xml_root(raw)

def test_order_format_explicit():
    with pytest.raises(PackageError): parse_order(b'A000    Cholera')
    raw=f'{1:05d} {"A000":7s} 1 {"Short":60s} Long original title'.encode()
    assert parse_order(raw)['A000'][0]==1

@pytest.mark.parametrize('suffix',['csv','xlsx'])
def test_translation_columns_and_formula(tmp_path,suffix):
    db=new_database(tmp_path/'test.sqlite'); source=tmp_path/f'nhi.{suffix}'
    if suffix=='csv': source.write_text('code,Chinese\nI50.9,心臟衰竭\n',encoding='utf-8')
    else:
        wb=Workbook();ws=wb.active;ws.append(['code','Chinese']);ws.append(['I50.9','=1+1']);wb.save(source)
    m={'mapping_policy':'unresolved','translation_edition':'SAMPLE-TW','translation_revision':'test'}
    with pytest.raises(PackageError): import_nhi(db,source,{'code':'unknown','title_zh_tw':'Chinese'},m)
    if suffix=='xlsx':
        with pytest.raises(PackageError,match='formulas'): import_nhi(db,source,{'code':'code','title_zh_tw':'Chinese'},m)
    else:
        assert import_nhi(db,source,{'code':'code','title_zh_tw':'Chinese'},m)['translation_rows']==1
        with pytest.raises(sqlite3.IntegrityError): import_nhi(db,source,{'code':'code','title_zh_tw':'Chinese'},m)
    db.close()

def test_never_overwrite_artifact(pack):
    before=pack.read_bytes()
    with pytest.raises(FileExistsError): sample(pack)
    assert pack.read_bytes()==before

def test_contract_asset_matches():
    assert json.loads(Path('app/assets/schema_contract.json').read_text())==contract()

def test_xlsx_container_is_bounded_before_openpyxl(tmp_path):
    source=tmp_path/'bomb.xlsx'
    with zipfile.ZipFile(source,'w',zipfile.ZIP_DEFLATED) as z:z.writestr('xl/worksheets/sheet1.xml',b'0'*(1024*1024))
    db=new_database(tmp_path/'db.sqlite')
    try:
        with pytest.raises(PackageError,match='resource'):import_nhi(db,source,{'code':'code','title_zh_tw':'zh'},{})
    finally:db.close()

def test_xlsx_dtd_rejected_before_openpyxl(tmp_path):
    source=tmp_path/'xxe.xlsx'
    with zipfile.ZipFile(source,'w') as z:z.writestr('xl/workbook.xml',b'<!DOCTYPE x SYSTEM "file:///etc/passwd"><x/>')
    db=new_database(tmp_path/'db.sqlite')
    try:
        with pytest.raises(PackageError,match='DTD'):import_nhi(db,source,{'code':'code','title_zh_tw':'zh'},{})
    finally:db.close()


def test_existing_staging_file_is_preserved(tmp_path):
    stage=tmp_path/'new.icdpack.staging';stage.write_bytes(b'PREEXISTING USER FILE')
    with pytest.raises(FileExistsError):sample(tmp_path/'new.icdpack')
    assert stage.read_bytes()==b'PREEXISTING USER FILE'
    assert not (tmp_path/'new.icdpack').exists()
