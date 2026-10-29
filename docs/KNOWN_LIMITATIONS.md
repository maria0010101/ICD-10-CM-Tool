# 已知限制與發布停止條件

本版是 **0.1.0 開發／demo**，不是已通過所有 Gate 的臨床產品。

* Windows：Linux 主機沒有 MSVC，未產生或實測 Windows portable ZIP；原生專案與 PowerShell 打包腳本已提供。G1、G7 不可標為通過。
* Android：使用者允許後的一次重試安裝成功，`.debug` 整合測試1/1通過、Linux↔Android兩包各50查詢一致；未修改手機設定、未解除安裝或清資料。Release APK實機啟動仍未測。
* 實體平板、旋轉、TalkBack／Windows 螢幕閱讀器及乾淨 Windows 環境未測；widget viewport 測試不等同實體裝置測試。
* Release 預設沿用 Flutter 的本機 debug 簽章，僅供 demo 安裝。正式簽署金鑰未配置，不可作正式發布憑證。
* 已實際解析官方 NHI 2023 中文 CSV（96,802列），但與 FY2027 美國版尚無已驗證 lineage；CSV/XLSX 可保存為 `unresolved`，但不因此自動標成相容譯名。ODS 明確不支援，需先人工另存 CSV/XLSX，公式一律拒絕。
* 版本差異能比對新增／移除／描述／billable／本節點 notes；**尚未實作官方 conversion 檔的拆分／合併 lineage**，不能從代碼前綴推論。FR-034 為 partial。
* 官方英文來源計數及原文稽核已執行；這不是疾病分類師的獨立內容簽核。未確認官方資料完整再散布權限，不把完整資料放入發行物。
* p95 若是 synthetic／無中文內容的資料，不算正式中文效能 Gate；已測Linux與Android正式英文warm資料層，所有效能須分別看資料、硬體與build mode。
* 匯入資源上限：ZIP ≤256 MiB，展開總量 ≤512 MiB，每個 metadata ≤1 MiB，最多三檔、最大壓縮比例200、JSON深度64、分類深度100。需大包時應採新版契約，不能關閉檢查。
* staging/atomic rename/SQLite transaction 的錯誤注入測試已通過；真實斷電、系統強制殺程序與真正 ENOSPC 尚未在 Windows/Android 實測，不能稱 T12 全通過。
* 目前 SHA256 是完整性驗證，不是簽章；使用者仍需核對來源，勿把自述 source_organization 當官方認證。
* 收藏／個人註解僅在本機，按 package ID 隔離；搜尋紀錄可關閉。不同版本收藏不自動遷移；未提供雲端同步或個人資料上傳。
* 低階 FTS、索引檢查均在 isolate 執行，還未完成正式資料冷啟動與 UI frame-time 1000 次效能報告。搜尋結果最多100筆，顯式提示上限；Index 主詞每批100筆，子詞按展開載入。
