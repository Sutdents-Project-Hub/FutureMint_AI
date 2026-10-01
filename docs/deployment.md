# Coolify 部署說明

## 目標與目前狀態

正式以原生 iPhone 為主，只啟動 `futuremint-ai-api`（backend/Dockerfile）與 `futuremint-ai-postgres`（Coolify managed PostgreSQL 17）。`futuremint-ai-web` 保留為測試 Resource，維持停止並關閉其 Auto Deploy；不需刪除。根 compose.yaml 僅供本機三容器整合，不作 production 入口。

既有三 Resources 曾部署成功是使用者提供的歷史事實。本輪只修改本機程式與文件，沒有改 Coolify、部署、寄信、呼叫正式 AI 或 Apple 發布；遠端健康與使用流程仍待驗收。Coolify 讀 GitHub commit，未 push 的本機修改不會部署。

## 1. GitHub 與資源

- API 使用既有私人 repository 的 main、Dockerfile Build Pack、Base Directory `/backend`、Dockerfile Location `/Dockerfile`、Port Exposes `3000`。
- API 配置公開 HTTPS domain，HTTP GET `/api/health` 預期200；Include Source Commit in Build 可維持Off以保留cache。
- PostgreSQL 使用既有 Resource、原 database／username／password／volume，不刪資料或重新建立。公開port關閉；API與database須在相同destination／network。
- Database健康後，將它的 Internal URL 填入API的 DATABASE_URL，DATABASE_SSL=false 對應目前未開SSL的內部連線。
- 本輪使用者選擇不建立定期備份，BACKUP_RETENTION_DAYS 預設0；這不是清除既有備份或journal的指令。
- 量界模型／key只放API，Client與Web不得持有。iPhone需要API的DNS／TLS，不需要Web的DNS。

## 2. API 最小 Runtime 設定

安全範本：[backend/.env.coolify.example](../backend/.env.coolify.example)。所有欄位 Runtime開啟、Buildtime關閉；真實值只填在Coolify。下列空白需自行補齊，沒有假憑證或營運資料預設：

```dotenv
NODE_ENV=production
HOST=0.0.0.0
PORT=3000
AI_PROVIDER=liangjie
DATA_PROVIDER=postgres
DATABASE_URL=
DATABASE_SSL=false
LIANGJIE_MODEL=
LIANGJIE_API_KEY=
PUBLIC_BASE_URL=
SERVICE_OPERATOR=
SUPPORT_EMAIL=
DATA_REGION=
PRIVACY_POLICY_REVIEWED=false
MAIL_PROVIDER=disabled
```

| 需填欄位 | 來源／要求 |
|---|---|
| DATABASE_URL | 既有PostgreSQL Resource的Internal URL；Runtime secret |
| LIANGJIE_MODEL／LIANGJIE_API_KEY | 帳號確定可用的model id與key；key為Runtime secret |
| PUBLIC_BASE_URL | API公開HTTPS origin，不帶 /api、其他path、尾端 /、port、query或credentials |
| SERVICE_OPERATOR／SUPPORT_EMAIL | 真實公開營運者及能收使用者來信的客服信箱；客服不依賴SMTP |
| DATA_REGION | 實際VPS／資料庫所在國家地區；不依網域猜測 |
| PRIVACY_POLICY_REVIEWED | 確認內建政策及營運資料後才改true；production仍要求true |

值含 `$` 時使用Coolify的Literal設定，避免插值。不設定ALLOW_DEMO_SEED，不把真實值寫入範本或repository。選量界時不需OPENAI_*，不用新增JWT_SECRET等程式未使用的變數。

### 可省略的預設

| 欄位 | 預設／作用 |
|---|---|
| LIANGJIE_BASE_URL | https://liangjiewis.com/v1 |
| ALLOWED_ORIGINS | 未填時使用PUBLIC_BASE_URL，API自身origin可服務公開頁；原生App不需要Web。選用Web時明確加入其完整HTTPS origin，不用萬用* |
| TRUSTED_PROXY_CIDRS | 空白時不採forwarding headers；取得實際proxy IP／最小CIDR後再設定，以正確辨識使用者IP |
| BACKUP_RETENTION_DAYS | 0；允許0..3650，若日後設定大於0須符合實際備份排程／保存期限，程式不建立或清除Coolify備份 |
| MINIMUM_AGE | 15，不允許production自行改成其他年齡 |
| PRIVACY_POLICY_VERSION | 2026-10-simple-v1；與通用說明一起在publicConfig.ts版本化，仍可覆寫 |
| MINOR_CONSENT_DISCLOSURE／AI_DATA_TERMS_DISCLOSURE | 內建產品公開說明，仍可覆寫 |
| AI_OPERATION_TIMEOUT_MS／AI_MAX_OUTPUT_TOKENS | 12000 ms／2048 tokens |
| AI_DAILY_USER_LIMIT／AI_DAILY_GLOBAL_LIMIT／AI_MAX_CONCURRENCY | 台北每日每人30／全站300次，並行5；操作次數不是供應商費用保證 |

完整名稱索引：[backend/.env.example](../backend/.env.example)。

## 3. 可選寄信與帳號功能

MAIL_PROVIDER未填或disabled時不要求SMTP憑證，可啟動production：

- 可使用訪客；資料僅在App記憶體，結束或切換帳號後消失。
- 可登入既有帳號，但仍需原Email驗證與年齡／監護人資格；不自動標記已驗證或成年。
- 新註冊回registration_disabled，新的驗證／忘記密碼／監護人寄信回mail_disabled；不假裝已寄信。
- 既有有效的確認連結仍可使用，原token到期與一次性限制不變。公開support頁說明當前狀態。

需要完整新帳號與15–17歲監護人流程時，啟用：

```dotenv
MAIL_PROVIDER=smtp
SMTP_HOST=
SMTP_PORT=465
SMTP_USER=
SMTP_PASSWORD=
SMTP_FROM=
```

host／帳號／憑證由郵件服務提供；port只接受465或587，強制TLS。SMTP_FROM為已驗證可寄送的純Email。SMTP_USER／PASSWORD只放Runtime secret。正式送達、DNS SPF／DKIM／DMARC、權限及費用另驗收。

## 4. 可選外部 AI 說明

量界維持主要供應商；不自動換Demo、OpenAI或任意GitHub Key。供應商公開接收方／資料條款／reviewed可放版本化 [providerPolicies.ts](../backend/src/config/providerPolicies.ts)，也支援原有runtime overrides：

```dotenv
LIANGJIE_DATA_RECIPIENTS=
LIANGJIE_DATA_TERMS_DISCLOSURE=
LIANGJIE_DATA_TERMS_REVIEWED=false
```

初始只有已知供應商名稱，條款未完成、reviewed=false。這不阻擋API啟動，但外部AI授權與請求回ai_policy_unavailable；可手動記錄、管理訂閱及查看固定教材。要使用真實AI，先補實際接收方（含上游）、用途、保存、訓練、地區與條款，再確認reviewed=true；只填旗標而缺條款仍拒啟動。不能把通用AI說明當成供應商資料條款。

覆寫接收方／說明後，不沿用內建reviewed狀態，須明確重新確認。provider／model／接收方／說明／隱私版本變更會旋轉fingerprint，使用者需再次同意。正式key、model權限、額度與連線仍待真實驗收。

官方OpenAI僅明確AI_PROVIDER=openai時使用OPENAI_MODEL、OPENAI_API_KEY及對應OPENAI_DATA_*；模型需在程式allowlist，base固定官方endpoint，不接受任意轉接key。

## 5. 部署與驗收順序

1. PostgreSQL healthy，保留原volume並取得Internal URL。
2. API填完整最小Runtime設定，確認公開政策後設PRIVACY_POLICY_REVIEWED=true。Docker先pure preflight，再套用尚未執行的migration、最後listen；沒有新migration不重寫schema。
3. 使用者Deploy API，確認migration／啟動log及HTTPS /api/health回200。錯誤只輸出missing／invalid變數名稱與階段，不記秘密。
4. 確認/privacy、/support及/api/service-policy回應；mailEnabled、registrationEnabled與ai.reviewed應符合實際啟用狀態。
5. 無SMTP先以訪客或既有合成帳號驗收；完整帳號模式另驗證註冊→驗證信→年齡／監護人→profile→保存→重新登入／API重啟後持久化→匯出／刪除。未啟用功能應得到明確錯誤。
6. 外部AI只在供應商說明確認與使用者同意後驗收合成輸入；health200不代表SMTP／AI成功。
7. iPhone另在已忽略的app/.env.appstore.local設定API_BASE_URL（以/api/結尾）、PRIVACY_POLICY_URL（/privacy）、SUPPORT_URL（/support）、客服／營運者與Apple資訊，再產生signed IPA、TestFlight及完成商店表單／實機驗收。API部署不會更新已安裝App。

本輪沒有新增migration、不改舊checksum、不刪volume。沒有備份時仍不得用舊API回滾來冒充schema／資料完整回復。

## 6. 自動部署與選用 Web

GitHub App／webhook正常且API Auto Deploy開啟時，push設定的main會重新build／deploy；手動Stop容器不等於關閉Auto Deploy。只修改本機未push不觸發，PostgreSQL不因Git push重建。

測試Web維持停止並關閉Auto Deploy，可避免每次main更新浪費Flutter建置資源。日後需測試時才使用/app的Dockerfile獨立Application、port3000、health /，並設定BUILD_ENV=production與公開API_BASE_URL／PRIVACY_POLICY_URL／SUPPORT_URL／SUPPORT_EMAIL／SERVICE_OPERATOR等Build only值；同時加入Web origin至API CORS。Compose與BUILD_ENV=validation產物只供本機／CI。

## 7. 維運驗收

確認API log沒有Authorization、密碼、capture原文、SQL URL、prompt或供應商body；database不公開port。取得實際proxy IP後設定TRUSTED_PROXY_CIDRS，避免所有使用者共用proxy IP限流；不可猜測全部信任網段。TWSE outbound HTTPS失敗時可顯示明示來源的教育快照，不冒充即時行情。

本輪只做本機typecheck／build，沒有SMTP／AI正式請求、遠端設定、Apple登入或送審；這些驗收不能由編譯結果取代。

## 8. Rollback 與故障處理

- ConfigurationError：補錯誤列出的變數名稱，不略過preflight／health。
- Database connection：核對private network、Internal URL、DATABASE_SSL與postgres provider；不公開資料庫繞過問題。
- SMTP：disabled不送信且不開新註冊；smtp有憑證但送達失敗需檢查服務權限與TLS，不能宣稱已寄出。
- AI：缺少政策僅停用外部AI；實際連線失敗核對key／model／額度／outbound HTTPS，不自動切Demo。
- Application code：可選前一healthy image，但須確認新schema向前相容；不是資料回復操作。資料毀損若沒有可用備份，不能宣稱能還原。

官方參考：[Dockerfile Build Pack](https://coolify.io/docs/applications/build-packs/dockerfile)、[Automatic Deployments](https://coolify.io/docs/applications/deployments/automatic-deployments)。

## 9. 隔離還原與刪除帳號對帳

以下只適用於日後啟用備份並進行還原時；本輪不建立定期備份，也不執行還原。011 會將帳號刪除時的 SHA-256 ID 雜湊與時間保存在最小 journal，與帳號刪除同一 transaction。沒有 Email、密碼或帳務；journal 不隨 account cascade 消失。此機制只涵蓋套用 011 後的刪除，歷史刪除需營運者另外確認。

1. 備份／journal 放入加密、限制存取的受控儲存，備份保留天數需與實際設定一致。還原前另從目前 live DB 匯出最新 journal，不能只用舊備份內的 journal。
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
