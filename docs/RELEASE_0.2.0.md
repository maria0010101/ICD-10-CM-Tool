# 0.2.0：大型手機資料包匯入修正與 PCS 模組

## 手機匯入問題

使用者原手機日誌確認 Release 0.1.1 在選取健保署 CM 資料包後發生 Java `OutOfMemoryError`：試圖配置146,479,904 bytes，Java growth limit 268,435,456 bytes。舊 Android file_selector 回傳整份 file bytes，即使 Dart 只使用 path，仍需經 Java／platform codec 複製大型陣列。

0.2.0 的 Android `.icdpack` 匯入改用系統 Storage Access Framework，僅取得使用者選取文件的讀取權；背景執行緒以64 KiB buffer複製到私有 cache，只回傳路徑。檔案大小仍限256 MiB，複製時檢查剩餘空間，取消／失敗只清理此次新建暫存副本，不清原始檔或App資料。未使用 largeHeap、廣泛儲存權限或安全設定繞過。

後續 Dart 解壓以64 KiB壓縮塊串流處理；中譯驗證採256筆keyset batch及prepared statement，不把96,802筆完整來源JSON一次載入。ZIP大小／比例／CRC、SHA256、schema allowlist、SQLite integrity/FK/FTS、每筆n-gram、staging及原子發布檢查仍保留。

使用者原始健保署包完全不需重製：
`e3007d6ddd00eed0f8477ab28a8537e6eb4f248f914589bb6b519a1aceb6d48b`。

## CM／PCS 明確分開

App 上方的 `CM 診斷`／`PCS 處置` 切換分類，再選該分類版次；搜尋、分類樹、收藏與來源均保留package身分。PCS支援完整碼／英文FTS、Index與cross-reference、七軸／同列組合及原始定義。三字元heading標為非完整碼，Index的部分碼不自動當成可申報完整碼；七軸不得跨row拼接。

新增三個 App 可直接匯入的共用 `.icdpack`（檔案可原封不動交給 Android／Windows）：

| 檔案 | 內容 |
|---|---|
| `pcs-fy2027-oct-app.icdpack` | CMS FY2027，79,256個完整處置碼；918個heading、七軸表、Index、定義、完整來源XML |
| `pcs-fy2026-apr-app.icdpack` | CMS FY2026 April，79,193個完整處置碼；917個heading及同版來源 |
| `nhi2023-pcs-app.icdpack` | 健保署2023／1150827，78,530筆同一官方列的中英文對照，可作該版本內中文搜尋；不宣稱與FY2027相容 |

健保署 PCS 包的前綴導覽明確標示是導覽分組，不冒稱包含美國官方七軸／Index。CM健保署overlay相對FY2027仍是unresolved，不因修正匯入而變成合格同版中譯。

0.1.2的 `pcs-*.sqlite` 與 `nhi2023-source-tables.sqlite` 仍是來源資料表，不可直接改名匯入App；請改用新增的PCS App profile製作 `.icdpack`。既有CM包、舊工具／產物與收藏不刪除。

## 資料契約與製作工具

實體 SQLite allowlist／`user_version=10000` 不變，舊CM `.icdpack` 繼續接受；分類協定擴充至API1.1，PCS manifest需 `classification=ICD-10-PCS`、`kind=icd10pcs_*`、`required_app_schema_min=1.1.0`。舊App會明確拒絕PCS，0.2.0可讀取；不對原包做平台轉換或就地migration。

PCS的七軸／列組合以typed notes保存結構化JSON及原始XML；來源完整文件置於獨立來源節點，避免每個詳情都載入整份XML。分類／Index共用既有分層與FTS schema，但不把PCS當成CM的chapter／coding notes語義。

工具GUI新增3個PCS App來源設定（連同舊設定共10種），由同一build入口產製。`audit_pcs` 獨立比對全部code／完整狀態／長描述、七軸表原XML與row分組、Index來源節點／path／明確目標，以及完整原XML；健保署版逐列核對原始中英文、USE與所有來源欄位。不是只核對總數。

```powershell
python -m tools.data_builder build --source-dir '2027 ICD-10-CM files' --profile docs/source_profiles/pcs-fy2027-oct-app.json --output new-pcs-fy2027.icdpack
python -m tools.data_builder.audit_pcs --package new-pcs-fy2027.icdpack --source-dir '2027 ICD-10-CM files' --profile docs/source_profiles/pcs-fy2027-oct-app.json
```

## 測試與交付

結果與原始日誌：`evidence/release-0.2.0/`。成品及說明放 `manual-test-0.2.0/`；完整正式資料只留本機，不上傳GitHub或嵌入APK／App／工具ZIP。

手機測試使用獨立 `.debug` 套件及新建測試目錄，以 `--no-uninstall` 安裝；不解除安裝／清除正式套件，不更改系統安全設定。Native streaming copy與實際SAF使用同一實作；自動化採私有輸入file URI，系統選檔UI操作另分列，不把兩者混稱。

舊Gate不因本次功能增加而自動全部通過：乾淨Windows人工操作、實體平板、飛航模式、真實斷電／ENOSPC與臨床內容簽核仍需另驗收。每次測試以實際裝置／資料／build mode與原包SHA為準。

### 本次實際執行結果

| 環境／內容 | 結果 | 證據 |
|---|---|---|
| Linux Python3.13.18 builder／惡意ZIP／ODS／PCS原始列及七軸 | 43 passed，1個刻意建立重複ZIP項目的warning | `python-tests.log` |
| Linux Flutter3.47.5靜態分析／native與widget tests | 0 issues／19 passed | `flutter-analyze.log`、`flutter-tests.log` |
| Windows獨立工具Python3.13.18／Tk8.6 | 43 passed，GUI實際建構成功 | `builder-windows-tests.log`、`builder-windows-gui.json` |
| 三個正式PCS包逐筆來源稽核 | 3/3 passed，mismatches皆空 | `*.source-audit.json` |
| 官方輸入原檔保全 | 34/34 SHA256及大小不變 | `source-preservation.json` |
| Android14 ARM64 `.debug` 大型原包／PCS整合測試 | 1/1 passed，四種包皆成功 | `android-large-import.log/json` |
| Android實際系統選檔→原NHI CM包→預覽→發布 | passed，原包SHA不變；無英文base時顯示安全提示 | `android-saf-import.json`、預覽PNG／XML |
| Release ARM64 APK建置／簽章／內容 | 成功；0.2.0／2003、同舊demo簽章；無INTERNET權限、Python或完整字典 | `android-*-verification.json`、badging/signature/build log |

手機整合測試的單包完整匯入耗時（debug、含原生stream copy／驗證／發布，不是查詢p95）：CM FY2027 **42.445秒**、舊NHI CM **213.762秒**、CMS PCS FY2027 **29.403秒**、NHI2023 PCS **176.992秒**。介面驗證大型包時需等候數分鐘；不能把這些數字當成G6查詢效能。

原NHI CM驗證期間採樣：Java heap約9,980KiB PSS／28,880KiB RSS，整體App PSS282,091KiB／RSS403,308KiB；這只是單次觀察，不宣稱記憶體峰值。原故障是Java需額外配置約146MB連續陣列；新流程沒有整包Java/platform codec byte array。

正式套件版本仍為0.1.1／2002，未自動升級、解除安裝或清除資料。新版APK和三個PCS包另放手機 `Download/manual-test-0.2.0/`，已核對手機副本與本機SHA一致；舊 `manual-test-0.1.2/data` 不改動。

Windows初次CI失敗證據保留：`40830841345`／`40831430478`。原因是widget測試用pumpAndSettle誤當等待原生SQLite isolate結束，Windows拒絕刪除仍開啟的測試檔；修正為等待實際按鈕觸發的Future完整結束，再關閉store並清理。沒有略過測試或關閉檔案安全檢查。

Windows最終重建成功：[Actions 40831793850](https://github.com/maria0010101/ICD-10-CM-Tool/actions/runs/40831793850)，commit `165937f`。Windows Python43項、Flutter18項通過／1項略過（未上傳正式完整CM資料，不能稱全量Windows已測），analyze0問題；portable EXE在hosted Windows上啟動8秒未退出，實際建立獨立user.sqlite並通過integrity及必要table檢查。PCS sample與Linux使用同一SHA256 `72b83564ca455aa00477e2df3a49af41885901f511d85f75ac3a88e942903c28`，原生七軸與Index測試通過。

獨立工具：[Actions 40830841409](https://github.com/maria0010101/ICD-10-CM-Tool/actions/runs/40830841409)，commit `02cadd2`；其後App-only修正不影響工具來源。下載ZIP內18個Python程式與目前來源逐檔核對（僅正規化CRLF／LF），10種profiles、CRC、SHA、Windows GUI／43項測試均核對。內含合成與惡意ZIP測試fixtures，不含完整官方資料。

三個可執行交付：

| 產物 | bytes | SHA256 |
|---|---:|---|
| ARM64 APK | 21,611,420 | `9eb09896e37af8eec68c8cbca8fa603e6d54662e7225dba1425a71fa5e70aea4` |
| Windows App portable ZIP | 15,147,951 | `e7470f0d7994a8fc42dc4a91669840a56f6d2d825d6d263afee11b424851b7b6` |
| Windows builder portable ZIP | 31,067,405 | `0158ee65303548fb7e047067e6086e19fd99f61368c0a298d92811fa0c8d0cdc` |

本機 `manual-test-0.2.0/README_手動測試.md` 提供原包重試／PCS搜尋／重新轉檔步驟；`SHA256SUMS.txt`含三成品與三PCS包。完整資料只在本機與使用者手機，不在GitHub。Windows x64 DLL／app-local CRT與根icon.png產生的圖示payload皆已核對；仍須使用者乾淨Windows正式包操作與Release APK升級驗收。

Android一般App畫面另實際以SAF匯入FY2027 PCS，輸入 `0016070` 得1筆，開啟詳情並捲動確認1–7軸（第7軸Qualifier 0／Nasopharynx）及同列組合展開入口；不是只做資料層自動化。截圖／UI樹見 `android-pcs-detail-*`。
