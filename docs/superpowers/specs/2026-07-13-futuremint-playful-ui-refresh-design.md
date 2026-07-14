# FutureMint AI 活力色塊 UI 重整設計

## 目的

將 Flutter Client 從偏保守的 Material 卡片介面，重整成適合青少年的活力色塊品牌。視覺參考來自使用者提供的四張 UI 圖片，但不複製特定品牌、插圖或版面；只提取粗輪廓、硬陰影、高彩度色塊、幾何角色、膠囊控制與清楚資訊層級等共通語言。

本次只改變視覺呈現與必要的共用 UI 結構，不改 API、repository contract、路由、資料模型、財務計算或既有 Demo 行為。

## 設計方向

- 亮色模式是主要展示體驗：暖白畫布、深墨色文字、青綠主色，搭配珊瑚紅、陽光黃、薰衣草紫與天空藍。
- 深色模式參考黑底高彩度畫面，但降低螢光面積；長篇文字維持高對比，亮色只用於操作、狀態與重點卡片。
- 以 2–3dp 深色輪廓、右下偏移硬陰影、18–28dp 圓角形成品牌識別。
- 大標題採平台字體的 800–900 粗度，不引入執行時字型下載；繁體中文與數字都必須清楚。
- 使用 Flutter 基本形狀與 `CustomPainter` 建立簡單種子角色及裝飾，不加入來源或授權不明的圖片。
- 不以顏色單獨表達收入、支出、成功或錯誤；文字、圖示和語意標籤仍是主要辨識方式。

## 共用視覺系統

### 色彩

- Ink：主要輪廓、標題、深色導覽。
- Cream：亮色背景，減少純白畫面的制式感。
- Mint／Teal：品牌與主要操作。
- Coral：教練提醒、Capture 與強調操作。
- Sun：目標、機會與溫暖提示。
- Lavender：學習與個人化內容。
- Sky：資料、紀錄與 FutureSeed 輔助資訊。
- Success、warning、error 保留獨立語意色，且需通過文字對比檢查。

### 字體與間距

- Display 34–42sp、900；Headline 26–32sp、800；Title 18–22sp、800。
- Body 維持 16sp 左右與 1.4–1.5 行高，Caption 不小於 12sp。
- 手機 gutter 16–20dp，桌面 28–36dp；互動區至少 48×48dp。
- 金額與圖表數字使用 tabular figures，避免更新時寬度跳動。

### 元件

- `PopCard`：可選背景色、深色輪廓、圓角與偏移硬陰影；所有主要內容卡共享此結構。
- `PopPill`／Theme buttons：主要按鈕採膠囊或大圓角，使用實色與清楚按下狀態；次要按鈕採深色描邊。
- `SectionHeading`：小型彩色 eyebrow、粗體主標與選用說明，建立穩定頁首節奏。
- `SeedlingMascot`：用簡單圓潤幾何與表情表示陪伴，不承載資料或狀態。
- Chips、輸入框、NavigationBar、NavigationRail、SnackBar 與 Sheet 共用粗輪廓和較明確的 focus／selected 狀態。

## 頁面設計

### App Shell

- 手機 AppBar 維持品牌與模式狀態；底部導覽改為深色圓角基座，中央 Capture 具最高對比。
- 平板與桌面保留 NavigationRail，改成暖白／深色品牌側欄與色塊選取狀態。
- Offline／Connected 標示仍然清楚且不以配色暗示實際連線成功。

### 首頁

- 頁首使用歡迎標題、小型種子角色與 Capture 主操作。
- 預算 Hero 改成青綠色塊、粗框與硬陰影；金額、進度與月預算仍是主資訊。
- 目標、教練提醒、訂閱機會、近期紀錄與合成資料揭露使用不同輔色，但遵循相同卡片骨架。
- 寬螢幕維持雙欄；手機依 Demo 故事順序排列：預算、提醒、目標、近期紀錄、訂閱、資料揭露。

### Capture

- 以大型珊瑚／暖白輸入卡呈現自然語言入口，範例 chips 更像可點選的提示貼紙。
- 解析 loading、拒絕、需要澄清、已保存與錯誤狀態使用不同語意面板；「已解析」不可看起來像「已保存」。
- DraftEditor 一併套用共用卡片、欄位與按鈕規則，但不改確認流程。

### 紀錄

- 分類切換採膠囊 segmented control。
- 每筆紀錄使用較扁平的彩色類別標記、清楚金額與日期；收入／支出差異同時由正負號、圖示和文字表達。

### 微課

- 使用薰衣草主卡和分段色塊，讓「先看懂」、「放進生活」、「做選擇」成為可掃讀的三段。
- 選項維持可及的單選語意與鍵盤 focus；選取後的下一步使用青綠行動面板。

### 訂閱比較

- 目前方案作為深色摘要卡；候選方案使用天空藍、黃色與珊瑚色交替。
- 資格與差額仍以文字和圖示說明，不把彩色卡片當成推薦或資格證明。

### FutureSeed

- 控制區使用黃色／暖白卡，結果區使用青綠與天空藍。
- 年度累積維持確定性資料；長條視覺改為粗框色塊，不加入誤導性的投資走勢或報酬暗示。

### 設定與共用狀態

- Settings sheet、global message、loading／empty／error 面板同步套用品牌元件。
- Connected 失敗不改成離線成功；切換 Offline demo 仍需使用者明確操作。

## 響應式與可及性

- 保留 720dp 與 1100dp 既有斷點，避免重新定義導覽行為。
- 375、768、1024、1440px 以及 landscape 不得產生水平溢位。
- 200% text scale 時允許卡片向下增高，按鈕與金額可換行，不固定文字容器高度。
- 所有 body text 對比至少 4.5:1；大字與裝飾色仍避免落在臨界對比。
- Web focus indicator、Semantics label、48dp touch target、reduced motion 與既有讀屏資訊不得退化。

## 驗證

- 新增或調整 widget tests，覆蓋 Theme、共用品牌卡片、主要頁面載入與窄寬版無例外。
- 執行 Dart format、`flutter analyze`、`flutter test` 與 `flutter build web`。
- 啟動 Flutter Web，人工檢查首頁、Capture、紀錄、微課、訂閱、FutureSeed 與設定；至少截取手機和桌面寬度確認資訊層級與溢位。
- 同步更新 `design-system/futuremint-ai/MASTER.md`、`design-system/README.md`、Flutter `lib/design/` 與測試證據文件；不虛構未執行的裝置或可及性驗證。

## 不在範圍內

- 登入、帳號、家長共管、真實金融資料與雲端部署。
- API、Azure provider、資料庫、模型提示、財務公式與合成資料內容。
- 新增第三方圖片、遠端字型、動畫套件或新的 runtime dependency。
- 重新命名既有路由、功能資料夾或可執行元件。
