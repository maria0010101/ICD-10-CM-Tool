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
