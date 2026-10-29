# 實作契約補充 v1.0.0

不取代 DATA_PACKAGE_SPEC 的語義；完整 DDL 是 `schemas/content.sql`，正式 manifest schema 是 `schemas/manifest.schema.json`。

* schema_version=`1.0.0`、SQLite PRAGMA user_version=`10000`，SQLite header 格式跨平台，不使用 WAL 或平台 extension。
* `is_sample`、所有七種 row_counts、來源檔案 SHA256 為必填；content/checksums 互驗；original archive SHA256 由外部發布清單／App 計算，不自含於 manifest 造成循環。
* `checksums.sha256` 精確兩行，依 content.sqlite／manifest.json 排序，hex 小寫、兩空白、LF。archive 三檔為唯一允許清單；metadata 不執行。
* `node_key` 作 heading穩定域鍵，code='' 不冒充診斷碼；code_normalized 在 heading 使用 @chapter:/@section: 前綴，正式碼移除小數點。`is_leaf` 與 `billable` 分離。
* 明確 `state`：billable／nonbillable／incomplete／requires_extension；billable必須依 release order標誌。
* `table_cells` 保留表格來源欄名、順序與未完整 target（含 --、末尾-）；不可視為自動跳轉的精確碼。
* `index_search_fts` 與 `code_search_fts` 使用 SQLite 內建 unicode61，沒有自訂 tokenizer；中文普通表不依靠平台斷詞。
* `translations.search_normalized` 僅供索引，展示使用原始 title_zh_tw；source_reference 保留 file/row，notes JSON 保存原CSV/XLSX全部欄位與 mapping決策。
* 合格中譯需 mapping_status∈{exact_edition,reviewed_cross_release} 且 base_package_id精確吻合，overlay manifest也必須列出 base ID。unresolved只可另行展開作警示參考，不默認合格、不能進入合格中文搜尋。
* 嚴格 schema allowlist 禁止SQL view/trigger、自訂extension、未知表。FTS shadow tables一併固定。所有DDL在兩平台由同一 schema契約比對；無任何平台專屬資料轉換。
* SHA完整性不能認證原始發布者；官方來源管理者須另保留下載頁、hash及版別稽核。
* 原包保留在 `packages/<archive_sha256>/original.icdpack`，另有readonly content.sqlite與manifest；user.sqlite單獨交易管理 active/previous，失敗不更新指標。
