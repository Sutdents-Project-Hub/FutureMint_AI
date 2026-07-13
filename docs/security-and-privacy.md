# 安全、身份與隱私

FutureMint AI 面向青少年，因此即使決賽只用合成資料，也把金額、商家、時間、訂閱與個人目標視為敏感資料。

## 已落實控制

- 預設 `offline-demo`，只使用合成 `demo-user`；UI 明示資料與解析來源。
- Capture 原文不持久化、不進監測 log；未確認 draft 不寫入帳本。
- Client bundle 只有公開 API URL／mode，不含 Azure OpenAI、Cosmos、Application Insights secret。
- Functions 用 Zod 驗證輸入、固定 user boundary、positive integer TWD 與 controlled enums。
- Azure AI 回覆視為不可信任資料；schema invalid、timeout、429 回安全錯誤，不傳 stack／prompt／SDK response。
- Cosmos query 依 `/userId` partition，寫入使用 idempotency key；不重複建立事件。
- CORS 只讀 `ALLOWED_ORIGINS`，不使用帶 credentials 的任意 `*`。
- FutureSeed 明示假設與教育用途，不推薦投資標的或保證報酬。
- 教練文案採非責備語氣，不污名化必要支出。

## Secrets 與 repository

- 本機 Functions 真實值只放已忽略的 `services/api/local.settings.json`。
- `.env.example` 只保留名稱與安全 placeholder。
- Azure 部署值放 App Settings／受控 secret store；可行時以 Managed Identity 取代 key。
- API key、token、password、private key、cookie、production `.env`、真實學生／客戶資料與合約／商業文件不得寫入程式、log、文件或 commit。
- 若共享 Portal 曾顯示可查看的 key，串接前由資源管理者輪替；不得複製、使用或提交暴露值。

## 明確限制

MVP 沒有正式登入、家長共管、同意紀錄、production retention、自助刪除、未成年人法遵流程或事件應變機制。因此只能作為使用合成資料的競賽原型，不宣稱適合真實學生 production 使用。

若未來加入真實帳號或資料，必須先完成：

1. 年齡適當的隱私告知與可驗證同意；
2. 角色／ownership／刪除與資料可攜；
3. 明確保留期限、備份刪除與 incident response；
4. 威脅模型、權限測試與法務／競賽授權審查。
