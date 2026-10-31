# 0.2.4 開發、測試與建置

[回首頁](../README.md) · [使用指南](USER_GUIDE.md) · [需求](../SRS.md) · [資料包契約](../DATA_PACKAGE_SPEC.md) · [測試計畫](../TEST_PLAN.md)

## 技術與目錄

工具鏈：Flutter **3.47.5**、Dart **3.13.4**、Python **3.13.18**；Windows x64建置需Windows主機及Visual Studio Desktop C++工作負載／合法app-local CRT，Android需SDK與JDK17。一般使用者只下載Release，不需開發工具。

| 目錄 | 用途 |
|---|---|
| `app/lib/`、`app/test/`、`app/integration_test/` | Flutter App、單元／widget與裝置整合測試 |
| `tools/data_builder/` | Python離線ETL、驗證與GUI |
| `docs/source_profiles/` | 21個原檔hash鎖定設定 |
| `schemas/`、`app/assets/schema_contract.json` | 共用資料契約 |
| `samples/` | 明示SAMPLE的合成包，非官方字典 |
| `scripts/`、`.github/workflows/` | 建置、打包、裝置驗證與CI |
| `evidence/` | 實際測試與來源稽核證據 |

App不嵌入Python或正式分類資料。`pubspec.lock`、`requirements.lock`／`requirements-windows.lock`鎖定依賴；`.local-source/`、本機官方來源、`官方資料/`、`dist/`及`manual-test-*/`不進版控。不要上傳使用者資料或完整官方資料包。

## 安裝依賴與測試

Windows PowerShell（repo根目錄）：

```powershell
py -3.13 -m venv .venv313
.\.venv313\Scripts\python -m pip install --require-hashes -r tools/data_builder/requirements-windows.lock
.\.venv313\Scripts\python -m pytest tools/data_builder/tests -q
Set-Location app
flutter pub get --enforce-lockfile
flutter analyze
flutter test --reporter expanded
```

Linux：

```bash
python3.13 -m venv .venv313
.venv313/bin/python -m pip install --require-hashes -r tools/data_builder/requirements.lock
.venv313/bin/python -m pytest tools/data_builder/tests -q
cd app
flutter pub get --enforce-lockfile
flutter analyze
flutter test --reporter expanded
```

本機Flutter3.47.5 analyzer曾在中文路徑出現LSP JSON截斷；可保留來源目錄並使用ASCII建置副本：

```bash
# repo根目錄
bash scripts/prepare_ascii_build.sh /tmp/icd-work-build
cd /tmp/icd-work-build/app
flutter pub get --enforce-lockfile
flutter analyze
flutter test --reporter expanded
```

不要在同一build directory同時執行test／pub／build；變更原始碼後重新同步副本。完整官方資料未提供時，選配測試會略過，不得將其列為通過。

## 資料製作CLI

一般Windows使用者可用Release附的獨立製作工具；從原始碼執行時用上述venv：

```powershell
.\.venv313\Scripts\python -m tools.data_builder catalog --source-dir 'D:\official-files'
.\.venv313\Scripts\python -m tools.data_builder build --source-dir 'D:\official-files' --profile docs\source_profiles\cm-fy2025-apr.json --output 'D:\fy2025-apr-new.icdpack'
.\.venv313\Scripts\python -m tools.data_builder verify --package 'D:\fy2025-apr-new.icdpack'
```

輸出檔不可已存在；不要改寫既有資料包。profile需明確記錄來源、版別、生效批次、相對檔名與hash。`validate-source`只做原檔安全檢查，不代替build／verify／source audit。自訂模板及歷史adapter說明見[來源紀錄](../SOURCE_PROVENANCE.md)與[0.2.3](RELEASE_0.2.3.md)。

## App建置

Windows PowerShell：

```powershell
# Windows主機、repo根目錄
.\scripts\build_windows.ps1
# 不能自動找到Visual Studio redist時，明確提供合法來源：
# .\scripts\build_windows.ps1 -VCRuntimeDir 'C:\licensed-redist\Microsoft.VC143.CRT'
.\scripts\build_android.ps1
```

Linux的Android建置（先設定Flutter／SDK PATH及JDK17）：

```bash
# repo根目錄，使用已同步的ASCII副本；同版dist輸出已存在時腳本會停止
bash scripts/build_android.sh /tmp/icd-work-build/app
```

成品：`dist/icd-offline-0.2.4-windows-x64.zip`／`dist/icd-offline-0.2.4-android-arm64.apk`及SHA256側檔。Windows ZIP必須包含EXE、DLL與data完整目錄；不能只發布EXE。Android目前沿用開發簽章及正式application ID，不在此次文件整理中換簽，以免破壞既有覆蓋升級；自行重建的簽章可能不同，不應直接覆蓋別人的安裝。

## 0.2.4完整資料／裝置驗證

公開程式碼只含合成測試資料。需要完整FY2025額外測試時，手動提供本機原包與新證據輸出路徑：

```bash
# ASCII副本的app目錄
flutter test test/guided_official_test.dart \
  --dart-define=GUIDED_OFFICIAL_PACK=/absolute/path/fy2025-apr.icdpack \
  --dart-define=GUIDED_OFFICIAL_EVIDENCE=/absolute/path/new-report.json
```

該測試核對449節點、五頁與九組快照，另外量測100次暖查詢首頁p95；不是UI繪製或全部裝置的效能驗收。

Android整合驗證先核對debug APK實際ID為 `tw.offline.icd.icd_dictionary.debug`，使用獨立debug套件及 `--no-uninstall`，不得開啟／清除正式App資料。0.2.4 runner把同一官方原包與Linux預期快照傳入debug套件，測後保留本機證據：

```bash
# ASCII副本app內，序列執行
flutter build apk --debug --target integration_test/guided_search_test.dart
# repo根目錄；expected為前段Linux完整報告
python scripts/run_android_guided_search.py \
  --device DEVICE --build-dir /tmp/icd-work-build/app \
  --pack /absolute/path/fy2025-apr.icdpack --expected /absolute/path/new-report.json
```

## CI與發版

- `Windows portable build`：main的App等路徑變更／手動觸發；analyze、native tests、CRT封裝、EXE啟動及使用者SQLite檢查。
- `Offline database builder for Windows`：工具相關路徑變更／手動觸發；固定Python runtime與wheel hash、58項測試、實際Tk視窗建構、工具ZIP。
- `offline-dictionary-tests`：PR／手動觸發，Linux／Windows矩陣。
- CI只使用合成包，完整官方資料不傳至GitHub；artifacts保留30天，正式下載用Release。
- 現有workflow沒有tag自動發版。發版前檢查同名tag／Release，草稿上傳後核對資產集合、大小與SHA256，再發布，不能覆蓋既有tag或靜默替換資產。

已實際執行的命令、提交與限制見[0.2.4測試報告](RELEASE_0.2.4.md)；沒有執行的實體裝置／斷網／磁碟滿驗收不得假設通過。
