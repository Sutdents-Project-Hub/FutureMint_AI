# Coolify 部署說明

## 目標與目前狀態

正式架構維持三個獨立 Resources：`futuremint-ai-web`（`app/Dockerfile`）、`futuremint-ai-api`（`backend/Dockerfile`）與 `futuremint-ai-postgres`（Coolify managed PostgreSQL 17）。根 `compose.yaml` 僅供本機驗證，不作 production 入口。

使用者確認既有 Coolify 三 Resources 曾成功部署；目前 live health、DNS／TLS、runtime 設定與完整使用者流程尚未在本輪驗證。本次程式變更需由使用者自行重新部署並驗收。

Coolify 讀 GitHub commit snapshot；未 push 的本機修正不會出現在平台。下列欄位是重新部署與驗收契約，不是本輪已執行的外部操作。

## 部署前準備

- VPS 已安裝並可登入 Coolify，磁碟、CPU、RAM、Docker cleanup 與防火牆已確認。
- 準備兩個 DNS names，例如 `futuremint.example.com` 與 `api.futuremint.example.com`，A／AAAA 指向實際承載 applications 的 VPS。
- 將 repository 放到 GitHub private repository，default branch 使用 `main`。
- Coolify 與 GitHub 管理者啟用 MFA。
- 準備量界智算正式 API key 與帳號確定可用的 model id；不要貼入 repository、issue、聊天截圖或 build arg。
- 準備團隊控制的 S3-compatible backup storage。

## 1. 連接 private GitHub repository

建議使用 Coolify GitHub App：

1. Coolify Sources／GitHub 建立 GitHub App。
2. GitHub 安裝 App 時選「Only select repositories」，只授權 `FutureMint_AI`。
3. 回 Coolify 建立 project `futuremint-ai` 與 environment `production`。
4. 後續兩個 Applications 都選 Private Repository (with GitHub App)、`FutureMint_AI`、branch `main`。
5. 每個 Application 的 Advanced 確認 Auto Deploy 已開。GitHub App 正常時 push webhook 會自動觸發，不需要另寫 GitHub Actions。
6. 若 GitHub App 無法使用，可改用 repository-scoped read-only Deploy Key，再另設有 secret 且啟用 SSL verification 的 push webhook。

PostgreSQL Resource 不讀 GitHub，也不會因 push 被重建。

## 2. 建立 PostgreSQL Resource

在相同 project／environment：

| 欄位 | 值 |
|---|---|
| Type | PostgreSQL |
| Name | `futuremint-ai-postgres` |
| Version | `17` |
| Database | `futuremint` |
| Username／Password | 由 Coolify 產生高強度值，不重用 |
| Public accessibility／Public port | 關閉 |
| Persistent storage | 保留 Coolify database 預設 volume |

啟動後：

1. 等 Coolify 顯示 database healthy。
2. 複製 Internal URL，稍後設為 API 的 `DATABASE_URL`。不要使用 public URL。
3. 在 Backup 設定 full PostgreSQL scheduled backup，目的地選團隊的 S3-compatible storage。
4. 先執行一次 manual backup，下載或確認 object 存在；production 前另建暫存 database 做 restore rehearsal。
5. 不要手動建立 tables；API 首次啟動會執行 versioned migrations。

Database 與 API 必須在同一 Coolify destination／network，否則 internal hostname 無法解析。不要為了繞過 network 問題而公開 PostgreSQL。

## 3. 建立 API Application

建立 Private Repository Application：

| Coolify 欄位 | 值 |
|---|---|
| Name | `futuremint-ai-api` |
| Repository／Branch | `FutureMint_AI`／`main` |
| Build Pack | Dockerfile |
| Base Directory | `/backend` |
| Dockerfile Location | `/Dockerfile`（若 UI 顯示此欄；相對 Base Directory） |
| Port Exposes | `3000` |
| Domain | `https://api.<your-domain>` |
| Health check | Dockerfile 已定義 `/api/health` |
| Auto Deploy | On |
| Include Source Commit in Build | Off，保留 build cache |

Environment Variables 全部設為 Runtime only（取消 Build Variable）：

```dotenv
NODE_ENV=production
HOST=0.0.0.0
PORT=3000
AI_PROVIDER=liangjie
DATA_PROVIDER=postgres
DATABASE_URL=<貼上 futuremint-ai-postgres Internal URL>
DATABASE_SSL=false
LIANGJIE_BASE_URL=https://liangjiewis.com/v1
LIANGJIE_MODEL=<量界帳號已驗證可用的 model id>
LIANGJIE_API_KEY=<量界 secret>
ALLOWED_ORIGINS=https://<frontend-domain>
```

注意：

- `DATABASE_URL` 與 `LIANGJIE_API_KEY` 鎖定為 secret，不能勾 Build Variable。
- Coolify 變數值若含 `$`，在 Normal View 勾 Literal，避免被當成其他變數插值。
- 不設定 `ALLOW_DEMO_SEED`，production 自動部署不寫示範資料。
- `ALLOWED_ORIGINS` 只放完整 HTTPS frontend origins；多個以逗號分隔，不用 `*`。
- API 會在 listen 前拒絕非 `liangjie|openai + postgres` provider pair，或遺漏、帶 path／尾端 `/`、非 HTTPS 的 `ALLOWED_ORIGINS`；看到 startup failure 時先修 runtime variable，不可先略過健康檢查。
- VPS／Coolify 必須允許 API 對 `https://openapi.twse.com.tw/` 的 outbound HTTPS；市場來源失敗時 UI 會顯示教育快照，不影響 health check。
- Docker image 先執行不連外部服務的配置 preflight，通過後才跑 PostgreSQL migration；任一步失敗即退出，不接受流量。
- API runtime image 已包含 `curl`，可供 Coolify UI 執行 HTTP health check；Dockerfile 也保留以 Node `fetch` 驗證 `/api/health`。只有該路徑回 200 時新 deployment 才應接流量。
- 不設定 pre／post-deployment migration command，避免與 image entrypoint 重複執行。

先 Deploy API。成功條件：

```bash
curl -i https://api.<your-domain>/api/health
```

應回 HTTP 200，JSON 的 `status` 為 `ok`、`aiProvider` 為 `liangjie`、`dataProvider` 為 `postgres`。Health 不會花用 AI token。

## 4. 建立 Flutter Web Application

建立第二個 Private Repository Application：

| Coolify 欄位 | 值 |
|---|---|
| Name | `futuremint-ai-web` |
| Repository／Branch | `FutureMint_AI`／`main` |
| Build Pack | Dockerfile |
| Base Directory | `/app` |
| Dockerfile Location | `/Dockerfile`（若 UI 顯示此欄；相對 Base Directory） |
| Port Exposes | `3000` |
| Domain | `https://<frontend-domain>` |
| Health check | Dockerfile 已定義 `/` |
| Auto Deploy | On |
| Include Source Commit in Build | Off |

設定以下非秘密的 Build only variables（勾 Build Variable、取消 Runtime Variable）：

```dotenv
BUILD_ENV=production
API_BASE_URL=https://api.<your-domain>/api/
PRIVACY_POLICY_URL=https://api.<your-domain>/privacy
SUPPORT_URL=https://api.<your-domain>/support
SUPPORT_EMAIL=<正式客服 Email>
SERVICE_OPERATOR=<公開營運者名稱>
```

末尾 `/` 不可省略。它是公開網址，不是 secret；Flutter 在 build 時把它編進 bundle。變更 API domain 後必須重新 deploy Web。

Nginx 會：

- 監聽 3000。
- 對 `/capture` 等 deep link fallback `index.html`。
- 對入口與 service worker 設 no-store。
- 對靜態 assets 短期 cache。
- 提供 Docker health check `/`。

## 5. 第一次部署順序

為避免 CORS／domain 互相等待，先在 Coolify 與 DNS 指定兩個預計使用的 domains，再照順序：

1. PostgreSQL healthy，取得 Internal URL。
2. API 填完 runtime variables，Deploy；確認 migration log 與 health 200。
3. Web 填 `API_BASE_URL` build variable，Deploy；確認首頁與 deep link。
4. 由 Web 註冊一個 synthetic test account，完成 profile，查看 AI 資料說明並為此合成帳號明確啟用，新增一筆事件，logout／login。
5. Redeploy 或 restart API，再登入確認事件仍在，證明不是 memory provider。
6. 用一筆合成 capture 驗證量界；UI source 應顯示量界智算。若失敗，保留錯誤證據，不改成宣稱 AI 成功。
7. 觸發一次 backup，並在隔離資料庫驗證 restore。

## 6. 自動部署

GitHub App + Auto Deploy 開啟後：

- push 到 `main` 會讓 Web 與 API 各自重新 build／deploy。
- PostgreSQL volume 與資料不因 application deploy 重建。
- API 每次 deploy 都會檢查 migration；沒有新 migration 時不修改 schema。
- 前端與 API 都使用 Dockerfile health checks；新 container unhealthy 時先看 migration、environment、port 與 internal network，不要直接開 public database。
- 團隊 Git 工作流仍以 task branch／PR／checks／squash merge 到 `main` 為主；merge 到 `main` 才觸發正式 deployment。

Coolify 若支援 application watch paths，可將 API 限定 `backend/**`、Web 限定 `app/**` 與各自需要的共同文件；未在實際版本驗證前可以先接受兩邊都 redeploy，較不容易漏部署。

## 7. Smoke test

```bash
curl -fsS https://api.<your-domain>/api/health
curl -fsSI https://<frontend-domain>/
curl -fsSI https://<frontend-domain>/capture
```

人工驗證：

- 首頁、deep link、重新整理與 HTTPS 正常。
- Register → profile → event → dashboard → logout → login 完整。
- 瀏覽器 Network 沒有 CORS、mixed content 或 5xx。
- Web bundle 沒有 `LIANGJIE_API_KEY`、`DATABASE_URL` 或 password。
- 投資練習場顯示 TWSE／fallback 來源與行情日期，虛擬訂單在 API restart 後仍存在。
- API log 沒有 Authorization、capture 原文、SQL URL 或 provider response。
- Database 沒有 public port。
- Backup 與 restore 證據已保存於受控位置。

## 8. Rollback 與故障處理

- Application code：在 Coolify Rollback 選仍存在於本機的上一個 healthy image。
- Frontend API URL 錯誤：修正 build-only `API_BASE_URL` 並重新 build。
- CORS：修正 API runtime `ALLOWED_ORIGINS` 後 redeploy API。
- Database connection：確認同一 network、Internal URL、`DATA_PROVIDER=postgres` 與 `DATABASE_SSL=false`。
- Migration 失敗：保留舊 application；不要刪 volume或手改 `schema_migrations`。先修 migration、測試 backup／restore，再部署新 commit。
- 量界失敗：確認 key、base URL、model access、quota 與 outbound HTTPS；不可把 key 貼在 log／issue，也不可自動改 Demo 冒充成功。
- Database corruption／誤刪：停止寫入，從已驗證 backup 還原到新 Resource，驗證後再切換 `DATABASE_URL`。

## 仍需人工決定

- 正式 frontend／API domains 與 DNS provider。
- VPS sizing、resource limits、監控、磁碟告警與 Coolify backup。
- 每日備份保留 30 天的排程與異地 endpoint、隔離 restore／刪除不復活演練。
- 量界正式 model、費率、額度、資料條款與競賽允許性。
- Production email verification、password reset、備份中帳號刪除 SLA、公開隱私／支援頁與未成年人法遵。

參考官方文件：[Dockerfile Build Pack](https://coolify.io/docs/applications/build-packs/dockerfile)、[GitHub Auto Deploy](https://coolify.io/docs/applications/ci-cd/github/auto-deploy)、[Environment Variables](https://coolify.io/docs/knowledge-base/environment-variables)、[Database internal URL](https://coolify.io/docs/databases/)、[Backups](https://coolify.io/docs/databases/backups)。

## 2026-09 正式產品新增發布條件

API Runtime variables 除前述項目外，必須設定：

| 變數 | 內容 |
|---|---|
| `TRUSTED_PROXY_CIDRS` | 實際連入 API 的 proxy IP／最小 CIDR；空值忽略 forwarding headers，不接受數字 hop count |
| `MAIL_PROVIDER` | production 必須 `smtp` |
| `SMTP_HOST`、`SMTP_PORT` | 郵件服務；只接受 465 或 587，強制 TLS 與憑證驗證 |
| `SMTP_USER`、`SMTP_PASSWORD` | Runtime secrets；不得提供給前端或 build |
| `SMTP_FROM` | 已驗證可寄送的寄件 Email |
| `PUBLIC_BASE_URL` | API 的公開 HTTPS origin，不帶 path；需路由根目錄公開頁與 `/api/` |
| `SERVICE_OPERATOR`、`SUPPORT_EMAIL` | 真實營運者名稱及公開客服 |
| `PRIVACY_POLICY_VERSION` | 經營運者確認的政策版本 |
| `DATA_REGION`、`BACKUP_RETENTION_DAYS` | 實際資料地區、備份最大保存天數；本次目標 30 天，需實際排程及清除驗收 |
| `MINIMUM_AGE`、`MINOR_CONSENT_DISCLOSURE` | production 最低年齡固定 `15`；揭露 15–17 歲監護人安排與 Email 不證明法定代理人身分 |
| `AI_DATA_TERMS_DISCLOSURE` | 公開隱私揭露；另需所選 provider 的接收方、條款及 reviewed 欄位一致 |
| `LIANGJIE_DATA_RECIPIENTS`、`LIANGJIE_DATA_TERMS_DISCLOSURE`、`LIANGJIE_DATA_TERMS_REVIEWED` | 量界及上游公開政策；選量界時 production 必填且 reviewed=true |
| `OPENAI_MODEL`、`OPENAI_API_KEY`、`OPENAI_DATA_RECIPIENTS`、`OPENAI_DATA_TERMS_DISCLOSURE`、`OPENAI_DATA_TERMS_REVIEWED` | 僅明確選 `AI_PROVIDER=openai` 時設定；key 為 runtime secret，模型需在能力 allowlist |
| `AI_OPERATION_TIMEOUT_MS`、`AI_MAX_OUTPUT_TOKENS` | 預設 12000 ms／2048 tokens；重試共用總 deadline、最多兩次上游嘗試 |
| `AI_DAILY_USER_LIMIT`、`AI_DAILY_GLOBAL_LIMIT`、`AI_MAX_CONCURRENCY` | 預設 30／300／5，PostgreSQL 共享台北日額度與到期 lease |
| `PRIVACY_POLICY_REVIEWED` | 只有完成上述內容的營運確認後才能設 `true` |

Web Build variables：`BUILD_ENV=production`、`API_BASE_URL`、`PRIVACY_POLICY_URL`、`SUPPORT_URL`、`SUPPORT_EMAIL`、`SERVICE_OPERATOR`。政策／支援通常分別指向 API origin 的 `/privacy`、`/support`；不要指向會被 Flutter SPA fallback 吃掉的路徑。所有值均非秘密。

本機 Compose 明確使用 `BUILD_ENV=validation`，不可部署該產物。Docker image、CI 與本機 build 通過只代表編譯與檢查可執行，沒有驗證 DNS、SMTP 送達或 Apple 接受。

新增 migration 006／007 會停用舊短邀請碼並讓現有帳號補驗證 Email。先做備份、隔離 migration／還原演練，再部署；不要直接 rollback 到依賴明文邀請碼的舊版本。發版後以合成帳號驗收：註冊→收信驗證→profile→AI 同意→記錄→家庭加入／停用→密碼重設→舊 session 失效→帳號刪除。SMTP、AI 真實請求及遠端資源操作須另獲使用者授權。

## 本輪重新部署與外部驗收

1. 先備份既有資料庫，於隔離 PostgreSQL 驗證 008／009／010／011 migration、還原與刪除不復活；不得改舊 migration checksum 或刪原 volume。
2. 核對 API runtime policy／SMTP／CORS／秘密與公開設定；Docker pure preflight 在 migration 前執行，不連資料庫／SMTP。失敗 log 只含缺失／不合法變數名稱及 configuration／startup 階段，不記值、連線字串或 provider body。
3. 使用者自行重新部署既有 API／Web，再確認 live `/api/health`、公開 `/privacy`／`support`、Email 驗證／密碼重設／監護人 fragment confirm／withdraw、資格限制、AI policy 再授權、訂閱／實付、分頁／匯出、家庭摘要及刪除。健康 200 不代表 SMTP、AI 或資料流程成功。
4. provider 預設選量界；官方 OpenAI 僅明確 runtime 切換，不 failover。欄位以 `backend/src/config/aiConfig.ts`、`startupConfig.ts` 及 `backend/src/http/runtime.ts` 為準，完整安全索引見 `backend/.env.example`。
5. 確認每日備份保留 30 天／異地 storage／隔離 restore 與刪除不復活。尚未整合 credential store、Discord 通知或完成演練，不用配置 placeholder 宣稱完成。
6. iPhone 另需 Apple Team、signed archive／TestFlight、App Privacy／年齡問卷、實機通知／權限／點擊與客服／政策 URL 驗收。未簽章 iOS／CI build 不可代替商店驗收。

本輪不執行部署、SMTP／AI 正式請求、Apple 登入或送審；這些需各自明確授權。

## 9. 隔離還原與刪除帳號對帳

新增 011 會將帳號刪除時的 SHA-256 ID 雜湊與時間保存在最小 journal，與帳號刪除同一 transaction。沒有 Email、密碼或帳務；journal 不隨 account cascade 消失。此機制只涵蓋套用 011 後的刪除，歷史刪除需營運者另外確認。

1. 每日備份／journal 放入加密、限制存取的異地儲存，保存備份最多 30 天。還原前另從目前 live DB 匯出最新 journal，不能只用舊備份內的 journal。
2. 在隔離且尚未接流量的資料庫還原，採用不同資料庫名稱，例如 `futuremint_restore`；套用最新 migrations。保留原 DB／volume。
3. 使用 API 已編譯的工具；環境值只放維運機器 secret，不貼在 shell 歷史／文件。`DATABASE_URL` 指向目前來源、`RESTORE_DATABASE_URL` 指向隔離還原 DB；僅允許 PostgreSQL URL，query options 只支援 `sslmode`，不得用 query 改 host／database。

```bash
node dist/scripts/reconcileRestoredAccounts.js export /protected/latest.deletion-journal.json
node dist/scripts/reconcileRestoredAccounts.js preview /protected/latest.deletion-journal.json
# 由營運者確認還原 DB 無應用流量後，在該維運環境設定：
# RESTORE_RECONCILIATION_MAINTENANCE=true
node dist/scripts/reconcileRestoredAccounts.js apply /protected/latest.deletion-journal.json
```

`export` 建立權限 0600 的新檔、不覆蓋既有檔；`preview` 只計數；`apply` 在 transaction 中移除對應帳號及其 cascade 資料、保存 journal，重跑不新增刪除。工具拒絕來源與還原 DB 同名，即使不同 host／credentials／URL 別名也拒絕；maintenance 旗標仍需人員確認隔離狀態。

4. 驗收已刪帳號無法登入、其帳務／sessions 不存在、未刪帳號及家庭摘要正常，再依既有核准流程切換資源。重新開放前，停止舊環境寫入並再匯出／對帳最終 journal，避免對帳後的新刪除遺失。
5. 最小 journal 需保留到所有早於刪除時間的備份及副本都已銷毀；在此前不可清空。排程、異地整合、備份到期銷毀及 production 還原演練尚未執行。
