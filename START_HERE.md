# START_HERE.md — 貼給 Antigravity / Codex 的第一個指令

你是資深 Flutter 跨平台工程師、SQLite 全文檢索工程師、Python 資料 ETL 工程師與 ICD-10-CM 編碼資料模型設計師。

請先完整閱讀同目錄的 `AGENTS.md`、`SRS.md`、`DATA_PACKAGE_SPEC.md`、`TEST_PLAN.md`、`README.md`，再**直接實作可執行專案、驗證與測試**；不要只給我建議、程式片段或高階藍圖。

本專案的最高優先限制：
1. Flutter/Dart 同一套 App 支援 Android ARM64（手機單欄、平板雙欄）與 Windows x64 免安裝 portable ZIP（三欄）。
2. SQLite FTS5 即時英文搜尋、中文 n-gram、完整代碼/Index/Tabular/notes。
3. CDC/CMS 官方英文資料、台灣衛福部/健保署官方中文資料；多版本共存，不混用相容性不明的中譯。
4. **App、資料包、使用者資料分離；同一個 `.icdpack` 不經修改、兩平台直接匯入**。這是不可妥協的 Gate。資料包需版本清單、SHA256、SQLite integrity 與安全的 staging/rollback。
5. Python 3.13 僅作離線官方原始檔匯入、驗證和共用 `.icdpack` 製作；最終 APK/Windows App 不需要 Python runtime、網路服務或雲端 API。
6. 所有工作在現有專案內完成，先檢查 Git 狀態、工具鏈與檔案，不得任意覆寫。沒有官方檔案時用標示清楚的非臨床測試資料實作，並說明如何匯入正式資料。
7. 依 `TEST_PLAN.md` 執行真正的測試；工具鏈不存在時列出阻礙與命令，不可虛報跨平台已通過。

請先依序交付：A. 工具鏈檢查與架構定稿；B. `.icdpack` schema、Python builder/validator 與 sample pack；C. Flutter 查詢/分類樹/詳情；D. 安全更新與跨平台 UI；E. 測試、打包、README 和驗收結果。每階段只提交實際完成的檔案與測試證據。
