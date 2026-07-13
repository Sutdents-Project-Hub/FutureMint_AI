# Azure 資源規劃

## 原則

Azure 服務不是用得越多越好。決賽只採用能直接證明核心價值、提高可靠度或保護資料的資源；每個資源都要能回答「它服務哪個使用者流程」與「不用它會失去什麼」。

## 建議採用

| Azure 服務 | 用途 | MVP 優先度 | 備註 |
|---|---|---:|---|
| Static Web Apps | 託管 Flutter Web `build/web` | P0 | 適合靜態 SPA；API 可分離部署 |
| Functions Flex Consumption | TypeScript API、AI 協調、規則與資料存取 | P0 | 目標 Node.js 22；注意 cold start、timeout 與區域 |
| Azure OpenAI／Foundry | 結構化交易解析、微課程與教練回饋 | P0 | 優先使用支援 structured outputs 的既有 `gpt-5` deployment；名稱從後端設定注入 |
| Cosmos DB for NoSQL | 使用者、金錢事件、訂閱與學習狀態 | P0 | Free tier 與 serverless 是不同容量選項，建立前依額度與 demo 流量選一種 |
| Application Insights | API、AI 延遲、失敗、429 與例外 | P0 | 日誌去識別，不收集財務全文 |
| Blob Storage | Demo 素材或日後檔案上傳 | P2 | MVP 若只有文字與結構化資料可不建 |
| Key Vault | 管理非 Managed Identity 可取代的秘密 | P2 | 決賽規模可先用受控 App Settings，正式化再導入 |

## 暫不採用

- AKS、VM、Service Fabric：維運成本遠高於本次 serverless 需求。
- Redis、Service Bus、Event Hubs：目前沒有高併發快取、非同步工作或事件串流證據。
- Synapse、Data Lake、Data Factory、Power BI：決賽資料量小，Flutter 內建視覺化即可；BI 不是核心 AI 證據。
- API Management、Front Door、CDN：MVP 不需多 API 治理或全球流量；Static Web Apps 已處理靜態內容發佈。
- Notification Hubs：推播不是主 Demo flow，延後。
- Azure AI Search：目前沒有大量知識庫；微課程先用經審核的短知識內容與 prompt 約束。
- Microsoft Entra External ID：正式帳號與青少年同意流程重要，但先完成核心閉環，再作為下一階段。

## 已盤點的共享環境

- 共享 subscription／resource group 可用，登入帳號具有建立一般資源與使用 Azure OpenAI 的部分角色。
- 帳號無法自行指派 RBAC，因此 Managed Identity 上線需要主辦方管理者協助。
- 共享 Foundry／Azure OpenAI 位於 Sweden Central，已有主辦方提供的模型 deployments；其他隊伍資源不可修改。
- quota 與帳務資訊可能受權限限制且由多隊共用；需要節流、429 重試與固定 Demo 備援。
- Portal UI 曾直接顯示共享 API key，視為已曝光；串接前請主辦方輪替，專案不得使用或保存舊值。

以上只是唯讀盤點；本次初始化沒有對 Portal 做任何建立、修改、部署或金鑰複製。

## 設定名稱（只列變數，不含值）

Functions 後續預計需要：

- `AZURE_OPENAI_ENDPOINT`
- `AZURE_OPENAI_DEPLOYMENT`
- `AZURE_OPENAI_API_VERSION`（只有所用 SDK／端點需要時）
- `COSMOS_ENDPOINT`
- `COSMOS_DATABASE_NAME`
- `APPLICATIONINSIGHTS_CONNECTION_STRING`
- `ALLOWED_ORIGINS`

使用 Managed Identity 時不需要把 Azure OpenAI 或 Cosmos 主金鑰放進設定；若決賽環境暫時只能用 key，僅放 Functions App Settings，並限制與輪替。

## 官方技術依據

- [Flutter Web 支援與適用情境](https://docs.flutter.dev/platform-integration/web)
- [Azure Static Web Apps 概觀](https://learn.microsoft.com/azure/static-web-apps/overview)
- [Azure Functions Node.js 開發者指南](https://learn.microsoft.com/azure/azure-functions/functions-reference-node)
- [Azure Functions Flex Consumption](https://learn.microsoft.com/azure/azure-functions/flex-consumption-plan)
- [Azure OpenAI Structured Outputs](https://learn.microsoft.com/azure/ai-services/openai/how-to/structured-outputs)
- [Azure OpenAI Managed Identity](https://learn.microsoft.com/azure/ai-services/openai/how-to/managed-identity)
- [Azure Cosmos DB for NoSQL](https://learn.microsoft.com/azure/cosmos-db/nosql/overview)
- [Application Insights 概觀](https://learn.microsoft.com/azure/azure-monitor/app/app-insights-overview)

服務供應狀態、支援 runtime、模型與 quota 會變動；真正建立資源前需再次以官方文件與 Portal 驗證。
