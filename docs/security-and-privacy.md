# 安全、身份與隱私

## 身份與授權

- Email/password registration 與 login 由 Fastify API 處理。
- Password 以 Node.js scrypt、每個帳號隨機 salt 與 timing-safe compare 驗證；資料庫不保存明文 password。
- Session token 使用 cryptographically random bytes，Client 只收到明文 token；PostgreSQL 只保存 SHA-256 token hash。
- Session 七天到期；logout 設 revoked timestamp。
- API 每次從 session 推導 account，所有 repository query 都依 account `user_id`；不接受 Client 指定 ownership。

這是競賽 prototype authentication，不是 production identity system。目前的孩子／家長欄位只控制內容視角，不代表親子關係、授權或跨帳號存取。尚未實作 email ownership verification、password reset、MFA、global logout、帳號鎖定、breached-password screening、CSRF cookie flow、帳號刪除或家長共管。

## API 邊界

- Fastify body limit 32 KiB；Zod 驗證 request。
- CORS 僅允許 `ALLOWED_ORIGINS` 完整 origins；production 只放正式 frontend HTTPS domain。
- 全域 rate limit 120 requests／minute；auth routes 10 requests／minute；AI 產生／陪讀 routes 20 requests／minute。現況為單 instance memory counter，水平擴充前應改 shared store／edge rate limit。
- Response 使用 no-store、nosniff、frame deny、referrer policy 與 restrictive CSP。
- PostgreSQL query 全部使用 parameter placeholders。
- AI 回覆視為不可信任：去 fence／抽 JSON 後再做 schema、列舉、金額、日期與範圍驗證。
- 金額、預算、訂閱、六個月收支與三條投資情境由 deterministic code 計算；AI 不產生資產數值。
- 虛擬投資價格只由後端市場 adapter 選取，Client 不可自訂成交價；後端驗證現金、持有量、教學標的與 idempotency。
- 公開市場 route 只回傳已篩選的 TWSE 日資料並有獨立 rate limit；不含使用者、帳號或投資組合資訊。

## 秘密

只放 API Coolify runtime environment：

- `DATABASE_URL`
- `LIANGJIE_API_KEY`
- 其他未來的 backend credentials

可公開但仍需正確設定：

- Flutter build argument `API_BASE_URL`
- API `ALLOWED_ORIGINS`
- `LIANGJIE_BASE_URL` 與 model id（不是 authentication secret）

本機秘密只放已忽略的 `backend/.env`。歷史上可能存在的 ignored `local.settings.json` 不再使用，也不得讀取、提交或複製。GitHub repository、Dockerfile、build arguments、Flutter bundle、文件、測試 fixture 與 log 都不得含真實 key、password、token、connection URL 或學生資料。

## Log 與錯誤

- API log 只記 request ID、route outcome、provider event type 與安全的 latency／錯誤類型。
- 不記錄 Authorization header、email、password、session token、capture 原文、完整財務事件、prompt、AI response、SQL connection string 或 stack response。
- Client 只顯示可操作的安全錯誤；server error 不回 SDK／SQL／stack detail。
- 正式 reverse proxy access log、Coolify build log 與 PostgreSQL log 也需檢查 retention 與存取權限。

## 隱私與外部 AI

量界智算會收到單次 capture 原文；學習規劃只送角色、分類與布林／加總摘要，陪讀只送使用者問題與所選合成情境，不送完整流水。它仍是外部資料處理邊界。比賽只輸入合成資料。任何真實未成年人資料使用前，都必須先取得適當同意、確認 relay／上游模型的資料條款、設定保留與刪除流程，並完成法遵與 incident response。

TWSE OpenAPI 是另一個外部可用性邊界，但 request 只要求公開市場資料，不傳帳號、持倉、訂單或任何個資。內建標的與事件骰子都必須標示為教育範例，不得以推薦、勝率、排名或獎勵高風險交易的方式呈現。

## 部署 checklist

- Coolify 與 GitHub 帳號啟用 MFA，GitHub App 只授權單一 private repository。
- PostgreSQL 不公開 port；使用 internal URL 與唯一高強度 credentials。
- Frontend／API 強制 HTTPS；`ALLOWED_ORIGINS` 不含 `*` 或 preview wildcard。
- Secret 只設 runtime，部署或截圖前遮蔽。
- Scheduled backup 寫入團隊控制的 S3-compatible storage，並實際 restore。
- 上線前輪替任何曾貼在聊天、截圖、PDF 或 log 的測試 key。
