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
| FR041 | adapters.import_nhi、audit_nhi.py | 官方 CSV 實際轉換、XLSX／公式 fixtures；0.1.2 ODS 串流／全分頁來源表已完成，逐值稽核見官方轉檔報告 |
| FR042/043/044 | package_store.dart、dictionary_app.dart | 選檔、預檢／預覽、staging、保留舊版、rollback／logs；0.2.0 Android SAF 原大型包實際選檔／預覽／發布已測 |
| FR045/046 | safe_zip.dart、validator.dart、package.py | Python + Dart malicious fixtures；schema allowlist、FTS integrity、副本；錯版拒絕 |
| FR050/051 | package_store.dart | user.sqlite 分離、收藏／註解／history、JSON；跨版收藏警示；回復前後不覆寫 |
| FR060/061 | 分層 repository、versioned manifest | P2 僅預留；沒有授權模組／私人詞庫 UI，不宣稱已完成 |
| NFR001 | Release Android manifest、所有 lib/ | 無 runtime HTTP／telemetry；正式 APK 無 INTERNET（以 badging 為準）；飛航／防火牆 Gate 待測 |
| NFR002/003 | test_support/probe、evidence、dist | sample + 官方英文各1000次 warm benchmarks；體積／SHA 實測；中文／冷啟動／frame time待補 |
| NFR004/005/008 | Android minSdk24、capacity.dart、package_store | Windows API 與 Android StatFs 實作；真正裝置空間不足／斷電待測 |
| NFR006/007 | schema、locks、tests、.github/workflows | 來源稽核／lockfile／CI 定義；Windows Actions 已實際執行，原生測試／建置／hosted啟動證據見各版報告 |

## 里程碑證據

* A：`evidence/toolchain.txt`、`docs/ARCHITECTURE.md`；初始 git 非 repository；六份原規格保留。
* B：`schemas/`、`tools/data_builder/`、`samples/`、`evidence/python-tests.log`、`cdc-audit.json`、`nhi-audit.json`。
* C：`app/lib/{app,domain,data,ui}/`、`evidence/flutter-tests.log`、`linux-probe.json`。
* D：`package_store.dart`、`safe_zip.dart`、`validator.dart`；Dart transaction/ZIP/overlay tests；首次安裝受阻；使用者允許後一次重試成功，Android整合測試1/1通過。
* E：`scripts/`、`LICENSES.md`、`README.md`、`docs/ACCEPTANCE.md`、`dist/`；Windows及Android實際產物以各版 log 與 checksum 為準；完整Gate未全部通過。

## 尚待完成的可執行工作

1. Windows x64 `scripts/test.ps1`／`build_windows.ps1`，乾淨工作站啟動；匯入同 SHA 包並比對50 queries。
2. Android `.debug` + `--no-uninstall` 已通過，device-report與Linux probe完整一致；接續需Release實機與更多故障／離線場景，不重建資料。
3. 實體平板、飛航／阻斷網路、旋轉、螢幕閱讀器、真正 ENOSPC／kill/relaunch。
4. 經審核 NHI 2023→選定 base lineage，或建立同版 CDC 英文包；不可直接把 FY2027 同碼對照改 exact。
5. 官方 conversion 拆分／合併資料 adapter、內容專業簽核、冷啟動／UI frame-time、正式發布簽署。

## 0.2.0 使用者追加需求追蹤

| 要求 | 實作／證據 | 驗收範圍 |
|---|---|---|
| 修復NHI大型包手機匯入 | MainActivity SAF 64KiB串流、package_picker、validator256筆批次、safe_zip64KiB；原OOM／SHA／四包Android整合測試及系統選檔預覽 | 原NHI CM包不改；正式App不清資料；release APK建置，人工升級另測 |
| App PCS查詢 | classification隔離、pcs_pack、七軸row、Index部分碼候選、NHI同版中英；Python43／Flutter19測試 | CMS兩版與NHI三包獨立來源逐筆稽核；正式全量Windows尚待人工匯入 |
| 新資料製作入口 | 3個App profiles + 舊7種，共10種；Windows獨立builder與Tk原生測試 | 原 `.sqlite` 是來源表，不改名冒充 `.icdpack` |

歷史表與0.1.0 Gate記錄保留其當時範圍；最新實際結果以[0.2.0報告](RELEASE_0.2.0.md)及對應evidence為準。

## 0.2.1修正追蹤

- FR003/032/035/041：新增NHI CM同版獨立combined包，原值全量audit及中文／英文／碼50次查詢，舊overlay不改版別政策；`nhi_cm_pack.py`、`audit_nhi_cm.py`、`nhi_cm_test.dart`。
- FR010/013/022：`loadChildren`與`resolveTarget`純資料API在UI作用域外產生查詢closure；分類樹／Index native widget展開及100筆分批，避免State/Element隱含跨isolate；`tree_regression_test.dart`，原重現log保留。
- FR043/046：管理介面分辨附加中譯／獨立版，無相容base時不允許錯用overlay；GUI預設獨立NHI CM與用途提示，11種profiles。

最新結果與未測範圍見[0.2.1報告](RELEASE_0.2.1.md)。

## 0.2.3追蹤

FR032/040/041→10個新profiles、nhi_legacy.py與audit_nhi_legacy.py；FR033/035→原始交錯列、未知USE manifest能力1.2及UI標示、缺譯不補；FR045/046→預設拒絕公式，僅來源設定指定輔助欄inert保存、雙端validator阻擋billability推定。對應T31～T34，結果見[0.2.3](RELEASE_0.2.3.md)。

## 0.2.4追蹤

FR002/010/011/013→repository.searchPage的FTS候選／遞迴context／原始順序、主詞建議／分支及精確碼回退；FR020→controller generation分頁防舊查詢覆蓋、可點目標碼及已載入／總數；T35～T37→guided_search_test、guided_ui_test、guided_official_test及Android integration。第三方資料不作來源，schema及既有包不改；詳[分析](SEARCH_SMARTICD10_ANALYSIS.md)。
