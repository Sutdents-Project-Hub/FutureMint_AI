# FutureMint Functions API

FutureMint AI 的可信任後端，提供 Azure Functions v4 HTTP API、Zod 契約、確定性財務計算、Azure OpenAI／Demo AI providers，以及 Cosmos DB／Memory repositories。

## 技術證據與前置需求

- Node.js 22.x、Azure Functions Runtime／Core Tools 4.x、TypeScript。
- Manifest 為 `package.json`，package manager／lockfile 為 npm／`package-lock.json`。
- 主要依賴：`@azure/functions`、`@azure/cosmos`、`@azure/identity`、OpenAI SDK、Zod；測試使用 Vitest。
- 只有 `npm start` 需要 Functions Core Tools；test、typecheck、build 與 evaluation 可直接使用 Node.js 22 執行。

## API routes

- `GET /api/health`
- `GET|PUT /api/profile`
- `POST /api/captures/parse`
- `GET|POST /api/money-events`（GET 可用 `type`、`from`、`to` 篩選）
- `GET /api/dashboard`
- `GET /api/subscriptions`
- `POST /api/subscriptions/compare`
- `POST /api/lessons/generate`
- `GET /api/lessons/current`
- `PATCH /api/lessons/{lessonId}`
- `POST /api/future-seed/preview`
- `POST /api/demo/reset`（只在明確啟用的非 production Demo）

所有回應都有去識別 `requestId`；錯誤使用穩定 `code`、繁中 `message`、`retryable` 與可選 `fieldErrors`，不回傳 stack、prompt 或環境值。

`GET /api/health` 是 runtime 設定與進程存活檢查，不會主動呼叫 Cosmos 或 Azure OpenAI，不得當成雲端依賴已通過的 readiness 證據。

## 執行與品質

需要 Node.js 22.x；啟動 host 另需 Azure Functions Core Tools 4.x。

```bash
npm ci
npm test
npm run typecheck
npm run build
npm run evaluate:captures
npm audit --omit=dev
npm start
```

`evaluate:captures` 會建置程式、執行 30 筆合成繁中 deterministic-provider 案例，並更新 `reports/capture-evaluation.json` 與 `.md`。這不是 Azure OpenAI 成效證據。

## Provider 設定

本機實際值放在已忽略的 `local.settings.json`，部署值放 Functions App Settings／受控 secret store。`.env.example` 只列安全名稱。

| 變數 | 可用值／用途 |
|---|---|
| `AI_PROVIDER` | `demo` 或 `azure`；不可省略或猜測 |
| `DATA_PROVIDER` | `memory` 或 `cosmos`；不可省略或猜測 |
| `DEMO_RESET_ENABLED` | 是否開啟 reset route |
| `ALLOW_DEMO_SEED` | 只在已授權合成 Cosmos Demo 環境執行 seed 時短暫設為 `true` |
| `AZURE_OPENAI_ENDPOINT` | Azure provider endpoint |
| `AZURE_OPENAI_DEPLOYMENT` | deployment 名稱 |
| `AZURE_OPENAI_API_VERSION` | API version |
| `AZURE_OPENAI_API_KEY` | Managed Identity 不可用時才使用 |
| `COSMOS_ENDPOINT` | Cosmos account endpoint |
| `COSMOS_DATABASE_NAME` | database name |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | 去識別監測 |
| `ALLOWED_ORIGINS` | 明確允許的 Client origins |

本機 Connected Web 若使用 `--web-port=4173`，將 `ALLOWED_ORIGINS` 設為 `http://localhost:4173`。多個 origin 以逗號分隔；未在名單中的 preflight 會回覆 403，不使用任意 `*`。

Azure provider 單次模型 timeout 為 8 秒、總預算 12 秒，429 只做一次受控重試。Cosmos 使用 `profiles`、`moneyEvents`、`learning` containers 與 `/userId` partition key；程式不會自動建立雲端資源。

### 受控 Cosmos 合成種子

Repository 提供可重複執行的 `npm run seed:cosmos-demo`，只會寫入固定 `demo-user` 合成 profile 與四筆帶 idempotency key 的合成事件。它不會建立 Azure 資源或 containers，也不會刪除資料。

只能在已取得雲端寫入授權、且已確認 database 為專用競賽合成環境時執行：

```bash
ALLOW_DEMO_SEED=true \
COSMOS_ENDPOINT=<authorized-endpoint> \
COSMOS_DATABASE_NAME=<authorized-database> \
npm run seed:cosmos-demo
```

預設缺少 `ALLOW_DEMO_SEED=true` 會拒絕寫入。真實 endpoint 與權限只放在 Functions App Settings／已忽略本機設定，不寫入 repository。

## 安全邊界

- 原始 capture 文字不寫入 event 或 log。
- 只有 `confirmed: true` 且契約合法的 payload 可以保存。
- `userId` 查詢與 idempotency key 防止越界與重複事件。
- AI 不計算權威金額，也不能直接決定資料庫寫入。
- Managed Identity 可用時優先於 API key／Cosmos key。

目前尚未建立 Azure 資源或驗證即時 Azure 連線。相關文件：[外部整合](../../docs/integrations.md)、[資料與儲存](../../docs/data-and-storage.md)、[部署](../../docs/deployment.md)。
