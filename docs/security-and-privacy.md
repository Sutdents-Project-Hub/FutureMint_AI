# 安全、身份與隱私

FutureMint AI 面向青少年，因此即使決賽只用合成資料，也把 email、金額、商家、時間、訂閱與個人目標視為敏感資料。

## 已落實控制

- 電子郵件／密碼註冊與登入由 Functions 處理；Client 不持有 Azure secret，也不決定使用者 ID。
- 密碼以每帳號隨機 salt 的 `scrypt` 雜湊保存；API 永不回傳 password hash、salt 或明文。
- Session 使用隨機 opaque token，server 僅保存 SHA-256 hash；token 7 天到期、登出可撤銷，保護路由要求 Bearer token。
- Capture 原文不持久化、不進監測 log；未確認 draft 不寫入帳本。
- 訪客模式資料只存在 App 記憶體，沒有瀏覽器／裝置持久化或後端寫入。
- Functions 用 Zod 驗證輸入；資料 ownership 一律從 session 帳號主體推導。
- Azure AI 回覆視為不可信任資料；schema invalid、timeout、429 回安全錯誤，不傳 stack／prompt／SDK response。
- Cosmos query 依 `/userId` partition，寫入使用 idempotency key；不重複建立事件。
- CORS 只讀 `ALLOWED_ORIGINS`，允許明確的 `authorization` header，不使用帶 credentials 的任意 `*`。
- FutureSeed 明示假設與教育用途，不推薦投資標的或保證報酬。

## Secrets 與 repository

- 本機 Functions 真實值只放已忽略的 `services/api/local.settings.json`。
- `.env.example` 只保留名稱與安全 placeholder。
- Azure 部署值放 App Settings／受控 secret store；可行時以 Managed Identity 取代 key。
- API key、token、password、private key、cookie、production `.env`、真實學生／客戶資料與合約／商業文件不得寫入程式、log、文件或 commit。
- 若共享 Portal 曾顯示可查看的 key，串接前由資源管理者輪替；不得複製、使用或提交暴露值。

## 明確限制

這是競賽原型，不是 production identity system。尚未有 email 驗證、忘記密碼、帳號刪除、rate limiting、登入嘗試防護、session 裝置管理、年齡／監護同意、正式保留／刪除流程、資安事件應變或法律審查。因此只適合使用合成資料的競賽展示，不應收集或宣稱可安全處理真實未成年人資料。

若未來加入真實帳號或資料，必須先完成：

1. 年齡適當的隱私告知與可驗證同意；
2. 角色／ownership／刪除與資料可攜；
3. 明確保留期限、備份刪除與 incident response；
4. 威脅模型、rate limit、權限測試與法務／競賽授權審查。
