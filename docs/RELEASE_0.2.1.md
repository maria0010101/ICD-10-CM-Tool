# 0.2.1：NHI CM獨立中英查詢與分類樹isolate修正

## 兩個問題的原因與處理

1. 使用者的 `nhi-icd-10-cm-20261029-152146.icdpack` 是舊profile製作的 `icd10cm_zh_tw` 附加中譯包，96,802譯名、0個代碼主表節點，mapping為unresolved。檔案可通過安全驗證，但不能當獨立版本啟用；改副檔名或將policy改exact不會補出主表，也不能證明相容FY2027。原檔只讀保留，不更改SHA。
2. 分類樹／Index在Widget State方法內建立資料查詢closure，Dart isolate隱含攜帶整個lexical context，連同Element／State／Future／RenderObject等不可傳送物件，引發 `Illegal argument in isolate message`；冗長錯誤文字以SnackBar覆蓋畫面。已以真實repository widget展開重現（`tree-before-fix.log`），不是主題色誤設。

## 修正

- 新增 `nhi2023-cm-app`，由相同官方ODS的ICD-10-CM分頁產製獨立 `icd10cm_combined` 包；同一官方列包含原始代碼、USE、中英文與所有其他欄位。無需先匯入美國英文包即可啟用、代碼／英文FTS／中文n-gram搜尋。
- `exact_edition`只指向此NHI2023包自身，與FY2027、FY2026無跨版相容宣告。代碼前綴導覽與原始欄位可查，但不是完整美國Chapter／Block／Tabular notes／Alphabetic Index，畫面與來源範圍註記明列。
- 工具來源選單預設NHI CM獨立版，共11種profile；舊附加中譯與來源SQLite用途明確提示。App資料管理分開顯示獨立版本／附加中譯；沒有相容主版本時停用附加包啟用鈕，提供正確改製入口。
- 分類樹、Index、收藏及表格目標查詢，改用controller的純參數API與UI作用域外的closure factory；只傳scalar／資料物件，不把Widget closure送往isolate。分類子節點每頁100筆，避免NHI根節點一次建立數千個Widget；保留背景SQLite、懶載入與安全檢查，未關閉錯誤檢查或改用主執行緒查詢。
- 實體schema／user.sqlite不變，App與資料／使用者資料仍分離；新 `.icdpack` 不分平台。0.2.0與舊檔案保留。

## 使用

使用本版 `manual-test-0.2.1/data/nhi2023-cm-app.icdpack` 匯入App，選「CM 診斷」及 `NHI-2023-CM`，可獨立搜尋中文。原先的附加包不必刪除；它不會因本次修正變成FY2027同版中譯。

自行重製：新版工具選「CM 健保署2023同版中英獨立版」，來源資料夾選含cms／健保署的總資料夾，輸出新檔名；勿選「附加中譯」來製作獨立版。

```powershell
python -m tools.data_builder build --source-dir '2027 ICD-10-CM files' --profile docs/source_profiles/nhi2023-cm-app.json --output nhi-cm-standalone-new.icdpack
python -m tools.data_builder.audit_nhi_cm --package nhi-cm-standalone-new.icdpack --source-dir '2027 ICD-10-CM files' --profile docs/source_profiles/nhi2023-cm-app.json
```

全量source audit逐筆比對代碼展示原值、英文、中文、USE、全部來源欄位、同版限定及每個導覽parent，不只比總數。資料仍只留本機與指定手機，不附送完整官方資料到GitHub或App／工具ZIP。

## 測試及未測範圍

以 `evidence/release-0.2.1/` 的原始日誌、metadata、SHA及最終報告為準。Windows hosted原生測試不等同使用者乾淨Windows完整資料／滑鼠操作；Android隔離測試不等同正式套件升級。未做的Gate不沿用推論通過，仍非臨床簽核版。
