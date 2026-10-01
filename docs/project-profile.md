# 學生專案 Profile

> Schema：Student Project Profile v1｜Profile JSON 只存 repository 外暫存位置。

## 基本資訊

- Project name：FutureMint AI
- Repository name：`FutureMint_AI`
- Project slug：`futuremint-ai`
- Local Docker Compose project：`futuremint_ai`
- Coolify project：`futuremint-ai`。使用者確認既有 Coolify 三 Resources 曾成功部署；目前 live health、DNS／TLS、runtime 設定與完整使用者流程尚未在本輪驗證。本次程式變更需由使用者自行重新部署並驗收，
- Coolify services：`futuremint-ai-web`、`futuremint-ai-api`、`futuremint-ai-postgres`
- Stage：正式產品準備（2026-09-06 使用者核准）；競賽原型為既有來源
- Product type：`hybrid`
- Bootstrap mode：`executable`
- Deployment：`other (self-hosted Coolify)`
- Team collaboration：`true`

## 結構與技術決策

- `structure_exception`：無。採固定 component roots：`app/`、`backend/`、`design/` 與 `docs/`。
- Framework root 證據：`app/pubspec.yaml` 與 `backend/package.json` 直接位於 component 根目錄，沒有 project-name／framework-name wrapper，也沒有巢狀 `.git/`。
- `technology_source`：`existing-project`。Flutter、Fastify、Node.js 22 與 npm 是競賽期間已實作且通過品質檢查的技術選型；公司基線只作未指定技術之新專案預設，不自動觸發遷移。

## Executable components

- `client`：path=`app`，kind=`app`，framework=`Flutter`，package_manager=`flutter`，quality=analyze, test, build，deployment=原生 iPhone App Store（簽章／送審未完成）；Coolify Dockerfile Web Application 僅供選用測試。
- `api`：path=`backend`，kind=`backend`，framework=`Fastify`，package_manager=`npm`，quality=test, typecheck, build, evaluate:captures，deployment=Coolify Dockerfile API Application。
- `database`：Coolify PostgreSQL 17 Resource，schema 由 `backend/migrations` 管理；它不是 source component，但有獨立資料／備份生命週期。

`design` 與 `docs` 是非執行型支援資產，不列入 executable components。

## 摘要

青少年 AI 金錢決策教練，將主動輸入的收入、支出與訂閱轉為可理解的預算回饋、個人化金融微課程與教育性未來預覽。主辦方 Azure 關閉後，正式目標改為 private GitHub → 自有 VPS Coolify。

## 功能領域

- 自然語言收入、支出與訂閱事件解析
- 青少年預算回饋與金錢決策教練
- 訂閱方案比較與最佳化建議
- 個人化金融微課程
- 教育性儲蓄與複利情境預覽

## 技術與資料邊界

- Flutter Web／Android 保留 Demo；正式 iOS 只支援 iPhone。前端僅持有公開 API／隱私／支援與營運設定。
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
- 本輪不建立定期資料庫備份；日後若啟用，另設定排程、保留、異地儲存及隔離還原。
- 臺灣 15 歲門檻與 15–17 歲監護人確認已實作；法定代理人身分查核／客服更正、資料地區、供應商條款及 Email／SMTP 實際送達仍需營運驗收。
- 訂閱方案資料授權。
- Android 實機與 iOS signing。

## 本輪產品準備範圍

新增訂閱合約／實付分離、分頁與手動紀錄、年齡／監護人資格、版本化供應商同意、官方 OpenAI 可選設定、跨 API instance AI 額度、個人匯出與 iPhone 本機提醒。分類為新能力、缺陷修正及釐清，保持 hybrid／executable、既有 Flutter／Fastify 與獨立 Resource 邊界；正式僅啟動 API／PostgreSQL，Web 為選用測試。完整行為見 [產品範圍](project-overview.md)。

目前部署模式維持 hybrid／executable，正式 iPhone 使用最小 API Runtime 範本；無 SMTP 停用新註冊與新的寄信流程，未確認供應商說明只停用外部AI，備份預設0。公開政策與 Apple 正式發布條件仍需確認。
