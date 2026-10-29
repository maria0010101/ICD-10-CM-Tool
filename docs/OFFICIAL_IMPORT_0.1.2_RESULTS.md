# Builder 0.1.2 官方轉檔實測（2026-10-29）

原始檔由使用者放入 `2027 ICD-10-CM files/`，原檔未改寫。既有 App／資料包 schema 不變；僅 builder 升版。原始資料與完整結果保留本機，不上傳 GitHub。

## 已執行

* Python 3.13.18／SQLite 3.53.1：`python -m pytest tools/data_builder/tests -q`，**41 passed**。故意重複 ZIP 的一條 warning 保留。
* 七種來源設定全部實際執行，CM／NHI source audit 全數 `passed=true`，SQLite integrity 與索引驗證通過。
* CM FY2027：98,403 個 code（包含非完整碼）、98,723 分類節點、27,079 notes、99,108 Index entries；Tabular／Order 描述差異保留在 audit，不靜默覆蓋。
* PCS FY2027：79,256 個完整處置碼、918 個非完整 heading；官方 code list／order 長名稱／七軸組合逐值相同。PCS FY2026 April：79,193 個完整處置碼，亦通過相同核對。
* 健保署 ODS：CM 96,802／PCS 78,530；全六分頁共178,497筆資料列（不含 header／空白），包含更新／刪除資料但不混進現行 code 主表。CM overlay 產生3,243,772個 n-gram postings，全部 unresolved。
* 現有 Flutter 資料層實際載入4個新 CM 包，**1/1 test passed**；核對原包 SHA 未改、三版代碼／英文搜尋、分類樹，以及未確認中譯不出現在合格搜尋。Linux native SQLite 3.54.1，1分04秒；未操作使用者手機或正式資料目錄。
* Linux Tk GUI construction 成功。Windows 可攜工具另由 GitHub Actions 使用 bundled Python 執行相同測試與 GUI smoke，結果見 `evidence/official-import-0.1.2/windows-ci-run.json`。

## 可重現命令

```bash
.venv313/bin/python scripts/build_official_local.py --source-dir '2027 ICD-10-CM files' --output-dir manual-generated-new
.venv313/bin/python -m pytest tools/data_builder/tests -q
scripts/prepare_ascii_build.sh /tmp/icd-work-build
cp scripts/verify_generated_cm.dart /tmp/icd-work-build/app/test/generated_official_test.dart
cd /tmp/icd-work-build/app
flutter test test/generated_official_test.dart --dart-define='ICD_IMPORT_DATA=/absolute/path/to/generated/data' --dart-define='ICD_IMPORT_EVIDENCE=/absolute/path/to/new-report.json' --reporter expanded
```

第一次 Flutter 命令錯在專案根目錄執行（無 pubspec），錯誤 log 保留；切到 ASCII `app/` 後完整通過。這是測試命令路徑錯誤，不隱藏或冒稱初次通過。

## 實際產物（`manual-test-0.1.2/data/`）

| 檔案 | bytes | SHA256 |
|---|---:|---|
| `cm-fy2026-apr.icdpack` | 15,409,743 | `91d01f64add33a08cf282251cbb0852f4dd24dd3f2120084f13b7ce566315078` |
| `cm-fy2026-oct.icdpack` | 15,333,338 | `982fb20fee7c0398f1123d4e0220ae08f88d7c81434ffd16eaad3b3bcfcfc53a` |
| `cm-fy2027-oct.icdpack` | 15,401,773 | `c1311f826d5491569438ee4cc30e7e402015ad763f960b8ababe4c2d1f536714` |
| `nhi2023-cm-ods-unresolved.icdpack` | 73,239,748 | `e3007d6ddd00eed0f8477ab28a8537e6eb4f248f914589bb6b519a1aceb6d48b` |
| `nhi2023-source-tables.sqlite` | 108,806,144 | `2a3c27c1424fb186954e9dfb1b79dec70d04138e5bcef89f5071fb28d9881614` |
| `pcs-fy2026-apr.sqlite` | 51,884,032 | `9be80913e9aa2bb2e5a445bb877854089d2c9a5ef607284926177f21eb676828` |
| `pcs-fy2027-oct.sqlite` | 51,974,144 | `e361752aeeb1f640fb76744bfda33dca126c199893e7e59eb6adf3e8b88433ce` |

## 驗收界線

* 新正式 CM 包尚未在 Windows／Android 兩端做完整50-query同包驗收；既有 sample 跨平台結果不移作本批正式資料通過證據。
* ODS 年版2023與美國FY2026／FY2027不自動相容；本次沒有把 lineage、中文正式效能或臨床簽核標為通過。
* PCS 是獨立來源資料表，不是 CM App 的 PCS 模組；完整碼／heading 與 Index 範圍保持區別。Guidelines／POA／conversion／PDF errata 未轉為可執行規則，FR-034 仍 partial。
* SHA256 是完整性與已審核批次鎖定，不是官方簽章。分開記錄 edition／effective release／來源，不因目錄名相同而混用。
* 舊工具與舊產物保留；已有輸出／report／staging 檔案不覆寫，新增測試特別驗證既有 staging 不被刪除。
