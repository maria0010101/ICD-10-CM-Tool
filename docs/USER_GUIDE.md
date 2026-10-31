# ICD Offline 0.2.4 使用指南

[回首頁](../README.md) · [下載v0.2.4](https://github.com/maria0010101/ICD-10-CM-Tool/releases/tag/v0.2.4) · [已知限制](KNOWN_LIMITATIONS.md)

## 安裝與升級

### Windows x64

1. 下載 `icd-offline-0.2.4-windows-x64.zip`，完整解壓至有寫入權限的資料夾。
2. 執行 `icd_dictionary.exe`；所有DLL及data目錄必須保留在原相對位置。不需系統Python／Flutter。
3. 首次啟動會在EXE旁建立 `portable-data/`，其中包含已匯入的資料包、安裝狀態及獨立使用者資料。
4. 升級前關閉舊App，備份整份 `portable-data/`；新版解壓至另一個新資料夾，將原資料目錄複製過去。保留舊目錄直到確認成功，勿用新建空資料覆蓋舊資料。

### Android ARM64

1. 下載 `icd-offline-0.2.4-android-arm64.apk`；最低Android7.0／API24，僅提供ARM64。
2. 使用系統正常安裝流程，視需要允許下載／檔案管理App安裝此來源。
3. 舊版直接覆蓋升級，**不要解除安裝或清除資料**。0.2.4沿用前版application ID及簽章；versionCode2007。
4. 資料位於App私人儲存空間；卸載可能移除資料。App不需要登入、雲端帳號或自動下載字典。

### 檢查下載完整性

Release的 `SHA256SUMS.txt` 列出三個程式成品及安裝說明的SHA256。Windows PowerShell範例：

```powershell
Get-FileHash .\icd-offline-0.2.4-windows-x64.zip -Algorithm SHA256
Get-FileHash .\icd-offline-0.2.4-android-arm64.apk -Algorithm SHA256
```

將結果與清單內相同檔名的一列核對。SHA256用於檔案完整性，不表示資料內容獲官方認證。

## 取得與匯入資料包

App沒有內建完整字典。已有 `.icdpack` 時不用下載製作工具，也不用為升級0.2.4重新轉檔。

1. 點首次畫面的「匯入 .icdpack」，或右上「資料管理」的匯入功能。
2. 選擇資料包，核對CM／PCS、發布機關、版別、生效日期與資料範圍。
3. 等待安全性及完整性驗證；預覽確認後點「匯入並啟用」。附加中譯包的啟用方式不同，見下節。
4. 在版本選擇處確認目前使用的包。可保留不同版本，資料管理可啟用其他版本或回復上一版。
5. 同一包直接複製到Windows／Android匯入，不重壓縮或改寫內容。

大型資料包需保留暫存與驗證空間。驗證失敗時閱讀具體錯誤，原啟用版本不會因失敗而被取代；不要以清資料作為排錯方式。

### 主包、同版中英包與附加中譯

| 類型 | 如何使用 |
|---|---|
| 美國CM／PCS英文App包 | 單獨匯入並啟用，使用原官方來源所提供的Index／notes等內容 |
| NHI2014／2023同版中英獨立App包 | 可單獨啟用及中文查詢，中英對照只針對自身NHI版別；原檔沒提供的Index或notes不補造 |
| NHI2023 unresolved附加中譯包 | 不是主包，需相容英文主版本；跨版相容未確認時僅供明示參考，不變成合格中文搜尋 |
| 來源資料表 `.sqlite` | 供離線稽核，不能直接匯入App；更名為 `.icdpack` 也無效 |

## 搜尋與查閱

### 英文CM索引導引

1. 選擇含官方Index的英文CM資料版本，保留「索引導引」、AND與前綴。
2. 單詞即時輸入顯示主詞建議；點主詞展開該來源分支。按Enter則查完整Index路徑。
3. 多詞AND查詢以原始路徑比對，逗號與詞序不影響相同詞彙的命中。OR可改為任一詞命中；前綴開關控制是否容許詞首匹配。
4. 命中結果保留祖先與縮排，按來源順序顯示。不同修飾詞指向同一碼仍保留各自節點。
5. 每批100筆；捲到底部按「載入更多」。長路徑可在提示／詳情查看完整內容。
6. 點目標碼到Tabular核對，再查本層與繼承notes及來源版本。

FY2025／2025-04-01實測：`Diabetes, diabetic`為449節點，載入數依序100、200、300、400、449。449個階層深度與目標碼位置已逐筆對照smarticd10；完整原文呈現與所有其他查詢不保證完全相同。App保留`type 1`／`type 2`數字差異及官方Note節點，詳[搜尋分析](SEARCH_SMARTICD10_ANALYSIS.md)。

### 其他查詢與詳情

- 完整代碼可輸入有／無小數點及大小寫；例如 `I50.9`、`I509`。CM代碼前綴例如 `I5` 仍查代碼。
- 想用原本英文描述的相關度結果，關閉「索引導引」或選Tabular；可指定Alphabetic、Neoplasm、Drugs、External等實際存在的來源。
- 中文須有合格中譯；NHI同版中英獨立包可中文搜尋。沒有合格中譯時省略中譯列，不另外顯示缺譯提示。
- PCS先選PCS分類與適用版本，再查完整碼、英文／同版中文、Index或來源提供的七軸；不要將CM規則套用為PCS語義。
- 「本層與繼承notes」在個人註解右側，按下開啟可捲動浮動視窗；保留本層／繼承來源與原順序。
- 手機保留搜尋／分類底部導覽；平板及Windows移除底列，雙欄／窄Windows保留內容區切換，寬Windows三欄同時呈現。
- Windows可用Ctrl+L／Ctrl+F聚焦搜尋、方向鍵選結果、Enter及Esc操作；即時主詞建議的Enter會展開選定主詞。

## 資料製作與來源選擇

### 不需安裝Python的Windows工具

Release附 `icd-data-builder-0.2.3-windows-x64-portable.zip`；它與App0.2.4相容，工具版本刻意保留0.2.3。

1. 完整解壓工具ZIP，開啟其中的 `ICD-Data-Builder-0.2.3/`，雙擊 `ICD-Data-Builder.cmd`。
2. 從官方網站取得所選版別的原始檔；工具本身不下載。按內建profile的 `inputs` 目錄／檔名放置，**來源選含 `cms`／`健保署` 子目錄的總資料夾，不是FY子資料夾**。
3. 在「官方資料製作」選「已核對的來源設定」，核對用途、CM／PCS及實際release。
4. 選官方原檔總資料夾，先執行「檢查總資料夾／可用設定」。設定含原檔hash；來源不符時不能假裝是同一版本。
5. 指定尚不存在的新輸出檔名；App包用 `.icdpack`，來源表用 `.sqlite`。點「離線建立資料包」，成功後可在「驗證 .icdpack」再檢查。
6. 將產出原包複製到Windows／Android，在App內匯入。工具不會替App安裝資料，也不會覆寫既有發行檔。

工具內含獨立Python3.13.18、Tk及鎖定依賴，不需系統Python／pip／網路。`SELF-TEST.cmd`可執行工具隨附測試。合成samples與安全負向fixtures只供測試。

### 21種內建設定

下表列全部profile；檔案在[來源設定目錄](source_profiles/)，`inputs`為必要相對路徑，`source_urls`為該批來源連結，`input_sha256`鎖定已核對原檔。不是所有FY都同時提供Oct與Apr。

| profile | 用途 |
|---|---|
| `cm-fy2023-apr`、`cm-fy2024-apr` | 對應FY4月CM英文App包 |
| `cm-fy2025-oct`、`cm-fy2025-apr` | FY2025不同生效批次的CM英文App包 |
| `cm-fy2026-oct`、`cm-fy2026-apr`、`cm-fy2027-oct` | 對應批次CM英文App包 |
| `pcs-fy2023-apr-app`、`pcs-fy2024-apr-app` | 對應FY4月PCS英文App包 |
| `pcs-fy2025-oct-app`、`pcs-fy2025-apr-app` | FY2025不同生效批次的PCS英文App包 |
| `pcs-fy2026-apr-app`、`pcs-fy2027-oct-app` | 對應批次PCS英文App包 |
| `nhi2014-cm-app`、`nhi2014-pcs-app` | 健保署2014同版中英獨立App包，未提供USE |
| `nhi2023-cm-app`、`nhi2023-pcs-app` | 健保署2023同版中英獨立App包 |
| `nhi2023-cm-ods-unresolved` | 未確認跨版相容的CM附加中譯，不可獨立啟用 |
| `pcs-fy2026-apr`、`pcs-fy2027-oct` | PCS來源資料表SQLite，**不是App包** |
| `nhi2023-source-tables` | NHI全部分頁來源表SQLite，**不是App包** |

FY2025 Oct生效日為2024-10-01，Apr為2025-04-01，不能因年度相同混用。NHI2014／2023不等於美國FY2014／FY2023；NHI同版中譯不自動嫁接美國版。2014原檔未提供USE時，App明示來源未提供可申報狀態；缺譯不補造。

### 官方下載入口與不同批次

- [CDC/NCHS CM檔案](https://www.cdc.gov/nchs/icd/icd-10-cm/files.html)
- [CMS各年度CM／PCS檔案](https://www.cms.gov/medicare/coding-billing/icd-10-codes)
- [健保署2014版頁](https://www.nhi.gov.tw/ch/lp-3839-1.html)
- [健保署2023中英對照開放資料入口](https://data.gov.tw/dataset/177507)

實際使用的檔案與修訂批次以profile及[來源紀錄](../SOURCE_PROVENANCE.md)為準。若官方另發新檔，即使檔名相同也可能hash不同；需重新核對版別、欄位、來源並建立新profile，不要關閉安全檢查或任意替換hash。本批歷史檔詳細差異見[0.2.3報告](RELEASE_0.2.3.md)。

命令列範例（在解壓後的工具目錄執行；輸出檔須尚不存在）：

```powershell
.\ICD-Data-Builder.cmd catalog --source-dir 'D:\official-files'
.\ICD-Data-Builder.cmd build --source-dir 'D:\official-files' --profile docs\source_profiles\cm-fy2025-apr.json --output 'D:\fy2025-apr-new.icdpack'
.\ICD-Data-Builder.cmd verify --package 'D:\fy2025-apr-new.icdpack'
```

## 備份與常見問題

- **程式開啟後沒有字典**：正常，Release不附完整字典；請匯入既有App包或先製作。
- **NHI包不能單獨啟用**：先確認是否選到附加中譯；獨立中文查詢應使用 `nhi2023-cm-app` 等同版獨立包，不修改overlay政策繞過驗證。
- **SQLite無法匯入**：來源表不是App包，請重選App profile，不只改副檔名。
- **FY相同但資料不同**：檢查Oct／Apr及實際release date；第三方網站也可能使用不同批次。
- **只看到100筆**：導引模式捲到底部按「載入更多」，總數仍保留；舊全文相關度模式維持前100筆上限。
- **來源設定hash不符**：核對下載批次、相對路徑及檔案是否被重包；不要直接放寬驗證。
- **如何備份收藏／註解**：資料管理可匯出JSON並在本機匯入。Windows亦備份整份 `portable-data/`；Android另保留原 `.icdpack`，不要卸載或清資料。收藏按資料包版本隔離，不自動遷移到另一版。
- **要如何更新字典**：自行取得新官方來源，另製新檔並驗證，再在App匯入啟用；舊版保留，不會自動連線更新。

資料排名不等於診斷或申報建議；應依適用版本的Index、Tabular及原始規則核對。
