# 需求追蹤與實作清單

日期 2026-10-29；「實作」不等於跨平台 Gate 已通過。全表以 TEST_PLAN 原 ID 對照。

| 需求 | 實際檔案 | 驗證／狀態 |
|---|---|---|
| FR001/002/003/005 | app/lib/data/repository.dart | repository_test + cross_probe；精確碼、FTS5、n-gram、版本／billable；正式中文相容性未確認 |
| FR004/013/014 | adapters.py、repository.dart、dictionary_app.dart | 四種官方 Index/Table 實際解析；subterm、see/seeAlso/manif/subcat/seecat；range 不作精確碼 |
| FR006 | dictionary_app.dart、widget_test.dart | Ctrl+L 實測；快捷鍵實作；完整平台鍵盤／可存取性驗收待補 |
| FR010/011/012 | schemas/content.sql、adapters.py、repository.detail | 原檔 notes 原文／順序稽核；繼承 source 標示；billable 依 order |
| FR015 | dictionary_app.dart | 本機 Clipboard，包含來源版號；平台實際剪貼簿未測 |
| FR020/021/022/023 | dictionary_app.dart、widget_test.dart | 390/800/1440px、文字1.6倍 widget 測試；單／雙／三欄／可拖曳；實體平板及 Windows 未測 |
| FR030/031 | package.py、safe_zip.dart、package_store.dart | 原檔 SHA 不改、無字典資產；Linux／Android同包匯入及兩組50查詢一致；Windows Gate仍受阻 |
| FR032/033/035 | manifest.dart、translations/zh_ngrams、SOURCE_PROVENANCE | 多版本、獨立 overlay、unresolved 不默認相容；正式中文 CSV 逐列稽核 |
| FR034 | repository.compare、compareVersions | 新增／移除／描述／state／notes；官方拆分／合併 lineage 尚未實作（partial） |
| FR040 | adapters.import_cdc、audit.py | CDC FY2027 ZIP/XML/TXT 實際轉換與完整 code/notes/Index 計數；未知 tag 阻擋 |
| FR041 | adapters.import_nhi、audit_nhi.py | 官方 CSV 實際轉換、XLSX／公式 fixtures；ODS 明確 unsupported |
| FR042/043/044 | package_store.dart、dictionary_app.dart | 選檔、預檢／預覽、staging、保留舊版、rollback／logs；UI 檔案選擇器實機待測 |
| FR045/046 | safe_zip.dart、validator.dart、package.py | Python + Dart malicious fixtures；schema allowlist、FTS integrity、副本；錯版拒絕 |
| FR050/051 | package_store.dart | user.sqlite 分離、收藏／註解／history、JSON；跨版收藏警示；回復前後不覆寫 |
| FR060/061 | 分層 repository、versioned manifest | P2 僅預留；沒有授權模組／私人詞庫 UI，不宣稱已完成 |
| NFR001 | Release Android manifest、所有 lib/ | 無 runtime HTTP／telemetry；正式 APK 無 INTERNET（以 badging 為準）；飛航／防火牆 Gate 待測 |
| NFR002/003 | test_support/probe、evidence、dist | sample + 官方英文各1000次 warm benchmarks；體積／SHA 實測；中文／冷啟動／frame time待補 |
| NFR004/005/008 | Android minSdk24、capacity.dart、package_store | Windows API 與 Android StatFs 實作；真正裝置空間不足／斷電待測 |
| NFR006/007 | schema、locks、tests、.github/workflows | 來源稽核／lockfile／CI 定義；CI 未遠端執行，沒有假造綠燈 |

## 里程碑證據

* A：`evidence/toolchain.txt`、`docs/ARCHITECTURE.md`；初始 git 非 repository；六份原規格保留。
* B：`schemas/`、`tools/data_builder/`、`samples/`、`evidence/python-tests.log`、`cdc-audit.json`、`nhi-audit.json`。
* C：`app/lib/{app,domain,data,ui}/`、`evidence/flutter-tests.log`、`linux-probe.json`。
* D：`package_store.dart`、`safe_zip.dart`、`validator.dart`；Dart transaction/ZIP/overlay tests；首次安裝受阻；使用者允許後一次重試成功，Android整合測試1/1通過。
* E：`scripts/`、`LICENSES.md`、`README.md`、`docs/ACCEPTANCE.md`、`dist/`；Windows無產物、Android是否產生以 log 與 checksum 實際結果為準。

## 尚待完成的可執行工作

1. Windows x64 `scripts/test.ps1`／`build_windows.ps1`，乾淨工作站啟動；匯入同 SHA 包並比對50 queries。
2. Android `.debug` + `--no-uninstall` 已通過，device-report與Linux probe完整一致；接續需Release實機與更多故障／離線場景，不重建資料。
3. 實體平板、飛航／阻斷網路、旋轉、螢幕閱讀器、真正 ENOSPC／kill/relaunch。
4. 經審核 NHI 2023→選定 base lineage，或建立同版 CDC 英文包；不可直接把 FY2027 同碼對照改 exact。
5. 官方 conversion 拆分／合併資料 adapter、內容專業簽核、冷啟動／UI frame-time、正式發布簽署。
