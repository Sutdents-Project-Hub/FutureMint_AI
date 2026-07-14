# FutureMint AI 平衡柔和風格融合設計

## 目的

第二輪視覺調整要修正現行介面過度依賴粗黑框、硬陰影與膠囊標籤，導致整體過度接近首張 neo-brutalist 參考圖的問題。新方向融合使用者提供的 `2017375.jpg` 與 `2017376.jpg`：以柔和飽和色塊、有機角色、留白、重疊卡片與不對稱拼貼建立年輕感，同時保留 FutureMint 的金融資訊清晰度與薄荷綠品牌識別。

本次只調整 Flutter Client 的視覺系統、共用呈現元件與頁面構圖。不改 API、repository contract、路由、資料模型、財務公式、合成資料或 Demo 流程。

## 融合比例與視覺角色

- 60% 取自兩張新參考圖：近白畫布、柔和全幅色塊、18–28dp 圓角、有機角色、錯落 bento 與重疊卡片。
- 25% 保留 FutureMint：薄荷／青綠品牌色、青少年金融教練語氣、清楚金額與決策提示。
- 15% 保留原始高對比語言：黑色主要 CTA、手機底部導覽、選取狀態與少數必要輪廓。
- 不把三種語言平均套在每個元件上；強黑只負責操作錨點，角色只負責陪伴，功能色只負責分區與導覽。

## 設計原則

### 安靜但有個性

- 亮色畫布從奶油黃改成帶極淡青綠的近白色，避免格紙／海報感主導產品介面。
- 一般卡片移除 2.5dp 黑框與 5×6dp 硬陰影，改成無框或 1dp 品牌色調 hairline。
- 陰影只用於浮層或真正需要抬升的操作，不作為所有卡片的裝飾。
- 色彩採「全幅色塊」而非框線貼紙；一個畫面最多使用三個可見功能色，其餘由中性色承接。
- 主標題保留清楚尺寸對比，但常用字重從 800–900 降至 700–800；正文維持 400–500。

### 黑色作為操作錨點

- 手機底部導覽保留近黑圓角基座，選取項目同時用形狀、文字與顏色識別。
- 每個畫面最多一個近黑或品牌深色主要 CTA；次要操作使用無框、淡底或 hairline 樣式。
- 表單、資訊卡與靜態標籤不得普遍使用粗黑框。

### 角色系統

- 將 `SeedlingMascot` 延伸或替換為 Flutter 原生繪製的 `MoneyBuddy` 系統，不加入外部圖片、遠端素材或新 dependency。
- 角色使用圓形、花形、星形、圓角方形等有機輪廓，搭配簡單黑色眼睛與嘴型；不複製參考圖的特定角色。
- 允許很輕微的徑向色階增加軟糖感，但不得使用制式紫藍漸層、玻璃擬態或高亮 3D 寫實材質。
- 角色只提供陪伴與品牌辨識，不承載金額、狀態或推薦結論；保留 Semantics 圖像標籤。

## 色彩系統

### 亮色模式

- Canvas：帶薄荷色偏的近白背景，負責約 60% 視覺重量。
- Ink：帶品牌色偏的近黑文字與主要導覽，不作為一般卡片邊框。
- Mint／Teal：60% 的彩色元素，負責品牌、預算與主要操作。
- Periwinkle／Lavender：學習、引導與個人化內容。
- Orange／Sun：FutureSeed、目標與需要注意的假設。
- Sky：紀錄、資訊與次要資料。
- Pink／Coral：Capture 與少數高能量提示；不可同時大量出現在所有畫面。
- Success、warning、error 保留語意角色；狀態仍需文字或圖示，不能只靠顏色。

### 深色模式

- 使用帶青綠色偏的 charcoal 畫布與三層表面明度建立深度，不反轉亮色模式的陰影。
- 功能色降低飽和度並提高必要文字對比；彩色表面上的文字使用該色的深色或淺色對應值，不使用洗白灰字。
- 近黑 CTA 在深色模式改為高對比薄荷或淡色 CTA，避免消失在背景中。

## 共用元件

### `SoftCard`

- 取代「所有內容都是 `PopCard`」的預設心智模型；名稱明確表達柔和表面。
- 支援 `color`、`padding`、`radius`、`border`、`elevated`，預設無硬陰影、無粗框。
- 一般內容使用 20dp radius；Hero／bento 重點卡使用 24–28dp。
- 只有選取、focus、錯誤或可拖動狀態才能使用較清楚輪廓，而且狀態必須另有圖示或文字。

### `PageHeading`

- 取代重複的全大寫描邊 eyebrow pill，使用小型純文字 kicker、較大頁面標題與簡短說明。
- kicker 可以使用功能色，但不加粗框；標題與說明靠字級、字重和間距建立層級。
- trailing action 在窄寬度自動換行，不固定高度。

### `MoneyBuddy`

- 提供至少 `blob`、`flower` 與 `spark` 三種幾何變體，使用同一張臉部語言。
- 頁首最多一個主角色，卡片內的輔助角色必須更小且不與資料搶焦點。
- 保留 `FutureMint 金錢夥伴` Semantics label；裝飾性重複角色可排除語意樹，避免讀屏重複。

### Buttons、Fields、Chips

- Filled button 使用近黑或 teal 的高對比圓角矩形／pill；每頁只保留一個主要層級。
- Outlined button 改為 1–1.25dp hairline，不沿用 2.5dp 全域邊框。
- Input 預設使用淡表面與 1dp 輪廓，focus 使用 2dp teal focus ring。
- Chips 使用淡色填充與無框／hairline；示例 chip 與狀態 chip 的顏色角色分開。

## 頁面構圖

### App Shell

- 手機保留近黑底部導覽，移除紅色偏移底線與硬陰影；選取項目使用淡色圓形或膠囊 indicator。
- 平板／桌面側欄改成近白表面與 hairline 分隔，不使用全高粗黑線；品牌角色維持小而清楚。
- 頁面畫布使用近白，內容 gutters 依 4dp spacing scale：手機 16、平板 24、桌面 32–36。

### Dashboard

- 頁首改成簡潔問候、日期／狀態與一個 `MoneyBuddy`，主要 Capture 按鈕是唯一強 CTA。
- 預算 Hero 使用 teal 全幅色塊，無粗框；金額、進度和月預算為第一層資訊。
- 下方採不對稱 bento：教練提醒為較寬的 lavender 卡，目標為較高的 orange 卡，訂閱為 sky 卡；近期紀錄使用安靜中性區塊，避免所有資料都被彩色卡包住。
- Dashboard 使用 `LayoutBuilder` 依側欄扣除後的內容寬度決定構圖：內容寬至少 900dp 才使用雙欄／bento，否則依 Demo 故事順序轉為單欄，不以固定高度維持拼貼。

### Capture

- 移除大面積珊瑚粗框卡與硬陰影，改成近白輸入面板嵌於 teal／mint Hero。
- `MoneyBuddy` 與簡短提示靠近標題；文字輸入與範例 chips 保持最清楚的操作順序。
- 「幫我整理」為近黑主 CTA；解析、澄清、草稿與保存狀態維持既有語意與文字，不因視覺改動混淆。

### Records

- 使用近白畫布與低彩度 sky 分區；篩選控制為簡潔 segmented pill。
- 紀錄清單不再每筆都是重色卡；以間距、日期群組、淡分隔與小型類別 glyph 建立掃讀節奏。
- 金額、正負號、類別與收入／支出文字共同表達，不靠色彩判斷。

### Learning

- 採 `2017375.jpg` 的重疊／階梯卡片節奏：課程摘要與各段內容使用 sun、periwinkle、teal、pink 的大色塊，但同一 viewport 最多露出三個主色。
- 卡片以 12–20dp 視覺重疊或負空間銜接，不能遮住文字、focus ring 或操作。
- 問答選項仍使用標準可及單選語意；完成後的下一步使用獨立 teal 行動面板。

### Subscriptions

- 目前方案使用一張深色摘要卡作為唯一黑色資料錨點。
- 比較方案以近白卡為主，僅用 sky、orange 或 pink 的小面積抬頭／圖形辨識，避免整頁像彩色海報。
- 資格、差額與 disclaimer 的文字順序及含義不變。

### FutureSeed

- 輸入控制使用 orange／sun 的柔和大卡；結果區使用 teal 主卡與 sky 次卡。
- 年度資料改為簡潔的進度條或分段列，無粗框；本金與假設成長仍明確分開。
- 有機角色可出現在結果摘要，但不得暗示投資報酬保證。

### Settings 與共用狀態

- Sheet、Dialog、AsyncPanel 使用中性表面、hairline 與清楚空間，不沿用粗黑框。
- Connected／Offline、loading、error、empty 與 disabled 狀態的文案與行為不變。

## 版面與響應式

- spacing 僅使用 4、8、12、16、24、32、48、64dp；相關項目 8–12dp，區塊間 24–48dp。
- 保留 720dp NavigationRail 斷點；Dashboard 不再以整個 viewport 的 1100dp 判斷，而以側欄扣除後至少 900dp 的實際內容寬判斷 bento。
- 全域桌面內容寬上限從目前漂移的 1240dp 收斂到 1200dp；表單／閱讀／資料畫布只保留少數語意化寬度 token。
- card padding 在手機使用 16dp，720dp 以上使用 24dp；頁面 gutter 為手機 16dp、平板 24dp、桌面 32dp。
- Dashboard 可使用非對稱 bento，但其他資料密集頁面優先維持可預測的一維結構。
- 禁止巢狀卡片造成多重容器邊界；資訊可透過間距與 divider 分組時，不新增卡片。
- 支援 375、768、1024、1440px、landscape 與 200% text scale；窄版不得用固定高度維持裝飾構圖。

## 可及性與互動

- Body text 對比至少 4.5:1；大字與 UI component 至少 3:1。
- 觸控目標至少 48×48dp，Web focus ring 清楚可見。
- 狀態、收入／支出、選取與錯誤皆保留文字或圖示，不以顏色單獨傳達。
- `MoneyBuddy` 不取代標題、提示、數值或按鈕 label。
- 動態只使用 150–250ms opacity／translation，遵守 reduced motion；本輪不新增裝飾性持續動畫。

## 驗證與成功標準

- 先以 widget tests 驗證 `SoftCard` 無預設硬陰影／粗框、`PageHeading` 結構與 `MoneyBuddy` Semantics，再修改 production code。
- 保留現有 capture、records、learning、subscriptions、FutureSeed、settings 行為測試與 key。
- 新增首頁 bento／學習堆疊與 375×812、812×375、200% text scale 無例外測試。
- 執行 Dart format、`flutter analyze`、`flutter test`、`flutter build web --release` 與 `git diff --check`。
- Flutter Web 人工檢查 375、768、1024、1440px 與 812×375；走訪 `/`、`/capture`、`/records`、`/learning`、`/subscriptions`、`/future-seed` 和 settings，檢查亮／深色模式與瀏覽器 console。
- 同步 `design-system/futuremint-ai/MASTER.md`、`design-system/README.md`、`apps/client/README.md` 與 `docs/testing-and-evidence.md`，只記錄實際執行證據。

## 不在範圍內

- 登入、帳號、家長共管、支付、銀行、真實金融資料或 Azure 部署。
- API、Functions、模型、資料庫、財務計算、資料格式或 Demo 文案流程。
- 外部圖片、未確認授權素材、遠端字型、新 animation package 或其他 runtime dependency。
- Git stage、commit、push、PR、merge、release 或 deployment。
