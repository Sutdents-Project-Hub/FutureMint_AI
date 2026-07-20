# Coolify 部署說明

## 目標與目前狀態

目標是同一個 Coolify project／production environment 內的三個獨立 Resources：

1. `futuremint-ai-postgres`：PostgreSQL 17 Database。
2. `futuremint-ai-api`：private GitHub repository 的 `/backend` Dockerfile Application。
3. `futuremint-ai-web`：同一 repository 的 `/app` Dockerfile Application。

Coolify 從 GitHub clone source，與開發者電腦無關。2026-07-20 已在團隊既有的 `Student Project / production` environment 建立以下 Resources：`futuremint-ai-postgres`（PostgreSQL 17、running、無 host port mapping）、`futuremint-ai-api`（Dockerfile、`/backend`、port 3000、`/api/health`、Auto Deploy）及 `futuremint-ai-web`（Dockerfile、`/app`、port 3000、`/`、Auto Deploy）。API 已寫入非敏感 runtime variables 與資料庫 internal URL，並完成正式 DNS／TLS domains 與 `ALLOWED_ORIGINS`；Web 的 `API_BASE_URL` 也已設定。Web／API 尚未首次部署，目前僅等待新的 `LIANGJIE_API_KEY`。本文件其餘段落是完成這些項目的實際設定清單，不代表 production 已上線。

根目錄 `compose.yaml` 只供本機整合測試：頂層 `name: futuremint_ai` 讓 Docker Desktop 顯示 `futuremint_ai` Compose project，內含 `web`、`api`、`postgres` 三個容器。Coolify project 使用 `futuremint-ai`，production 仍應建立下列三個獨立 Resources，不使用 Compose 的本機免密碼 PostgreSQL 設定。

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
- API 會在 listen 前拒絕非 `liangjie + postgres` provider pair，或遺漏、帶 path／尾端 `/`、非 HTTPS 的 `ALLOWED_ORIGINS`；看到 startup failure 時先修 runtime variable，不可先略過健康檢查。
- VPS／Coolify 必須允許 API 對 `https://openapi.twse.com.tw/` 的 outbound HTTPS；市場來源失敗時 UI 會顯示教育快照，不影響 health check。
- Docker image 在 `DATA_PROVIDER=postgres` 時會先跑 migration；migration 失敗則 container 退出。
- Dockerfile health check 會優先於 UI health check。只有 `/api/health` 回 200 時新 deployment 才應接流量。
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

只新增一個 Build only variable（勾 Build Variable、取消 Runtime Variable）：

```dotenv
API_BASE_URL=https://api.<your-domain>/api/
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
4. 由 Web 註冊一個 synthetic test account，完成 profile，新增一筆事件，logout／login。
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
- PostgreSQL backup schedule／retention／S3 endpoint。
- 量界正式 model、費率、額度、資料條款與競賽允許性。
- Production email verification、password reset、帳號刪除與未成年人法遵。

參考官方文件：[Dockerfile Build Pack](https://coolify.io/docs/applications/build-packs/dockerfile)、[GitHub Auto Deploy](https://coolify.io/docs/applications/ci-cd/github/auto-deploy)、[Environment Variables](https://coolify.io/docs/knowledge-base/environment-variables)、[Database internal URL](https://coolify.io/docs/databases/)、[Backups](https://coolify.io/docs/databases/backups)。
