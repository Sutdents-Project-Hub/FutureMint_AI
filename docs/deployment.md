# 部署說明

## 目前狀態

- 目標平台：Microsoft Azure
- 狀態：本機產品、Functions、Azure adapters 與 Web release build 已完成；尚未建立、修改或部署任何雲端資源。
- Remote／CI：尚未設定；不得把本機已有骨架誤寫成已上線。

## 目標部署契約

| 元件 | Base directory | Runtime／產物 | 建議 Azure 服務 | 狀態 |
|---|---|---|---|---|
| Flutter Web | `apps/client` | `flutter build web --release` → `build/web` | Azure Static Web Apps | 本機 release build 已驗證 |
| Flutter Android/iOS | `apps/client` | APK／AAB／IPA | 現場裝置或測試發佈 | Android/iOS 建置待驗證 |
| API | `services/api` | Node.js 22、Functions v4 | Azure Functions Flex Consumption | build／test 已驗證，未部署 |
| Data | 不適用 | Cosmos DB for NoSQL | Azure Cosmos DB | 尚未建立 |
| AI | 後端呼叫 | Azure OpenAI deployment | 既有共享 Foundry／OpenAI 資源 | Adapter／mock 已驗證，真實連線未驗證 |
| Observability | API 整合 | traces、metrics、exceptions | Application Insights | 尚未建立 |

## 環境與命名

- 建議先只建 `dev`／決賽環境，避免有限額度被多環境消耗。
- 建議資源前綴：`hshs003-futuremint-<service>-dev`；實際名稱需確認 Azure 全域唯一與主辦方規則。
- 區域優先跟隨可用模型與共享資源，避免跨區延遲；資料落地區域需在建立前確認。
- 共享帳號與 quota 可能同時被多隊使用，AI 呼叫必須處理 HTTP 429、指數退避、逾時與安全降級。

## 秘密與權限

- Flutter bundle 不得含 Azure OpenAI key、Cosmos DB key、connection string 或管理權杖。
- 本機 secret 放在未追蹤的 `services/api/local.settings.json`；部署值放 Functions App Settings／Key Vault，不寫入 repository。
- 正式首選 Managed Identity 搭配最小權限；目前登入帳號無法自行指派 RBAC，需主辦方管理者協助。
- 已在共享 Portal UI 看見可直接顯示的 API key。串接前由主辦方輪替；不得使用、記錄或提交已曝光值。
- Application Insights 不記錄完整使用者輸入、財務明細、Authorization header 或模型憑證。

## 發布順序（取得明確授權後）

1. 再次確認 subscription、resource group、區域、quota、命名與預估費用。
2. 建立或選定專屬的 Functions、Cosmos DB、Application Insights 與 Static Web Apps 資源。
3. 設定 Managed Identity／RBAC；若主辦方暫時只能提供 key，限制在後端 App Settings 並建立輪替紀錄。
4. 部署 API，驗證健康檢查、schema、錯誤處理與 CORS。
5. 部署 Flutter Web，設定 API base URL，再驗證主 Demo flow。
6. 設定 budget／alerts（若權限允許）、日誌保留與最低必要監測。
7. 固定可回復的最後成功版本與 Demo 合成資料。

Cosmos adapter 不會自動建 containers。若已取得專用競賽合成環境的雲端寫入授權，可依 [Functions README](../services/api/README.md) 執行 `npm run seed:cosmos-demo`；它有 `ALLOW_DEMO_SEED=true` 顯式安全開關、固定合成內容與 idempotency keys。目前只驗證程式可建置，尚未在真實 Cosmos 執行。

## 回滾

- Web：保留上一個成功靜態產物或 deployment，失敗時還原。
- API：以已驗證套件重新部署；schema 變更須向後相容。
- Data：MVP 避免破壞性 migration；Demo 資料可由去識別種子重建。
- AI：模型不可用時停用生成式回饋，保留確定性預算與既有資料，不捏造成功結果。

實際 resource ID、domain、API URL、deployment name、port、healthcheck 與費用在部署前都屬未驗證值，禁止寫死或猜測。
