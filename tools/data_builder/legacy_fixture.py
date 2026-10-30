"""Reproducible NHI 2014-format synthetic packs, never official data."""
import argparse
import json
from pathlib import Path
import tempfile
import zipfile
from .build import build
from .package import ROOT


def sample(output, pcs=False):
    classification='pcs' if pcs else 'cm'
    with tempfile.TemporaryDirectory() as td:
        folder=Path(td);profile=json.loads((ROOT/f'docs/source_profiles/nhi2014-{classification}-app.json').read_text(encoding='utf-8'))
        pid='sample-nhi2014-'+classification+'-v1'
        profile['metadata'].update(package_id=pid,compatible_base_package_ids=[pid],source_organization='SAMPLE / NOT FOR CLINICAL CODING',source_urls=['sample://synthetic-2014-layout'],is_sample=True)
        sheet='0-1' if pcs else 'Chapter_1'
        profile['legacy_layout']=dict(sheets=[sheet],reference_sheets=['修正說明'],inert_formula_columns={})
        if not pcs:profile['legacy_layout']['missing_translation_codes']=['I50']
        rows=[['SAMPLE / NOT FOR CLINICAL CODING'],['代碼','英/中文名稱']]
        rows+=([['0016070','SAMPLE heart bypass'],['','合成心臟繞道']] if pcs else [['I50','SAMPLE heart failure'],['I50.9','SAMPLE heart failure unspecified'],['','合成心臟衰竭']])
        from xml.sax.saxutils import escape
        def row(values):return '<table:table-row>'+''.join('<table:table-cell><text:p>'+escape(v)+'</text:p></table:table-cell>' for v in values)+'</table:table-row>'
        source=folder/'SAMPLE-NOT-FOR-CLINICAL-CODING.ods'
        with zipfile.ZipFile(source,'w',zipfile.ZIP_DEFLATED) as z:
            def member(name,body): z.writestr(zipfile.ZipInfo(name,(2026,1,1,0,0,0)),body)
            member('mimetype','application/vnd.oasis.opendocument.spreadsheet')
            member('content.xml','<office:document-content xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"><office:body><office:spreadsheet><table:table table:name="'+sheet+'">'+''.join(row(r) for r in rows)+'</table:table><table:table table:name="修正說明">'+row(['代碼','英/中文名稱','說明'])+row(['SAMPLE','SAMPLE reference','合成修訂，不併入主表'])+'</table:table></office:spreadsheet></office:body></office:document-content>')
        profile.update(inputs=[source.name],input_sha256={})
        path=folder/'profile.json';path.write_text(json.dumps(profile,ensure_ascii=False),encoding='utf-8')
        return build(folder,path,output)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--pcs',action='store_true');a=p.parse_args();sample(a.output,a.pcs)
