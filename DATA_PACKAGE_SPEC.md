# DATA_PACKAGE_SPEC.md — 跨 Windows / Android 統一離線資料包規格

版本：1.0；此文件為 **規範性契約**，App 與 Python Builder 同時遵循。

## 1. 設計目的

- 程式主體、官方分類資料、使用者資料分離。
- `.icdpack` 由 Windows 建立後可 **不做任何修改** 匯入 Windows 或 Android；相同位元組 SHA-256 相同。
- 不依賴絕對路徑、Android/Windows 特有 SQLite 擴充套件、伺服器或 Python runtime。
- 多版本並存；可建立英文基本包與中文版 overlay 包，或合併發行包；資料來源可追溯。

## 2. 檔案封裝（ZIP，副檔名 `.icdpack`）

```text
icd10cm-fy2027-2026-10-en.icdpack
├── manifest.json
├── content.sqlite
└── checksums.sha256
```

- `content.sqlite` 使用 SQLite 標準檔案格式；FTS5 虛擬表建置並驗證，Android/Windows 均必須具 FTS5 的 sqlite library。禁止寫入平台原生 library。
- 匯入時先確認 ZIP central directory、檔案清單、壓縮/解壓比例、每檔大小與總限制；不允許 `../`、絕對路徑、symlink、重複 entry、未知可執行檔。
- 在同一檔案系統的 staging 資料夾驗證後，將 SQLite 資料庫搬移至 app-private data；不直接對 ZIP 執行 SQL；使用者提供的包視為不受信任。
- manifest 需使用 UTF-8 JSON，所有時間使用 ISO 8601，欄位命名固定 snake_case。

### manifest 範例（示意，數量/雜湊均需由 builder 實際計算）

```json
{
  "format": "icdpack",
  "schema_version": "1.0.0",
  "package_id": "icd10cm-us-fy2027-oct-en",
  "package_version": "1.0.0",
  "kind": "icd10cm_en",
  "classification": "ICD-10-CM",
  "jurisdiction": "US",
  "edition": "FY2027",
  "release_id": "2026-10-01",
  "effective_from": "2026-10-01",
  "effective_to": "2027-09-30",
  "language": "en",
  "source_organization": "CDC/NCHS; CMS",
  "source_urls": ["https://www.cdc.gov/nchs/icd/icd-10-cm/files.html"],
  "source_files": [{"name":"official-source.zip","sha256":"<actual-source-hash>"}],
  "created_at": "2026-10-29T00:00:00Z",
  "content_filename": "content.sqlite",
  "content_sha256": "<actual-hash>",
  "required_app_schema_min": "1.0.0",
  "row_counts": {"code_nodes": 0, "index_entries": 0, "notes": 0}
}
```

中文 overlay `kind=icd10cm_zh_tw`、`jurisdiction=TW`、`language=zh-TW`、`translation_edition`、`translation_revision`、`compatible_base_package_ids`、`mapping_policy` 等屬性；對應政策為 exact edition / reviewed cross-release / unresolved；只有已人工或規則驗證符合版本者可標示官方相容。

## 3. 基本 SQL 結構（欄位可補充，不可破壞語義）

```sql
CREATE TABLE package_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE code_nodes (
  id INTEGER PRIMARY KEY, code TEXT NOT NULL, code_normalized TEXT NOT NULL,
  parent_id INTEGER REFERENCES code_nodes(id), node_type TEXT NOT NULL,
  title_en TEXT NOT NULL, billable INTEGER NOT NULL CHECK (billable IN (0,1)),
  valid_from TEXT, valid_to TEXT, sort_order INTEGER NOT NULL,
  UNIQUE(code_normalized)
);
CREATE INDEX idx_code_parent ON code_nodes(parent_id, sort_order);
CREATE TABLE notes (
  id INTEGER PRIMARY KEY, owner_node_id INTEGER NOT NULL REFERENCES code_nodes(id),
  note_type TEXT NOT NULL, note_text TEXT NOT NULL, display_order INTEGER NOT NULL,
  source_element TEXT, source_reference TEXT
);
CREATE INDEX idx_notes_owner ON notes(owner_node_id,display_order);
CREATE TABLE index_entries (
  id INTEGER PRIMARY KEY, parent_id INTEGER REFERENCES index_entries(id),
  main_term TEXT NOT NULL, sub_term TEXT, term_path TEXT NOT NULL,
  target_code TEXT, entry_type TEXT NOT NULL, display_order INTEGER NOT NULL,
  source_reference TEXT
);
CREATE TABLE index_crossrefs (
  id INTEGER PRIMARY KEY, index_entry_id INTEGER NOT NULL REFERENCES index_entries(id),
  ref_type TEXT NOT NULL, target_term TEXT NOT NULL, display_order INTEGER NOT NULL
);
CREATE TABLE translations (
  id INTEGER PRIMARY KEY, code_normalized TEXT NOT NULL, title_zh_tw TEXT NOT NULL,
  translation_edition TEXT NOT NULL, translation_revision TEXT NOT NULL,
  source_reference TEXT NOT NULL, mapping_status TEXT NOT NULL,
  base_package_id TEXT, notes TEXT
);
CREATE INDEX idx_trans_code ON translations(code_normalized);
CREATE VIRTUAL TABLE code_search_fts USING fts5(code, title_en, synonyms, tokenize='unicode61');
CREATE TABLE zh_ngrams (ngram TEXT NOT NULL, code_normalized TEXT NOT NULL,
  source_translation_id INTEGER NOT NULL, PRIMARY KEY(ngram,code_normalized,source_translation_id));
CREATE INDEX idx_zh_code ON zh_ngrams(code_normalized);
```

**注意**：以上是 schema 最小示例；正式資料模型必須支援多章節分類節點（部分 heading 不具有正式 ICD code）、Index 子詞與跨參照、Neoplasm/Drugs/External Causes 表的類型及 source order。不能把所有 Index 內容只攤成 code→text。FHIR/ML 搜尋不屬首版強制需求。

## 4. 使用者資料獨立保存

`user.sqlite` 不包含在官方資料包；表格例如 `favorites`、`personal_notes`、`search_history`、`preferences`、`installed_packages`；引用以 `(classification, package_id, code)` 或穩定 domain key 進行，不可假設跨版 code 語意完全一致。Android 存於 app-private storage；Windows 預設便攜使用者資料夾（若執行位置不可寫，明確提示或改用使用者資料目錄）。

## 5. 更新交易流程

1. 文件選擇器選取 `.icdpack`；只在本機處理。
2. ZIP 安全檢查，解包到 staging。
3. 驗證 `manifest` JSON schema、checksum、SQLite `PRAGMA quick_check` / `integrity_check`、必要 table/index、foreign_key_check、schema compatibility。
4. 檢查分類、代碼、Index、notes 計數及代表性抽查；拒絕破損、重複 package id 且 hash 不同未升版、與 App schema 不相容資料。
5. overlay 包驗證 base 版本及來源/對應狀態；不確定映射顯示警示。
6. 切換前確認空間與備份；原子改名/交易方式發布；同步更新 `installed_packages`；保留舊版以回復。
7. 若失敗則清除 staging，舊資料完整不變；提供可讀錯誤與不含個資的本地 log。

## 6. 同包跨平台相容測試

- Builder 只製作一個 `.icdpack`，記錄 SHA-256；原檔分別複製到 Windows 和 Android（不重新壓縮、改寫 manifest 或重建 SQLite）。
- 比較兩端 package SHA-256、SQLite `schema_version`、row_counts、50 條預定查詢結果、Index crossrefs、notes 繼承呈現與 Unicode 中文搜尋結果。
- 首版 SQLite/FTS5 版本差異必須測試：無需特定自訂 tokenizer；中文採預建 n-gram 普通表，英文 FTS5。
- 版本 migration 只能在 **App 安裝狀態庫** 或 staging 複製上進行，原 `.icdpack` 位元組不可改動。

## 7. 發布、授權與來源

發行前檢查各官方檔案使用條款；`SOURCE_PROVENANCE.md` 記錄下載頁、原始檔 SHA256、release/effective date、轉換工具版、匯入時間與譯名來源。不得把其他網站的排版、搜尋結果或受限制文件直接再散布。

## 分類API1.1擴充（App 0.2.0）

新增 `classification=ICD-10-PCS`，kind為 `icd10pcs_en`／`icd10pcs_zh_tw`／`icd10pcs_combined`，PCS的required_app_schema_min為1.1.0；CM仍為1.0.0。實體schema_version仍1.0.0，既有SQL allowlist完全不變。PCS採分離分類語義：七軸／row組合及完整來源XML以typed notes保留，非CM coding notes；完整碼、來源heading、明確Index目標及來源版號不可混淆。詳 `docs/RELEASE_0.2.0.md`。
