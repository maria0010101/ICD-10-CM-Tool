"""Synthetic overlay for lineage tests. NOT FOR CLINICAL CODING."""
from pathlib import Path
from tempfile import TemporaryDirectory
from .adapters import new_database, import_nhi, fill_search
from .package import digest, write_package

def generate(output):
    m={'package_id':'sample-overlay-unresolved','package_version':'1.0.0','kind':'icd10cm_zh_tw','classification':'ICD-10-CM','jurisdiction':'SAMPLE','edition':'SAMPLE-TW-OLD','release_id':'2026-10-29','effective_from':'2026-10-01','effective_to':'2027-09-30','language':'zh-TW','source_organization':'SAMPLE / NOT FOR CLINICAL CODING','source_urls':['sample://overlay-fixture'],'source_files':[{'name':'overlay_fixture.py','sha256':digest(Path(__file__).read_bytes())}],'created_at':'2026-10-29T00:00:00Z','is_sample':True,'translation_edition':'SAMPLE-TW-OLD','translation_revision':'fixture','mapping_policy':'unresolved','compatible_base_package_ids':['sample-demo-v1']}
    with TemporaryDirectory() as td:
        source=Path(td)/'overlay.csv';source.write_text('code,zh\nI50.9,跨版測試譯名\n',encoding='utf-8')
        path=Path(td)/'content.sqlite';db=new_database(path)
        import_nhi(db,source,{'code':'code','title_zh_tw':'zh'},m);fill_search(db);db.close()
        return write_package(path,m,Path(output))

if __name__=='__main__':
    import sys
    generate(sys.argv[1])
