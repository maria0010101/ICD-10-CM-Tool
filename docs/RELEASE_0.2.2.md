# 0.2.2：疾病分類人員驗收後介面調整

## 需求與實作追蹤

| 回饋 | 實作 | 驗證 |
|---|---|---|
| 無官方中英對照時不顯示缺譯列 | 搜尋結果及詳情只呈現存在的合格中譯 | `review_ui_test.dart` CM／NHI／PCS |
| notes不固定占用內容區 | 個人註解後方新增「本層與繼承notes」，開啟可捲動／選取的浮動視窗 | 原文、來源及PCS語義回歸；手機實機另測 |
| 移除重複資料入口 | 底列移除資料，右上資料管理保留 | 手機2項；管理進出往返 |
| 平板／Windows無底列 | 依原720／1180斷點；Windows窄視窗亦無底列 | Android390／800及Windows1440／650 |

資料格式、SQLite、Python轉檔工具及既有資料包均不變。缺譯文字原為App UI加入，非builder寫入的假資料列；不用重製或重新匯入。合格同版譯文、來源、mapping status與未確認跨版警示仍保留。

平板雙欄原本需靠底列切換搜尋與分類，現在將此切換移到左側內容區；三欄同時呈現兩者。Windows縮到單欄仍可從內容區切換。不保留重複的底部導覽列。

## 可重現命令

```sh
.venv313/bin/python -m pytest tools/data_builder/tests -q
bash scripts/prepare_ascii_build.sh /tmp/icd-build-022
cd /tmp/icd-build-022/app
flutter pub get --enforce-lockfile
flutter analyze
flutter test --reporter expanded
# 手機隔離ID，PACK1只含合成sample，先產生DEFINES並建置debug目標：
flutter build apk --debug --target integration_test/review_ui_test.dart --dart-define-from-file=DEFINES
# 回repo根目錄，由host核對實際APK ID、執行測試及截圖握手：
python3 scripts/run_android_review_ui.py --device DEVICE --build-dir /tmp/icd-build-022/app --defines DEFINES
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

手機測試的notes截圖握手由host收到`ICD022_NOTES_VISIBLE`後擷取，於隔離ID的support目錄建立`review022-captured`再繼續；操作記錄在`evidence/release-0.2.2/`。正式App與資料不由整合測試更新、清除或解除安裝。

Windows PowerShell：`./scripts/build_windows.ps1`（原生analyze/test/build及完整app-local CRT ZIP）；Android：`./scripts/build_android.ps1`。兩者由pubspec版本產生新檔名，不覆寫舊交付物。

## 證據與限制

- Linux Flutter3.47.5／Dart3.13.4；Python3.13.18。Windows透過既有私有GitHub Actions原生建置，不從Linux宣稱Windows已建置。
- 初次新增介面測試因platform override晚於framework invariant才回復而失敗；已在finally回復後重跑，未略過斷言。
- 本版未改資料或要求重做全部正式資料稽核／效能Gate。Windows乾淨工作站、平板實機、正式App Release人工驗收與樣本／hosted測試分列，不假設通過。
- 實際完成結果及產物雜湊於建置後補記。

### 已完成本機及手機結果

- Python46項通過；一則warning來自刻意建立的惡意重複ZIP項目fixture。Flutter28項通過／1項未在ASCII隔離目錄提供完整官方CM資料而略過；analyze無問題。
- 手機Android14／ARM64隔離ID整合測試1項通過，實際點擊搜尋結果→詳情→notes浮動視窗→關閉→返回→資料管理往返；S00.0合成碼確實沒有合格中譯，缺譯列省略，未確認跨版參考警示保留。
- 手機實際notes截圖為 `evidence/release-0.2.2/android-notes-dialog.png`，內容完全為SAMPLE；未用test engine截圖冒充EXE畫面。
- 初次手機測試的捲動helper未限定Scrollable而報Too many elements，改為詳情主捲動區後重測，不是忽略framework例外。
- 正式Android套件仍0.1.1／2002；測試未安裝或清除正式包，也沒有改裝置安全設定。
- 既有NHI CM獨立包SHA仍為 `544c441b27e8b126d6342da50405580098298613b9d7ba360883268008b1ab7a`；原附加中譯包SHA仍為 `d81e1127ae174692a7bcda7e27189675639d6520dfe4f19385de39584bea52f0`。
- Windows早期run41000225046由本次更新的相鄰按鈕排版run41000384050取代而取消，不計為通過。

### 最終建置與交付

Windows [Actions41000384050](https://github.com/maria0010101/ICD-10-CM-Tool/actions/runs/41000384050)／產品來源`71ce0cf`成功：Python46項、Flutter28項通過／1項完整官方資料略過、analyze0問題、EXE啟動與user.sqlite完整性通過。下載ZIP已核對遠端sidecar、CRC、AMD64、必要DLL及無內嵌官方／使用者資料；與Linux CM／NHI／PCS樣本snapshot逐值一致。

Release ARM64 APK0.2.2／2005已完成並驗證與前版相同簽章，無INTERNET權限或內嵌字典。APK與Windows ZIP均已放 `manual-test-0.2.2/`，SHA256SUMS全數核對通過，手機APK副本在 `Download/manual-test-0.2.2/`。詳細大小、雜湊及測試矩陣見該目錄artifact-manifest與驗收報告；正式App未由測試自動升級。
