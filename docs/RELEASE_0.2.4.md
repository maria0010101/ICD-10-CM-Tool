# 0.2.4：Index導引搜尋與完整分頁

依使用者對smarticd10搜尋結果的回饋實作；[完整分析](SEARCH_SMARTICD10_ANALYSIS.md)說明觀察方法、相同範例與刻意保留的差異。

- 英文CM有Index時預設索引導引：依詞首AND／OR比對、原始階層與來源順序，不以Tabular或BM25擠掉Index。
- 即時主詞建議、點選展開分支；目標碼可到Tabular核對。
- 結果顯示已載入／總節點數，每100筆可繼續載入，449筆範例不截斷。
- 保留「全文相關度」切換；精確碼、中文、NHI無Index資料及PCS維持原語義。數字1／2不忽略，不複製網站該項觀察行為。
- 不改資料包格式、不重製或改寫使用者官方包、不新增網路依賴；收藏與個人註解不變。轉檔工具0.2.3可繼續使用，不需更新。

## 可重現

```sh
.venv313/bin/python -m pytest tools/data_builder/tests -q
# 僅需要重新建立合成fixture時，使用新檔名，不能覆寫既有包：
.venv313/bin/python scripts/make_guided_fixture.py --output NEW-SAMPLE.icdpack
bash scripts/prepare_ascii_build.sh /tmp/icd-build-024
cd /tmp/icd-build-024/app
flutter pub get --enforce-lockfile
flutter analyze
flutter test --reporter expanded
# 本機完整資料額外測試：
flutter test test/guided_official_test.dart --dart-define=GUIDED_OFFICIAL_PACK=ABSOLUTE_PACK_PATH --dart-define=GUIDED_OFFICIAL_EVIDENCE=NEW_REPORT_PATH
# Android隔離測試先建置、核對實際.debug id，再由host傳原包及預期結果：
flutter build apk --debug --target integration_test/guided_search_test.dart
# 回repo根目錄
python scripts/run_android_guided_search.py --device DEVICE --build-dir /tmp/icd-build-024/app --pack OFFICIAL_PACK --expected LINUX_REPORT
bash scripts/build_android.sh /tmp/icd-build-024/app
```

Windows：`./scripts/build_windows.ps1`原生analyze／test／build／CRT ZIP，沿用私有Actions。完整官方包與網站原始頁面不放CI。

## 實際結果

測試日期：2026-10-31。正式程式碼提交：`8713b9125a6a0888509ef0f961389bc92c814842`；最後驗收提交另含整合測試事件等待修正與本報告，不改正式程式碼。

| 項目 | 實際結果與範圍 |
|---|---|
| Python 3.13.18 | 58項通過；既有builder 0.2.3不需更換 |
| Linux Flutter | 35項通過、2項完整資料選配測試略過；final analyze無問題；代碼前綴修正後另跑3項通過 |
| 完整FY2025額外測試 | 1項通過：449節點、五頁不重不漏、九組查詢；範例全部449個位置的階層深度與目標碼對照一致 |
| 資料層效能 | Linux本機暖查詢100次，首頁p95 **8.041ms**；不是UI繪製時間，也不代表所有裝置或全部資料版本 |
| Android實機隔離測試 | 1項通過；同一原包SHA256，九組完整查詢快照與Linux相同；實際畫面100／449，按載入更多後200個唯一節點；已檢視截圖 |
| Windows原生CI | [私有Actions 41190945188](https://github.com/maria0010101/ICD-10-CM-Tool/actions/runs/41190945188)：Python58項通過，Flutter35項通過、2項略過，analyze無問題；release build／app-local CRT／EXE啟動均成功；合成包所有查詢快照與Linux一致，不將完整官方包上傳 |
| 原資料保留 | `官方資料/`內14個原始包SHA256全部不變；手機正式App版本與安裝時間不變，測試只操作獨立`.debug`套件 |

手機整合測試首輪在送出搜尋事件時等待未完成；已修正測試腳本，使觸發事件與原生Future均在runAsync內執行，重跑通過。先前失敗／中止紀錄保留，不計入通過。Widget回歸也涵蓋390／800／1440寬度與1.6倍文字。

Android交付版為`0.2.4 / versionCode 2007 / arm64`，名稱`ICD Offline`、無INTERNET權限，簽章與0.2.3相同。正式Android App不由整合測試安裝、清資料或解除安裝。正式簽章延續前版；仍為前版開發簽章，未宣稱商店簽署。

兩個正式成品SHA256已核對通過：Android 21,808,048 bytes；Windows 15,230,843 bytes。Windows ZIP CRC、AMD64 EXE、名稱／版本／圖示、必要CRT及SQLite DLL均已核對，封裝不含官方或使用者資料庫。手機下載目錄只放新APK與說明，不自動安裝。

## 明確限制

- 網站後端為未取得的PHP程式；本版依公開介面、JS及實際請求推論規則，不聲稱重製完整後端。
- 已對照的Diabetes範例449個深度／目標碼位置一致，不代表所有年度與任意查詢完全一致；保留type 1／2數字，以及官方Note節點，差異詳見分析。
- Windows CI是GitHub hosted Windows環境，不等同乾淨工作站；完整官方FY2025的449節點實測在Linux與Android，Windows跨平台比對使用合成包。
- 實體平板、乾淨Windows人工驗收、所有年度的完整效能／飛航模式／低磁碟空間回歸未於本次重新執行，不算通過。
- 不隨本次成品再附完整官方資料；既有資料包／收藏／個人註解不需重新匯入。

測試證據保存在`evidence/search-review-20261031/`；`local-*`完整資料快照與裝置截圖只保存在本機。成品SHA256、體積與封裝檢查另列交付目錄的`artifact-manifest.json`及`SHA256SUMS.txt`。
