"""Audit every translation against the manually mapped original CSV snapshot."""
import argparse
from .spreadsheets import mapped_records
import json
from pathlib import Path
import sqlite3
import tempfile
from .package import code_key, digest, normalized, verify

def audit(package,source,code_column,title_column,sheet=None):
    with tempfile.TemporaryDirectory() as td:
        manifest=verify(package,Path(td));db=sqlite3.connect(Path(td)/'content.sqlite')
        rows=[row for line,row in mapped_records(source,dict(code=code_column,title_zh_tw=title_column,**({'sheet':sheet} if sheet else {})))]
        actual=db.execute('SELECT code_normalized,title_zh_tw,search_normalized,mapping_status,notes FROM translations ORDER BY id').fetchall()
        differences=[]
        for i,(row,translated) in enumerate(zip(rows,actual),2):
            code,title,search,status,notes=translated
            if (code!=code_key(row[code_column]) or title!=row[title_column] or search!=normalized(title) or json.loads(notes)['source_columns']!=row or status!='unresolved'):
                differences.append(i)
        report={'source_sha256':digest(source.read_bytes()),'package_sha256':manifest['archive_sha256'],'source_rows':len(rows),'translation_rows':len(actual),'ngram_rows':manifest['row_counts']['zh_ngrams'],'mismatched_rows':differences,'mapping_status':'unresolved','official_compatibility_with_fy2027':False,'passed':len(rows)==len(actual) and not differences}
        db.close();return report

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--package',type=Path,required=True);p.add_argument('--source',type=Path,required=True);p.add_argument('--code-column',required=True);p.add_argument('--title-column',required=True);p.add_argument('--sheet')
    a=p.parse_args();report=audit(a.package,a.source,a.code_column,a.title_column,a.sheet);print(json.dumps(report,ensure_ascii=False,indent=2));raise SystemExit(0 if report['passed'] else 1)
