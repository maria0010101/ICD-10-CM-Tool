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
# 手機隔離ID，PACK1只含合成sample：
flutter test -d DEVICE integration_test/review_ui_test.dart --no-uninstall --dart-define-from-file=DEFINES
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

手機測試的notes截圖握手由host收到`ICD022_NOTES_VISIBLE`後擷取，於隔離ID的support目錄建立`review022-captured`再繼續；操作記錄在`evidence/release-0.2.2/`。正式App與資料不由整合測試更新、清除或解除安裝。

Windows PowerShell：`./scripts/build_windows.ps1`（原生analyze/test/build及完整app-local CRT ZIP）；Android：`./scripts/build_android.ps1`。兩者由pubspec版本產生新檔名，不覆寫舊交付物。

## 證據與限制

- Linux Flutter3.47.5／Dart3.13.4；Python3.13.18。Windows透過既有私有GitHub Actions原生建置，不從Linux宣稱Windows已建置。
- 初次新增介面測試因platform override晚於framework invariant才回復而失敗；已在finally回復後重跑，未略過斷言。
- 本版未改資料或要求重做全部正式資料稽核／效能Gate。Windows乾淨工作站、平板實機、正式App Release人工驗收與樣本／hosted測試分列，不假設通過。
- 實際完成結果及產物雜湊於建置後補記。
