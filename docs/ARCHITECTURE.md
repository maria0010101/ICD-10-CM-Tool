# A — 架構決策（2026-10-29）

初始目錄只有六份規格，git status 回報非 Git repository；原規格保留，README 原文另存 README.spec-original.md 後更新。

* Flutter 3.47.5 / Dart 3.13.4，Android API 24+ ARM64、Windows x64；Linux 僅作開發主機驗證，不替代 Windows Gate。
* sqlite3 3.8.0 native assets 隨 App 打包相同上游 SQLite/FTS5；sqlite3_flutter_libs 已 EOL，不再使用。評估 Drift 後選擇直接 sqlite3：唯讀固定 schema 與少量參數化 SQL，避免自動 migration 改寫官方資料。所有資料查詢及驗證在 isolate 執行。
* 狀態採 Flutter ChangeNotifier / StatefulWidget；不需要另一套產碼框架。UI/domain/data 分層，repository 可獨立測試。
* 不將字典打包為資產；只帶 schema 契約。三層：程式、唯讀 content.sqlite、獨立 user.sqlite。
* 標準 ZIP 僅三個檔案，固定 SQL v1；heading 使用獨立 node_key，不冒充 ICD code。billable 由官方 order file 明確提供，不能由葉節點推論。
* SHA256 保證完整性，不是發布者簽章；來源 URL/manifest 是可追溯宣告，不構成官方認證。正式來源由管理者核對並保留原檔 hash。
* 安裝目錄以整包 SHA256 定址。先驗證 staging，再 rename；user.sqlite 單一交易更新 active/previous 指標。中斷留下未引用目錄可保留，不會改寫舊資料；讀取者持有唯讀舊 handle。
* Windows 預設 exe 同目錄 portable-data，無寫入權限時清楚提示；Android app-private support directory。手動選檔，不讀公共資料夾、不啟動網路。
* 英文 FTS5 unicode61、每個使用者 token 引號化，AND/OR 與 prefix；中文 NFKC 後預建 unigram/bigram intersection 再 contains 驗證。搜尋用正規化字串，展示原文不改。
* 合成包只供測試。官方 XML/TXT/XLSX/CSV adapter 遇未知結構會阻擋，不靜默忽略；ODS 不支援並回報，避免假解析。

## 工具鏈限制

Linux 無 MSVC/Windows runner，Windows release 與乾淨 Windows 實測 blocked。Android SDK 36、API 37，連接 Android 14 ARM64 手機；尚無實體平板。Android license 警告需以實際 build 結果判斷。Python 3.13 使用專案隔離工具環境，不變更系統 Python。
