# AGENTS.md — ICD-10-CM Offline Dictionary Agent 開發指令

> 本文件為 Agent AI（Antigravity / Codex 等）的執行規範。必須與 `SRS.md`、`DATA_PACKAGE_SPEC.md`、`TEST_PLAN.md` 一併閱讀。版本：1.0（2026-10-29）。

## 0. 目標與執行原則

直接建立、實作、測試、打包「ICD-10-CM Offline Dictionary」。不只輸出規劃或樣板。目標：**Flutter / Dart 共用 Android 手機、平板及 Windows 桌面 UI；SQLite FTS5 本機搜尋；Python 3.13 離線官方資料轉換器**。必須符合資料與程式分離：**同一個位元組完全一致的資料包，在 Windows 與 Android 均可直接匯入，無平台專屬轉換，無伺服器依賴**。

如開發環境沒有 Flutter、Android SDK 或 Windows 編譯器，先檢查現有環境並記錄缺失；完成可實作部分與測試，不得聲稱沒有實際執行的建置成功。不得覆蓋既有檔案或刪除資料；修改前檢視 repo 狀態、保留使用者變動。

## 1. 工具與技術

- App：Flutter stable / Dart，採用 responsive/adaptive UI；Windows x64 可攜 ZIP、Android arm64 APK；不在 App 中嵌入 Python runtime。
- 儲存：SQLite + FTS5；優先評估 `sqlite3` + `sqlite3_flutter_libs`（版本依當期套件實際相容性）及 Drift；在兩平台驗證 FTS5 是否可用。避免使用 Android 只適用的 SQLite API 或擴充功能。
- 資料建置：Python 3.13；`lxml`（禁用外部實體/網路）、`openpyxl`、標準庫 `sqlite3`；版本鎖定並產生 requirements lock。
- 版本資料：CDC/NCHS、CMS 官方 ICD-10-CM 原始資料（英文、階層、Alphabetic Index、各類 notes）；台灣衛福部/健保署官方中譯獨立對照層。不可將第三方專案資料或非官方中文當成官方內容。
- `simple_icd_10_CM`：僅作**參考實作**或相容性比較，不得作唯一資料來源或將其內建代碼版本當成最新版本。
- 完全離線：正式 App 無登入、帳號、遙測、API、雲端查詢、外網依賴，無背景網路下載；更新由使用者手動下載檔案及匯入。

## 2. 開工步驟（依序）

1. 檢視工作目錄、Git 狀態及現有程式；記錄 Python、Flutter、Dart、Android SDK、Windows 工具鏈版本。
2. 閱讀 `SRS.md`、`DATA_PACKAGE_SPEC.md`、`TEST_PLAN.md`，建立需求追蹤表與可執行任務清單。
3. 先定義跨平台資料包 schema、`manifest.json`、樣本資料、Python builder/validator、完整性測試。先證明相同資料包能被 Windows/Android SQLite 開啟。
4. 實作 Flutter domain repository、精確碼搜尋、英文 FTS5、中文索引、版本辨識、階層樹及 notes 資料存取；測試結果正確性。
5. 實作 responsive UI：手機一欄列表→詳情，平板雙欄，Windows 三欄；鍵盤操作與可存取性。
6. 實作安全匯入：檔案選取→預檢→複製至暫存→SHA256/SQLite integrity/schema/來源驗證→索引檢查→原子切換；保留舊版及回復。
7. 實作官方原始檔匯入（由 Python desktop builder 支援 CDC/CMS XML/TXT/ZIP 與健保署 XLSX/CSV/ODS 視可用解析器）；Android 首版匯入**標準資料包**，不必直接解析大型原始 XML/Excel。
8. 完成單元、整合、安全、效能、跨平台測試；產生 Windows portable ZIP、Android ARM64 APK（若工具鏈齊備）。
9. 更新 README、版本與授權清單、驗收表、已知限制；提供實際測試輸出與發行物 checksum。

## 3. 必須遵守的不可妥協條件

- **資料與程式分離**：App 不把編碼資料寫死在 Dart；既有資料包不能因 App 升版無預警失效。應用程式、官方資料、使用者收藏/註解三層物理隔離。
- **跨平台原封不動匯入**：標準 `.icdpack` 為帶版本的 ZIP 容器，內含純 SQLite/JSON，禁止任何絕對路徑、平台專屬二進位與平台專屬 SQL extension；Windows 與 Android 接受同一 SHA-256 的檔案，資料與查詢結果一致。
- **資料版本**：英文字典（例如 FY2027 Oct release）與台灣中文翻譯版（例如 2023 edition + revision date）獨立標記；不得只依 code 字串無條件合併跨版本翻譯；不明者顯示警示。
- **註記與索引忠實度**：Chapter、Block、Category、Subcategory notes 都要保留來源節點及順序；顯示繼承註記並清楚標示來源。包括 Excludes1/2、Code First、Use Additional Code、Code Also、Includes、7th character、placeholder、Index cross-references（see / see also）等；不能因搜尋引擎正規化而改變官方原文。
- **編碼安全**：結果排序不等於診斷確立；不要將未完成的 Category 當成有效可申報碼，須有明確的 billable/leaf/state 與版本語義；無中譯時顯示「該版本無經驗證官方中譯」。
- **離線安全**：所有匯入均不得執行外部內容，ZIP 限制解壓大小/數量/路徑穿越，XML 禁止 XXE、公式不執行，SQLite 使用唯讀開啟資料包（匯入驗證階段為例外）。
- **資料回復**：所有資料更新 staging + validation + atomic publish，錯誤則不影響現行版本；使用者資料獨立且不被清除。
- **絕不杜撰資料**：沒有官方原始檔時，只使用清楚標示 `SAMPLE / NOT FOR CLINICAL CODING` 的測試資料；不得將示例當作正式完整字典。

## 4. 必要交付物

```text
app/                       Flutter 專案
  lib/{app,domain,data,features,ui}/
  test/ integration_test/
tools/data_builder/        Python 離線 builder、validator、tests
samples/                   明確標示非正式之小型測試包
schemas/                   manifest JSON Schema、SQLite schema/migrations
scripts/                   build/test/package 指令及 Windows .bat/.ps1
AGENTS.md SRS.md README.md DATA_PACKAGE_SPEC.md TEST_PLAN.md
LICENSES.md SOURCE_PROVENANCE.md
```

所有程式提供可重現指令（Windows PowerShell 與 CI 命令），版本鎖定；README 詳列官方資料的取得和導入方式。不要附送未確認再散布權限的完整官方/第三方資料。

## 5. 驗收 Gate（全部必過，否則標示阻礙）

- G1：Windows、Android **同一 `.icdpack` 的 SHA256 相同**，兩端正常匯入、資料列數/notes/Index 關係/範例查詢一致。
- G2：停用網路/飛航模式下啟動、搜尋、切版、離線更新、回復功能可用；無網路呼叫/遙測。
- G3：官方資料完整性驗證，對應版本代碼、階層、Index、notes 等數量與原始檔一致；差異須說明。
- G4：中文跨版本對應不得默默當成官方相容；需要 lineage/status。
- G5：匯入損壞、錯版、惡意 ZIP、低磁碟空間、更新中斷均不損毀前一版。
- G6：效能：在代表性裝置與正式資料上測 p95：代碼查詢 ≤50ms、英文 ≤100ms、中文 ≤150ms、樹展開 ≤100ms（純資料層，另量 UI 首次繪製）；若未達標提供測量與改善。
- G7：Release 產物必須能在乾淨 Windows 工作站（免程式安裝）和 Android ARM64 裝置實機啟動。Windows 可以包含 app-local VC++ redistributable，遵照授權。
- G8：整份測試報告、檔案體積及未達標項目，均需有實際證據，嚴禁「假設通過」。

## 6. 提交與互動規則

- 不要以反覆詢問代替實作；遇到不明確事項依 SRS 預設值執行並記錄決策。
- 不能存取官方檔案時先完成 parser adapter、fixtures、測試及可插拔入口；清楚標示正式內容尚待匯入。
- 每個里程碑附：完成功能、檔案變更、測試命令/結果、風險、下一步。
- 禁止發送任何病歷、個資或使用者資料至網路；專案示例必須是合成資料。
