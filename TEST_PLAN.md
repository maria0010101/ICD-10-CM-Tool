# TEST_PLAN.md — 測試與驗收計畫

## 1. 執行規則

使用 Python pytest + Flutter test/integration_test；Windows x64 真機與 Android ARM64 實機（手機及平板），沒有裝置就標為未測，不得聲稱通過。每項測試輸出 build revision、OS、裝置、資料包 SHA256、source edition、測試時間與結果。

## 2. 測試矩陣

| ID | 類別 | 測試案例 | 預期 |
|---|---|---|---|
| T01 | 跨平台 | 同一 `.icdpack` 複製到 Windows/Android | SHA256 一致、可匯入、50 個 queries 結果一致 |
| T02 | 資料完整 | Code count, hierarchy, notes, Index 與官方原檔核對 | 無遺漏/差異有解釋 |
| T03 | 代碼 | `I50.9`、`I509`、混合大小寫/空白 | 正規化後相同正確結果 |
| T04 | 英文查詢 | `heart failure`、詞序變化、前綴 | 相關結果、排序穩定 |
| T05 | 中文查詢 | `心臟衰竭`、`腎衰竭` | 正確版本的中文結果與來源 |
| T06 | Index | 多層 subterm、See、See also | 顯示正確跳轉，保留完整 term path |
| T07 | Notes | 本碼及祖先 Excludes1/2, code first 等 | 保留來源、順序，不遺漏 |
| T08 | 版本 | 相同 code 描述改變、停用、細分 | 依版本顯示差異、警示 |
| T09 | 中文 overlay | 無相容中文版、跨版相同 code | 不誤標同版官方中譯 |
| T10 | 匯入安全 | ZIP Slip、ZIP bomb、重複 entry、損壞 DB | 拒絕，不破壞既有資料 |
| T11 | XML 安全 | DTD、XXE、外部 URL | 禁止外部實體解析及連線 |
| T12 | 交易安全 | 匯入到一半關閉、磁碟不足 | 既有資料仍可查、可回復 |
| T13 | 離線 | Android 飛航模式/Windows 阻斷網路 | 所有核心功能可用、無網路請求 |
| T14 | UX | 手機單欄、平板雙欄、Windows 三欄 | 操作完整且無文字截斷 |
| T15 | 鍵盤/無障礙 | 鍵盤焦點、enter、文字放大 | 可用且無阻塞 |
| T16 | 個人資料隔離 | 更新/卸載官方版本 | 收藏/註解不被覆寫 |
| T17 | 效能 | 正式版 cold/warm query ≥1000 次 | 報告 p50/p95/p99 及裝置硬體 |
| T18 | 體積 | Windows ZIP、Android ARM64 APK、包大小 | 量測並與 SRS 目標比較 |
| T19 | Windows | 乾淨 Windows 未安裝 Python/Flutter | 解壓能執行；含必要 VC runtime |
| T20 | SQLite | 兩端 SQLite FTS5/n-gram 支援 | 相同 token/搜尋 semantics |
| T21 | CSV/XLSX | 變更欄名、重複碼、公式儲存格 | 明確預覽/警示/阻擋錯誤 |
| T22 | Schema | 資料包需較新版 App schema | 安全拒絕並提示，不動現有資料 |

## 3. 最小自動化與證據

- `python -m pytest tools/data_builder/tests -q`
- `flutter analyze`
- `flutter test`
- `flutter test integration_test`（依平台配置）
- Windows `flutter build windows --release`，將所需 DLL/data 打成 portable ZIP。
- Android `flutter build apk --release --split-per-abi`；交付 ARM64 APK，需實際確認 apk 檔名。
- `sha256sum` / PowerShell `Get-FileHash` 驗證包；Android 透過 App 展示匯入 SHA256 並保留 log。
- 匯入前後 SQLite integrity_check 與 row count dump。
- 所有官方資料測試只可對實際取得且記錄哈希的官方文件聲稱完整。

## 4. 發布停止條件

若有跨平台不同結果、版本錯置、Excludes/Code First 遺漏、匯入失敗覆寫正式資料、非離線網路行為、官方中文錯誤標籤，皆不可標記可供正式編碼用途。無正式資料時，發行物只能標為 demo。

## 0.2.0新增回歸

- T23：以原始70MiB級NHI包驗證Android native64KiB串流、原包SHA不變、完整驗證與舊資料保留；SAF UI與私有file URI的native實作測試分列。
- T24：PCS精確碼／FTS／Index明確目標／七軸同row與分類切換；同年度與不同年度分開，heading不可當完整碼。
- T25：健保署2023 PCS同一原始列的中英文可搜尋，但不冒稱FY2027中譯；原CM unresolved overlay政策不變。

## 0.2.1新增回歸

- T26：NHI CM獨立combined包在沒有英文包時可啟用，精確碼／英文FTS／中文n-gram結果及來源正確，USE與前綴導覽逐值稽核；不接受US base相容宣告。原使用者overlay SHA不變，不改policy繞過限制。
- T27：真實SQLite與isolate的widget測試展開分類樹、Index主／子詞、窄桌面欄，無不可傳送Widget／Future例外；等待查詢Future結束後才關閉資料庫。Windows原生測試截圖與使用者實際EXE操作分列。

## 0.2.2 分類人員介面回歸

- T28：無中譯的CM／PCS搜尋與詳情不顯示缺譯字串或空中譯列；合格同版中譯、來源與跨版警示保留，既有包不變。
- T29：notes按鈕緊接個人註解，點選才顯示浮動視窗；各筆原文、順序、本碼／繼承來源可捲動閱讀及選取；關閉不改變詳情與個人資料。PCS仍標示非CM繼承規則。
- T30：390手機僅有搜尋／分類兩個底部導覽；800平板及1440／650寬Windows無底部列，搜尋、分類與右上資料管理往返可用。文字1.6倍無framework例外。
