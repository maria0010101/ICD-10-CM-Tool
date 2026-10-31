# ICD Offline 0.2.4

Windows／Android完全離線的ICD-10-CM／PCS字典。經疾病分類人員測試，使用者回報內容正確、功能可初步使用。本次發布既有已核對成品，沒有更換簽章、改寫官方資料包或清除使用者資料。

## 下載哪個檔案

| 資產 | 用途 |
|---|---|
| `icd-offline-0.2.4-windows-x64.zip` | Windows x64免安裝App，完整解壓後執行icd_dictionary.exe |
| `icd-offline-0.2.4-android-arm64.apk` | Android ARM64 App，最低Android7.0／API24；versionCode2007 |
| `icd-data-builder-0.2.3-windows-x64-portable.zip` | 相容的Windows離線資料包製作工具，21種來源設定，無需系統Python |
| `INSTALL_0.2.4.md` | 安裝、升級、首次匯入及資料製作入口 |
| `SHA256SUMS.txt` | 三個程式成品及安裝說明的SHA256檢查碼 |

**製作工具維持0.2.3，不是漏升版；App0.2.4可直接使用既有資料包，不用重新轉檔或重新匯入。** 自動附加的Source code不是安裝包。儲存庫維持私有，下載需具備存取權限。

## 主要更新

- 英文CM有官方Index時預設「索引導引」：主詞建議、完整來源路徑比對、祖先脈絡與原始階層排序。
- 每批100筆可繼續載入，顯示已載入／總節點數，不截斷449筆範例；不同修飾詞指向同碼仍分別保留。
- 精確碼與代碼前綴保留；可關閉索引導引回到全文相關度。中文、無Index的NHI包、PCS維持原語義。
- 整理GitHub首頁、使用／資料製作指南、開發指南及已知限制，移除首頁過時的demo下載與舊工具指示。

FY2025／2025-04-01輸入 `Diabetes, diabetic`，449個節點的階層深度與目標碼順序已逐筆對照一致。App保留type1／2數字與官方Note，不為完全模仿第三方顯示而改寫來源；不宣稱所有查詢與smarticd10完全相同。

## 升級與資料

- Windows：關閉舊App，備份整份portable-data；新版解壓到新目錄，再複製原資料目錄。不要只取EXE或丟棄DLL／data。
- Android：直接覆蓋安裝，**不要解除安裝或清除資料**。簽章與0.2.3相同，沿用目前開發簽章，未宣稱商店簽署。
- App不附完整官方字典、登入、雲端API或自動下載。已有.icdpack可直接匯入；沒有資料包時，使用工具從官方原檔製作。
- CM／PCS與英文字典／NHI中譯版別分開核對；NHI同版不等於美國同FY。來源SQLite不是App包。
- Release不包含完整官方資料、病歷、收藏或個人註解；工具samples只供測試。

## 已驗證與邊界

- Python58項通過；Linux／Windows Flutter各35項通過、2項完整資料選配測試略過。
- FY2025完整資料另測通過；Android實機隔離測試九組完整查詢與Linux一致，UI載入100→200筆通過。
- Windows原生建置／EXE啟動／獨立user.sqlite成功，合成查詢快照與Linux一致。
- Android／Windows成品SHA256、Windows ZIP CRC／AMD64／DLL已核對；builder沿用0.2.3已驗證成品。
- 實體平板、乾淨Windows工作站、全部年度完整跨端、飛航／真實磁碟滿／強制中斷等驗收尚未全部完成，不將其標為通過。

App成品正式程式碼來源：`8713b9125a6a0888509ef0f961389bc92c814842`；此次tag另含後續測試harness與文件／證據整理，沒有修改正式程式碼。Builder成品沿用0.2.3來源`b4dbff1`。本次不重新建置或改名冒充不同版本。

[使用指南](https://github.com/maria0010101/ICD-10-CM-Tool/blob/v0.2.4/docs/USER_GUIDE.md) · [搜尋分析](https://github.com/maria0010101/ICD-10-CM-Tool/blob/v0.2.4/docs/SEARCH_SMARTICD10_ANALYSIS.md) · [實測報告](https://github.com/maria0010101/ICD-10-CM-Tool/blob/v0.2.4/docs/RELEASE_0.2.4.md) · [已知限制](https://github.com/maria0010101/ICD-10-CM-Tool/blob/v0.2.4/docs/KNOWN_LIMITATIONS.md)
