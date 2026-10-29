# E — 實際驗收報告（2026-10-29）

**結論：可建置的 0.1.0 demo，不是已通過全部 Gate 的正式臨床版本。**

## 執行身分與版本

* OS：Linux CachyOS 7.3.0-4-cachyos x86_64；硬體見 `evidence/host-cpu.txt`。
* Flutter 3.47.5 stable / Dart 3.13.4；Python 3.13.18；SQLite native 版本 `3.54.1`。
* 初始目錄非 Git repository；build revision 記為 working-tree-0.1.0，另以來源檔案 SHA 清單定址，不捏造 commit。
* 測試原始碼在本專案；Flutter 因中文路徑 LSP 錯誤在 `/tmp/icd-work-build/app` 同步副本執行。SDK 未修改。套件 lock 相同，lib 原始碼逐檔一致。
* Android 手機：2109119DG / Android14 / ARM64，完整工具鏈與裝置資訊在 `evidence/toolchain.txt`、`android-device.txt`。

## 已執行命令／結果

| 工作 | 實際命令 | 結果／證據 |
|---|---|---|
| Python | `.venv313/bin/python -m pytest tools/data_builder/tests -q` | **28 passed**；`evidence/python-tests.log`；唯一 warning 來自故意建 duplicate ZIP fixture |
| Flutter 靜態分析 | `flutter analyze`（ASCII build copy） | **No issues found / EXIT=0**；`evidence/flutter-analyze.log` |
| Flutter 單元／widget／native | `flutter test --reporter expanded` | **17 passed / EXIT=0**；`evidence/flutter-tests.log` |
| Android release build | `flutter build apk --release --target-platform android-arm64 --split-per-abi` | **Built / EXIT=0**；`evidence/android-build.log` |
| Android integration | `flutter test -d ea6879f4 integration_test/device_test.dart --no-uninstall --dart-define-from-file=...` | Debug APK Built；安裝 **INSTALL_FAILED_USER_RESTRICTED**；**0 integration cases executed**，不得算通過 |
| Windows | PowerShell build/test 腳本已寫入 | **NOT RUN**；無 MSVC／Windows 主機 |
| CDC source audit | `python -m tools.data_builder.audit --package ... --input ... --input ...` | **passed=true**；`evidence/cdc-audit.json` |
| NHI source audit | `python -m tools.data_builder.audit_nhi --package ... --source ... --code-column ... --title-column ...` | **passed=true**；`evidence/nhi-audit.json` |
| Release APK audit | `aapt2 dump badging` + `apksigner verify --print-certs` | ARM64 only、minSDK24、target36、**無 INTERNET 權限**；native SQLite 隨包；沒有 `.icdpack/.sqlite/.py` 資產 |

17項 Flutter 測試包含：正規化、FTS／中文、notes／Index／版本差異、惡意ZIP／DB／schema、staging中斷／空間不足注入、rename後中斷／transaction rollback、user資料保留、overlay隔離、50 queries／1000次benchmarks、手機／平板／桌面viewport及1.6倍文字。Widget驗證不等於實體裝置通過。

## B — 官方來源完整性與資料版本

* CDC FY2027：**98,403** 個 code 無缺漏／多餘，billable 與 order 一致。共有98,723 nodes（含22章、297 blocks及1個引言heading）。
* notes **27,079**：依來源節點分組，文字與相對順序精確一致。Index **99,108**、crossrefs **16,344**、table cells **54,182** 與原 XML 計數一致。
* XML／TXT描述存在 **109** 個差異（例如重音字元）；保留Tabular原文，只有補出的七字元完整碼使用Order描述。差異代碼全列於audit，不靜默改寫。
* NHI 2023 / 1150827：原CSV與轉換 **96,802** 列逐列一致（包含原始所有欄位），n-gram **3,243,772**；全部 **unresolved**，未把它冒稱FY2027合格中譯。
* 官方完整資料僅留 `.local-source/`，不在App或source ZIP散布。正式內容仍待專業簽核與所有跨平台Gate。

## T17 效能實測：Linux、官方 FY2027 英文、warm cache、debug test engine

單位 ms；每種20次暖機後1000次。測資料層，不含 isolate啟動、UI或匯入；原始JSON含OS、時間、版號、原包SHA及50條查詢輸出。

| 操作 | 次數 | p50 | p95 | p99 |
|---|---:|---:|---:|---:|
| code | 1000 | 0.024 | 0.042 | 0.082 |
| english | 1000 | 1.226 | 1.605 | 1.868 |
| chinese | 1000 | 0.082 | 0.132 | 0.184 |
| tree | 1000 | 0.099 | 0.166 | 0.210 |

**chinese 在這個英文包中是空資料路徑，不代表正式中文效能通過。** 合成中譯可用性另有sample測試。Android／Windows正式資料、cold start與UIframe time未測，G6未通過。

## T01／T20 同包指紋

* Sample原包：`47a8de79118cd66e7e7365a0085a4323318b893fad08282074730d31b5582ed5`
* Linux 50 queries + notes + Index關係指紋：`9a6c1e4a7a4ab4b0c8666d1291818ac74ca19bf0acee58bafc235f61685b26d4`
* CDC原包：`6f46a5a52fe2f371ffc19eda5026ca69775aaf36c1c03d76ec8e3e0df7093baa`
* CDC Linux 50 queries指紋：`73477607c97a153a12eb215ae035dfd0fb15a59fa9a988a61825212dac94d6fb`
* **Android 尚未執行、Windows 尚未執行**，不能宣稱跨平台同包成功。integration_test 已備妥相同原檔base64（只在test target），會驗證archive SHA與Linux snapshot SHA，從不重建資料。

## T18 實際產物

| 檔案 | bytes | SHA256 |
|---|---:|---|
| `samples/sample-demo-v1.icdpack` | 7,260 | `47a8de79118cd66e7e7365a0085a4323318b893fad08282074730d31b5582ed5` |
| `samples/sample-demo-v2.icdpack` | 7,295 | `ea0f25d4e0364bafd906966657bfce48940931dbe43b4f7ffb7f93f4308ca335` |
| `samples/sample-overlay-unresolved.icdpack` | 5,187 | `01a4e5595fb2c4d65373621c89417512f588113ae6eb279060be9af9edcb1778` |
| `dist/icd-offline-0.1.0-android-arm64-demo.apk` | 19,915,808 | `75e2ac8379890718b4405de98c30c70cc054caffd94f6665f3eda6608c7ab5cd` |

APK 19.916 MB（約18.99 MiB），低於40 MB目標；**debug certificate簽署之demo**。簽章與native assets審核在 `apk-signature.txt`、`apk-audit.json`。Windows ZIP無產物，不能量測。完整 source ZIP另有 `dist/SHA256SUMS.txt`，不含官方資料或本機venv／SDK／憑證。

## G1–G8 Gate 結論

| Gate | 狀態 | 未完成事項 |
|---|---|---|
| G1 同包跨平台 | **BLOCKED** | 僅Linux native成功；Windows缺主機，Android安裝拒絕 |
| G2 離線 | **PARTIAL** | Release無INTERNET、無HTTP／遙測呼叫；飛航／Windows防火牆實測未執行 |
| G3 官方完整性 | **PARTIAL** | 官方英文、官方中文原檔計數／原文已稽核；全平台內容專業簽核未完成 |
| G4 中譯版控 | **自動化部分通過** | unresolved不進合格搜尋、錯base阻擋；FY2027↔NHI2023相容性不宣稱完成 |
| G5 安全回復 | **PARTIAL** | 惡意ZIP／DB／schema／注入失敗通過；真實裝置斷電／ENOSPC待測 |
| G6 效能 | **PARTIAL** | Linux正式英文達目標；正式中文、Windows／Android、冷啟動／UI待測 |
| G7 Release乾淨環境 | **BLOCKED** | APK已建置但未啟動；Windows無ZIP；平板未測 |
| G8 證據完整 | **已記錄當前結果** | 失敗／未測／體積／checksum均列示；不是全Gate通過 |

## TEST_PLAN 22項對照

| ID | 本次結果 |
|---|---|
| T01 | BLOCKED：兩個目標平台皆未執行，Linux50 queries已保存 |
| T02 | 官方英文與中文source audit通過；專業內容簽核另需 |
| T03/T04/T05 | 自動化通過；中文合格顯示測試是SAMPLE，正式跨版中譯未確認 |
| T06/T07 | fixtures及官方來源計數／notes原文稽核通過；真機呈現待測 |
| T08 | 描述／狀態／新增移除／notes diff實作；官方拆分合併lineage尚未實作 |
| T09 | unresolved／錯base／切版解除overlay測試通過 |
| T10/T11 | Python／Dart惡意ZIP、DB；XXE／XLSX容器／formula安全測試通過 |
| T12 | 故障注入通過；真正強制關閉／低磁碟裝置測試未執行 |
| T13 | 靜態離線審核通過；飛航模式／防火牆實測未執行 |
| T14/T15 | 三種viewport與文字放大／Ctrl+L widget通過；完整真機可存取性待測 |
| T16 | user.sqlite隔離及rollback前後收藏／註解保存測試通過 |
| T17 | Linux正式英文／sample每種1000次；正式中文與目標平台未測 |
| T18 | APK及sample實際體積／checksum已保存；Windows無產物 |
| T19 | 未測，沒有Windows主機 |
| T20 | Linux native SQLite FTS5／n-gram通過；兩端比較待測 |
| T21 | 欄名映射、重複碼、公式、XLSX ZIP/XXE fixtures通過；正式NHI CSV全列audit通過 |
| T22 | 不相容schema拒絕／不改現行版本測試通過 |

## 後續恢復條件

正常允許Android安裝後，核對`.debug`套件與`--no-uninstall`再執行integration；不解除安裝、不改安全設定繞過拒絕。Windows依scripts在實際Windows x64執行後才可生成並驗證portable ZIP。所有未完成需求見 `TRACEABILITY.md`、`KNOWN_LIMITATIONS.md`。
