# 授權清單（開發版 0.1.1）

本次新增原始碼採 MIT（見 LICENSE）；原有規格文件維持原作者權利，不變更其授權。

| 元件 | 版本 | 授權 / 注意 |
|---|---|---|
| Flutter / Dart | 3.47.5 / 3.13.4 | BSD-3-Clause；由 Flutter license registry 顯示完整 notices |
| sqlite3 Dart | 3.8.0 | MIT；native-assets 內含 SQLite，需一併交付 |
| SQLite | 以 native probe 為準 | SQLite public domain；不使用外掛 tokenizer |
| archive | 4.5.2 | MIT；僅使用 CRC32 工具，ZIP 驗證由 bounded reader 處理 |
| crypto | 3.0.8 | BSD-3-Clause |
| file_selector | 1.1.0 | BSD-3-Clause，平台實作版本見 pubspec.lock |
| path_provider | 2.1.6 | BSD-3-Clause |
| path | 1.9.1 | BSD-3-Clause |
| ffi | 2.2.0 | BSD-3-Clause |
| unorm_dart | 0.3.3 | MIT，Unicode 資料依上游附帶條款 |
| lxml | 6.0.4 | BSD-3-Clause；libxml2/libxslt 依其附帶條款 |
| openpyxl | 3.1.5 | MIT |
| jsonschema | 4.26.0 | MIT |
| pytest | 9.0.2 | MIT（僅開發） |
| flutter_launcher_icons | 0.14.4 | MIT，僅開發期圖示產生器 |
| image | 4.12.0 | MIT，僅開發期圖示處理 |
| CPython standalone | 3.13.18 / 20261026 | Python PSF 及 runtime 內附第三方授權；僅獨立資料庫工具，非 App 依賴 |
| Tcl/Tk | 依工具 runtime report | 保留 runtime 內附授權；僅資料庫 GUI |
| colorama | 0.4.6 | BSD-3-Clause，Windows工具測試依賴 |
| VC++ app-local CRT | Windows 建置時指定 | Microsoft redistributable license；不得任意複製系統 DLL |

完整直接／間接依賴版本與套件雜湊見 `app/pubspec.lock`、`tools/data_builder/requirements.lock`。
Flutter 內建 LicensePage 列示 bundle 中的 notices（資料頁「開放原始碼授權」）。

## 官方內容

程式 MIT 授權**不涵蓋** ICD-10-CM、WHO 分類、CDC/CMS 發布檔、健保署翻譯或第三方文獻。下載、使用與再散布須依對應發布者條款，尤其不得把 ICD-10-PCS 誤當 ICD-10-CM。未確認完整資料再散布權限前，官方原檔及本機轉換包僅保留在 `.local-source/`，不放入發行物。合成 samples 不是官方資料。
