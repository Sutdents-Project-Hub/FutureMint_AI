# FutureMint Fastify API

Node.js 22／TypeScript 後端，提供帳號與 session、Zod 契約、確定性財務計算、量界智算／Demo AI providers、證交所市場資料 adapter，以及 PostgreSQL／Memory repositories。正式部署為 Coolify 中獨立的 `futuremint-api` Application。

## Runtime

- Node.js 22.x，Fastify 5，TypeScript，Zod，Vitest。
- PostgreSQL 17 透過 `pg` 連線；SQL migration 位於 `migrations/`。
- 量界智算由 OpenAI SDK 透過 OpenAI-compatible base URL 呼叫；瀏覽器不會取得 API key。
- API base path 是 `/api`，預設監聽 `0.0.0.0:3000`。
- 全域限制每個來源每分鐘 120 requests；register／login 每分鐘 10 requests。限制器是單一 API instance 的記憶體狀態。

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
| `NODE_ENV` | `development`、`test` 或 `production` |
| `HOST` | 預設 `0.0.0.0` |
| `PORT` | 預設 `3000` |
| `AI_PROVIDER` | 必填：`demo` 或 `liangjie` |
| `DATA_PROVIDER` | 必填：`memory` 或 `postgres` |
| `DATABASE_URL` | PostgreSQL connection URL；`postgres` 模式必填 |
| `DATABASE_SSL` | Coolify private network 使用 `false`；外部 TLS database 才設 `true` |
| `LIANGJIE_BASE_URL` | 建議 `https://liangjiewis.com/v1` |
| `LIANGJIE_MODEL` | 量界帳號實際可用的 model id |
| `LIANGJIE_API_KEY` | 只放 runtime secret |
| `ALLOWED_ORIGINS` | 允許的完整 Web origins，以逗號分隔；不接受萬用 `*` |
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
| GET／PUT | `/api/profile` | Bearer |
| POST | `/api/captures/parse` | Bearer |
| GET／POST | `/api/money-events` | Bearer |
| GET | `/api/dashboard` | Bearer |
| GET | `/api/insights` | Bearer |
| GET | `/api/subscriptions` | Bearer |
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

`/api/market/quotes` 使用不需金鑰的證交所 OpenAPI 每日成交資料，server 端快取 15 分鐘。來源逾時或格式異常時會回明確標示的教育快照，不會把 fallback 冒充即時行情。投資練習場只接受內建教學標的與虛擬買賣，不連券商或交易所下單。

## PostgreSQL migrations 與種子

```bash
npm run migrate
```

Migration runner 建立 `schema_migrations`、使用 PostgreSQL advisory lock，並只執行尚未套用的 SQL。API Docker image 在 `DATA_PROVIDER=postgres` 時會先執行 migration，再啟動服務；失敗時 container 不會假裝 ready。

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

- Base directory：`/services/api`
- Build pack：Dockerfile
- Port：`3000`
- Health check：`/api/health`
- Runtime variables：依上表設定；`DATABASE_URL` 使用 PostgreSQL Resource 的 internal URL
- 不公開 PostgreSQL port，不把秘密設成 build arguments

完整部署順序與 private GitHub 自動部署見 [部署說明](../../docs/deployment.md)。

## 品質

```bash
npm test
npm run typecheck
npm run build
npm run evaluate:captures
npm audit --omit=dev
```

`evaluate:captures` 使用 deterministic provider 驗證 30 筆合成繁中案例；結果不是量界真實模型準確率。即時量界模型、帳號額度與 production latency 必須在取得正式 secret 後另行驗證。
