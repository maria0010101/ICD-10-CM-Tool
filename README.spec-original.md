# ICD-10-CM Offline Dictionary

跨平台、完全離線的 ICD-10-CM 中英雙語查詢字典（開發規格 1.0）。**Flutter + Dart** 構建 Windows 可攜版與 Android 手機/平板；**SQLite FTS5** 即時查詢；**Python 3.13** 在 Windows 離線轉換 CDC/CMS 官方英文原始檔及衛福部/健保署中文資料。

> 目前此檔案集是 Agent AI **開發規格與指令**，不是已完成的 App；沒有附完整正式 ICD-10-CM 代碼資料或已建置 APK/EXE。

## 最重要的設計

- **程式與資料完全分離**：App 不含正式 ICD 字典；官方資料包 `.icdpack`、App 使用者收藏/註解分開儲存。
- **同一包跨平台**：`.icdpack` 是含 `manifest.json` + `content.sqlite` + SHA256 的 ZIP；不重新轉換即可在 Windows/Android 匯入，兩端結果一致。
- **可長期更新**：保留英文年度/發布版本；台灣中文中譯按其發行/修訂批次管理；不同版本不自動默認相容。
- **主搜尋＋分類樹**：即時英文/中文/代碼搜尋、Index→Tabular、完整 Code First/Excludes 等註記與來源、手機/平板/Windows 自適應。
- **不需網路**：安裝/啟用後資料查詢、版本切換、資料包匯入完全在裝置本機處理。

## 文件導覽

| 文件 | 用途 |
|---|---|
| `AGENTS.md` | 對 Agent AI 的執行流程、不可妥協限制與交付標準 |
| `SRS.md` | 完整功能性/非功能性需求、UI、資料更新與驗收要求 |
| `DATA_PACKAGE_SPEC.md` | Windows+Android 共同 SQLite 資料包格式、schema、版本及安全規範 |
| `TEST_PLAN.md` | 22 類測試與發布 Gate |
| `START_HERE.md` | 可直接貼到 Antigravity/Codex 的啟動提示 |

## 預期目錄（由 Agent 實作）

```text
icd10cm-offline-dictionary/
├── app/                       # Flutter application
│   ├── lib/                   # UI、domain、data 等
│   ├── test/
│   └── integration_test/
├── tools/data_builder/        # Python CDC/CMS/NHI parser、validator、package builder
├── schemas/                   # SQLite DDL + manifest JSON schema
├── samples/                   # 人工示例，非臨床
├── scripts/                   # Windows / Android 建置、測試、打包
├── AGENTS.md
├── SRS.md
├── DATA_PACKAGE_SPEC.md
├── TEST_PLAN.md
└── README.md
```

## 預計開發與建置方式（須由 Agent 在實作後驗證）

```powershell
flutter doctor -v
flutter pub get
flutter analyze
flutter test
flutter build windows --release
flutter build apk --release --split-per-abi
```

資料處理工具預期介面（**介面契約草案，尚未實作**）：

```powershell
python -m tools.data_builder validate-source --input <official-file> --profile cdc-fy2027
python -m tools.data_builder build --source-dir <official-files> --output <dataset.icdpack>
python -m tools.data_builder verify --package <dataset.icdpack>
```

Windows portable 必須把 `exe`、Flutter DLL、`data/` 與必要的 VC++ runtime 一併打包；Android 以 ARM64 APK 發布。執行環境不能建置時，提供可重現的步驟與阻礙清單，不能捏造可執行檔。

## 官方來源與資料處理

- 美國 CDC/NCHS: https://www.cdc.gov/nchs/icd/icd-10-cm/files.html
- CMS: https://www.cms.gov/medicare/coding-billing/icd-10-codes
- CDC FY2027: https://ftp.cdc.gov/pub/Health_Statistics/NCHS/Publications/ICD10CM/2027/
- 台灣：由衛福部／中央健康保險署官網取得**對應版別**之官方中文中英對照表，匯入時記錄來源網址、發布/修訂日期、原檔 checksum。不得以非官方翻譯冒充官方。

FY2027 美國版自 2026-10-01 生效；台灣使用的 ICD-10-CM 版別可能與美國不同，需依實際申報適用規定選擇。本 App 是**編碼字典**，不是對 Tw-DRG 申報正確性作保證的分組器。

## 搜尋與中譯提醒

1. 輸入 `I50.9` 或 `I509` 查精確碼。
2. 輸入 `heart failure` 或 `心臟衰竭` 搜尋相關項目。
3. 點選 Index 項目，轉往官方 Tabular 完成確認。
4. 檢查上層/本層 notes、版本與中文翻譯相容性；不可用搜尋排名代替醫學與編碼判斷。

## 發布注意事項

官方分類資料的使用/重散布條款需個別檢查，並保留 `SOURCE_PROVENANCE.md`；第三方文獻（例如 Coding Clinic）需明確授權。所有測試範例必須是合成/示意資料，禁止患者個資。
