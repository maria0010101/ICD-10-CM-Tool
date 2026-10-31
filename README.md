# ICD Offline · 0.2.4

**Windows／Android 完全離線的 ICD-10-CM／PCS 查詢工具。** 支援官方英文索引、健保署同版中英對照、分類樹與註記查閱；App、字典資料包及收藏／個人註解分開保存。

經疾病分類人員測試，使用者已回報內容正確、功能可初步使用。這不是所有平台與安全／效能驗收均已完成的宣告；實際測試範圍與限制見下方。

## 下載與選擇檔案

前往 **[Release v0.2.4](https://github.com/maria0010101/ICD-10-CM-Tool/releases/tag/v0.2.4)**，下載需要的檔案：

| 檔案 | 用途 | 適用對象 |
|---|---|---|
| `icd-offline-0.2.4-windows-x64.zip` | Windows x64 免安裝 App | Windows 使用者 |
| `icd-offline-0.2.4-android-arm64.apk` | Android ARM64 App，Android 7.0／API 24以上 | 手機／平板使用者 |
| `icd-data-builder-0.2.3-windows-x64-portable.zip` | Windows 離線資料包製作工具，21種來源設定 | 需自行從官方原檔製作資料包的人 |
| `INSTALL_0.2.4.md` | 繁體中文安裝、升級與首次匯入說明 | 所有使用者 |
| `SHA256SUMS.txt` | 以上三個程式成品與安裝說明的檢查碼 | 下載後核對完整性 |

**App 0.2.4 與製作工具 0.2.3 相容，工具不需為此次搜尋調整而升版。** GitHub自動附加的 Source code 壓縮檔是原始碼，不是可直接安裝的 App。儲存庫目前為私有，Release 也需具有儲存庫存取權限。

### 第一次安裝

1. Windows：將 ZIP **完整解壓**到可寫入的資料夾，再執行 `icd_dictionary.exe`。不要只取 EXE，或在 ZIP 內直接執行；不需安裝 Flutter／Python。
2. Android：在系統允許此來源安裝後，開啟 ARM64 APK 安裝；App 不需登入，也不會下載字典或連線查詢。
3. 準備 `.icdpack`，由 App 的「匯入 .icdpack」或右上「資料管理」選取，完成版本／來源預覽與驗證後啟用。
4. 選擇正確的 CM／PCS、資料版別與生效批次，再開始查詢。

**程式不內附完整官方字典。** 已有 `.icdpack` 可直接使用；沒有資料包時，先用製作工具從官方原檔建立。相同檔案可原封不動匯入 Windows 和 Android，不需平台轉換。

### 升級與備份

- **Windows**：關閉 App，備份舊目錄的整份 `portable-data/`；將新版解壓到新目錄，再複製原有 `portable-data/` 至新版目錄。保留原目錄，確認資料正常後再自行整理。
- **Android**：直接覆蓋安裝新版；**不要解除安裝或清除資料**。目前 APK 沿用前版簽章及 application ID，versionCode 為2007。
- App 0.2.4 **不改既有資料包格式，不需重新製作或重新匯入**。資料管理另提供收藏／註解 JSON 匯出與匯入；這不等同字典資料包備份。

[完整操作與資料製作指南](docs/USER_GUIDE.md) · [開發、測試與建置](docs/DEVELOPMENT.md)

## 0.2.4 的搜尋方式

英文 CM 資料包有官方 Index 時，預設啟用「索引導引」：

- **輸入單詞**：提供主詞前綴建議，點主詞展開該分支；Enter 送出完整路徑查詢。
- **輸入多詞**：以詞首 AND／OR 搜尋原始 Index 路徑，保留上層脈絡，依官方來源順序呈現，不再讓 Tabular 或全文相關度擠掉 Index。
- **完整結果**：每批100筆，顯示已載入／總節點數，按「載入更多」繼續；不會因不同修飾詞指向同碼就刪除節點。
- **查代碼**：完整碼如 `I50.9`／`I509` 與代碼前綴 `I5` 保留代碼查詢；點 Index 的目標碼可到 Tabular 核對。
- **原本的全文模式**：關閉「索引導引」或選 Tabular。中文、沒有 Index 的 NHI 包及 PCS 維持各自查詢語義。

對照範例：FY2025／2025-04-01 包輸入 `Diabetes, diabetic`，449個節點的**階層深度與目標碼順序**已逐筆與 smarticd10 觀察結果核對一致。App 仍保留數字1／2與官方 Note，不為強行一致改寫官方資料；不宣稱任意查詢或所有年度與第三方網站完全相同。

[搜尋邏輯分析與明確差異](docs/SEARCH_SMARTICD10_ANALYSIS.md)

## 其他功能

- CM／PCS 分開選版；精確碼、英文 FTS5 AND／OR／前綴、合格同版中文搜尋。
- 官方來源提供的分類樹、Index、cross-reference、Neoplasm／Drugs 表格及 PCS 七軸查閱。
- 詳情中的「本層與繼承notes」位於個人註解右側，按下才開啟浮動視窗，保留來源及順序；缺少合格中譯時省略中譯列。
- 手機單欄、平板雙欄、寬 Windows 三欄；平板與 Windows 無底部導覽，資料管理統一在右上角。支援文字放大、明暗模式及鍵盤操作。
- 多資料版本並存、驗證後啟用與回復上一版；收藏、個人註解及可關閉的查詢歷史獨立儲存。
- App 無登入、雲端 API、遙測或背景下載；資料更新由使用者自行取得及匯入。

## 資料包與來源設定

製作工具0.2.3內建 **21種設定**，包括 App 資料包、附加中譯及僅供稽核的來源資料表；不是21份已附送的字典。

| 來源 | App包支援範圍 |
|---|---|
| 美國 CM | FY2023 Apr、FY2024 Apr、FY2025 Oct／Apr、FY2026 Oct／Apr、FY2027 Oct |
| 美國 PCS | FY2023 Apr、FY2024 Apr、FY2025 Oct／Apr、FY2026 Apr、FY2027 Oct |
| 健保署同版中英獨立包 | 2014 CM／PCS、2023 CM／PCS |

- FY與 Oct／Apr 是不同資訊，請核對實際生效日期，不能僅按檔名年份混用。
- NHI 同版中英獨立包可單獨啟用；舊的 unresolved 附加中譯包不是獨立字典，也不自動視為美國版官方中譯。
- NHI 原檔未提供的美國 Tabular notes／Index／七軸不會補造；2014原檔未提供USE時，App明示來源未提供可申報狀態，不從是否末層推定。
- 名稱含「獨立 SQLite／來源資料表」的輸出**不能匯入 App**；請選 App `.icdpack` 設定，不能只更改副檔名。
- Release 不附完整官方資料或使用者資料；工具中的 `samples/` 僅為明確標示的合成測試內容，不供編碼使用。

[來源選擇與官方下載入口](docs/USER_GUIDE.md#資料製作與來源選擇) · [21種來源設定](docs/source_profiles/) · [來源追溯](SOURCE_PROVENANCE.md) · [資料包規格](DATA_PACKAGE_SPEC.md)

## 驗證範圍與限制

0.2.4既有成品驗證：Python58項通過；Linux／Windows Flutter各35項通過、2項未放完整資料的選配測試略過。完整FY2025另測通過；Android實機隔離測試的九組完整查詢快照與Linux一致，並驗證100→200筆載入；Windows hosted runner完成EXE啟動與獨立使用者資料庫檢查，合成包查詢與Linux一致。成品SHA256已核對。

使用者後續回報疾病分類人員測試內容正確、功能可初步使用；這與上述自動化測試分開記錄。實體平板、乾淨Windows工作站、所有年度全量跨端驗證，以及完整飛航／真實磁碟滿／強制中斷測試仍未全部完成。現有APK沿用開發簽章，未宣稱商店簽署；跨版本拆分／合併 lineage 尚未完成。

[0.2.4實測報告](docs/RELEASE_0.2.4.md) · [已知限制](docs/KNOWN_LIMITATIONS.md) · [測試計畫](TEST_PLAN.md)

## 專案文件

| 文件 | 內容 |
|---|---|
| [使用指南](docs/USER_GUIDE.md) | 安裝、資料製作、匯入、搜尋、備份與常見問題 |
| [開發指南](docs/DEVELOPMENT.md) | 鎖定工具鏈、測試、建置與專案結構 |
| [更新紀錄](CHANGELOG.md) | 0.2.4及歷史版本摘要 |
| [SRS](SRS.md)／[需求追蹤](docs/TRACEABILITY.md) | 需求與實作對照 |
| [架構](docs/ARCHITECTURE.md)／[資料包規格](DATA_PACKAGE_SPEC.md) | 技術及相容性契約 |
| [來源](SOURCE_PROVENANCE.md)／[授權](LICENSES.md) | 官方來源紀錄與第三方元件授權 |

搜尋排序不是診斷判定或申報建議；請依適用版本的 Index、Tabular 與原始規則核對。
