PRAGMA foreign_keys=ON;
PRAGMA user_version=10000;
CREATE TABLE package_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE code_nodes (
 id INTEGER PRIMARY KEY, node_key TEXT NOT NULL UNIQUE, code TEXT NOT NULL,
 code_normalized TEXT NOT NULL UNIQUE, parent_id INTEGER REFERENCES code_nodes(id),
 node_type TEXT NOT NULL CHECK(node_type IN ('chapter','block','category','subcategory')),
 title_en TEXT NOT NULL, billable INTEGER NOT NULL CHECK(billable IN (0,1)),
 is_leaf INTEGER NOT NULL CHECK(is_leaf IN (0,1)),
 state TEXT NOT NULL CHECK(state IN ('billable','nonbillable','incomplete','requires_extension')),
 valid_from TEXT, valid_to TEXT, sort_order INTEGER NOT NULL, source_reference TEXT NOT NULL,
 CHECK ((billable=1 AND state='billable') OR (billable=0 AND state!='billable'))
);
CREATE INDEX idx_code_parent ON code_nodes(parent_id,sort_order);
CREATE TABLE notes (
 id INTEGER PRIMARY KEY, owner_node_id INTEGER NOT NULL REFERENCES code_nodes(id),
 note_type TEXT NOT NULL, note_text TEXT NOT NULL, display_order INTEGER NOT NULL,
 source_element TEXT NOT NULL, source_reference TEXT NOT NULL, raw_xml TEXT NOT NULL
);
CREATE INDEX idx_notes_owner ON notes(owner_node_id,display_order);
CREATE TABLE index_entries (
 id INTEGER PRIMARY KEY, parent_id INTEGER REFERENCES index_entries(id),
 main_term TEXT NOT NULL, sub_term TEXT, term_path TEXT NOT NULL, target_code TEXT,
 entry_type TEXT NOT NULL CHECK(entry_type IN ('alphabetic','external','neoplasm','drugs')),
 display_order INTEGER NOT NULL, source_reference TEXT NOT NULL
);
CREATE INDEX idx_index_parent ON index_entries(parent_id,display_order);
CREATE VIRTUAL TABLE index_search_fts USING fts5(term_path, tokenize='unicode61');
CREATE TABLE index_crossrefs (
 id INTEGER PRIMARY KEY, index_entry_id INTEGER NOT NULL REFERENCES index_entries(id),
 ref_type TEXT NOT NULL, target_term TEXT NOT NULL, display_order INTEGER NOT NULL
);
CREATE TABLE table_cells (
 id INTEGER PRIMARY KEY, index_entry_id INTEGER NOT NULL REFERENCES index_entries(id),
 column_label TEXT NOT NULL, target_code TEXT NOT NULL, display_order INTEGER NOT NULL
);
CREATE TABLE translations (
 id INTEGER PRIMARY KEY, code_normalized TEXT NOT NULL, title_zh_tw TEXT NOT NULL,
 search_normalized TEXT NOT NULL, translation_edition TEXT NOT NULL, translation_revision TEXT NOT NULL,
 source_reference TEXT NOT NULL, mapping_status TEXT NOT NULL CHECK(mapping_status IN ('exact_edition','reviewed_cross_release','unresolved')),
 base_package_id TEXT, notes TEXT, UNIQUE(code_normalized,translation_edition,translation_revision)
);
CREATE INDEX idx_trans_code ON translations(code_normalized);
CREATE VIRTUAL TABLE code_search_fts USING fts5(code, title_en, synonyms, tokenize='unicode61');
CREATE TABLE zh_ngrams (
 ngram TEXT NOT NULL, code_normalized TEXT NOT NULL,
 source_translation_id INTEGER NOT NULL REFERENCES translations(id),
 PRIMARY KEY(ngram,code_normalized,source_translation_id)
);
CREATE INDEX idx_zh_code ON zh_ngrams(code_normalized);
CREATE INDEX idx_zh_translation ON zh_ngrams(source_translation_id);
