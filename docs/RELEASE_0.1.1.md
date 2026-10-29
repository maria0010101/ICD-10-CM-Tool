# 0.1.1 Demo 發行／補驗報告（2026-10-29）

本版更換使用者提供的 `icon.png`，交付 Android ARM64、Windows x64 免安裝 App，以及獨立 Windows 資料庫製作工具。仍是 **Demo / NOT FOR CLINICAL CODING**，不表示所有臨床／乾淨工作站驗收 Gate 通過。

## GitHub 備份與可重建流程

* 私有原始碼：[maria0010101/ICD-10-CM-Tool](https://github.com/maria0010101/ICD-10-CM-Tool)。原工作目錄先檢查後建立 Git，未覆寫既有專案或舊產物。
* App Windows 建置來源 commit：`d8c2910`；[Windows App Actions](https://github.com/maria0010101/ICD-10-CM-Tool/actions/runs/40806947784)。
* 獨立工具建置來源 commit：`c9a6d1f`；[Windows builder Actions](https://github.com/maria0010101/ICD-10-CM-Tool/actions/runs/40806513703)。
* Git 不含 `.local-source/` 官方完整資料、手機資料、venv、SDK、機器路徑設定與手動測試二進位。GitHub artifact 保存 30 天，已下載的交付副本留本機。
* `windows.yml` 使用 GitHub hosted Windows／Visual Studio，鎖定 Flutter 3.47.5；Python 3.13.18 standalone archive 與依賴核對 SHA256。建置 App 不會把 Python 加入 App bundle。
* `builder.yml` 在 Windows 封裝附私有 Python 3.13.18／Tk 的獨立工具，再使用該工具自己的 interpreter 執行 28 項測試與 GUI construction smoke；不依賴使用者系統 Python。

## 圖示與 Android

* 根目錄 `icon.png` SHA256：`7782dfcd8417ff264aecd72ca52ad89b55ae49fb028166d79d3522bfaacc675a`。
* 同一檔案複製為 Flutter branding asset；生成 Android 各密度 launcher/adaptive icon 與 Windows 256×256 ICO。首次啟動畫面使用同一品牌圖示。
* `flutter analyze`：0 issues；Linux `flutter test`：17 passed；Python：28 passed。命令及原始輸出在 `evidence/icon-release-0.1.1/`。
* `flutter build apk --release --target-platform android-arm64 --split-per-abi` 成功。APK version 0.1.1 / code 2002，ARM64、minSDK24、targetSDK36，無 INTERNET 權限。
* APK 內 branding asset 與原圖逐位元組一致；無 `.icdpack`／SQLite 資料檔／Python 程式。APK 使用 demo/debug 憑證，不是正式發布簽章。
* 新 APK 留給使用者手動安裝，未再次操作手機。先前 0.1.0 `.debug` 一次重試整合測試通過，不冒稱新版 Release 已實機測試。

## Windows 獨立資料庫工具

* Windows 原生 bundled Python：28 passed，唯一 warning 為故意建立重複 ZIP fixture。
* 真正 Tk GUI construction／圖示設定成功；Python 3.13.18 MSC v.1944 AMD64、SQLite 3.53.1、Tk 8.6，Windows Server 2025 runner。
* ZIP 完整性、上游 runtime SHA256、鎖定 wheels、必要檔案皆核對。使用者雙擊 `ICD-Data-Builder.cmd`；`SELF-TEST.cmd` 可重跑測試。
* GUI 支援官方原檔＋profile 製作、驗證及合成包；不下載原檔，不上傳內容，不覆寫輸出。中文跨版未確認仍維持 unresolved。
* 證據：`builder-windows-tests.log`、`builder-windows-gui.json`、`builder-windows-runtime.json`、`builder-artifact-verification.json`。

## Windows App 實際建置與同包驗證

* GitHub Windows／Visual Studio 成功建置 Release x64，附合法 Visual Studio app-local CRT。真正 EXE 的 PE machine 為 AMD64 `0x8664`，生成 ICO 的 image payload 確實存在 EXE 中。
* 原生 `flutter analyze` 無問題；Flutter 測試 **16 passed、1 skipped**（完整官方資料未上傳，因此官方英文 probe 明確略過），Python **28 passed**。
* Hosted runner 啟動 Release EXE，8 秒後程序仍存活；EXE 旁建立 `portable-data/user.sqlite`，必要資料表與 SQLite `integrity_check=ok` 驗證通過。這不是乾淨工作站人工 UI 驗收。
* ZIP 解壓 CRC／SHA256、必要 Flutter／SQLite／CRT DLL、data 與 assets 通過；沒有 Python runtime、`.icdpack`、SQLite 字典檔或現存使用者資料。未把開發機的 portable-data 打包。
* Windows 原生 SQLite 3.54.1，直接匯入 **相同 SHA256** 的 sample v1，不重建或轉換；50 條查詢及 notes、Index crossrefs、table cells、row counts 的**完整 snapshot**與 Linux／Android ARM64 逐值相同。
* 原包 SHA：`47a8de79118cd66e7e7365a0085a4323318b893fad08282074730d31b5582ed5`；snapshot SHA：`9a6c1e4a7a4ab4b0c8666d1291818ac74ca19bf0acee58bafc235f61685b26d4`。
* Sample warm 資料層，各 1000 次 p95：code 0.324ms、英文 0.981ms、中文 0.974ms、tree 0.182ms。僅小型合成資料／debug test engine，不宣稱正式資料效能 Gate 通過。
* 證據：`windows-ci-run.json`、`windows-ci-success.log`、`windows-bundle-launch.json`、`windows-artifact-verification.json`、`windows-probe.json`、`windows-android-linux-comparison.json`、`windows-pe.txt`。Probe 原始 JSON 沿用歷史 `working-tree-0.1.0` label；實際本次來源以 CI head SHA 為準，未修改原始證據。
* 初次 CI Python security release 不能由 setup-python 取得 Windows installer，改用 SHA-pinned standalone；後續不支援的 Flutter build flag 已移除並重建成功。失敗歷史保留，不冒稱初次執行即成功。

## 本機交付產物

全部存於 `manual-test-0.1.1/`，舊版 `dist/` 產物原封保留。三個 samples 是合成測試資料，Windows／Android 使用同一檔案。

| 檔案 | bytes | SHA256 |
|---|---:|---|
| `icd-data-builder-0.1.1-windows-x64-portable.zip` | 31,023,993 | `aa81de65dafdf3e783ba7bf82ad8b3dfef89218ddf4ab0b891b295669078ff9a` |
| `icd-offline-0.1.1-android-arm64-demo.apk` | 21,545,852 | `e6ef5641de6cbfa8757e5aaa0df2cc0856df194a9d0f78df3aeacfa0272d3448` |
| `icd-offline-0.1.1-windows-x64-demo.zip` | 15,121,952 | `af2e761dacd04288e923446f8e9676b42f2b9d116b1c3d97d24dea98dfeca29b` |
| `samples/sample-demo-v1.icdpack` | 7,260 | `47a8de79118cd66e7e7365a0085a4323318b893fad08282074730d31b5582ed5` |
| `samples/sample-demo-v2.icdpack` | 7,295 | `ea0f25d4e0364bafd906966657bfce48940931dbe43b4f7ffb7f93f4308ca335` |
| `samples/sample-overlay-unresolved.icdpack` | 5,187 | `01a4e5595fb2c4d65373621c89417512f588113ae6eb279060be9af9edcb1778` |

操作步驟見該資料夾的 `README_手動測試.md`；校驗清單為 `SHA256SUMS.txt`。APK／Windows App 均不含完整資料，請先用 samples 驗證，再手動匯入已核對的正式包。

## 未完成 Gate（保留，不假設通過）

* 尚待使用者乾淨 Windows x64 工作站與新版 Android Release APK 人工安裝／操作、實體平板、飛航模式、輔助功能及真實斷電／滿磁碟測試。
* Hosted Windows smoke 不是乾淨工作站 G7；sample 的跨平台成功不是完整官方資料的跨平台 G1／正式中文效能 G6。
* 官方 FY2027 英文原檔與 NHI2023 中文原檔本機稽核已完成；未將未確認相容的中文冒稱 FY2027 官方中譯。FR-034 官方拆分／合併 lineage 仍未完成。
* [0.1.0 歷史驗收](ACCEPTANCE.md) 的 Windows BLOCKED 是當時紀錄；本報告與本次 CI 證據是後續補驗，其他未完成 Gate 不因此自動變成通過。
