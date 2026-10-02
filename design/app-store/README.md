# App Store iPhone 截圖

2026-10-03 從 FutureMint AI `1.0.0 (1)`、程式版本 `55d030f` 的 iPhone 17 Pro Max／iOS 26.4 模擬器實際擷取。一般 `lib/main.dart` 入口，production 公開配置，使用 App 既有的合成訪客模式；沒有登入真實帳號、上傳私人資料或呼叫外部 AI。使用者於 2026-10-03 確認公開營運名稱為「FutureMint AI 團隊」。

## 素材與順序

`zh-Hant/iphone-6.9/` 保留 Simulator Save Screen 原始 PNG；`upload/` 是同尺寸、不含透明通道的 JPEG（sips quality 100），供 App Store Connect 繁體中文、iPhone 6.9 吋欄位使用。全部為 **1320 × 2868**，未縮放、裁切、加框或改寫介面。沒有 App 預覽影片。

| 順序 | 檔名 | 實際功能與資料來源 |
|---|---|---|
| 1 | `01-budget-overview` | 預算首頁；內建合成預算與收支 |
| 2 | `02-spending-analysis` | 收支趨勢及需要／想要分析 |
| 3 | `03-review-entry` | 「今天買珍奶 75」產生待確認草稿；畫面保留離線規則解析標示，沒有保存該筆草稿 |
| 4 | `04-subscription-tracking` | 在訪客記憶體採用既有影音付款為訂閱追蹤；98 元／月、下次 2026-11-01，沒有實際扣款 |
| 5 | `05-learning-roadmap` | 固定學習路線；保留離線規劃及教育用途文字 |
| 6 | `06-futureseed-scenarios` | 預設 4,200 元、每月 500 元、5 年合成情境；不是市場預測 |

## 驗證與上傳狀態

- 六張 JPEG 均確認尺寸、無 alpha；人工檢視沒有帳密、私人聯絡或真實交易資料，保留訪客提示。
- 對照 [Apple 截圖規格](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) 與 ASC 6.9 吋欄位列出的 1320 × 2868。
- 截圖完成不代表 signed build 或 TestFlight 驗收；這次是模擬器 debug 產物。最終送審 build 如有 UI 差異須重拍。
- 六張 JPEG 已透過 Chrome 原生選檔器上傳至 ASC 繁體中文 iPhone 6.9 吋欄位；重新載入後確認共六張，6.5 吋沿用 6.9 吋素材。未變更瀏覽器擴充功能的檔案存取權限。
- 原有紫色、黃色等角色依使用者 2026-10-03 確認為團隊使用 ChatGPT 生成；不是學生自繪或第三方下載。來源及 OpenAI 輸出權利條款見 [Design README](../README.md)。

建置產物的 `UIDeviceFamily=[1]`，沒有 native iPad target。這不等同排除 iPad 的 iPhone 相容模式；沒有加入虛假的硬體限制。Mac／Vision Pro 供應已於 ASC 關閉。
