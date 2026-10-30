# 0.2.3：歷史版本來源設定與正式程式名稱

## 需求／決策／追蹤

| 要求 | 實作 | 驗證 |
|---|---|---|
| 相容新增FY2023～FY2025 CMS資料 | 8個獨立來源設定：CM／PCS各FY2023 Apr、FY2024 Apr、FY2025 Oct與Apr | 20個原檔與CMS當期下載SHA256相同；全量build與獨立source audit |
| 健保署2014版 | 2個`nhi_legacy_app`設定、分頁交錯列解析器；保留原文／列號／修正說明 | 合成fixtures、安全負向案例與全量逐值audit |
| 程式名稱移除Demo、升版0.2.3 | Android顯示名稱、Windows視窗／產品、授權頁、成品命名、builder GUI與portable版本 | analyze、native tests、APK metadata／簽章、WindowsCI |

官方完整檔與產出資料僅留本機。私有備份／CI只含程式、來源設定與合成fixtures；不發布公開Release。新版21個設定均鎖定原檔hash，GUI／CLI共用build流程。

## 如何選來源

來源資料夾選含`cms`與`健保署`的總目錄，例如`2027 ICD-10-CM files`，不選FY子目錄。

| 下拉選項／profile | 實際release | 限制 |
|---|---|---|
| `cm-fy2023-apr`／`pcs-fy2023-apr-app` | 2023-04-01～2023-09-30 | CMS提供的是4月更新，不冒稱2022-10原版 |
| `cm-fy2024-apr`／`pcs-fy2024-apr-app` | 2024-04-01～2024-09-30 | 2024 CM含勘誤，PCS含新增碼 |
| `cm-fy2025-oct`／`pcs-fy2025-oct-app` | 2024-10-01～2025-03-31 | 不與同FY的4月檔混用 |
| `cm-fy2025-apr`／`pcs-fy2025-apr-app` | 2025-04-01～2025-09-30 | 不以檔名大小寫自動判斷；各檔hash固定 |
| `nhi2014-cm-app` | NHI-2014-CM，1131212修訂 | 23主表工作表、修正說明另外保存 |
| `nhi2014-pcs-app` | NHI-2014-PCS，1120509修訂 | 18主表工作表、修正說明另外保存 |

2014年版的臺灣採用期間依健保署公告記錄為2016-01-01～2024-12-31，與原檔修訂日期分開，不視為每列修訂自2016年即生效。不可把舊版相同代碼當成2023／US FY2023中譯。

2014原檔沒有USE／billable宣告：資料庫`billable=0`保守儲存，manifest增加`code_status_policy=not_provided`，App顯示「來源未提供可申報狀態」，不能將這個0解讀成來源已宣告非申報碼。分類樹只用來源工作表與碼前綴導覽，不重建未提供的美國Tabular／Index／PCS七軸。CM的T50.B96原檔確實缺中譯，省略translation記錄與UI中譯列，不顯示缺譯提示。

2014 PCS在`0-2`工作表E/F欄有2725個輔助公式。僅該設定顯式允許該兩欄的公式保存為`INERT FORMULA; NOT EVALUATED`文字及未使用的cached值；不求值、不執行、不讀取外部連結、也不將其結果用於代碼／譯名／狀態。A/B主欄的公式、其他欄或工作表的公式仍拒絕。一般ODS／2023 adapter維持全面拒絕公式。每個來源列的其他註記欄完整保留供audit，修正說明不併入現行主表。

## 相容性與升級

- 舊資料包、收藏、個人註解及原應用程式ID不變；直接覆蓋升級，不解除安裝或清資料。
- SQLite實體schema仍1.0.0；新2014包的manifest要求App資料能力1.2.0（App0.2.3）。舊App會拒絕未知metadata，不會把缺少USE誤讀為完整碼；升版後再匯入。其他CM／PCS包沿用1.0／1.1資料能力。
- 正式App名稱`ICD Offline`，不再含Demo。合成SAMPLE資料、來源範圍與未測Gate標示保留。使用者已回報分類人員初步內容可用；這不代替尚未執行的平台／安全／效能驗收。

## 可重現命令

```sh
.venv313/bin/python -m pytest tools/data_builder/tests -q
.venv313/bin/python -m tools.data_builder catalog --source-dir '2027 ICD-10-CM files'
.venv313/bin/python scripts/build_official_local.py --source-dir '2027 ICD-10-CM files' --output-dir NEW-DIR --profile nhi2014-cm-app --profile nhi2014-pcs-app
bash scripts/prepare_ascii_build.sh /tmp/icd-build-023
cd /tmp/icd-build-023/app
flutter pub get --enforce-lockfile
flutter analyze
flutter test --reporter expanded
# 回repo根目錄
bash scripts/build_android.sh /tmp/icd-build-023/app
```

Windows PowerShell（可攜製作工具不需系統Python）：

```powershell
.\ICD-Data-Builder.cmd catalog --source-dir 'D:\2027 ICD-10-CM files'
.\ICD-Data-Builder.cmd build --source-dir 'D:\2027 ICD-10-CM files' --profile docs\source_profiles\nhi2014-cm-app.json --output 'D:\new-nhi2014-cm.icdpack'
.\ICD-Data-Builder.cmd verify --package 'D:\new-nhi2014-cm.icdpack'
# 原始碼Windows原生建置
.\scripts\build_windows.ps1
```

## 官方核對來源

- [CMS各年度與半年度檔案](https://www.cms.gov/medicare/coding-billing/icd-10-codes)：本次20個所需ZIP逐檔下載計算SHA256，均與使用者原檔相同；這是內容一致性核對，不是數位簽章。
- [健保署2014版原檔頁](https://www.nhi.gov.tw/ch/lp-3839-1.html)：CM 113.12.12、PCS 112.05.09；[採用及轉版公告](https://www.nhi.gov.tw/ch/cp-6051-aeadf-3050-1.html)。
- 檔案清單、實測log、來源核對方法見`evidence/release-0.2.3/`；完整內容與逐碼audit中的原文只留本機，不隨程式再散布。

## 實際測試／交付結果

建置完成後於本節補記結果；未完成的項目不得算通過。

### 完成結果

- Python3.13.18：Linux58項通過；Windows可攜工具內建Python58項通過，真正Tk8.6視窗建構通過。LinuxTk9.0亦實際建構成功。唯一pytest warning來自刻意建立重複ZIP entry的惡意fixture。
- Flutter3.47.5／Dart3.13.4：Linux及Windows各29項通過、1項既有完整英文資料測試因隔離／CI未放該原包而略過；兩端analyze無問題。本機另以`verify_source_profiles.dart`對全部10個新完整包執行App匯入／啟用與500次查詢，1項整合測試通過，原包hash全數不變。
- 新資料全量來源稽核：8個CMS包及2個NHI2014包全部passed；NHI2014 CM91737碼／91736中譯／195修訂參照列，PCS71924碼及中譯／25修訂參照列。86個官方輸入檔前後hash相同。
- Android14 ARM64隔離`.debug`整合測試1項通過，2個合成2014包的SHA／列數／100次完整查詢結果與Linux／Windows golden完全相同；正式套件的版本及安裝時間未變，測試沒有開啟其資料。測試harness初次傳入多行JSON define導致frontend URI解析失敗；改用minified JSON的UTF-8 base64後重新建置及實機測試通過。aapt版本由已安裝build-tools動態檢查，不假設存在36.1.0。
- [Windows App CI 41010070834](https://github.com/maria0010101/ICD-10-CM-Tool/actions/runs/41010070834)／產品來源`e712aaa`成功：原生測試、完整CRT ZIP及EXE實際啟動，建立獨立user.sqlite且完整性通過。下載成品核對SHA／CRC／AMD64／產品名稱與版本／圖示payload／DLL／無內嵌資料，NHI2014兩包100次snapshot與Linux及Android一致。
- [Windows Builder CI 41009953752](https://github.com/maria0010101/ICD-10-CM-Tool/actions/runs/41009953752)／工具來源`b4dbff1`成功：下載ZIP中的Python程式、schema及21個profiles與本機一致（文字CRLF/LF正規化比對，二進位逐byte）。更新的整合測試harness不屬於製作工具或正式App入口。
- Release ARM64 APK0.2.3／2006、label為ICD Offline，與0.2.2相同簽章及applicationId，無INTERNET權限。仍沿用前版開發簽章，未宣稱商店正式簽署。三個成品與10個新資料包在`manual-test-0.2.3/`；APK副本已核對SHA並放手機`Download/manual-test-0.2.3/`，未自動安裝正式包。
- 舊Windows App run41009953691因新增snapshot比對由最終run取代取消，不計為通過。`xvfb-run`不在本機；直接使用既有桌面DISPLAY的GUI smoke成功，不把缺工具算通過。

### 尚未執行的驗收

乾淨Windows工作站、實體平板、正式Release覆蓋安裝後的人工操作、全部10個新完整資料包在Windows／Android的全量跨端比對、飛航／封鎖網路及真實ENOSPC／kill/relaunch、正式資料各裝置p95 Gate仍未完整執行。這些不因名稱移除Demo而標示通過。現有跨端自動驗證是兩個合成2014包，不等同完整官方資料在所有平台的專業驗收。
