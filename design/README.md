# FutureMint AI Design System

本資料夾是 FutureMint Flutter Client 的非執行型設計支援資產，沒有 package manager、runtime 或獨立部署生命週期，因此不列入 Student Project Profile 的 executable components。

## 權威文件

- [MASTER.md](futuremint-ai/MASTER.md)：全域色彩、字體、間距、元件、響應式、動態、狀態與可及性規範。
- [App Store 截圖](app-store/README.md)：繁中 iPhone 6.9 吋原始截圖、上傳素材、來源與驗證界線。
- 若未來建立 `futuremint-ai/pages/<page>.md`，頁面 override 只覆蓋該頁明確列出的規則，其餘仍以 `MASTER.md` 為準。

## 與程式碼的關係

- Flutter tokens 與 Material theme 位於 `app/lib/design/`。
- `soft_components.dart` 提供共用 `SoftCard`、`PageHeading`、`ResponsivePageCanvas` 與 Flutter 原生幾何 `MoneyBuddy`；目前學生 UI 另使用 `app/assets/images/` 的本機 PNG 插圖。Web／Android 品牌圖示是本機 SVG／Android Vector Drawable，不依賴遠端圖片或字型。
- 新畫面先重用既有 semantic colors、type scale、spacing 與 components，不自行新增近似 token。
- 規範與實作改變時必須同步兩邊；不得只改文件或只改 UI，造成交接內容漂移。
- 年齡聲明與資格確認的下拉選單使用欄位外標題，框內只顯示選擇提示或選定年齡。註冊新增可獨立顯示／隱藏的確認密碼，8–128 字元規則及欄位旁比對錯誤依 `MASTER.md` 實作。
- 2026-10-02 依使用者操作回饋更新首次設定／等待頁分區、草稿優先、FutureSeed 內容順序、訂閱欄位間距、設定彈窗與提醒卡換行。保留既有插圖與品牌；具體規則見 `MASTER.md` 的「iPhone 逐頁排版補充」，實測與未驗證範圍見測試證據。
- 同日實際登入帳號巡檢後，AI 未啟用提示改為淡紫圓角資訊卡；補上虛擬成交結果與通知權限拒絕的恢復說明。輸入控制器由彈窗元件卸載時釋放，避免儲存／取消時退場錯誤；具體規則見 `MASTER.md` 的「登入後 AI 狀態提示與操作回饋」。
- AI 資料說明彈窗依使用者閱讀回饋分段、增加行距，將長版本碼收進可展開的詳細資訊；隱私／支援連結靠左對齊內文。原揭露及啟用條件維持，手機與放大字級驗證見測試證據。
- 2026-10-03 15–17 歲監護人確認改為登入後在 App 內簡單勾選並繼續，不收集監護人 Email；介面需清楚說明這是聲明、不驗證身分，且家庭摘要與 AI 授權分開選擇、可在孩子設定撤回。沿用既有表單元件與視覺規範，細節見 `MASTER.md`。

目前學生 UI 的 Demo 預設為深靛黑畫布、紫色發光重點與本機角色插圖；亮色 token 仍保留作為主題支援。紫色與綠色光效只用於 Hero 與重點行動，不延伸到所有內容卡。一般卡片以深淺表面與必要的細框區隔，不以大量陰影製造層次。

`app/assets/images/` 的插圖目前只作為學生提供的本機 Demo 資產；在公開發表、上架或部署前，團隊必須補記每個插圖的作者、來源與授權，或以自有／明確可用的素材替換。未確認前不得把它們宣稱為第三方可再散布素材。

## iPhone App icon（2026-10-01）

- 使用者核准替換 iOS icon；原稿為 [app-icon.png](futuremint-ai/assets/app-icon.png)，由 Codex 內建 imagegen 依本專案品牌方向產生，沒有使用第三方圖片或商標作為輸入。
- 視覺為靛紫滿版背景、暖金幣及象牙白／淡紫嫩芽，表達預算、儲蓄與學習。原稿保留完整方形、不透明背景，圓角由 iOS 呈現。
- 在 `app/` 執行 `python3 tool/generate_ios_icons.py`，使用 macOS `sips` 按現有 `AppIcon.appiconset/Contents.json` 輸出全部尺寸；1024px 項目亦由同一原稿產生。
- 本次範圍為 iOS launcher icon；App 內畫面、Web／Android 原有向量品牌與啟動畫面沿用既有資產。其他學生插圖的來源紀錄不因本次生成而完成。
- 生成提示：FutureMint 青少年金錢教育與預算教練的單一方形 App icon；置中的金幣與雙葉嫩芽整合標記，靛紫 `#6D5BD0` 滿版背景，暖金色、象牙白與淡紫色，清楚輪廓及柔和立體陰影，縮小至 60px 可辨識；無文字、貨幣符號、數字、商標、水印、手機 mockup、外框、預先圓角或透明角落。
- 完整 imagegen 提示存於 [app-icon.prompt.txt](futuremint-ai/assets/app-icon.prompt.txt)。生成原稿為 1254×1254，尺寸輸出由腳本負責，沒有對原稿重新繪製。

## 人工品質檢查

學習路線卡片的紫色探頭角色使用 `app/assets/images/mascot_peek_purple_level.png`。內建 imagegen 以原有學生角色為參考，整理為水平底緣與抓邊的雙手；只裁去透明畫布留白（1176×744），角色身體底緣位於圖像 y=642。角色與卡片上界共用此縮放錨點，依最新使用者指示不再額外畫紫色橫線。角色縮為 112／136dp 並左移，頭部右側為等大 12dp、等距 8dp 的兩圓一菱形；角色與裝飾共用卡片上方的預留空間，取消原本獨立裝飾列，收短標題下方間距。此素材沿用原角色，原素材的來源／授權查核仍需保留。生成提示見 [learning-mascot.prompt.txt](futuremint-ai/assets/learning-mascot.prompt.txt)。

- 375px、768px、1024px、1440px 與 landscape 不溢位。
- 可用的 desktop post-rail 寬度達 900dp 時，登入後的主要頁面必須填滿該網頁畫布（保留規定 gutter），不可置中成狹窄 App 卡片；登入、說明與設定彈窗則維持聚焦寬度。
- 角色插圖與星點等裝飾必須放在自己的版位或內容背景層；不得以負位移、前景絕對定位或固定座標遮住文字、數值、表單與操作項。
- 學生提供的角色插圖應保有明顯的視覺份量；窄寬時改成獨立視覺列或卡片尾端，而非因避免遮擋就縮小到失去存在感或移除。
- 窄寬或 130% 以上字級時，多選項切換控制項應改為可換行的 chips／buttons，不能強迫所有項目維持單列。
- 亮／暗主題 body text 對比至少 4.5:1，狀態不只靠顏色表達。
- 互動目標至少 48×48dp，Web focus 清楚，鍵盤順序合理。
- 200% text scale、reduced motion、loading／empty／error／網路不可用／disabled 狀態可用。
- API 失敗不得靜默切換成合成資料；訪客模式必須由使用者明確選擇，並固定標示資料不會儲存。

手機寬度的亮／暗主題與 200% 字級溢位由 `app/test/features/mobile_layout_test.dart` 自動檢查；目前沒有自動化 design build；實測證據記錄於 [docs/testing-and-evidence.md](../docs/testing-and-evidence.md)。

## 正式產品流程補充（2026-09）

iOS 只支援 iPhone。沿用既有設計，淺色／深色／系統主題需實際控制 MaterialApp，系統元件提供 zh_TW 語系。帳號驗證畫面需可重寄、重新確認、登出與刪除帳號；錯誤不能被持續顯示的同意對話框遮住。家庭邀請碼只在建立／更新時顯示，須標示有效期限並提供更新／停用操作。隱私與支援入口開啟經發布設定提供的公開 URL。AI 教育文字標明 AI 選題與受控教材來源。

## 上架流程與狀態（2026-10-01）

本輪不改既有布局、色彩、字級與插圖；年齡／監護人、AI 政策、手動紀錄、訂閱管理、匯出與 iPhone／Android 提醒入口重用原元件。等待資格、寄信失敗、撤回及政策過期均需保留可見的 help/retry、登出與刪除，不用不可退出的全螢幕同意流程。

訂閱卡分開呈現合約承諾成本與實際付款，不能把新增合約顯示成已扣款。提醒文字明示 iPhone／Android 本機權限、系統送達限制與 Web App 內限制；遠端變更需同步。AI disclosure 顯示當前 provider、模型、資料接收方與政策版本；拒絕後手動功能仍有入口。微課標明受控教材與選題來源。

## 公開隱私與支援頁（2026-10-02）

API SSR 的公開頁沿用淺色 `#F8F7FC`／靛紫 `#6D5BD0`／文字 `#1B1B2A`，深色採 `#14131F`／`#1C1B2A`／淡紫重點；用簡單圓角資訊框、44px 以上導覽觸控範圍、可見 focus 與單欄閱讀。手機時標題／營運資訊與語言按鈕換行，不用裝置座標。繁中、English 與明暗切換由網址參數控制，不使用 cookie 或第三方字型／素材。App 內既有主題與角色版位沿用原設計；免寄信說明只新增所需狀態文案。

公開頁左上角使用與 iPhone 相同的金幣嫩芽 App icon，來源為 iOS catalog 的 120px 圖檔；API 部署副本為 `backend/public/app-icon.png`。維持 40px 方形、原圓角及品牌文字，替代字母 F，繁中／英文與明暗頁共用同一資產。

## 親子分享互動（2026-10-02）

沿用既有 Material／SoftCard 與品牌 tokens；首次設定說明目前帳號的預算歸屬及家庭入口。家庭查詢有載入／失敗重試，加入與離開採可捲動確認畫面，說明分享範圍與退出後資料保留。唯讀模式停用新增分享，保留離開／停用邀請；家長有孩子時顯示不能關閉家庭的理由。具體規則見 MASTER，合成模擬器與大字級測試見測試證據。
