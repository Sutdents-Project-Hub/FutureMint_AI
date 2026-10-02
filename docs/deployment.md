# Coolify 部署說明

## 目標與目前狀態

正式以原生 iPhone 為主，只啟動 `futuremint-ai-api`（backend/Dockerfile）與 `futuremint-ai-postgres`（Coolify managed PostgreSQL 17）。`futuremint-ai-web` 保留為測試 Resource，維持停止並關閉其 Auto Deploy；不需刪除。根 compose.yaml 僅供本機三容器整合，不作 production 入口。

既有三 Resources 曾部署成功是使用者提供的歷史事實。2026-10-02 本輪修改前，Coolify 顯示 API 的 `0bf08b0` deployment 為 Running (healthy)；這是前一版本的啟動狀態。新版免寄信及雙語頁須以自己的 deployment 驗收，正式帳號／AI／Apple 發布不由 healthy 狀態取代。Coolify 讀 GitHub commit，未 push 的本機修改不會部署。

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
| PRIVACY_POLICY_VERSION | 2026-10-02-optional-mail-v1；中英文公開內容的版本，仍可覆寫；既有舊值需同步更新 |
| MINOR_CONSENT_DISCLOSURE／AI_DATA_TERMS_DISCLOSURE | 內建產品公開說明，仍可覆寫 |
| AI_OPERATION_TIMEOUT_MS／AI_MAX_OUTPUT_TOKENS | 12000 ms／2048 tokens |
| AI_DAILY_USER_LIMIT／AI_DAILY_GLOBAL_LIMIT／AI_MAX_CONCURRENCY | 台北每日每人30／全站300次，並行5；操作次數不是供應商費用保證 |

完整名稱索引：[backend/.env.example](../backend/.env.example)。

## 3. 可選寄信與帳號功能

MAIL_PROVIDER未填或disabled時不要求SMTP憑證，可啟動production：

- 可使用訪客；資料僅在App記憶體，結束或切換帳號後消失。
- 可註冊及登入，不要求 Email 驗證；Email 是未驗證的登入識別，不寫入 `emailVerifiedAt`，不自動標記成年或監護人同意。
- 新的驗證／忘記密碼／監護人寄信回 `mail_disabled`；App 顯示寄信停用，提醒保存密碼，不能只憑該 Email 人工恢復帳號。
- 成年帳號完成服務聲明後可使用正式功能；15–17 歲仍需有效監護人同意，未完成者可使用訪客，不能寫入正式資料。這版尚無新的免寄信監護人同意管道。
- 既有有效的確認連結仍可使用，原token到期與一次性限制不變。公開support頁說明當前狀態。

需要 Email 驗證、已驗證信箱的密碼重設，以及新的監護人確認／撤回信時，才啟用：

```dotenv
MAIL_PROVIDER=smtp
SMTP_HOST=
SMTP_PORT=465
SMTP_USER=
SMTP_PASSWORD=
SMTP_FROM=
```

host／帳號／憑證由郵件服務提供；port只接受465或587，強制TLS。SMTP_FROM為已驗證可寄送的純Email。SMTP_USER／PASSWORD只放Runtime secret。正式送達、DNS SPF／DKIM／DMARC、權限及費用另驗收。

### 公開網址、語言與 App Store

政策與支援由 API 的 SSR routes 提供，不需要 Web Resource，使用者不需登入。部署的 `PRIVACY_POLICY_REVIEWED=true` 且公開資訊完整時回 200；未審核環境回 503 服務準備中。

- App 與 App Store 可共用 `PUBLIC_BASE_URL/privacy`；聯絡支援使用 `PUBLIC_BASE_URL/support`。
- 網頁提供繁體中文／English 切換；可用 `/privacy?lang=zh-Hant`、`/privacy?lang=en` 及同樣的 support query。未指定時依 `Accept-Language`，無匹配則繁中。App build 設定仍使用不帶 query 的原本網址。
- 公開頁左上角使用 iPhone App icon（API 的 `public/app-icon.png`）；`npm run build` 複製到 `dist/public/`，Docker image 包含此資產，不需額外 resource 或環境變數。
- 預設淺色及可選 `?theme=dark` 取自 App 的紫色、靛色、圓角與表面 tokens，不載入第三方素材、字型或追蹤。
- 本版政策為 `2026-10-02-optional-mail-v1`。未設定 `PRIVACY_POLICY_VERSION` 可採新版預設；若 Coolify 有舊的明確值，更新為此版本。版本變更會更新 AI 同意 fingerprint，使用者需重新同意。
- 營運者須重新閱讀新版政策，核對 `SERVICE_OPERATOR`、`SUPPORT_EMAIL`、`DATA_REGION` 與供應商公開條款。`PRIVACY_POLICY_REVIEWED` 是內容確認，不能取代真正審核，也不能填虛構資料。

Apple 要求 iOS App 提供 Privacy Policy URL，並允許各語言的隱私 URL 本地化；同一可切換語言的公開頁可供 App 及商店使用。App Privacy 資料標籤需另依實際資料流填寫，並非只填網址即可完成。[Apple App Privacy 設定](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)、[Review Guidelines 5.1.1](https://developer.apple.com/app-store/review/guidelines/)。

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
4. 確認 `/privacy`、`/support` 及 `/api/service-policy` 回應；disabled 時應為 `mailEnabled=false`、`registrationEnabled=true`、`emailVerificationRequired=false`，`ai.reviewed` 仍以供應商實際審核狀態為準。
5. 無 SMTP 以合成成年帳號驗收註冊→年齡聲明→profile→保存→重新登入／API 重啟後持久化→匯出／刪除；15–17 歲需確認待監護人同意仍阻擋受限寫入。啟用 SMTP 時另驗證註冊→驗證信→年齡／監護人流程、已驗證信箱的重設與真實送達。未啟用寄信功能應得到明確錯誤。
6. 外部AI只在供應商說明確認與使用者同意後驗收合成輸入；health200不代表SMTP／AI成功。
7. iPhone另在已忽略的app/.env.appstore.local設定API_BASE_URL（以/api/結尾）、PRIVACY_POLICY_URL（/privacy）、SUPPORT_URL（/support）、客服／營運者與Apple資訊。正式 archive 腳本先執行下述公開檢查，通過後才產生 signed IPA；再完成 TestFlight、商店表單及實機驗收。API部署不會更新已安裝App。

### iPhone 正式 archive 的公開配置檢查（2026-10-02）

`app/tool/check_release_readiness.py` 使用 Python 3 標準函式庫，只 GET 公開端點，不登入、寄信、呼叫 AI 或寫入資料。`build_ios_release.sh` 會在建置前強制執行；不提供略過阻擋的選項。可先獨立檢查：

```bash
cd app
set -a
source .env.appstore.local
set +a
python3 tool/check_release_readiness.py
```

需要檢查：正式 HTTPS URL；health 為 hosted／postgres；臺灣 15+ 現行政策及服務資格 gate；註冊、寄信及信箱驗證開啟；外部 AI 公開政策完整且已核准；繁中／英文隱私及支援頁均為 200，營運者／客服與 App build 一致。Cloudflare 對公開 Email 的 HTML 改寫會在本機解碼核對，不執行網頁 script。失敗回非零 exit code，阻止正式 IPA。

`MAIL_PROVIDER=disabled` 仍是最小 API 啟動選項；目前沒有新的免寄信監護人管道，不能作完整 15+ 上架配置。上架版須提供真實 SMTP runtime 設定並驗收送達；AI reviewed 只能在實際查核供應商後確認。此檢查不取代以下人工驗收：

- 合成成年與 15–17 歲帳號：註冊、Email 驗證、監護人確認、個人設定、家庭加入／退出；家長只看摘要，孩子不看家長帳務。
- 信件送達、過期／重寄、已驗證信箱的密碼重設與舊 session 失效；客服信箱可收信，不能依未驗證 Email 復原。
- API 重啟後仍能重新登入及取回資料、匯出／刪除；真實 PostgreSQL 跨帳號隔離。
- 已核准 provider／model 的真實 AI 連線、限額及資料條款；Apple Team、Bundle ID、signed TestFlight、真機、App Privacy／年齡問卷及送審資訊。

上述動作另依授權操作。純設定檢查通過、CI validation build 或 API healthy 皆不表示已送審或正式營運驗收完成。

本輪沒有新增migration、不改舊checksum、不刪volume。沒有備份時仍不得用舊API回滾來冒充schema／資料完整回復。

## 6. 自動部署與選用 Web

GitHub App／webhook正常且API Auto Deploy開啟時，push設定的main會重新build／deploy；手動Stop容器不等於關閉Auto Deploy。只修改本機未push不觸發，PostgreSQL不因Git push重建。

測試Web維持停止並關閉Auto Deploy，可避免每次main更新浪費Flutter建置資源。日後需測試時才使用/app的Dockerfile獨立Application、port3000、health /，並設定BUILD_ENV=production與公開API_BASE_URL／PRIVACY_POLICY_URL／SUPPORT_URL／SUPPORT_EMAIL／SERVICE_OPERATOR等Build only值；同時加入Web origin至API CORS。Compose與BUILD_ENV=validation產物只供本機／CI。

## 7. 維運驗收

確認API log沒有Authorization、密碼、capture原文、SQL URL、prompt或供應商body；database不公開port。取得實際proxy IP後設定TRUSTED_PROXY_CIDRS，避免所有使用者共用proxy IP限流；不可猜測全部信任網段。TWSE outbound HTTPS失敗時可顯示明示來源的教育快照，不冒充即時行情。

本輪驗證紀錄見 [測試與證據](testing-and-evidence.md)。編譯／公開頁預覽／Coolify healthy 均不能取代正式帳號、SMTP／AI、Apple 登入或送審驗收。

## 8. Rollback 與故障處理

- ConfigurationError：補錯誤列出的變數名稱，不略過preflight／health。
- Database connection：核對private network、Internal URL、DATABASE_SSL與postgres provider；不公開資料庫繞過問題。
- SMTP：disabled 開放註冊／登入但不送信，信箱保持未驗證，監護人資格仍獨立檢查；smtp 有憑證但送達失敗需檢查服務權限與 TLS，不能宣稱已寄出。
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
