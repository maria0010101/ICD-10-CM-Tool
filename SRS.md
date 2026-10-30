# SRS.md — ICD-10-CM Offline Dictionary 軟體需求規格書

版本 1.0｜2026-10-29｜狀態：Agent AI 開發基準規格

## 1. 系統目標與範圍

建立支援 Windows 免安裝與 Android 手機／平板的**完全離線、專業 ICD-10-CM 中英雙語編碼字典**。以 SmartICD-10 式即時關鍵字/代碼搜尋為主，電子書分類樹為輔；英文以 CDC/NCHS、CMS 官方資料為準；中文以台灣衛福部中央健康保險署官方資料為準。**App、官方資料包與使用者資料物理分離；單一共用 `.icdpack` 同時相容 Windows/Android**。

第一版不納入 ICD-10-PCS、Tw-DRG 自動分組、AHA Coding Clinic 全文或 AI 自動編碼；預留掛載模組。不得將搜尋結果稱為診斷判定或最終可申報代碼建議。

## 2. 角色及使用情境

- 疾病分類師：已知代碼直接搜尋；輸入英文/中文疾病術語，查看 Index → Tabular；確認註記、章節繼承規則與有效版本。
- 教學/查閱者：從 Chapter → Block → Category → 子碼展開；查詢版本間差異。
- 資料管理者：在 Windows 由官方原始資料建立標準資料包、驗證後分享給 Android；兩平台使用者可於 App 匯入同一個包。

## 3. 技術基線

| 項目 | 規格 |
|---|---|
| UI | Flutter stable / Dart，單一 codebase |
| 平台 | Windows x64 Portable ZIP；Android ARM64 APK，手機／平板自適應 |
| DB | SQLite + FTS5；中文使用預建 n-gram 索引 |
| 資料匯入 | Python 3.13 CLI / Windows 離線 builder；Flutter 匯入 `.icdpack` |
| 狀態管理 | 由 Agent 選擇成熟、持續維護且與 Flutter 版本相容的方案並記錄理由 |
| 架構 | UI / domain / repository / import / persistence 分層；可測試、可替換 |
| 發行 | 無伺服器、雲端或網路呼叫；Release 不含 Python runtime |

## 4. 功能性需求（優先度 P0/P1/P2）

### 4.1 查詢（P0）

- **FR-001** 精確 ICD-10-CM 代碼查詢，支援有無小數點、大小寫與前後空白正規化；不改動原始展示碼。
- **FR-002** 英文疾病名稱 FTS5 全文、多關鍵字 AND/OR 切換、前綴詞、相關度排序；可用別名/拼字建議，須標記為搜尋輔助非官方診斷。
- **FR-003** 中文官方名稱查詢，支援無空白中文字、Unicode 正規化與 n-gram，顯示中譯來源與版本。
- **FR-004** 搜尋可限定來源：All / Alphabetic Index / Tabular / Neoplasm Table / Drugs & Chemicals / External Cause Index（表資料存在時才顯示可用）。
- **FR-005** 列表顯示 code、英文完整描述、中文名稱（如有合格中譯）、版本、billable 狀態；搜尋排名不得取代 Index→Tabular 驗碼。
- **FR-006** 提供 Ctrl+L/Ctrl+F 聚焦搜尋、Esc 清空或返回、方向鍵選結果、Enter 開啟；Android 支援軟鍵盤與觸控。

### 4.2 詳情與分類架構（P0）

- **FR-010** 顯示 Chapter / Block / Category / Subcategory 階層與上下層關係；懶載入，支援收合展開。
- **FR-011** 詳情呈現英文原文、對應官方中文、代碼、有效時間、是否完整可用（不得只由是否 leaf 推論）。
- **FR-012** 顯示 Includes、Excludes1、Excludes2、Code First、Use Additional Code、Code Also、7th character、placeholder、注釋及適用的上層繼承 notes；保留來源節點與原始順序。
- **FR-013** Alphabetic Index 樹包含 main term、subterm、see/see also cross reference，支援 Index→Tabular 與 Tabular→相關 Index 候選；Index 指向範圍需可確認而非任意當作精確碼。
- **FR-014** Neoplasm、Drugs & Chemicals、External Causes 依官方來源可用內容支援結構化瀏覽；不得宣稱缺失資料已匯入。
- **FR-015** 快速複製 code、完整英文名稱、中文（可選），可複製來源版號。

### 4.3 畫面（P0）

- **FR-020** Android 小螢幕：搜尋列表／詳情兩頁或分頁，底部導覽；觸控元素大小符合平台標準。
- **FR-021** Android 平板：雙欄列表＋詳情；旋轉螢幕自動調整且保留查詢狀態。
- **FR-022** Windows：三欄（分類樹、結果、代碼詳情），可調整欄寬；鍵盤與滑鼠優先，視窗縮小時退化為雙欄/單欄。
- **FR-023** Light/Dark 模式、英文原始拼寫忠實呈現、文字縮放、無障礙標籤。

### 4.4 資料、版本與來源（P0）

- **FR-030** 資料與程式獨立：Flutter 原始碼與執行檔不嵌入正式資料；初次啟動提供匯入精靈、示例資料顯著標註非臨床用途。
- **FR-031** 共用標準 `.icdpack`：不經轉檔或重封裝，Windows 與 Android 均可匯入；具 manifest、校驗碼與 SQLite 內容；詳 `DATA_PACKAGE_SPEC.md`。
- **FR-032** 多英文年度/半年度 effective release 並存，可選擇；繁體中文資料另標版本/修訂批次，跨版匹配需顯示明確狀態。
- **FR-033** 來源追溯：每筆或每組資料均有發布者、release ID、原始檔參照、匯入批次；不提供假造官方中文名稱。
- **FR-034** 版間對照：新增、停用、代碼拆分、描述更改、註記改變，以官方發布檔及版本比較建立，不以相同代碼判定語義完全相同。
- **FR-035** 官方英文與台灣中文資料不互相覆蓋；無相容中文時省略中譯列與缺譯提示（2026-10-30修訂），可選擇顯示跨版參考並警示。

### 4.5 匯入與更新（P0）

- **FR-040** Python CLI builder 支援 CDC/CMS ZIP/XML/TXT，以 adapter 分別解析 Tabular、Index、notes、描述及發布資料；對變動欄位可調整 adapter，不能默默忽略資料。
- **FR-041** Python CLI 支援健保署中英對照 XLSX、CSV；ODS 若原始檔提供且依賴可用則支援；表格格式變動採人工欄位對應／模板，避免自動誤識別。
- **FR-042** Windows/Android App 以檔案選擇器匯入同一 `.icdpack`；不需要 Python、網路或管理員權限。
- **FR-043** 匯入有預覽、版本/來源、row count、checksum 與不相容警示，明確點擊才啟用。
- **FR-044** staging 安全驗證、切換、失敗回復、匯入紀錄與保留舊版。
- **FR-045** 必須防惡意 ZIP/路徑穿越/ZIP bomb、XML XXE、SQLite 外來檔案損毀、XLSX 公式；不可執行匯入資料中的程式碼。
- **FR-046** 允許資料包獨立於 App 升級；schema 不相容要有明確阻擋與升級指示，且不毀損原始包。

### 4.6 使用者資料（P1）

- **FR-050** 我的收藏、註解、最近查詢存於 `user.sqlite`，與官方資料完全分開；關閉查詢歷史功能選項。
- **FR-051** 本地匯出/匯入收藏（JSON），版本變更後代碼失效應警示；禁止自動同步外網。

### 4.7 後續擴充（P2）

- **FR-060** ICD-10-PCS、Tw-DRG、AHA Coding Clinic／官方 Guidelines 的**獨立模組接口**；有授權資料才可匯入，避免混淆診斷代碼與處置代碼。
- **FR-061** 允許未來增加其他搜尋字典及自訂別名，私人詞庫不得標為官方中譯。

## 5. 非功能性需求

- **NFR-001 離線**：啟動、搜尋、切換版本、匯入/回復均無網路，無遙測；離線/飛航模式實機測試。
- **NFR-002 效能**：在指定基準裝置使用正式資料、warm-cache p95：精確碼 ≤50 ms；英文 ≤100 ms；中文 ≤150 ms；樹節點 ≤100 ms；模糊搜尋 ≤300 ms。需另記錄冷啟動及 UI frame time。效能數字是驗收目標，不是既成事實。
- **NFR-003 體積**：程式主體（不含資料包）發行物大小應被量測並列出；初期目標 Windows ZIP ≤80 MB、Android ARM64 APK ≤40 MB，超標需報告原因與縮減方式；不得以犧牲完整性換體積。
- **NFR-004 相容性**：同一資料包在 Windows x64 與 Android ARM64 使用；Android 最低 OS 版本由 Agent 依 Flutter 套件相容性提出並測試；提供 matrix。
- **NFR-005 安全性**：匯入不受信任檔案須設大小與 resource limits；user.sqlite 避免外洩，無憑證與個資上傳。
- **NFR-006 資料準確度**：官方來源完整、可追溯；重要 notes 正確繼承；測試涵蓋 Index 類型、版本與譯文一致性。
- **NFR-007 可維護**：獨立 importer adapter/schema migrations、lockfile、CI、單元與跨平台驗收；遵循基本授權。
- **NFR-008 穩定性**：更新中止或手機儲存空間不足不能損壞原已啟用資料；支援 rollback。

## 6. 核心 UX 流程

1. 初次啟動 → 偵測已安裝資料包 → 無包時「匯入官方資料包」及示範模式（強烈警示）。
2. 版本選擇 → 代碼/關鍵字搜尋 → 結果 → 詳情 → Index/Tabular 交叉跳轉 → 檢視來源/繼承 notes。
3. 資料管理 → 選 `.icdpack` → 查看 manifest 與差異 → 驗證 → 啟用/保留舊版 → 出錯回復。
4. 中文顯示：優先完全相容官方版本；無匹配時英文原文，若選跨版對照則標示「非同版，僅供參考」。

## 7. 交付與驗收

通過 `TEST_PLAN.md`，交付完整 Flutter 原始碼、Python builder、schema、測試、Windows portable ZIP、Android arm64 APK（工具鏈具備時）、資料包規格、樣本包、官方來源與授權說明；未實際建置項目標示 blocked。每次更新都可回歸執行相同驗收腳本。

## 8. 官方資料參考入口

- CDC: https://www.cdc.gov/nchs/icd/icd-10-cm/files.html
- CDC FY2027 files: https://ftp.cdc.gov/pub/Health_Statistics/NCHS/Publications/ICD10CM/2027/
- CMS: https://www.cms.gov/medicare/coding-billing/icd-10-codes
- 健保署：請以其官網當期「ICD-10-CM/PCS 編碼資料與中文對照」正式下載頁取得（頁面/下載路徑可能變更）；匯入時記錄實際 URL、日期、版別及雜湊。

> 美國 FY 與台灣採用版本並不必然同步；使用者必須明確選擇查詢版本及翻譯版。

## 2026-10-29 使用者變更：PCS 納入本版

使用者明確要求應用程式增加PCS查詢，FR-060的PCS部分升為本次P0。CM／PCS獨立分類與版次、共用標準封包、完整碼／heading辨識、英文FTS／Index／七軸與同版健保署PCS中英對照搜尋列入0.2.0。Tw-DRG／AI自動編碼及未確認跨版合併仍不納入。舊版「首版不納入PCS」為歷史範圍，現以此變更及 `docs/RELEASE_0.2.0.md` 為準。

## 2026-10-30 分類人員驗收後介面修訂（0.2.2）

- FR-012：notes改由個人註解右側「本層與繼承notes」按鈕開啟可捲動浮動視窗；內容、順序、繼承來源及PCS語義不變，不固定占用詳情版面。
- FR-020～022：移除底部「資料」項，資料管理統一由右上按鈕開啟。手機保留搜尋／分類底部導覽；平板與Windows不顯示底部導覽。雙欄及窄Windows保留內容區搜尋／分類切換，三欄同時呈現。
- FR-035：缺譯提示為App顯示字串，不是官方資料或builder產生的資料列。無須重製既有包；不得寫入提示為譯名、填補譯文或放寬跨版規則。

## 2026-10-30 新增來源與名稱修訂（0.2.3）

使用者回報疾病分類人員初步確認內容可使用；程式名稱移除Demo，App與製作工具升版0.2.3，合成測試資料的SAMPLE標示及尚未執行Gate仍保留。FR032/040/041新增CMS FY2023～FY2025現有原檔各effective release及健保署2014 CM／PCS交錯列ODS來源設定。未提供USE時明示未知狀態、不依leaf推定；缺中譯省略列。細節與實測範圍見docs/RELEASE_0.2.3.md。
