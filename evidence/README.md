# 實際證據索引

* `toolchain.txt`：Flutter doctor、主機與工具版本；初始目錄非 Git repository，沒有 commit hash。
* `python-tests.log`：最後一次 Python suite，28 passed（含惡意 duplicate ZIP 的預期 warning）。
* `flutter-analyze.log`：ASCII 同步副本上最後一次 analyze，No issues found／EXIT=0。
* `flutter-tests.log`：最後一次 Flutter suite，17 passed／EXIT=0。
* `flutter-analyze-initial.log`：原中文路徑下的 LSP 截斷失敗，不當作程式分析通過。
* `android-build.log`：ARM64 release Built／EXIT=0；不證明實機啟動。
* `android-integration.log`：首次debug Built，但安裝被手機拒絕；該次案例未執行。
* `android-integration-retry.log`：使用者允許後重試一次安裝成功，整合測試1/1通過。
* `android-device-report.json`／`android-linux-comparison.json`：sample與正式英文各50查詢及notes／Index完整結果一致；Android1000次warm benchmarks。
* `android-debug-retry-badging.txt`／`android-debug-installed.txt`：此次實際APK ID與已安裝版本；只安裝.debug。
* `flutter-analyze-after-device.log`：新增裝置測試harness後的靜態分析結果。
* `android-*-badging.txt`：production / .debug ID 分離；release 無 INTERNET 權限。
* `apk-signature.txt`：demo Android debug certificate，不是正式發布簽章。
* `apk-audit.json`：ARM64 native SQLite／Flutter、無字典或 Python assets。
* `cdc-build.json`／`cdc-source-counts.json`／`cdc-audit.json`：實際官方原檔 hash、解析計數、原文差異與完整性結果。
* `nhi-build.json`／`nhi-audit.json`：官方 CSV 逐列對照，全部 unresolved；不是 FY2027 合格官方中譯。
* `linux-probe.json`／`linux-official-probe.json`：同一原包 50 queries／notes／Index snapshot + 1000 warm queries。官方英文包的中文測試為空資料路徑，不算正式中文效能。
* `build-source-parity.json`／`android-resume-source-parity.json`：APK build copy 與 canonical runtime sources／schema／lock 相同，原Release APK雜湊未變。
* `source-sha256.txt`：來源 revision 替代清單，不冒充 Git commit。
* `artifacts.json`／`checksums.sha256`：實際 APK／sample 大小、SHA256。

時間、OS、edition、package SHA 以各 JSON 內紀錄為準。正式原始資料及完整轉換包只留在 `.local-source/`，沒有放入發行物。Windows、Release實機、平板未測結果請以 `docs/ACCEPTANCE.md` 為準。
