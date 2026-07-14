# 資料與儲存

## 資料原則

- 決賽以合成資料與測試帳號展示；不蒐集姓名、學校、卡號、銀行帳戶或真實學生財務明細。
- 自然語言原文只存在於 parse request 生命週期，不寫入 MoneyEvent、Cosmos document、SharedPreferences 或監測 log。
- Client 不直接存取 Cosmos DB；登入帳號所有讀寫都經 Functions 的 Bearer token 驗證。
- 訪客模式只使用當次 App 記憶體；離開、重新整理或切換帳號後清除，不寫入瀏覽器、本機儲存或後端。
- Azure OpenAI 只收到單次輸入、locale、參考時間與受控分類；lesson 只使用最小事件摘要。

## 已實作資料模型

| 資料 | 關鍵欄位 | 儲存位置 |
|---|---|---|
| Account | `id`、正規化 email、scrypt password hash／salt、`profileComplete`、createdAt | `accounts` container 或 memory repository |
| Session | token SHA-256 hash、`userId`、createdAt、expiresAt、revokedAt | `sessions` container 或 memory repository |
| Profile | `userId`、月／週預算、目標、已存、日期、語氣 | `profiles` container 或訪客記憶體 |
| MoneyEvent | type、正整數 `amountMinor`、category、merchant、occurredAt、recurrence、split、idempotency | `moneyEvents` container 或訪客記憶體 |
| CaptureDraft | 候選欄位、confidence、missingFields、source | 僅 Client 記憶體／request response，不是正式 event |
| Learning | lesson、來源 event IDs、selected option、completedAt | `learning` container 或訪客記憶體 |
| Subscription catalog | 合成價格、週期、資格、sourceType、asOf | 版本化程式 fixture，不需要 container |
| FutureSeed preview | 本金、假設成長、期末值、年度點 | 即時計算，不持久化 |

Cosmos adapter 固定 database 名稱由設定注入，不會自動建資源。正式資料 containers 為 `accounts`、`sessions`、`profiles`、`moneyEvents`、`learning`，partition key 為 `/userId`。帳號與 session document 均以帳號 ID 作為 `userId`；session 先用 token hash 查找，再驗證未撤銷與到期時間。

## 帳號、session 與 ownership

1. 使用者註冊時，後端將 email 正規化、以 `scrypt` 搭配隨機 salt 保存密碼雜湊。
2. 後端產生 opaque token，只保存 SHA-256 hash；Client 僅保存 token，以 `/api/auth/me` 恢復登入。
3. 每個保護路由從 `Authorization: Bearer` 推導帳號 ID，從不採信 body 或 query 的 `userId`。
4. 註冊帳號第一次寫入 profile 後，`profileComplete` 才標為完成；新帳號不會讀到任何固定 seed。
5. 登出撤銷 server session 並清除本機 token。訪客退出只丟棄記憶體 repository。

## 寫入一致性

1. Parse 只產生未保存草稿。
2. 使用者修改與確認。
3. Client 送出 `confirmed: true` 與 idempotency key。
4. Functions 忽略不屬於契約的 AI 欄位並重新驗證金額、列舉、日期與範圍。
5. Repository 以已驗證帳號 partition 與 idempotency document key 防止重複。
6. Dashboard 每次由已確認事件重算，不保存容易失去同步的 AI 算術結果。

## FutureSeed

採每月月底投入普通年金：`FV = P × (((1 + r / 12)^n - 1) / (r / 12))`；`r = 0` 時使用 `P × n`。金額四捨五入為整數 TWD，並分開回傳本金與假設成長。這是教育試算，不保存、不保證報酬。

## 尚待部署與產品決策

真實 Cosmos 建立前仍須確認容量模式、區域、備份／還原、保留期限、刪除流程、RBAC 與費用。此競賽 MVP 尚未提供 email 驗證、忘記密碼、帳號刪除、資料匯出、家長共管、年齡同意或 production retention。使用真實未成年人的資料前，必須先完成這些產品與法遵決策。
