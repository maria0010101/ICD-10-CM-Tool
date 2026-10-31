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

完成後補記；未執行項目不算通過。正式Android App不由整合測試安裝、清資料或解除安裝。正式簽章延續前版；仍為前版開發簽章，未宣稱商店簽署。
