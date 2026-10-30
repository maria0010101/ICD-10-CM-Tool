"""NHI 2014 alternating-row ODS: explicit sheets, inert auxiliary formulae.

No formula evaluator or Office process. Source code/title cells must be literals.
The absent USE field is never inferred from code length or tree leaves.
"""
from __future__ import annotations
import json
import re
from pathlib import Path
from .adapters import add_node
from .package import PackageError, code_key, grams, normalized
from .spreadsheets import ods_rows


def read_legacy(path, profile):
    spec = profile['legacy_layout']
    classification = profile['metadata']['classification']
    pattern = (r'[A-Z][0-9][A-Z0-9](?:\.[A-Z0-9]{1,4})?' if classification == 'ICD-10-CM'
               else r'[0-9A-HJ-NP-Z]{7}')
    selected = spec['sheets']; excluded = spec.get('reference_sheets', [])
    if set(selected) & set(excluded): raise PackageError('Overlapping source/reference sheets')
    missing_zh = set(spec.get('missing_translation_codes', []))
    records = []; reference_rows = []; headings = {}; seen = set(); found = set(); pending = None
    for sheet, number, row in ods_rows(path, inert_formula_columns=spec.get('inert_formula_columns')):
        if sheet not in selected and sheet not in excluded:
            raise PackageError('Unreviewed NHI 2014 sheet: ' + sheet)
        found.add(sheet)
        ref = path.name + ':' + sheet + ':row:' + str(number)
        if sheet in excluded:
            reference_rows.append({'reference':ref, 'cells':row}); continue
        if number == 1:
            if pending:
                if pending['code'] not in missing_zh: raise PackageError('Missing bilingual continuation before new sheet')
                pending['title_zh_tw']=None; records.append(pending); pending=None
            headings[sheet] = {'reference':ref, 'cells':row}; continue
        if number == 2:
            if row[:2] != ['代碼', '英/中文名稱']: raise PackageError('Unexpected NHI 2014 header: '+ref)
            continue
        if len(row) < 2 or not row[1].strip(): raise PackageError('Missing source title: '+ref)
        code = row[0].strip()
        if code:
            if pending:
                if pending['code'] not in missing_zh: raise PackageError('Missing Chinese continuation: '+ref)
                pending['title_zh_tw']=None;records.append(pending);pending=None
            if not re.fullmatch(pattern, code): raise PackageError('Invalid NHI 2014 code: '+ref)
            key = code_key(code)
            if key in seen: raise PackageError('Duplicate NHI 2014 code: '+code)
            seen.add(key)
            pending = dict(code=code, title_en=row[1], sheet=sheet, source_reference=ref,
                           english_row=number, source_rows=[{'reference':ref, 'cells':row}])
        else:
            if pending is None or pending['sheet'] != sheet:
                raise PackageError('Orphan Chinese continuation: '+ref)
            pending['title_zh_tw'] = row[1]
            pending['source_rows'].append({'reference':ref, 'cells':row})
            records.append(pending); pending = None
    if pending:
        if pending['code'] not in missing_zh: raise PackageError('Missing Chinese continuation at end of source')
        pending['title_zh_tw']=None;records.append(pending)
    if not set(selected + excluded) <= found: raise PackageError('Missing reviewed NHI 2014 sheets')
    if not records: raise PackageError('Empty NHI 2014 source')
    return records, headings, reference_rows


def import_legacy(db, path, profile, meta):
    kind = 'icd10cm_combined' if meta['classification']=='ICD-10-CM' else 'icd10pcs_combined'
    if (meta['kind'] != kind or meta.get('mapping_policy') != 'exact_edition'
        or meta.get('compatible_base_package_ids') != [meta['package_id']]
        or meta.get('code_status_policy') != 'not_provided'):
        raise PackageError('NHI 2014 requires own bilingual edition and explicit unknown code status')
    records, headings, references = read_legacy(path, profile)
    db.execute('SAVEPOINT legacy_import')
    try:
        root = add_node(db,'@nhi2014-source','',None,'chapter',
                        '健保署2014 '+meta['classification']+' 中英對照（代碼前綴導覽）',
                        0,0,'nonbillable',0,path.name,meta)
        scope = '來源未提供USE／可申報狀態；不依碼長或leaf推定。只含該版中英原文及來源列，非美國Tabular／Index／七軸表；修正說明另存，不與主表合併。不宣稱其他年度相容。'
        def note(owner, typ, body, ref, order=0):
            db.execute('INSERT INTO notes(owner_node_id,note_type,note_text,display_order,source_element,source_reference,raw_xml) VALUES (?,?,?,?,?,?,?)',
                       (owner,typ,body,order,typ,ref,''))
        note(root,'source_scope',scope,path.name)
        for pos, item in enumerate(references):
            note(root,'nhi_revision_reference',json.dumps(item,ensure_ascii=False),item['reference'],pos+1)
        groups={}
        for sheet, heading in headings.items():
            groups[sheet] = add_node(db,'@nhi2014-sheet:'+sheet,'',root,'block',
                                    ' / '.join(heading['cells']),0,0,'nonbillable',len(groups),heading['reference'],meta)
            note(groups[sheet],'nhi_source_heading',json.dumps(heading,ensure_ascii=False),heading['reference'])
        parents={}
        for pos,r in enumerate(records):
            key=code_key(r['code'])
            parent=next((parents[key[:n]] for n in range(len(key)-1,2,-1) if key[:n] in parents),groups[r['sheet']]) if kind=='icd10cm_combined' else groups[r['sheet']]
            ident=add_node(db,key,r['code'],parent,'category' if len(key)==3 else 'subcategory',r['title_en'],
                           0,1,'nonbillable',pos+1,r['source_reference'],meta)
            parents[key]=ident
            note(ident,'nhi_source_rows',json.dumps(r['source_rows'],ensure_ascii=False),r['source_reference'])
            if r['title_zh_tw'] is None: continue
            tid=db.execute('INSERT INTO translations(code_normalized,title_zh_tw,search_normalized,translation_edition,translation_revision,source_reference,mapping_status,base_package_id,notes) VALUES (?,?,?,?,?,?,?,?,?)',
                (key,r['title_zh_tw'],normalized(r['title_zh_tw']),meta['translation_edition'],meta['translation_revision'],r['source_rows'][1]['reference'],
                 'exact_edition',meta['package_id'],'NHI 2014 original adjacent bilingual rows only; USE absent')).lastrowid
            db.executemany('INSERT INTO zh_ngrams VALUES (?,?,?)',((g,key,tid) for g in sorted(grams(r['title_zh_tw']))))
        db.execute('UPDATE code_nodes SET is_leaf=0 WHERE id IN (SELECT parent_id FROM code_nodes WHERE parent_id IS NOT NULL)')
        db.execute('RELEASE legacy_import')
    except BaseException:
        db.execute('ROLLBACK TO legacy_import');db.execute('RELEASE legacy_import');raise
    return dict(bilingual_rows=len(records),source_sheets=len(headings),reference_rows=len(references),
                code_status_policy='not_provided',formula_policy='auxiliary formulas preserved as inert text; never evaluated or used as data')
