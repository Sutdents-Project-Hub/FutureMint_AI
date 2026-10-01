# FutureMint Fastify API

Node.js 22／TypeScript 後端，提供帳號與 session、Zod 契約、確定性財務計算、量界智算／官方 OpenAI／Demo AI providers、證交所市場資料 adapter，以及 PostgreSQL／Memory repositories。正式部署為 Coolify 中獨立的 `futuremint-ai-api` Application。

## Runtime

- Node.js 22.x，Fastify 5，TypeScript，Zod，Vitest。
- PostgreSQL 17 透過 `pg` 連線；SQL migration 位於 `migrations/`。
- 量界智算由 OpenAI SDK 透過 OpenAI-compatible base URL 呼叫；瀏覽器不會取得 API key。解析結構經 Zod 驗證；教育功能只讓模型選擇教材主題，正文由受控繁體中文教材提供。
- 所有外部 AI runtime 會在 parse、lesson generate、learning plan 與 coach 四個入口檢查服務資格及當前 `third-party-ai-v2-<fingerprint>` 同意；未同意或 policy version 已過期時於 provider 呼叫前回 `403 ai_consent_required`。
- API base path 是 `/api`，預設監聽 `0.0.0.0:3000`。
- 全域限制每個來源每分鐘 120 requests；register／login 每分鐘 10 requests；會呼叫 AI 的 parse、lesson generate、learning plan 與 coach routes 每分鐘 20 requests。PostgreSQL runtime 的限制器使用資料庫原子計數，跨 API instances 共用；demo memory runtime 僅在該程序內共用。

## 本機執行

不需資料庫或 AI key 的模式：

```bash
npm ci
AI_PROVIDER=demo \
DATA_PROVIDER=memory \
ALLOWED_ORIGINS=http://localhost:4173 \
npm run dev
```

PostgreSQL 模式：

```bash
cp .env.example .env
# 僅在本機、已忽略的 .env 填入 DATABASE_URL 與需要的 AI 設定
npm run migrate
npm run dev
```

健康檢查：

```bash
curl http://localhost:3000/api/health
```

`/api/health` 在 PostgreSQL 無法連線時回 `503`；不會為健康檢查呼叫量界模型。

## 環境變數

| 變數 | 用途 |
|---|---|
| `NODE_ENV` | `development`、`test` 或 `production`；production 只接受 `liangjie` 或 `openai` 配合 `postgres` |
| `HOST` | 預設 `0.0.0.0` |
| `PORT` | 預設 `3000` |
| `AI_PROVIDER` | 必填：`demo`、`liangjie` 或 `openai`；正式預設選用量界 |
| `DATA_PROVIDER` | 必填：`memory` 或 `postgres` |
| `DATABASE_URL` | PostgreSQL connection URL；`postgres` 模式必填 |
| `DATABASE_SSL` | Coolify private network 使用 `false`；外部 TLS database 才設 `true` |
| `LIANGJIE_BASE_URL` | 僅允許 `https://liangjiewis.com/v1`，拒絕 HTTP、任意主機及 URL credentials |
| `LIANGJIE_MODEL` | 量界帳號實際可用的 model id |
| `LIANGJIE_API_KEY` | 只放 runtime secret |
| `ALLOWED_ORIGINS` | 允許的完整 Web origins，以逗號分隔；未填時使用 PUBLIC_BASE_URL；production 只接受不帶 path／尾端 `/` 的 HTTPS origin，不接受萬用 `*` |
| `ALLOW_DEMO_SEED` | 只有受控合成資料 seed 時短暫設為 `true` |

`.env.example` 只放安全 placeholder。真實 `.env`、API key、database URL、密碼與 token 不得提交或寫入 log。

## HTTP API

| Method | Route | Authentication |
|---|---|---|
| GET | `/api/health` | 無 |
| GET | `/api/market/quotes` | 無 |
| POST | `/api/auth/register` | 無 |
| POST | `/api/auth/login` | 無 |
| GET | `/api/auth/me` | Bearer |
| POST | `/api/auth/logout` | Bearer |
| DELETE | `/api/auth/account` | Bearer；再驗證目前密碼 |
| GET／PUT | `/api/privacy/ai-consent` | Bearer |
| GET／PUT | `/api/profile` | Bearer |
| GET | `/api/family` | Bearer |
| POST | `/api/family/invite` | Bearer；家長 |
| POST | `/api/family/join` | Bearer；孩子 |
| POST | `/api/family/leave` | Bearer |
| POST | `/api/captures/parse` | Bearer |
| GET／POST | `/api/money-events` | Bearer |
| PUT／DELETE | `/api/money-events/:eventId` | Bearer；只可操作自己的紀錄 |
| GET | `/api/dashboard` | Bearer |
| GET | `/api/insights` | Bearer |
| GET／POST | `/api/subscriptions` | Bearer；POST 需服務資格 |
| PUT／DELETE | `/api/subscriptions/:subscriptionId` | Bearer；自己的合約與服務資格 |
| GET | `/api/service-policy` | 無 |
| GET | `/api/privacy/eligibility` | Bearer |
| PUT | `/api/privacy/age-declaration` | Bearer |
| GET | `/api/privacy/export` | Bearer；僅本人 JSON |
| GET | `/api/education/catalog` | 公開受控教材，無帳戶資料／AI 呼叫／server completion |
| POST | `/api/privacy/guardian-consent/request` | Bearer |
| POST | `/api/privacy/guardian-consent/confirm`、`/withdraw` | 單次 token |
| POST | `/api/privacy/guardian-consent/withdrawal-request` | 帳號及監護人 Email；generic accepted |
| DELETE | `/api/privacy/guardian-consent` | Bearer |
| POST | `/api/subscriptions/compare` | Bearer |
| POST | `/api/lessons/generate` | Bearer |
| GET | `/api/lessons/current` | Bearer |
| PATCH | `/api/lessons/:lessonId` | Bearer |
| GET | `/api/learning-plan` | Bearer |
| POST | `/api/future-seed/preview` | Bearer |
| POST | `/api/future-seed/simulate` | Bearer |
| GET | `/api/investment-lab` | Bearer |
| POST | `/api/investment-lab/orders` | Bearer |
| POST | `/api/investment-lab/dice` | Bearer |
| POST | `/api/coach/chat` | Bearer |

成功回應包含 `requestId` 與 `data`；錯誤回應包含安全的 `code`、`message`、`retryable` 與 `requestId`，不回傳 stack、SQL、prompt 或 provider response。`insights`、投資曲線、虛擬持倉、成本、配置與訂單限制由 deterministic domain 計算；AI 只提供分類理由、學習規劃與白話解釋。

`/api/coach/chat` 可帶 `style=brief|example|steps`，讓學習頁與 FutureSeed 自訂回答方式。`/api/privacy/ai-consent` 保存當前同意狀態與最近授權／撤回時間；目前不是 append-only 事件帳本。帳號刪除成功後，PostgreSQL FK cascade 會移除 session、profile、events、lessons、虛擬投資、AI consent 與家庭關聯；email 可再註冊。

家庭關聯使用 24 字元 base64url 邀請碼（144-bit 隨機、24 小時到期）；家長回傳的 `childSummaries` 只含預算、收支摘要、可用金額、目標進度與提醒數量，不回傳孩子的 `money_events`。

`/api/market/quotes` 使用不需金鑰的證交所 OpenAPI 每日成交資料，server 端快取 15 分鐘，且同一個 cache miss 只會共用一個上游請求。來源逾時或格式異常時會回明確標示的教育快照，不會把 fallback 冒充即時行情。投資練習場只接受內建教學標的與虛擬買賣，不連券商或交易所下單；PostgreSQL 以帳號 transaction lock 序列化下單，並在鎖內生成 `executionSequence`，跨 API replicas 依此序列重建持倉。

## PostgreSQL migrations 與種子

```bash
npm run migrate
```

Migration runner 建立 `schema_migrations`、使用 PostgreSQL advisory lock，並只執行尚未套用的 SQL。API Docker image 先做無 I/O 的 pure preflight，通過後在 `DATA_PROVIDER=postgres` 時執行 migration，再啟動服務；失敗時 container 不會假裝 ready。

可選的競賽合成種子有明確安全開關：

```bash
ALLOW_DEMO_SEED=true npm run seed:postgres-demo
```

它建立無法登入的 synthetic account、profile 與四筆固定事件，可重複執行且不建立真實使用者。未設 `ALLOW_DEMO_SEED=true` 時會在寫入前拒絕。

## Docker／Coolify

```bash
docker build -t futuremint-api .
```

Coolify Application 設定：

- Base directory：`/backend`
- Build pack：Dockerfile
- Port：`3000`
- Health check：`/api/health`
- Runtime variables：依上表設定；`DATABASE_URL` 使用 PostgreSQL Resource 的 internal URL
- 不公開 PostgreSQL port，不把秘密設成 build arguments

production 啟動會驗證 `AI_PROVIDER=liangjie|openai`、`DATA_PROVIDER=postgres` 與至少一個合法 HTTPS origin（ALLOWED_ORIGINS 未填時使用 PUBLIC_BASE_URL）；任何一項不符會在 listen 前退出，不能以 health 200 掩蓋錯誤設定。API 只信任 `TRUSTED_PROXY_CIDRS` 指定的 proxy IP／CIDR，VPS firewall 不得讓使用者直接繞過 proxy 連 API container。

完整部署順序與 private GitHub 自動部署見 [部署說明](../docs/deployment.md)。

## 品質

```bash
npm test
npm run typecheck
npm run build
npm run evaluate:captures
npm audit --omit=dev
```

`evaluate:captures` 使用 deterministic provider 驗證 30 筆合成繁中案例；結果不是量界真實模型準確率。即時量界模型、帳號額度與 production latency 必須在取得正式 secret 後另行驗證。

## 正式環境與帳號恢復

Production 需真實公開政策設定；最小變數見 `.env.coolify.example`，完整選項見 `.env.example`。MAIL_PROVIDER 未填／disabled 不要求 SMTP 憑證，可啟動 API，但新註冊及新的驗證／重設／監護人寄信停用；既有帳號仍需通過原驗證與資格門檻。設定 smtp 才啟用完整新帳號流程。本機 demo 可免驗證，不代表 production 可繞過驗證。

新增 API：`POST /api/auth/email-verification/request`（Bearer）、`POST /api/auth/email-verification/confirm`（token）、`POST /api/auth/password-reset/request`（email）、`POST /api/auth/password-reset/confirm`（token/password）。密碼沿用 12–128 字元、英文字母及數字規則。家庭邀請可用 `POST /api/family/invite/rotate` 更新、`DELETE /api/family/invite` 停用。

公開路徑 `/privacy`、`/support`、`/account/verify`、`/account/reset-password`、`/public.css`、`/account-actions.js` 均由此 API Resource 服務。公開政策未確認時前兩頁回 503。未驗證帳號的 `/api/auth/me`、重寄驗證、登出及刪除仍可使用；業務資料 API 回 `email_verification_required`。

## 訂閱、分頁與啟動契約

POST `/api/subscriptions` 必填 `idempotencyKey`，名稱、`amountMinor`（TWD 整數）、月／年週期及 `anchorDate`；可選 `initialPayment` 或 `legacyPaymentId`，兩者互斥並與合約同交易保存。相同 key／完整 payload 回原結果，不同 payload 回 409；事件與虛擬訂單同樣保護重試。合約有 stable ID、owner、原扣款日／月、future next billing date 與 active，停止不刪實付。

GET `/api/subscriptions` 回 `items`、`monthlyCommitmentMinor`、`legacyCandidates`；付款 MoneyEvent 可帶 `subscriptionId`，月承諾成本與實付分析分開。GET `/api/money-events` 帶 query 時使用 cursor、預設 limit 50／最多 100，無 query 保留舊 array 相容；dashboard／insights 不依單頁統計。

設定以 `src/config/aiConfig.ts`、`startupConfig.ts` 及 `src/http/runtime.ts` 為準，完整名稱見 `.env.example`。`npm run preflight` 驗證設定不開 socket、寄信、讀資料庫或 migration；Docker 在 migration 前執行，失敗只輸出安全變數名稱／階段，不含 values。migrations 008／009／010／011 為 additive，舊 checksum 不變。年齡、監護人／AI 政策與額度見 [安全](../docs/security-and-privacy.md)及[整合](../docs/integrations.md)。

隔離備份還原可使用 `node dist/scripts/reconcileRestoredAccounts.js export|preview|apply /protected/latest.deletion-journal.json`。刪除 journal 只保存帳號 ID 雜湊與時間；套用 011 後才開始記錄。來源與還原必須不同資料庫名稱，apply 需維運確認無流量；完整 secret／保留／切換流程見 [部署文件](../docs/deployment.md#9-隔離還原與刪除帳號對帳)。

## 簡化設定與功能狀態

公開政策版本、最低年齡15、未成年人說明、通用AI說明及備份0天有內建預設；覆寫仍會驗證。ALLOWED_ORIGINS 可省略，採 API 自身 PUBLIC_BASE_URL。真實營運者／客服／資料地區與 PRIVACY_POLICY_REVIEWED=true 仍為 production 啟動條件。

`src/config/providerPolicies.ts` 維護公開供應商資料，初始 reviewed=false；既有 LIANGJIE_/OPENAI_DATA_* 可覆寫。缺少完整說明或未確認時，API 可啟動但授權／呼叫外部 AI 回 ai_policy_unavailable。單改 reviewed=true 而未提供條款仍拒絕啟動。mail_disabled 與 registration_disabled 明確回報功能未開放，不冒充已寄信。

`GET /api/service-policy` 增加 mailEnabled／registrationEnabled；公開支援頁顯示當前寄信狀態。Flutter UIUX 不改動，既有錯誤處理顯示上述訊息。未設定 SMTP 的訪客資料不永久保存。最小刪除 journal 仍保留；備份天數不控制或自動清除 Coolify 的排程／既有副本。
