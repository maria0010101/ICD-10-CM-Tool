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

### 已完成測試證據

- Python3.13.18：46項通過，1個刻意製作重複ZIP的warning；`python-tests.log`。
- Linux Flutter3.47.5：22項通過，靜態分析0問題；新測試實際啟用CM sample、50次中英碼查詢、lineage拒絕、收藏／註解保留、附加包按鈕提示與樹狀／多層Index展開。原故障日誌保留，不以略過測試修復。
- 正式NHI CM包：96,802原始中英列，96,803代碼節點（含1個來源根）、96,803來源註記、3,243,772 n-gram，Index為0不冒充已提供；逐筆原值與導覽parent稽核mismatches為空。
- 原使用者包：SHA256 `d81e1127ae174692a7bcda7e27189675639d6520dfe4f19385de39584bea52f0`，完整validator通過、內容未變。34個官方原檔大小及SHA均不變。
- Windows獨立工具：[Actions 40837889917](https://github.com/maria0010101/ICD-10-CM-Tool/actions/runs/40837889917)成功；私有Python3.13.18、46項原生測試與Tk GUI建構成功。ZIP 31,080,426 bytes，SHA256 `8138a575a150c79942df89b0fb6af3ebadf17cf6bbc405f889af3049708ec912`。下載後CRC、11個profiles、21個Python來源逐檔比對通過（僅正規化CRLF）。

新CM包SHA256 `544c441b27e8b126d6342da50405580098298613b9d7ba360883268008b1ab7a`，81,248,397 bytes。它是另一個新的獨立資料包，不是悄悄重寫使用者舊包。基礎包與附加包可以共存，但此NHI同版對照不會因相同code而套入US版。

Android14 ARM64隔離`.debug`完整資料測試1/1通過：同一SHA的新NHI CM包可在沒有US英文包時獨立啟用，`I509`／`heart failure`／`心臟衰竭`均查到結果，I50分類樹Widget實際展開無SnackBar／framework例外，原輸入hash不變。總測試6分12秒，report的367,655ms包含驗證／發布／搜尋及UI等待；手機休眠後正常喚醒，不能將此耗時當成查詢p95。未改安全設定、未解除安裝或清除正式資料。

Windows中途失敗 `40838049027` 是新增test capture在ListTile與Material間用了ColoredBox，framework正確拒絕可能遮住ink的繪製層；已改Material並保留原錯誤log，再以同一展開斷言重新跑。沒有將failure改成skip。`40837889935`為被新版取代而主動取消的早期App run，不算通過。可閱讀的native tree capture明列是test engine繪製，不冒充使用者Windows EXE實際操作。

Release ARM64 APK已建置：0.2.1／versionCode2004，21,611,420 bytes，SHA256 `9e29dfa335c2ddb62be0cc1b40c3c61d11a06882f8cb83693a0a869be08fa888`；badging／CRC／簽章驗證通過，與原demo簽章一致，無INTERNET權限、Python或正式字典。正常main的debug包也已在隔離ID以install-r更新，測試harness未覆蓋正式套件。正式Release安裝／使用者收藏升級仍交由人工驗收，不把debug測試當成Release通過。


Windows最終App [Actions 40838564627](https://github.com/maria0010101/ICD-10-CM-Tool/actions/runs/40838564627)／commit `cc40ed3`成功。Python46項、Flutter21項通過／1項正式完整CM資料因未上傳而略過，analyze0問題；分類樹與Index真實SQLite/isolate多層展開測試通過，native capture保留。hosted EXE實際啟動8秒未提前退出，建立的獨立user.sqlite經integrity與必要表檢查。這不是乾淨工作站完整官方資料的人工驗收。

下載的App ZIP為15,148,895 bytes，SHA256 `3f5fc0033a0a8308ed3d24902513bd2845b38dbb6658e586ec5a4dedb32923d3`；CRC／AMD64／SQLite、Flutter及app-local VC DLL／原icon payload核對通過。不含Python、官方字典或測試生成的portable-data。NHI CM合成包與Linux同SHA `48693eec99323996424cbc1827edaf868a676985c5344bce8f04dc4b53d7bd1e`，50次查詢完整snapshot逐值一致；不把小型sample當成正式全量Windows Gate。

手機一般main App `.debug`另實際點「分類」並展開FY2027 PCS的Medical and Surgical，正確顯示各Body System，無錯誤覆蓋；`android-normal-app-tree.png/xml`是實際裝置畫面，與test engine tree capture分開。正式App仍0.1.1／2002，未由測試自動更新。新CM包與Release APK另存手機 `Download/manual-test-0.2.1/`，SHA與本機相同。

本機交付 `manual-test-0.2.1/`，四個二進位成品（APK、Windows App ZIP、Windows工具ZIP、新NHI CM包）以SHA256SUMS核對；原始碼與測試證據推回私有GitHub，完整官方資料及使用者資料不上傳。請照README手動升級／匯入，保留舊版本目錄與收藏。
