# 官方原檔轉資料表 · Builder 0.1.2

App 維持 0.1.1，資料包 schema 維持 1.0.0；這次僅升級離線製作工具。既有 APK／Windows App 可直接匯入新增的 **CM `.icdpack`**，不需要重裝 App 或清除資料。

## Windows 圖形操作

1. 解壓新版 `icd-data-builder-0.1.2-windows-x64-portable.zip`，雙擊 `ICD-Data-Builder.cmd`。
2. 在「官方資料製作」的下拉選單選來源設定。
3. 選取 **`2027 ICD-10-CM files` 總資料夾**（不是 FY 2027 子目錄）。它的下層須有 `cms/FY 2027`、`cms/FY 2026`、`健保署`。
4. 可按「檢查總資料夾／可用設定」確認檔案是否齊全。這是存在性清單；正式製作另核對 profile 中的 SHA256、XML 年度及內容結構。
5. 選擇新的輸出檔名，再按「離線建立資料包」。CM 選 `.icdpack`；PCS／ODS 全分頁選 `.sqlite`。
6. App 只匯入 CM `.icdpack`。**PCS／原始資料表 SQLite 不是 App 資料包，不能改副檔名冒充。** 請使用 SQLite 查閱工具或 SQL 讀取。

工具附私有 Python 3.13.18、Tk、lxml 與鎖定依賴；不需安裝 LibreOffice、不會啟動試算表巨集、不下載或上傳任何內容。舊工具 ZIP 與原始資料不覆寫。

## 七種內建來源設定

| profile | 輸出 | 來源與適用區間 |
|---|---|---|
| `cm-fy2027-oct` | `.icdpack` | CM FY2027，2026-10-01～2027-09-30 |
| `cm-fy2026-apr` | `.icdpack` | CM FY2026 April，2026-04-01～2026-09-30 |
| `cm-fy2026-oct` | `.icdpack` | CM FY2026 October，2025-10-01～2026-03-31 |
| `nhi2023-cm-ods-unresolved` | `.icdpack` | 健保署 2023 CM／修訂批次1150827，只讀 `ICD-10-CM` 分頁；跨版未確認 |
| `pcs-fy2027-oct` | 獨立 `.sqlite` | PCS FY2027，2026-10-01～2027-03-31 |
| `pcs-fy2026-apr` | 獨立 `.sqlite` | 本批 FY2026 PCS 實際是 April release，2026-04-01～2026-09-30 |
| `nhi2023-source-tables` | 獨立 `.sqlite` | 健保署 ODS 全六分頁，CM／PCS／修訂與2014刪除碼分開保存 |

CM 發布版本標為 `1.1.0`，以區別先前 CDC ZIP 來源版本；package ID 保持同一英文 release 的身分，避免同 ID／同版卻不同 SHA 被 App 安全機制拒絕。

健保署 2023 不是美國 FY2026／FY2027 的同版譯名，`unresolved` 不自動進入相容中譯搜尋。profile 的多個 base ID 僅表示可掛載作未確認參考，並非臨床相容聲明。`effective_to=9999-12-31` 為未宣告終止日的本機契約值，不是官方保證。

FY2026 PCS 原始下載檔名未標出 April，已用 CMS April order ZIP 的實際 SHA256 比對確認。本批沒有完整 October PCS snapshot，不把它標成 October。

官方版別與有效區間核對：[CMS ICD-10 官方下載頁](https://www.cms.gov/medicare/coding-billing/icd-10-codes)；健保署來源：[官方開放資料入口](https://data.gov.tw/dataset/177507)。profile 綁定使用者本批原檔的 SHA256，不把檔名或 SHA 當作官方數位簽章。

## CLI（開發環境／可攜版私有 interpreter 均可）

以下在專案／可攜工具根目錄執行；Windows 無系統 Python 時，把 `python` 換成 `runtime\python.exe -E -s -X utf8`。

```powershell
python -m tools.data_builder catalog --source-dir '2027 ICD-10-CM files'
python -m tools.data_builder inspect-sheet --input '2027 ICD-10-CM files/健保署/1.2023年中文版ICD-10-CM_PCS_1150827.ods'
python -m tools.data_builder build --source-dir '2027 ICD-10-CM files' --profile docs/source_profiles/cm-fy2027-oct.json --output cm-fy2027-new.icdpack
python -m tools.data_builder verify --package cm-fy2027-new.icdpack
python -m tools.data_builder build --source-dir '2027 ICD-10-CM files' --profile docs/source_profiles/pcs-fy2027-oct.json --output pcs-fy2027-new.sqlite
```

整批製作並稽核（輸出目錄必須沒有同名結果，不覆寫）：

```powershell
python scripts/build_official_local.py --source-dir '2027 ICD-10-CM files' --output-dir local-generated-new
```

Linux 可使用專案 `.venv313/bin/python`。單一 profile 製作也會產生同名 `.build-report.json`；批次腳本另執行 CM／NHI 逐碼、notes、Index、來源欄位稽核並寫 `.audit.json`。來源缺檔、SHA 不符、錯版或 ODS 欄位變動會停止；新下載批次請複製 profile，人工核對版本、欄位及來源 SHA，不要取消檢查。

## 產出的資料表

### CM `.icdpack`

契約不變：`manifest.json`、`content.sqlite`、`checksums.sha256`。SQLite 含 `code_nodes`、`notes`、`index_entries`、`index_crossrefs`、`table_cells`、`translations`、`zh_ngrams` 及 FTS5。英文、中文各自產包，既有 App 安裝狀態／收藏／註解不受轉檔影響。

### PCS 獨立 SQLite（`source-tables-1`）

* `pcs_codes`：完整碼與三字元 heading；`billable=1` 才是完整處置碼。保留長／短英文名稱與來源順序。
* `pcs_tables`、`pcs_rows`、`pcs_axis_labels`：七軸、列、label、definition 及原始 XML；軸1～3屬 table，4～7屬 row。不能跨不同 row 任意組合。
* `pcs_index_entries`、`pcs_index_refs`：主／子詞樹與原文交叉參照；未把部分碼或 see/use 當作有效完整碼。
* `pcs_definitions`：section／axis／term、定義、說明與 includes。
* `source_documents`：三份原 XML 完整位元組、SHA256；`source_metadata`：版別、有效日期、來源檔及 `app_import_supported=false`。

驗證會枚舉各列的七軸組合，與官方完整碼清單及 order 長名稱逐值核對；不只比較總數。Addenda 不重複套用已完整發布的 snapshot；guidelines、POA、conversion、PDF errata／更新摘要不宣稱已轉入可執行規則。這不是 PCS App 模組或 Tw-DRG grouper。

```sql
SELECT code,long_title FROM pcs_codes WHERE billable=1 AND code='0016070';
SELECT * FROM pcs_axis_labels WHERE table_id=1 ORDER BY row_id,position,id;
```

### 健保署全分頁 SQLite

* `spreadsheet_sheets`：工作表名稱與原始 header（含換行）。
* `spreadsheet_rows`：原始工作表、原始列號、所有欄位 JSON。更新歷程／更新明細／2014刪除碼不混進現行主表。
* `nhi_codes`：主分頁的 CM／PCS 分類、2023 edition、code、原始中英文、USE、狀態、修訂日期，全部 `unresolved`，不覆蓋美國英文。

```sql
SELECT classification,count(*) FROM nhi_codes GROUP BY classification;
SELECT code,title_zh_tw FROM nhi_codes WHERE classification='ICD-10-CM' AND code='I50.9';
SELECT source_columns_json FROM spreadsheet_rows WHERE sheet='更新明細' LIMIT 5;
```

ODS 使用 lxml 串流讀取，保留多段落、span、空白／tab／換行；不展開百萬空白列／16384空欄。ZIP 有數量／大小／比例／路徑檢查；XML 禁止 DTD／XXE／外連、公式及主動物件，所有工作表均檢查。CM overlay 明確限定 `ICD-10-CM` 分頁，避免 PCS 數字碼或2014刪除碼混入。

## 本機輸出與驗收界線

本批實際結果在 `manual-test-0.1.2/data/`，新版工具 ZIP 在 `manual-test-0.1.2/`。原始官方檔及完整 SQLite／資料包不傳上 GitHub、不嵌入 App；Git 僅備份程式、來源 hash、profiles、合成 fixtures、計數與測試證據。

本次轉檔及來源核對不等於臨床簽核，也不替代 Windows／Android 用本批正式資料的完整跨平台 G1、飛航模式 G2、實機效能 G6 或乾淨工作站 G7。現有 CM App 功能與 PCS 模組範圍沒有被偷偷改變。
