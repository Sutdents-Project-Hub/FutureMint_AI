# FutureMint AI Azure Direct Deployment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 不使用虛擬機，將 FutureMint AI 以 Azure Serverless 架構部署成可公開操作、可觀測、可回滾的決賽環境。

**Architecture:** Flutter Web 發布至 Azure Static Web Apps；TypeScript API 發布至 Azure Functions Flex Consumption；Functions 以 System Assigned Managed Identity 呼叫 Azure OpenAI／Foundry 與 Cosmos DB for NoSQL，並把去識別遙測送至 Application Insights。部署採雲端分段驗證：先 Functions＋真實 AI，再 Cosmos，最後 Web，以縮小故障範圍。

**Tech Stack:** Flutter Web、Azure Static Web Apps、Azure Functions v4／Node.js 22、Azure OpenAI／Foundry、Azure Cosmos DB for NoSQL、Application Insights、Azure CLI、Azure Functions Core Tools、Static Web Apps CLI。

## Global Constraints

- 不建立 VM、AKS、App Service container、API Management 或其他 MVP 不需要的常駐基礎設施。
- 只使用合成 `demo-user` 資料；不匯入真實學生、銀行、支付或訂閱帳號資料。
- Flutter bundle 不得含 OpenAI key、Cosmos key、connection string、deployment token 或管理權杖。
- Azure OpenAI 與 Cosmos 優先使用 Function App 的 System Assigned Managed Identity。
- 目前帳號不能自行指派 RBAC；完整資料路徑上線前，必須由主辦方管理者完成角色指派。
- 共享 Portal 曾顯示過的 Azure OpenAI key 視為已曝光；只有輪替後的新 key 才能作為短期備援。
- 本計畫不授權 git commit、push、PR、release 或 production promotion。
- 依使用者指示跳過完整本機測試；仍執行 `npm run build` 與 `flutter build web --release`，因為它們是部署必要步驟。

---

## File and resource map

| Item | Responsibility |
|---|---|
| `backend` | Functions API、Azure AI orchestration、Cosmos access、deterministic calculations |
| `app` | Connected-mode Flutter Web client |
| `docs/deployment.md` | 實際 Azure resource、URL、部署與回滾證據 |
| `docs/testing-and-evidence.md` | 雲端 smoke／integration 驗證結果，不與 mock 混稱 |
| `docs/azure-resources.md` | 最終資源選型、區域、RBAC 與費用控制 |
| Azure Functions Flex Consumption | 公開 `/api/*` 與可信任後端 |
| Azure OpenAI／Foundry | 自然語言解析與微課生成 |
| Cosmos DB for NoSQL | `profiles`、`moneyEvents`、`learning` persistence |
| Azure Static Web Apps | Flutter Web production artifact |
| Application Insights | 去識別 request、failure、latency 與 AI provider telemetry |

### Task 1: Azure preflight and authorization gate

**Files:**
- Read: `docs/azure-resources.md`
- Read: `docs/security-and-privacy.md`
- Modify after verification: `docs/deployment.md`

**Interfaces:**
- Consumes: 主辦方允許使用的 subscription、resource group、Azure OpenAI resource 與 deployment。
- Produces: 已選定的 subscription、region、resource names 與權限證據。

- [ ] **Step 1: 登入並確認授權 subscription**

```bash
az login
az account list --output table
az account set --subscription "$AZURE_SUBSCRIPTION_ID"
az account show --query '{id:id,name:name,tenantId:tenantId}' --output json
```

Expected: selected subscription 與主辦方授權一致；輸出不含 token 或 API key。

- [ ] **Step 2: 確認 resource providers 與 Flex region**

```bash
az provider show --namespace Microsoft.Web --query registrationState --output tsv
az provider show --namespace Microsoft.DocumentDB --query registrationState --output tsv
az provider show --namespace Microsoft.Insights --query registrationState --output tsv
az functionapp list-flexconsumption-locations --output table
```

Expected: providers 為 `Registered`，且 Azure OpenAI 鄰近區域支援 Flex Consumption。

- [ ] **Step 3: 確認管理者能指派兩個角色**

```text
Azure OpenAI: Cognitive Services OpenAI User
Cosmos DB: Cosmos DB Built-in Data Contributor
Principal: FutureMint Function App system-assigned managed identity
```

Expected: 管理者確認可指派；否則 Cosmos 完整模式暫時 blocked，只能先用 `DATA_PROVIDER=memory`。

### Task 2: Create the serverless Azure resources

**Files:**
- Modify after creation: `docs/azure-resources.md`
- Modify after creation: `docs/deployment.md`

**Interfaces:**
- Consumes: Task 1 的 resource group 與 region。
- Produces: Function App、identity principal ID、Cosmos schema、Static Web App hostname、Application Insights。

- [ ] **Step 1: 在 Portal 建立 Node.js 22 Flex Consumption Function App**

```text
Hosting option: Flex Consumption
Runtime stack: Node.js 22
Operating system: Linux
Application Insights: Enabled
Deployment source: not configured yet
```

Expected: Function Overview 顯示 Flex Consumption 與 Node.js 22。

- [ ] **Step 2: 啟用 system-assigned identity**

```bash
az functionapp identity assign \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$FUNCTION_APP_NAME"

export FUNCTION_PRINCIPAL_ID="$(az functionapp identity show \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$FUNCTION_APP_NAME" \
  --query principalId --output tsv)"

test -n "$FUNCTION_PRINCIPAL_ID"
```

Expected: command exits 0 and principal ID is non-empty。

- [ ] **Step 3: 建立 Cosmos database 與 containers**

先建立專用 Cosmos DB for NoSQL account；共享訂閱允許時選 Serverless，否則使用主辦方核准的最低 provisioned 選項。接著執行：

```bash
az cosmosdb sql database create \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --account-name "$COSMOS_ACCOUNT_NAME" \
  --name "$COSMOS_DATABASE_NAME"

for container in profiles moneyEvents learning; do
  az cosmosdb sql container create \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --account-name "$COSMOS_ACCOUNT_NAME" \
    --database-name "$COSMOS_DATABASE_NAME" \
    --name "$container" \
    --partition-key-path /userId
done
```

Expected: 三個 containers 都存在，partition key 都是 `/userId`。

- [ ] **Step 4: 建立沒有 GitHub integration 的 Static Web App**

Portal 使用 Free plan 與 deployment source `Other`，再取得 hostname：

```bash
export STATIC_WEB_HOSTNAME="$(az staticwebapp show \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$STATIC_WEB_APP_NAME" \
  --query defaultHostname --output tsv)"

test -n "$STATIC_WEB_HOSTNAME"
```

Expected: hostname 非空且使用 Azure Static Web Apps domain。

### Task 3: Apply least-privilege identity and settings

**Files:**
- Read: `backend/.env.example`
- Modify after verification: `docs/deployment.md`

**Interfaces:**
- Consumes: Function principal、OpenAI resource/deployment、Cosmos endpoint/database、SWA hostname。
- Produces: 不需在 Flutter 放 secret 的 Azure runtime。

- [ ] **Step 1: 由管理者指派 Azure OpenAI role**

```text
Scope: authorized Azure OpenAI resource
Role: Cognitive Services OpenAI User
Member: FUNCTION_PRINCIPAL_ID
```

Expected: role assignment 可見並完成 propagation。

- [ ] **Step 2: 由管理者指派 Cosmos native data-plane role**

```text
Scope: dedicated Cosmos account or database
Role: Cosmos DB Built-in Data Contributor
Principal: FUNCTION_PRINCIPAL_ID
```

Expected: `az cosmosdb sql role assignment list` 顯示正確 principal 與 scope。

- [ ] **Step 3: 設定 Function App Settings**

```bash
az functionapp config appsettings set \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$FUNCTION_APP_NAME" \
  --settings \
    AI_PROVIDER=azure \
    DATA_PROVIDER=memory \
    DEMO_RESET_ENABLED=false \
    ALLOW_DEMO_SEED=false \
    AZURE_OPENAI_ENDPOINT="$AZURE_OPENAI_ENDPOINT" \
    AZURE_OPENAI_DEPLOYMENT="$AZURE_OPENAI_DEPLOYMENT" \
    AZURE_OPENAI_API_VERSION=2024-10-21 \
    COSMOS_ENDPOINT="$COSMOS_ENDPOINT" \
    COSMOS_DATABASE_NAME="$COSMOS_DATABASE_NAME" \
    ALLOWED_ORIGINS="https://$STATIC_WEB_HOSTNAME"
```

Expected: settings 成功；Azure 自動建立的 `APPLICATIONINSIGHTS_CONNECTION_STRING` 仍存在；Managed Identity 可用時不設定 `AZURE_OPENAI_API_KEY`。

### Task 4: Deploy Functions and prove real Azure AI first

**Files:**
- Deploy from: `backend`
- Modify with results: `docs/testing-and-evidence.md`

**Interfaces:**
- Consumes: `AI_PROVIDER=azure`、初始 `DATA_PROVIDER=memory`。
- Produces: live Functions API 與 `source: azure-ai` 的真實模型回覆。

- [ ] **Step 1: 產生部署 artifact**

```bash
cd backend
PATH="/opt/homebrew/opt/node@22/bin:$PATH" npm ci
PATH="/opt/homebrew/opt/node@22/bin:$PATH" npm run build
```

Expected: TypeScript build exits 0；完整本機 test suite 依使用者指示延後。

- [ ] **Step 2: Publish Functions**

```bash
func azure functionapp publish "$FUNCTION_APP_NAME"
```

Expected: publish exits 0 and lists FutureMint routes。

- [ ] **Step 3: 驗證 liveness 與真實 AI**

```bash
curl --fail-with-body "https://$FUNCTION_APP_NAME.azurewebsites.net/api/health"

curl --fail-with-body \
  --request POST \
  "https://$FUNCTION_APP_NAME.azurewebsites.net/api/captures/parse" \
  --header 'Content-Type: application/json' \
  --data '{"text":"今天買珍奶 75 元","locale":"zh-TW","referenceTime":"2026-07-13T12:00:00+08:00"}'
```

Expected: health 200；parse 200 且 draft 的 `source` 為 `azure-ai`。401/403 優先檢查 RBAC；404 檢查 deployment name；429 檢查共享 quota。

### Task 5: Enable Cosmos persistence and seed synthetic data

**Files:**
- Execute: `backend/scripts/seedCosmosDemo.ts`
- Modify with results: `docs/testing-and-evidence.md`

**Interfaces:**
- Consumes: 已驗證 AI 路徑與 Cosmos identity role。
- Produces: persistent `demo-user` data 與 `DATA_PROVIDER=cosmos` runtime。

- [ ] **Step 1: 暫時授予部署者 Cosmos data role**

Expected: 目前 `az login` 使用者只在專用合成 database／account 有 `Cosmos DB Built-in Data Contributor`；seed 完成後移除不再需要的個人角色。

- [ ] **Step 2: 執行 guarded idempotent seed**

```bash
cd backend
ALLOW_DEMO_SEED=true \
COSMOS_ENDPOINT="$COSMOS_ENDPOINT" \
COSMOS_DATABASE_NAME="$COSMOS_DATABASE_NAME" \
npm run seed:cosmos-demo
```

Expected: 固定合成 profile/events 寫入；重跑不重複新增事件。

- [ ] **Step 3: 將 runtime 切到 Cosmos**

```bash
az functionapp config appsettings set \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$FUNCTION_APP_NAME" \
  --settings DATA_PROVIDER=cosmos
```

Expected: Functions restart successfully。

- [ ] **Step 4: 驗證真實 persistence**

```bash
curl --fail-with-body "https://$FUNCTION_APP_NAME.azurewebsites.net/api/profile"
curl --fail-with-body "https://$FUNCTION_APP_NAME.azurewebsites.net/api/dashboard"
```

Expected: 兩者都從 seeded `demo-user` 回 200；同一 idempotency key 重送得到相同 event ID。

### Task 6: Build and deploy connected Flutter Web

**Files:**
- Deploy from: `app`
- Artifact: `app/build/web`
- Modify with final URL: `README.md`
- Modify with final URL: `docs/deployment.md`

**Interfaces:**
- Consumes: live Functions `/api/` URL 與 Static Web App。
- Produces: public connected-mode Flutter Web app。

- [ ] **Step 1: 建置 Connected Web**

```bash
cd app
flutter pub get
flutter build web --release \
  --dart-define=APP_MODE=connected \
  --dart-define=API_BASE_URL="https://$FUNCTION_APP_NAME.azurewebsites.net/api/"
```

Expected: build 0；`build/web/index.html` 存在；URL 含尾端 `/api/` 且沒有 secret。

- [ ] **Step 2: 用短效 SWA token 發布**

```bash
export SWA_CLI_DEPLOYMENT_TOKEN="$(az staticwebapp secrets list \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$STATIC_WEB_APP_NAME" \
  --query properties.apiKey --output tsv)"

swa deploy build/web --env production
unset SWA_CLI_DEPLOYMENT_TOKEN
```

Expected: production deployment 成功；token 不被輸出、寫檔或提交。

- [ ] **Step 3: 跑公開 browser smoke flow**

```text
Open https://STATIC_WEB_HOSTNAME
Confirm Connected mode
Parse 「今天買珍奶 75 元」 and verify Azure AI source
Edit and confirm the draft
Reload and verify Cosmos persistence
Open dashboard, subscription comparison, lesson and FutureSeed
```

Expected: 無 CORS error；reload 後資料存在；browser source／network 不出現 Azure secret。

### Task 7: Observe, correct and establish rollback evidence

**Files:**
- Modify: `docs/testing-and-evidence.md`
- Modify: `docs/deployment.md`
- Modify: `docs/competition.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: live Web/API/AI/Cosmos environment。
- Produces: cloud issue list、verified fixes、monitoring evidence、URLs 與 rollback procedure。

- [ ] **Step 1: 檢查 Application Insights**

```text
Function App → Application Insights → Failures
Function App → Application Insights → Performance
Function App → Application Insights → Live Metrics
```

Expected: 可見 request、duration、status 與安全 `futuremint_ai_provider` event；看不到 raw capture、prompt、Authorization 或完整 model response。

- [ ] **Step 2: 分類平台問題後才修正**

```text
Azure OpenAI: 429, token quota, latency
Cosmos DB: throttled requests, normalized RU
Functions: 5xx, duration, cold start
Static Web Apps: production deployment status
```

Expected: 每個問題先分類為 configuration、identity、quota、CORS、application contract 或 platform availability。

- [ ] **Step 3: 同步真實部署證據**

將實際 resource names、region、公開 URL、執行指令、smoke 結果、剩餘問題、rollback artifact 與費用／quota alerts 寫入四份文件。不得記錄 subscription ID、tenant ID、principal ID、token、key、connection string 或個人帳號資料。

Expected: 只有相關 Azure resources 與 smoke tests 確實成功後，文件才將狀態由「尚未部署」改為「已部署」。

- [ ] **Step 4: 建立 rollback 路徑但不執行 git 操作**

```text
Web: 保留最後成功 `build/web` artifact 或 SWA deployment。
API: 保留最後成功 Functions source/artifact。
Data: 不做破壞性 migration，只用 guarded seed 重建合成資料。
AI: 必要時明確切成 AI_PROVIDER=demo 降級，不冒充 Azure AI 成功。
```

Expected: 不刪 Cosmos account、不修改其他隊伍 shared resource，就能恢復最後可用 Demo。

## Self-review

- Spec coverage: resources、identity、AI、Cosmos、Web、CORS、monitoring、seed、rollback 與文件皆有任務。
- Scope: 沒有 VM、付款、銀行、真實未成年人資料、登入、CI/CD、自訂網域或無關重構。
- Secret boundary: 敏感值只在 Azure App Settings、短暫環境變數或 Managed Identity。
- Cloud truthfulness: Azure AI、Cosmos 與 hosting 的 HTTPS smoke tests 通過前，不宣稱已完成。
