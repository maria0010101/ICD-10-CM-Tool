"""Independent all-row audit for a standalone NHI CM bilingual App pack."""
import argparse
import json
import sqlite3
import tempfile
from pathlib import Path
from .package import code_key, verify
from .spreadsheets import mapped_records


def audit(package, source_dir, profile):
    with tempfile.TemporaryDirectory() as td:
        manifest = verify(package, Path(td)); db = sqlite3.connect(Path(td)/'content.sqlite')
        try:
            cols = profile['translation']['columns']; expected = {}
            for line,row in mapped_records(source_dir/profile['translation']['file'],cols):
                expected[code_key(row[cols['code']])] = (row[cols['code']], row[cols['title_en']], int(row[cols['use']]), row[cols['title_zh_tw']], row)
            actual = {}; mismatches = []
            for key,code,title,use,zh,status,base,raw in db.execute("SELECT n.code_normalized,n.code,n.title_en,n.billable,t.title_zh_tw,t.mapping_status,t.base_package_id,s.note_text FROM code_nodes n JOIN translations t ON t.code_normalized=n.code_normalized JOIN notes s ON s.owner_node_id=n.id AND s.note_type='nhi_source_columns'"):
                actual[key]=(code,title,use,zh,json.loads(raw))
                if status != 'exact_edition' or base != manifest['package_id']: mismatches.append('same NHI edition only')
            if expected != actual: mismatches.append('original display code / English / USE / Chinese / all source columns')
            if manifest.get('compatible_base_package_ids') != [manifest['package_id']]: mismatches.append('must not claim US bases')
            parents = dict(db.execute("SELECT n.code_normalized,p.code_normalized FROM code_nodes n JOIN code_nodes p ON p.id=n.parent_id WHERE n.code!=''"))
            for key in expected:
                parent = next((key[:n] for n in range(len(key)-1,2,-1) if key[:n] in expected), '@nhi-cm-source')
                if parents.get(key) != parent: mismatches.append('code-prefix navigation parent '+key)
            if db.execute('SELECT count(*) FROM index_entries').fetchone()[0] != 0: mismatches.append('unprovided Index claimed')
            return {'source_bilingual_rows':len(expected),'package_bilingual_rows':len(actual),'package_sha256':manifest['archive_sha256'], 'classification':manifest['classification'],'edition':manifest['edition'],'same_source_edition_only':True,'us_cross_release_compatibility_claim':False,'mismatches':mismatches,'passed':not mismatches}
        finally: db.close()

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--package',type=Path,required=True);p.add_argument('--source-dir',type=Path,required=True);p.add_argument('--profile',type=Path,required=True)
    a=p.parse_args();r=audit(a.package,a.source_dir,json.loads(a.profile.read_text(encoding='utf-8')))
    print(json.dumps(r,ensure_ascii=False,indent=2));raise SystemExit(0 if r['passed'] else 1)
