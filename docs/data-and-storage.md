# 資料與儲存

## 資料原則

- 決賽只使用固定合成 `demo-user`；不蒐集姓名、學校、卡號、銀行帳戶或真實學生財務明細。
- 自然語言原文只存在於 parse request 生命週期，不寫入 MoneyEvent、Cosmos document、SharedPreferences 或監測 log。
- Client 不直接存取 Cosmos DB；Connected 所有讀寫經 Functions。
- Azure OpenAI 只收到單次輸入、locale、參考時間與受控分類；lesson 只使用最小事件摘要。

## 已實作資料模型

| 資料 | 關鍵欄位 | 儲存位置 |
|---|---|---|
| Profile | `userId`、月／週預算、目標、已存、日期、語氣 | `profiles` container 或 Offline SharedPreferences |
| MoneyEvent | type、正整數 `amountMinor`、category、merchant、occurredAt、recurrence、split、idempotency | `moneyEvents` 或 Offline SharedPreferences |
| CaptureDraft | 候選欄位、confidence、missingFields、source | 僅 Client 記憶體／request response，不是正式 event |
| Learning | lesson、來源 event IDs、selected option、completedAt | `learning` container；Offline 保存於 SharedPreferences |
| Subscription catalog | 合成價格、週期、資格、sourceType、asOf | 版本化程式 fixture，不需要 container |
| FutureSeed preview | 本金、假設成長、期末值、年度點 | 即時計算，不持久化 |

Cosmos adapter 固定 database 名稱由設定注入，不會自動建資源。containers 為 `profiles`、`moneyEvents`、`learning`，partition key 為 `/userId`。所有 query 參數化並帶 `userId`。

## 寫入一致性

1. Parse 只產生未保存草稿。
2. 使用者修改與確認。
3. Client 送出 `confirmed: true` 與 idempotency key。
4. Functions 忽略不屬於契約的 AI 欄位並重新驗證金額、列舉、日期與範圍。
5. Repository 以 user partition 與 idempotency document key 防止重複。
6. Dashboard 每次由已確認事件重算，不保存容易失去同步的 AI 算術結果。

## Offline demo

SharedPreferences keys 使用版本化名稱，只保存合成 profile、確認 events 與微課選擇。重設功能會先清除這三組本機資料，再重建固定收入、飲料、遊戲、分帳訂閱與未完成微課故事；不影響 Connected／雲端資料。

## FutureSeed

採每月月底投入普通年金：`FV = P × (((1 + r / 12)^n - 1) / (r / 12))`；`r = 0` 時使用 `P × n`。金額四捨五入為整數 TWD，並分開回傳本金與假設成長。這是教育試算，不保存、不保證報酬。

## 尚待部署決策

真實 Cosmos 建立前仍須確認容量模式、區域、備份／還原、保留期限、刪除流程、RBAC 與費用。MVP 不做破壞性 migration；正式帳號與跨使用者 ownership 不在本階段。

Cosmos adapter 不會自動建立 profile、事件或 Azure 資源。全新 Connected 使用者可從 Client 設定建立預算與目標；未記錄訂閱前，Client 不會虛構「目前訂閱」或發出方案比較請求。決賽固定故事預設使用 Offline／Memory；已授權的專用 Cosmos Demo 可依 [Functions README](../services/api/README.md) 執行受控、帶顯式開關且可重複的合成 seed。
