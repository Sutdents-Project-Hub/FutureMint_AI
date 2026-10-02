# App Store 繁體中文資料草稿

分類：首次上架資料準備（2026-10-03）。已建立 App Store Connect record `6818587553`（SKU `futuremint-ai-ios`），儲存下列繁中商店欄位、審查備註與使用者指定的登入／既有審查聯絡資料。已設定臺灣免費供應、手動發佈，關閉 Mac／Vision Pro 相容供應；狀態仍為「準備提交」，沒有送審或公開。帳密與私人聯絡資料不保存於 repository。AI、新版後端及簽章待驗收，見 [測試與證據](testing-and-evidence.md)。

## 商店欄位

| 欄位 | 內容 |
|---|---|
| 名稱 | FutureMint AI |
| 副標題 | 記帳、訂閱管理與金錢學習 |
| 主要語言 | 繁體中文 |
| 主要類別 | 教育 |
| 次要類別 | 財經 |
| Bundle ID | `tw.futuremint.futuremintApp` |
| 目前專案版本 | `1.0.0 (1)`；尚無已簽章／處理完成的商店 build |
| 支援 URL | https://futuremint-ai-api.beioverworked.com/support |
| 隱私政策 URL | https://futuremint-ai-api.beioverworked.com/privacy |
| 關鍵字 | 記帳,預算,零用錢,訂閱,儲蓄,複利,金錢教育,理財學習,收支,學生,目標,虛擬投資 |

### 行銷宣傳文字

從一筆日常支出開始，整理預算、檢視訂閱與學習金錢觀念。用教育情境探索儲蓄與複利，在虛擬投資練習中理解風險。

### 描述

FutureMint AI 陪你從生活中的每一筆收支開始，練習管理預算與理解金錢選擇。

【整理日常收支】
手動記錄收入與支出，查看收支變化與「需要／想要」分類。啟用第三方 AI 並同意資料處理說明後，可用繁體中文輸入消費內容，檢查及修改草稿，再自行確認保存。

【看清訂閱與預算】
管理月繳或年繳訂閱，分開查看訂閱承諾與實際付款。可選擇開啟 iPhone 本機續訂提醒；通知需授權，提醒設定需在 App 內同步。

【學習金錢觀念】
透過短篇教材理解預算、消費與風險。AI 功能需另外同意，拒絕 AI 仍可使用符合帳號資格的手動記帳及固定教材。

【探索未來情境】
FutureSeed 以合成路徑呈現儲蓄及複利情境。投資練習場使用延遲行情與虛擬資金，練習理解配置、價格變動及費用。

【自己決定分享】
孩子可自行選擇加入家庭，與家長分享預算、目標及學習摘要；不分享逐筆交易明細。家庭分享、監護人同意與 AI 授權各自獨立。

正式帳號服務面向臺灣 15 歲以上使用者；15–17 歲由家長或法定代理人在 App 內閱讀並勾選同意，不需要監護人 Email。也可使用合成資料的訪客體驗。使用者可匯出自己的資料，並在 App 內刪除帳號。

本 App 不連接銀行、支付或真實證券交易。教育試算及虛擬投資不代表即時報價、投資建議或報酬保證。

## 審查備註草稿

FutureMint AI is a Traditional Chinese financial education and budgeting app intended for Taiwan. It does not connect to banks, process payments, execute real securities trades, or offer guaranteed returns. The investment practice area uses virtual funds and delayed market data; FutureSeed charts are synthetic educational scenarios.

The dedicated review account is supplied in the sign-in fields. Guest mode provides synthetic data without registration. Account services are intended for ages 15+. For ages 15–17, a parent or legal guardian reads the disclosure and confirms on the child’s device; this is a declaration, not identity verification. No guardian email is required.

AI processing requires separate in-app consent showing the current provider and data handling terms. Manual records and fixed learning materials remain available to eligible users who decline AI. Family summary sharing is optional and separate from guardian approval and AI consent.

Account deletion is available in the app settings and requires the current password and confirmation. Renewal notifications are scheduled locally on iPhone after notification permission is granted; no remote push notification service is used.

內部送審前置（未填入 Apple 備註）：新版 API 與 migration 012 上線後，重新驗收審查帳號及 15–17 歲 App 內監護人流程；SMTP 不再是必需條件。仍須驗收目前外部 AI 服務／資料說明及已簽章 iPhone build。

## 隱私與問卷填寫依據

尚未提交 App Privacy 回答。需依正式部署與供應商資料流核對，不能填「不收集資料」。程式保存帳號 Email／帳號 ID、年齡分組、使用者輸入的收支／預算／目標／訂閱、教材進度、虛擬投資與家庭關聯；新的監護人流程只記錄同意方式／狀態，不收集監護人 Email；舊 Email 流程可能保留先前資料。這些資料與帳號關聯，用於 App 功能。來源 IP 與請求紀錄另需按代管平台實際保留方式核對。

Apple 的「其他財務資訊」涵蓋收入等資料；不連銀行不等於不收集財務資訊。可對應的項目包括 Email、User ID、Other Financial Info、Purchase History（自填支出、商家、訂閱及日期需核對此分類）、Other User Content、Product Interaction、Other Data Types，最終選項與用途需逐項對照現行問卷，不以此草稿代替營運者確認。帳號資料多與 User ID 關聯，主要用於 App Functionality；依摘要選課另需按實際資料類別判斷 Product Personalization，不把所有用途一律勾選。

目前程式沒有廣告 SDK／跨 App 廣告追蹤、相片上傳或定位權限；AI 接收方與上游用途仍需核對，不能以「沒有廣告 SDK」推論所有第三方用途。年齡分級由 Apple 問卷產生，服務資格 15+ 不等同商店分級；不得直接猜填分級或兒童類別。

內容權利仍有具體缺口：[Design README](../design/README.md) 記錄原有學生角色 PNG 尚待作者、來源與商用授權確認；新 iOS icon 的生成紀錄不涵蓋其他插圖。這不能由 repository 的 LICENSE 宣告或本輪截圖替代。年齡問卷可依固定金融教材、不提供使用者互相聊天或一般網頁瀏覽等程式事實回答；家庭摘要及自我年齡／家長聲明不冒充身分驗證或內容家長控制。

參考：[Apple App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)、[管理 App 隱私權](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)。

## 尚待取得與製作

- Apple 協議、Bundle ID 註冊及 App record 已完成；仍需 Apple signing identity、signed build 與 TestFlight。
- 審查聯絡姓名／電話／Email 已依使用者指示沿用 EmoChess；公開營運者與版權名称尚待確認，與審查聯絡人分開。
- 已從目前 1.0.0(1) 模擬器版本製作六張 1320×2868 繁中 iPhone 6.9 吋截圖，見 [素材與來源](../design/app-store/README.md)。使用合成訪客資料，原生 PNG 保留，JPEG 無透明通道；已上傳 ASC 並重新載入確認六張，6.5 吋沿用 6.9 吋；仍待最終 signed build 對照。
- 新版 API／migration 與 App 內監護人流程、AI 資料處理條款與功能、通知真機驗收，以及新版審查帳號完整流程。
- 免費價格及臺灣供應已保存；仍須 App Privacy、年齡問卷、內容權利、加密、build 選擇與提交檢查。

## 剩餘人工資料與接續操作（2026-10-03）

- **Apple 登入**：Xcode → Settings → Apple Accounts → ＋ → Apple Account，直接在 Apple 視窗輸入開發者帳號並完成雙重驗證。Runner 已配置已確認的開發團隊及 Automatic signing；登入完成後仍須確認憑證／profile、正式 archive 與 Apple 上傳驗證，不把 Team 設定視為已簽章。不要將密碼或驗證碼寫入文件。
- **公開名稱**：提供實際負責本服務的個人或組織公開名稱，以同步商店版權、App 公開配置及政策；審查聯絡人已填，不能據此推定營運主體。
- **原插圖**：確認角色素材為自製、AI 生成或第三方來源；自製需確認作者同意使用，第三方需提供來源與適用授權。新 App icon 的生成來源不涵蓋其他角色。
- **年齡問卷**：App 有自行選擇年齡及服務資格門檻，不查驗身分證件；是否依 Apple 當前定義填入「年齡確認」已請營運者確認。問卷尚未保存，不能將準備中的回答視為完成。
- **App Privacy**：程式端收集項目已整理於上節；正式 API／平台請求日誌的欄位、保存期限及供應商處理用途仍待證據。診斷資料與用途分類尚未保存或發布。

可向量界客服提供以下詢問文字；本輪未代寄：

> 我們預計在臺灣上架含 15–17 歲監護人同意流程的教育 App，使用量界 gpt-4o-mini API。請提供適用此 API 的隱私政策／資料處理條款及營運主體，並說明實際上游服務商、傳送內容及回覆是否用於訓練／人工審閱／廣告或跨公司追蹤、prompt／回覆／IP／日誌／備份的保存期限、處理國家、刪除申請與上游刪除方式，以及是否允許上述未成年人使用情境。請附可引用的文件或書面答覆；我們不會寄送使用者資料或 API 金鑰。

公開頁面查核目前未取得足以填補上述用途、保存及上游資訊的條款；沒有證據時不宣稱第三方「不保存／不訓練／不追蹤」。取得書面資料後再完成問卷與公開告知。
