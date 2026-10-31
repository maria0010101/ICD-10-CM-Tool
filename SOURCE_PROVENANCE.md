# 來源與轉換紀錄

目前相容的可攜製作工具為0.2.3，App為0.2.4；下列分節保留各批歷史下載／轉換紀錄（2026-10-29起），不將舊批次冒稱最新。無病歷或個人資料。

## 隨附 samples

`sample-demo-v1.icdpack`、v2 都是 `tools/data_builder/sample.py` 產生的**合成**資料。
譯名、notes、分類與版本全為測試用途，不可聲稱官方內容或用於申報。
包內 manifest 記錄 generator SHA256，發布雜湊見 `evidence/checksums.sha256`。

## 本機 CDC FY2027 英文測試（不隨 App／交付壓縮檔散布）

下載入口：https://ftp.cdc.gov/pub/Health_Statistics/NCHS/Publications/ICD10CM/2027/

| 官方下載名稱 | 本機名 | SHA256 |
|---|---|---|
| icd10cm-table-and-index-2027.zip | .local-source/cdc-2027.zip | 99b5c2be16ff53eab861cc0be4b1dacba27f687b8ff4bc700679944355037ee0 |
| icd10cm-code-descriptions-2027.zip | .local-source/cdc-descriptions-2027.zip | 93e3ad6004badf470c55bfe679b748ae88fd9b2b421851e409eec382c7713b9a |

* 英文 FY2027，release/effective 2026-10-01～2027-09-30，發布者 CDC/NCHS。
* XML Tabular + 四種 Index/Table；TXT order 作 billable 與七字元完整碼來源。
* 描述檔 codes 與 addenda 是冗餘對照輸入：本次以完整 order snapshot 為準，不再套用 addenda 以免重複新增。所有原檔雜湊保留於 `evidence/cdc-source-counts.json`。
* 保留 Tabular 原文（例如重音字元）；與 order 的不同描述清單在 `evidence/cdc-audit.json`，不以 TXT 去改寫 XML 描述。
* 稽核：98,403 code、297 block、22 chapter、1 個 introduction heading，共 98,723 nodes；27,079 notes、99,108 Index entries、16,344 crossrefs、54,182 table cells。七字元完整碼由 order 補出，非從 leaf 推論 billable。
* 來源節點為檔名 + XPath；notes 同時保留原 XML 及 display_order。引言另存 heading，避免冒充 ICD code。
* 已另測健保署官方 2023 中文 CSV，但對 FY2027 的 lineage 未確認，不聲稱正式相容雙語資料。官方英文包未通過所有跨平台 Gate，不屬可供臨床使用之正式發行。

## 台灣官方中譯導入

從 https://www.nhi.gov.tw/ 或 https://www.mohw.gov.tw/ 當期正式下載頁取得，不以本文件模板的 URL 冒充實際來源。
依實際檔案填 `docs/nhi-profile.example.json`；記錄原檔 hash、下載頁、版別、修訂日期、明確欄位名稱與工作表。
`mapping_policy=unresolved` 預設不進入合格中譯查詢；只有管理者已驗證同版／跨版 lineage 後才填 `exact_edition`／`reviewed_cross_release`，並指定唯一 base package ID。這是來源管理宣告，不是密碼學官方認證。

## 參考實作

未使用 simple_icd_10_CM 或第三方資料庫作為資料來源。SQLite native assets 與套件 API 依 pub.dev 維護者文件選用；不存在雲端查詢或自動下載功能。

## 已實際測試的健保署 CSV

* 資料集：https://data.gov.tw/dataset/177507
* CM CSV：https://info.nhi.gov.tw/api/iode0000s01/Dataset?rId=A21030000I-D20025-005
* 版別 NHI 2023、修訂批次 1150827（2026-08-27），下載日期 2026-10-29。
* 原檔 SHA256：acd950e2ae193ac7c1438165584d48cfa239a9ac6ae9819444cae4d679e123dc
* 實際轉換列數：96802；n-gram 列數：3243772。
* 所有 mapping_status=unresolved；不視為 FY2027 已驗證官方中譯。effective_to=9999-12-31 是未知期限 sentinel，非官方有效期限保證。
* 原始全部欄位（包括英文、USE、修訂狀態）保存於 translations.notes JSON；譯名不覆蓋英文內容。
* 資料頁標示政府資料開放授權條款第1版；本專案仍不將完整分類資料隨 App 再散布。

## 使用者提供的官方批次（Builder 0.1.2）

來源目錄 `2027 ICD-10-CM files/`，共 34 檔；逐檔 SHA256／大小在 `evidence/official-import-0.1.2/source-inventory.json`。本批包括 FY2026／FY2027 CM、FY2026 April／FY2027 PCS，以及健保署 2023／1150827 多分頁 ODS。下載時間未由檔名或本機時間推定。

實際轉檔設定在 `docs/source_profiles/`，操作與範圍見 `docs/OFFICIAL_IMPORT_0.1.2.md`，實測見 `docs/OFFICIAL_IMPORT_0.1.2_RESULTS.md`。原檔及完整轉換資料不隨 Git／工具 ZIP 散布。


## 0.2.0 PCS App projection

使用本機原官方下載（原檔34/34 SHA256保全），CMS FY2027／FY2026 April的codes、order、tables、Index、definitions投影至共用schema；原XML逐節點及完整來源保留，七軸row分組不跨組合併。健保署2023／1150827 ODS明確選ICD-10-PCS分頁，同一列英中對照的exact_edition只針對本身NHI2023版，不與美國FY2027宣稱相容。全量資料僅留本機，獨立原值稽核結果見 `evidence/release-0.2.0/*.source-audit.json`。合成PCS fixture明標SAMPLE，與正式資料分開。

## 0.2.1 NHI CM獨立版

相同官方2023／1150827 ODS的ICD-10-CM分頁，96,802同源中英／USE及其他欄位，原始碼展示不改。新增combined包僅聲明對自身NHI版本exact_edition；原使用者overlay保存原SHA且仍unresolved。前綴導覽不是美國Chapter／Block，沒有原檔未提供的Index或Tabular註記；逐筆稽核與原檔保全見release-0.2.1 evidence，完整資料留本機。

## 0.2.3補充來源

新增FY2023 Apr、FY2024 Apr、FY2025 Oct／Apr CM與PCS；20個所需ZIP與CMS官網對應檔SHA256完全一致。來源URL及hash鎖定於docs/source_profiles各JSON，核對紀錄在evidence/release-0.2.3/cms-release-verification.json。健保署2014 CM修訂1131212／PCS修訂1120509分立包，以官方2014版頁與使用者原檔hash記錄，不宣稱跨年度相容。2725個PCS輔助公式僅保留inert原文；不求值／不作資料依據。原檔與完整產出只留本機；使用者資料不上傳。
