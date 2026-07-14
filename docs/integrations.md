# 外部整合與 AI

## 整合狀態

| 服務 | 實作 | 已驗證 | 尚未驗證 |
|---|---|---|---|
| Azure OpenAI／Foundry | structured output adapter、Managed Identity／key 建立路徑、timeout／429／schema handling | fake client tests | 真實 endpoint、deployment、RBAC、quota、latency |
| Cosmos DB for NoSQL | account／session／profile／event／learning repository、partition query、idempotency | fake client tests | 真實 account、containers、RBAC、吞吐與備份 |
| Application Insights | 安全設定名稱與去識別 event 邊界 | 程式不輸出 capture 原文 | 真實 connection、dashboard 與 retention |
| Static Web Apps | Flutter release Web 產物可建置 | `flutter build web --release` | Azure resource、domain、CORS 與 deployment |

## Functions authentication

- Auth 是 application 自己的 email/password prototype，不是 Azure AD B2C、Entra ID 或第三方 OAuth 整合。
- 帳號密碼用 `scrypt` 雜湊；登入 token 只以 hash 儲存於 server，並有 7 天到期及登出撤銷。
- `Authorization: Bearer` 是 CORS 明確允許 header；登入後所有資料路由由後端 session 主體決定 ownership。
- 不得把 password、token、Authorization header 或 session document 寫入 Application Insights／一般 log。
- email verification、reset password、delete account、rate limit 與 age consent 尚未實作，不能宣稱 production-ready。

## Azure OpenAI 契約

- Client 不直接呼叫模型；endpoint、deployment、API version 與可選 key 只在 Functions 設定。
- 無 key 時使用 `DefaultAzureCredential`／Managed Identity token provider。
- Parse 使用嚴格 JSON Schema，最多五筆 drafts；回覆仍經 Zod 驗證、列舉與數值範圍檢查。
- Lesson 只收到類型、分類、是否週期／分帳與目標名稱，不傳事件金額；輸出若新增未驗證的金額、比例、期限或數量會被拒絕。
- 單次呼叫 timeout 8 秒、整體 budget 12 秒；429 依 `Retry-After` 加 jitter，且最多一次 bounded retry。
- 日誌只記 provider event、attempt、status 與 elapsed time，不記 prompt、原始財務文字或完整 response。
- AI 不計算權威金額、預算、分帳、訂閱成本或複利，也不能直接寫資料庫。

## Deterministic demo provider

此 provider 支援繁中收入、餐飲／交通／娛樂／教育／購物支出、訂閱、中文／阿拉伯數字分帳、缺金額、否定句、多筆、折扣實付、昨天／前天與無關文字。所有 draft 標示 `deterministic-demo`。

它只用於本機 Functions、可重現自動化測試與 30-case 評估；不是 Client 的離線資料來源。不得把 deterministic 結果描述成 Azure OpenAI 模型表現。

## 訂閱資料來源與未整合項目

MVP 方案目錄是版本化合成 fixture，所有 options 帶 `sourceType` 與 `asOf`，畫面明示不是即時市場資訊。AI 不會捏造價格、資格或官方條款。

不整合支付、銀行、電子發票、證券、Apple Pay、LINE Pay、Email、SMS 或真實未成年人金融服務。主辦方若提供共享 Azure 資源，串接前必須確認授權、輪替任何已曝光金鑰，且不得修改其他隊伍 deployment。
