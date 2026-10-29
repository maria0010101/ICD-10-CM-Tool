"""Standalone NHI CM bilingual snapshot; never a US cross-release overlay."""
from __future__ import annotations
import json
import re
from .adapters import add_node
from .package import PackageError, code_key, grams, normalized
from .spreadsheets import mapped_records


def import_nhi_cm_app(db, path, columns, meta):
    if (columns.get('sheet') != 'ICD-10-CM' or
        meta.get('classification') != 'ICD-10-CM' or
        meta.get('kind') != 'icd10cm_combined' or
        meta.get('mapping_policy') != 'exact_edition' or
        meta.get('compatible_base_package_ids') != [meta['package_id']]):
        raise PackageError('NHI CM standalone requires its own same-edition bilingual package, never US bases')
    db.execute('SAVEPOINT nhi_cm_app')
    try:
        root = add_node(db, '@nhi-cm-source', '', None, 'chapter',
                        ('SAMPLE / NOT FOR CLINICAL CODING 中英格式測試' if meta.get('is_sample') else '健保署2023 CM 中英對照（代碼前綴導覽，非官方章節樹）'),
                        0, 0, 'nonbillable', 0, path.name, meta)
        db.execute('INSERT INTO notes(owner_node_id,note_type,note_text,display_order,source_element,source_reference,raw_xml) VALUES (?,?,?,?,?,?,?)',
                   (root, 'source_scope', '僅含健保署2023同版代碼、USE及原始中英文欄位；代碼前綴導覽不是官方Chapter/Block。未含美國Tabular註記或Alphabetic Index，不宣稱與FY2027相容。', 0, 'source_scope', path.name, ''))
        parents = {}; count = 0
        for line, row in mapped_records(path, columns):
            code = row[columns['code']]; key = code_key(code)
            english = row[columns['title_en']]; chinese = row[columns['title_zh_tw']]; use = row[columns['use']]
            if (not re.fullmatch(r'[A-Z][0-9][A-Z0-9](?:\.[A-Z0-9]{1,4})?', code)
                    or use not in ('0', '1') or not english or not chinese):
                raise PackageError('Invalid NHI CM source row ' + str(line))
            if key in parents: raise PackageError('Duplicate NHI CM code ' + code)
            parent = next((parents[key[:n]] for n in range(len(key)-1, 2, -1) if key[:n] in parents), root)
            ref = path.name + ':ICD-10-CM:row:' + str(line)
            ident = add_node(db, code, code, parent, 'category' if len(key)==3 else 'subcategory',
                             english, int(use), 1, 'billable' if use=='1' else 'nonbillable', count+1, ref, meta)
            parents[key] = ident
            db.execute('INSERT INTO notes(owner_node_id,note_type,note_text,display_order,source_element,source_reference,raw_xml) VALUES (?,?,?,?,?,?,?)',
                       (ident, 'nhi_source_columns', json.dumps(row, ensure_ascii=False), 0, 'nhi_source_columns', ref, ''))
            translation = db.execute('INSERT INTO translations(code_normalized,title_zh_tw,search_normalized,translation_edition,translation_revision,source_reference,mapping_status,base_package_id,notes) VALUES (?,?,?,?,?,?,?,?,?)',
                (key, chinese, normalized(chinese), meta['translation_edition'], meta['translation_revision'], ref,
                 'exact_edition', meta['package_id'], 'Same original NHI bilingual row; no US cross-release compatibility')).lastrowid
            db.executemany('INSERT INTO zh_ngrams VALUES (?,?,?)', ((g,key,translation) for g in sorted(grams(chinese))))
            count += 1
        if not count: raise PackageError('Empty NHI CM sheet')
        db.execute('UPDATE code_nodes SET is_leaf=0 WHERE id IN (SELECT parent_id FROM code_nodes WHERE parent_id IS NOT NULL)')
        db.execute('RELEASE nhi_cm_app')
        return {'same_edition_bilingual_rows':count, 'hierarchy':'code-prefix navigation only', 'us_cross_release_compatibility_claim':False}
    except BaseException:
        db.execute('ROLLBACK TO nhi_cm_app'); db.execute('RELEASE nhi_cm_app'); raise
