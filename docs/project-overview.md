# 專案範圍與驗收

## 一句話定義

FutureMint AI 是專為青少年設計的 AI 金錢決策教練：把使用者主動輸入的收入、支出與訂閱，轉為當下可理解的選擇建議、個人化金融微課程與教育性未來預覽。

## 核心問題

青少年開始獨立面對零用錢、交通、飲食、遊戲與數位訂閱，卻常只有「月底才發現錢不夠」的記帳結果。現有工具多著重交易彙整或成人財務管理，較少把青少年當下的真實金錢事件，轉成能理解、能反思、能採取下一步的學習閉環。

## 主要使用者與情境

- 主 Persona：有零用錢與數位消費、開始自行管理日常開銷的中學生。
- 主要情境：收入進帳後沒有分配、小額支出累積、共享或重複訂閱、想存錢卻看不見選擇的長期差異。
- 家長、上班族與銀髮族只列未來延伸，不進入本次主要故事與 MVP。

## 決賽 MVP 範圍

1. 自然語言記錄收入、支出與訂閱；Connected mode 由 Azure AI provider、Offline demo 由明確標示的 deterministic provider 回傳符合 schema 的草稿。
2. 使用者確認或修正草稿後，才保存交易。
3. 以規則計算預算、剩餘金額、期限與分類統計。
4. 教練 provider 根據事件與有限度的摘要背景提供青少年可理解的回饋；Azure AI 真實連線尚未驗證時不得冒充其成效。
5. 產生與事件相關的微課程，包含一個觀念、一個例子與一個行動。
6. 依已記錄的訂閱價格與分帳人數，比較版本化合成方案的成本、差額與資格；不假裝為即時市場資訊。
7. 用明確公式展示儲蓄與複利情境，標示假設且不等同實際投資報酬。

## 非本階段範圍

- Apple Pay、LINE Pay、悠遊卡、銀行、電子發票或 Email 的自動同步。
- 付款、轉帳、證券下單、開戶、金融商品推薦、信用評分或保證報酬。
- 家長監控、學校帳號、公開排行榜與跨世代完整產品線。
- 正式營運等級的法遵、客服、付費、災難復原與大規模資料管線。
- 將所有數學或分類工作交給 AI；可以確定計算的部分由程式處理。

## 核心驗收

| 流程 | 可觀察完成條件 |
|---|---|
| Quick Capture | deterministic provider 的 30 筆合成繁中案例與 225 個欄位檢查通過；Azure provider 另以 fake client 測試，真實模型成效尚待驗證 |
| 交易保存 | 未確認草稿不寫入；確認後重新整理仍能取回 |
| 預算回饋 | 相同輸入產生相同數學結果，金額與邊界條件有測試 |
| 訂閱教練 | 至少能比較兩種方案，清楚區分已知價格、使用者輸入與 AI 建議 |
| 微課程 | 內容與最近已確認事件相關、適合青少年、含限制提示；新事件會使舊課失效並產生新課 |
| FutureSeed | 公式、期間、投入與假設利率可見；結果標示為教育模擬 |
| AI 失敗 | timeout、429、格式錯誤或服務不可用時有重試／降級，不破壞既有資料 |
| 決賽 Demo | 使用合成資料可在固定腳本內完成，另有錄影或靜態備援 |

## 已知決定

- Client：Flutter，共用 Android、iOS 與 Web。
- Server：Azure Functions TypeScript，Node.js 22。
- Data：Cosmos DB for NoSQL；資料模型與容量模式在部署前確認。
- AI：Azure OpenAI／Foundry adapter 與錯誤處理已用 fake client 驗證；真實 endpoint、deployment、quota、latency 與內容品質尚待實測。
- Web Hosting：Azure Static Web Apps；API 可分離部署至 Functions Flex Consumption。
- 監測：Application Insights，禁止記錄完整財務文字或秘密。
- Design：`design-system/futuremint-ai/MASTER.md` 是 Flutter 視覺、響應式與可及性共同依據，不是獨立 executable component。

## 尚待團隊確認

- 決賽實際 demo 裝置與網路備援順序。
- 青少年訪談／可用性測試人數，以及監護與去識別方式。
- 訂閱方案資料採純合成資料、人工維護資料或公開來源；不得未經授權爬取。
- 共享 Azure 配額、區域、模型 deployment 名稱與主辦方可提供的 RBAC 協助。
- iOS 簽章 Team；未完成前以 Android 與 Web 作為主要展示面。

完整版本演進、競品、簡報與問答見 [產品規格與決賽策略](product-spec.md)。

可重現的實測結果見 [測試與證據](testing-and-evidence.md)，現場流程與降級說法見 [Demo 腳本](demo-script.md)。
