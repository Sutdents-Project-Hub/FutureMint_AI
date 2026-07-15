# 學生專案 Profile

> Schema：Student Project Profile v1｜Profile JSON 只存 repository 外暫存位置。

## 基本資訊

- Project name：FutureMint AI
- Repository name：`FutureMint_AI`
- Project slug：`futuremint-ai`
- Stage：`competition`
- Product type：`hybrid`
- Bootstrap mode：`executable`
- Deployment：`other (self-hosted Coolify)`
- Team collaboration：`true`

## Executable components

- `client`：path=`apps/client`，kind=`app`，framework=`Flutter`，package_manager=`flutter`，quality=analyze, test, build，deployment=Coolify Dockerfile Web Application。
- `api`：path=`services/api`，kind=`backend`，framework=`Fastify`，package_manager=`npm`，quality=test, typecheck, build, evaluate:captures，deployment=Coolify Dockerfile API Application。
- `database`：Coolify PostgreSQL 17 Resource，schema 由 `services/api/migrations` 管理；它不是 source component，但有獨立資料／備份生命週期。

`design-system` 與 `docs` 是非執行型支援資產，不列入 executable components。

## 摘要

青少年 AI 金錢決策教練，將主動輸入的收入、支出與訂閱轉為可理解的預算回饋、個人化金融微課程與教育性未來預覽。主辦方 Azure 關閉後，正式目標改為 private GitHub → 自有 VPS Coolify。

## 功能領域

- 自然語言收入、支出與訂閱事件解析
- 青少年預算回饋與金錢決策教練
- 訂閱方案比較與最佳化建議
- 個人化金融微課程
- 教育性儲蓄與複利情境預覽

## 技術與資料邊界

- Flutter Web／Android 是主要 Demo 面；Web 只有公開 `API_BASE_URL`。
- Fastify 是唯一可接觸量界 API key 與 PostgreSQL URL 的 component。
- PostgreSQL 是帳號資料 source of truth；訪客模式只用 Client memory。
- 量界 AI output 一律重新驗證；金額、期限與複利由 deterministic code 計算。
- 不連銀行、支付、電子發票、證券或真實未成年人金融服務。
- 決賽只使用合成或取得同意且去識別的資料。

## Bootstrap 證據

- Flutter 有 manifest、lockfile、Dockerfile 與 analyze／test／build。
- API 有 manifest、lockfile、Dockerfile、migration 與 test／typecheck／build／evaluation。
- PostgreSQL adapter 有 unit tests，且 migrations 與 API persistence 已用 PostgreSQL 17 本機容器驗證。
- `executable` 只代表可建置與有品質證據；不代表 Coolify、量界 production、DNS 或備份已完成。

## 未決事項

- 正式 domains、VPS sizing、監控、磁碟與現場網路備援。
- 量界 model、quota、費率、資料處理與比賽規則確認。
- PostgreSQL backup retention 與 restore rehearsal。
- 青少年測試同意／去識別與 production identity hardening。
- 訂閱方案資料授權。
- Android 實機與 iOS signing。
