# ICD-10-CM / PCS Offline Dictionary · 0.2.3

已實作 Flutter/Dart 離線 App、Python 3.13 builder/validator、標準 `.icdpack` 與自動化測試。經使用者回報疾病分類人員初步確認資料內容可用，0.2.3移除程式名稱Demo；未測Gate及來源資料範圍仍明確列示。

App、資料包、`user.sqlite` 物理分離；App 不含字典、Python runtime、雲端 API 或自動下載。相同原包直接匯入，不重封、不按平台轉換。

## 交付與驗收

* **0.2.3：新增FY2023～FY2025與健保署2014來源設定（共21種），App／製作工具同步升版，程式名稱移除Demo。** [操作與驗收](docs/RELEASE_0.2.3.md)；成品與本機資料包在`manual-test-0.2.3/`。

* **0.2.2：依分類人員回饋調整缺譯提示、notes浮動視窗及各尺寸導覽。** [操作與驗收](docs/RELEASE_0.2.2.md)，資料格式與既有包不變。
* **0.2.1：新增健保署CM同版中英獨立包，修正分類樹／Index展開的isolate閉包錯誤。** [操作與驗收](docs/RELEASE_0.2.1.md)，新版成品與NHI CM包在 `manual-test-0.2.1/`；舊附加中譯包不變。

* **0.2.0：修正Android大型NHI包匯入OOM，新增PCS獨立查詢／七軸／健保署2023同版中文搜尋。** [操作與驗收](docs/RELEASE_0.2.0.md)，成品放 `manual-test-0.2.0/`；舊CM包不用重製，PCS新包需新版App。

* 原始碼私有備份：[maria0010101/ICD-10-CM-Tool](https://github.com/maria0010101/ICD-10-CM-Tool)。不包含官方完整資料、使用者資料、venv 或 SDK。
* 本機手動測試交付目錄：`manual-test-0.1.1/`；內有新版圖示 APK、Windows App ZIP、Windows 獨立資料庫工具 ZIP、合成 samples、SHA256 與繁體中文操作說明（產物不混入 Git 原始碼）。
* [0.1.1 發行與 Windows CI 證據](docs/RELEASE_0.1.1.md)／[0.1.0 歷史 Gate 報告](docs/ACCEPTANCE.md)／[原始證據](evidence/)
* [架構與工具鏈](docs/ARCHITECTURE.md)／[需求追蹤](docs/TRACEABILITY.md)
* [已知限制](docs/KNOWN_LIMITATIONS.md)／[來源與版本](SOURCE_PROVENANCE.md)／[授權](LICENSES.md)
* Android APK：`dist/icd-offline-0.1.0-android-arm64-demo.apk`（以驗收報告與 SHA256 清單確認是否實際產生）
* 完整原始碼 ZIP：`dist/icd-offline-0.1.0-source-demo.zip`（不含官方完整資料、SDK、venv）；雜湊在 `dist/SHA256SUMS.txt`。
* Android 補驗：一次重試安裝成功，`.debug` 整合測試1/1通過；sample／正式英文兩包各50查詢與Linux一致。補驗後原始碼：`dist/icd-offline-0.1.0-source-android-verified.zip`。Release實機及Windows Gate仍未通過。
* Windows 由 GitHub Actions 的 Windows x64／Visual Studio 建置；結果、執行環境與限制見 0.1.1 報告。Hosted runner 不等同乾淨工作站驗收。

原本的開發規格 README 已原封保存為 [README.spec-original.md](README.spec-original.md)；規範文件 AGENTS/SRS/DATA_PACKAGE_SPEC/TEST_PLAN 保留。

## 可執行功能

* 完整碼正規化（有無小數點、大小寫、全形）、英文 FTS5 AND/OR／前綴、中文 NFKC unigram/bigram 索引。
* Chapter→Block→Category→Subcategory 懶載入；Index 主詞／子詞、see/seeAlso/subcat/manif/seecat、Neoplasm／Drugs 表格欄位與 External Cause Index。
* 本碼與上層 notes 按來源／順序呈現，保留原文、原始 XML、7th character 與 placeholder；不從 leaf 推論 billable。
* 手機單欄列表→詳情頁、平板雙欄、寬桌面三欄／可拖動欄寬；明暗模式、文字放大、Ctrl+L/F、方向鍵、Enter、Esc。
* 手動檔案選取→安全 ZIP→staging→SHA256→schema allowlist→SQLite integrity／FK／FTS／n-gram→預覽→原子發布→啟用，保留多版本與上一版。
* 收藏／本機註解／可關閉搜尋紀錄、個人 JSON 匯出匯入；與官方資料完全分開。
* 版間新增、移除、描述、狀態與 notes 差異；官方拆分／合併 lineage **尚未完成**，不作語義等價保證。

## 一、安裝開發依賴

已驗證工具鏈：Flutter **3.47.5**、Dart **3.13.4**、Python **3.13.18**。直接及間接依賴鎖在 `app/pubspec.lock`、`tools/data_builder/requirements.lock`。

Windows PowerShell（先自行安裝 Python 3.13／Flutter；建 Windows 另需 Visual Studio C++ workload）：

```powershell
py -3.13 -m venv .venv313
.\.venv313\Scripts\python -m pip install --require-hashes -r tools/data_builder/requirements-windows.lock
.\.venv313\Scripts\python -m pytest tools/data_builder/tests -q
cd app
flutter pub get --enforce-lockfile
flutter analyze
flutter test
```

Linux：

```bash
python3.13 -m venv .venv313
.venv313/bin/python -m pip install --require-hashes -r tools/data_builder/requirements.lock
.venv313/bin/python -m pytest tools/data_builder/tests -q
cd app && flutter pub get --enforce-lockfile && flutter analyze && flutter test
```

**本機 Flutter 3.47.5 的 analyzer 在中文路徑出現 LSP JSON 截斷**，已保留初始失敗 log；可使用 ASCII 暫存副本（不改 SDK）：

```bash
scripts/prepare_ascii_build.sh /tmp/icd-work-build
cd /tmp/icd-work-build/app
flutter analyze
flutter test
```

不要同時在同一 build directory 執行 Flutter test/pub/build，避免 generated plugin registrant 競爭。原始碼修改後重新同步；產物與 evidence 複製回原專案。

## 二、直接執行 App／匯入 sample

```bash
cd app
flutter run -d windows  # 在 Windows 主機
flutter run -d <android-device-id>
```

第一次啟動沒有字典，點「匯入 .icdpack」，從 `samples/` 選 `sample-demo-v1.icdpack`。它是 **SAMPLE / NOT FOR CLINICAL CODING** 合成資料，不自稱官方字典。v2 用於版本差異／回復，overlay 用於未確認中譯測試。

App 的正式 Android package ID 為 `tw.offline.icd.icd_dictionary`，debug／integration 為 `.debug`，不共用正式資料；最低 API 24、ARM64。不要以解除安裝／清資料解決測試安裝問題。

* Android：app-private support directory，無公共儲存權限要求。
* Windows：EXE 旁 `portable-data/`；必須先解壓到可寫目錄，不能直接在 ZIP 中執行。
* `.icdpack` 原檔以 archive SHA256 定址保留，唯讀 `content.sqlite`；只有 `user.sqlite` 可寫。

## 三、資料製作（Python 僅在 builder 執行）

**目前 Builder 0.2.1 共11種設定：新增可單獨啟用的NHI CM同版中英App包，保留既有CM／PCS與來源資料表設定。** 請使用 `manual-test-0.2.1/` 工具；PCS App包必須搭配App0.2.0以上，不可使用舊來源表SQLite改副檔名。詳細步驟見[0.2.1說明](docs/RELEASE_0.2.1.md)，PCS來源細節見[0.2.0說明](docs/RELEASE_0.2.0.md)。

**歷史 Builder 0.1.2 新增本批官方原檔的 7 種來源設定、ODS 直接串流匯入，以及獨立 PCS／健保署全分頁 SQLite。** 詳見 [官方轉檔操作說明](docs/OFFICIAL_IMPORT_0.1.2.md)／[實測報告](docs/OFFICIAL_IMPORT_0.1.2_RESULTS.md)。新工具與實際資料在 `manual-test-0.1.2/`；舊 App 0.1.1 與舊產物保留，無需重建 APK。

Windows 無開發環境時，解壓獨立工具 ZIP，雙擊 `ICD-Data-Builder.cmd` 開啟繁體中文 GUI；附私有 Python 3.13.18／Tk／鎖定依賴，不需系統 Python、pip 或網路。`SELF-TEST.cmd` 執行隨附測試；命令列可使用 `ICD-Data-Builder.cmd verify --package path.icdpack`。工具與 App 完全分開，App ZIP／APK 不含 Python。

```powershell
# 如 samples 既有輸出同名，請選新檔名；builder 不覆寫發行檔。
python -m tools.data_builder sample --output sample-demo-new.icdpack
python -m tools.data_builder verify --package samples/sample-demo-v1.icdpack
python -m tools.data_builder validate-source --input official-files/cdc-2027.zip
python -m tools.data_builder build --source-dir official-files --profile docs/cdc-profile.example.json --output fy2027-new.icdpack
```

`validate-source` 檢查 archive／原檔 hash／XML DTD，完整語義與列數驗證由 `build`／`verify`／`audit` 執行。CLI 遇錯 exit 1，輸出具體原因。輸出含 manifest、標準 SQLite、checksums；檔頭固定，可重現（相同原檔、profile、builder、SQLite 版本）。

### CDC/CMS 官方英文

從 [CDC 官方 FY2027 下載目錄](https://ftp.cdc.gov/pub/Health_Statistics/NCHS/Publications/ICD10CM/2027/) 取得 `icd10cm-table-and-index-2027.zip` 與 `icd10cm-code-descriptions-2027.zip`，另存為 profile 指定的兩個本機名稱，或修改 inputs。CMS 的 ICD-10-PCS 不是本 App 的 CM 資料來源。

Adapter 解析 Tabular XML、四種 Index/Table XML、order TXT，補足官方 order 中的七字元完整碼；完整 order snapshot 不再重複套用 addenda。未知 XML tag、錯年度、缺少必要檔案會阻擋；未載入的輔助檔雜湊會記錄在報告，不宣稱其已套用。

```powershell
python -m tools.data_builder.audit --package fy2027-new.icdpack --input official-files/cdc-2027.zip --input official-files/cdc-descriptions-2027.zip
```

實際 FY2027 原檔 hash、計數、描述差異及 notes 稽核在 `evidence/cdc-*.json`。完整下載／轉換包保留 `.local-source/`，未包含在 APK 或程式交付 ZIP。

### 台灣健保署官方中譯

[健保署政府開放資料集（2023 中文 CM／PCS）](https://data.gov.tw/dataset/177507)；依需求選 CM overlay 或新版 PCS 同版雙語 App profile，記錄實際修訂批次、URL、SHA256。也可從健保署官網取得 XLSX。

1. 複製 `docs/nhi-profile.example.json`，填實際 header／sheet、版別及修訂日期；CSV 必須 UTF-8，XLSX 公式拒絕。ODS 已支援串流讀取，須明確指定 `ICD-10-CM` 分頁；本批可直接選內建來源設定。
2. `inputs` 列出原檔，`translation.columns` 明確指定 code／title_zh_tw 欄位。所有來源欄位原值保留於 translation.notes JSON，以供追溯。
3. `mapping_policy` 預設 `unresolved`，不進入合格中譯搜尋。不得只因同一 code 就改為 exact_edition。
4. 有明確驗證／審核紀錄才指定 `exact_edition` 或 `reviewed_cross_release`，以及唯一 base package ID；跨版始終顯示警示。
5. 使用相同 `build --profile` CLI 製作 overlay；在 App 匯入並選定適用英文版。不同 base 切換時自動解除不相容 overlay，不刪檔。

本機已以官方 2023 CSV 實際測試 parser，但對 FY2027 的 mapping 仍未確認。`effective_to=9999-12-31` 是未宣告期限的本機契約值，**不是官方保證有效至該年**。不提供假造的官方中譯相容性。

## 四、安全、測試與打包

* ZIP 僅三檔、≤256 MiB、總展開≤512 MiB、比例≤200；拒絕重複／路徑穿越／symlink／加密／未知格式，streaming 限制實際解壓大小與 CRC。
* XML 禁止 DTD／外部實體／網路；XLSX 不執行公式。SQLite 唯讀、trusted_schema=OFF、schema allowlist，FTS write-command 僅在驗證副本執行。
* SHA256 是完整性而非官方簽章。來源仍需獨立核對。
* 匯入先查可用空間，切換用 SQLite FULL synchronous transaction；任何驗證／複製失敗不更動現行指標。

```powershell
powershell -File scripts/test.ps1
powershell -File scripts/build_android.ps1
powershell -File scripts/build_windows.ps1 -VCRuntimeDir 'C:\licensed-redist\Microsoft.VC143.CRT'
Get-FileHash -Algorithm SHA256 samples/sample-demo-v1.icdpack
```

Windows 腳本可由 Visual Studio 安裝目錄自動尋找合法的 app-local Microsoft CRT，也可明確指定路徑；不拷貝系統 DLL。完整 Release bundle（exe、SQLite／Flutter DLL、data）才可打 portable ZIP。必須再於乾淨 Windows 工作站實際啟動。

可在 GitHub Actions 選 `Windows portable build`／`Offline database builder for Windows` 執行 `workflow_dispatch` 重建；Flutter 及 Python runtime 版本固定，Python archive 與依賴皆核對 SHA256。Actions artifacts 保留 30 天；本機交付資料夾另保存下載副本。

Android build 預設 demo debug signing，不是正式發布憑證。正式發布前另配置簽署、通過飛航模式及實機 Gate，不能把「Built APK」當作「實機成功」。

實機 integration 指令與 define 檔產生方式見 `scripts/prepare_device_test.py`。使用 `.debug`，加 `--no-uninstall`；若手機拒絕安裝，停止並處理正常系統授權，不重試清資料。

### 一次安裝＋自動同包比對（已實際通過）

先準備ASCII build copy、Linux官方probe與integration defines，再於使用者正常允許安裝時執行：

```bash
python3 scripts/run_android_integration.py --device <device-id> --build-dir /tmp/icd-work-build/app --official .local-source/cdc-fy2027.icdpack
```

runner只呼叫一次Flutter安裝流程，不解除安裝／清資料／改設定；debug程式啟動後，透過自身UID傳入原包並再次比對SHA。成功後保存device report及完整query snapshot。原始`android-integration.log`是首次被拒的歷史紀錄；此次成功證據在`android-integration-retry.log`。

封裝新的原始碼／證據ZIP（已有輸出不覆寫）：

```bash
python3 scripts/package_source.py --output dist/icd-offline-0.1.0-source-new-run.zip
```
