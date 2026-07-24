# FutureMint AI Design System

本資料夾是 FutureMint Flutter Client 的非執行型設計支援資產，沒有 package manager、runtime 或獨立部署生命週期，因此不列入 Student Project Profile 的 executable components。

## 權威文件

- [MASTER.md](futuremint-ai/MASTER.md)：全域色彩、字體、間距、元件、響應式、動態、狀態與可及性規範。
- 若未來建立 `futuremint-ai/pages/<page>.md`，頁面 override 只覆蓋該頁明確列出的規則，其餘仍以 `MASTER.md` 為準。

## 與程式碼的關係

- Flutter tokens 與 Material theme 位於 `app/lib/design/`。
- `soft_components.dart` 提供共用 `SoftCard`、`PageHeading`、`ResponsivePageCanvas` 與 Flutter 原生幾何 `MoneyBuddy`；目前學生 UI 另使用 `app/assets/images/` 的本機 PNG 插圖。Web／Android 品牌圖示是本機 SVG／Android Vector Drawable，不依賴遠端圖片或字型。
- 新畫面先重用既有 semantic colors、type scale、spacing 與 components，不自行新增近似 token。
- 規範與實作改變時必須同步兩邊；不得只改文件或只改 UI，造成交接內容漂移。

目前學生 UI 的 Demo 預設為深靛黑畫布、紫色發光重點與本機角色插圖；亮色 token 仍保留作為主題支援。紫色與綠色光效只用於 Hero 與重點行動，不延伸到所有內容卡。一般卡片以深淺表面與必要的細框區隔，不以大量陰影製造層次。

`app/assets/images/` 的插圖目前只作為學生提供的本機 Demo 資產；在公開發表、上架或部署前，團隊必須補記每個插圖的作者、來源與授權，或以自有／明確可用的素材替換。未確認前不得把它們宣稱為第三方可再散布素材。

## 人工品質檢查

- 375px、768px、1024px、1440px 與 landscape 不溢位。
- 可用的 desktop post-rail 寬度達 900dp 時，登入後的主要頁面必須填滿該網頁畫布（保留規定 gutter），不可置中成狹窄 App 卡片；登入、說明與設定彈窗則維持聚焦寬度。
- 角色插圖與星點等裝飾必須放在自己的版位或內容背景層；不得以負位移、前景絕對定位或固定座標遮住文字、數值、表單與操作項。
- 學生提供的角色插圖應保有明顯的視覺份量；窄寬時改成獨立視覺列或卡片尾端，而非因避免遮擋就縮小到失去存在感或移除。
- 窄寬或 130% 以上字級時，多選項切換控制項應改為可換行的 chips／buttons，不能強迫所有項目維持單列。
- 亮／暗主題 body text 對比至少 4.5:1，狀態不只靠顏色表達。
- 互動目標至少 48×48dp，Web focus 清楚，鍵盤順序合理。
- 200% text scale、reduced motion、loading／empty／error／網路不可用／disabled 狀態可用。
- API 失敗不得靜默切換成合成資料；訪客模式必須由使用者明確選擇，並固定標示資料不會儲存。

目前沒有自動化 design build；實測證據記錄於 [docs/testing-and-evidence.md](../docs/testing-and-evidence.md)。
