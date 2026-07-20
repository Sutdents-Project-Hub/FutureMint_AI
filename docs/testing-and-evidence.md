# 測試與證據

## 最新本機驗證

驗證日期：2026-07-19（Asia/Taipei）。以下只記錄實際執行結果，不代表 Coolify production、量界正式帳號或真實未成年人服務驗收。

| 元件 | 指令／操作 | 結果 |
|---|---|---|
| Fastify API | `npm test` | 15 個 test files、86 tests 通過 |
| Fastify API | `npm run typecheck` | 通過 |
| Fastify API | `npm run build` | 通過 |
| Dependencies | `npm audit --omit=dev` | 0 vulnerabilities |
| Capture evaluation | `npm run evaluate:captures` | 30/30 cases、30/30 schema、225/225 field checks |
| PostgreSQL migration | PostgreSQL 17 Compose 執行 migration | 套用 `001_initial.sql`、`002_roles_and_intents.sql`、`003_investment_lab.sql`、`004_family_accounts.sql`；家庭 groups／members、角色／意圖欄位與兩個虛擬投資 tables 存在 |
| PostgreSQL seed guard | 未設 `ALLOW_DEMO_SEED=true` 執行 seed | 在建立 repository／寫入前拒絕，exit code 1 |
| PostgreSQL synthetic seed | 設安全開關後執行兩次 | 無法登入的 synthetic account／profile／4 events；idempotent，event count 仍為 4 |
| API Docker build | `docker build -t futuremint-api:codex backend` | 通過；Node.js 22 multi-stage image |
| API Docker demo | `AI_PROVIDER=demo`、`DATA_PROVIDER=memory` | Container health 200；沒有要求 `DATABASE_URL` 或執行 migration |
| API Docker + PostgreSQL | `DATA_PROVIDER=postgres` 指向 PostgreSQL 17 | 啟動 migration applied 0、health 200，回報 hosted／postgres |
| Persistence E2E | Container register → profile → event → stop／new container → login → list | 通過；重啟後讀回 1 event |
| Investment persistence E2E | Container register → profile → virtual buy → restart API → login → investment lab | 通過；重啟後讀回 1 order、2 股與正確剩餘現金 |
| TWSE market adapter | 實際呼叫 `/v1/exchangeReport/STOCK_DAY_ALL` 與 `/api/market/quotes` | 取得 5 個內建教學標的、資料日 2026-07-14、`isFallback=false`；另有 timeout／fallback unit test |
| Docker Compose | `docker compose config`、`docker compose up -d --build --wait` | `futuremint_ai` 單一專案群組內 Web／API／PostgreSQL 三服務 healthy；Web 200、API health 200（hosted／demo／postgres） |
| Production fail-fast | 以 production Node image 注入 `demo + memory` | container 在 listen 前退出；unit test 同時驗證 production 只接受 `liangjie + postgres`、HTTPS CORS origin 為必填且合法 |
| Flutter format | `dart format --output=none --set-exit-if-changed lib test integration_test` | 52 files，0 changed |
| Flutter analyze | `flutter analyze` | 0 issues |
| Flutter tests | `flutter test` | 74 tests 通過 |
| Flutter Web | `flutter build web --release --dart-define=API_BASE_URL=...` | 通過 |
| Android debug | `flutter build apk --debug` | 通過，產出 debug APK；尚未進行實機驗收或 signing |
| UX visual QA | Docker Web + in-app Browser（1440×900、375×812、812×375） | 登入／訪客／dashboard 可用，底部導覽與 landscape rail 正常、沒有水平溢位與 console error；已確認新 PWA brand icon 可取得 |
| Frontend Docker build | `docker build --build-arg API_BASE_URL=... -t futuremint-web:codex app` | 通過；固定 Flutter 3.41.9 commit，Nginx runtime image 約 34.4 MB |
| Frontend container | root／`/capture`、Docker health、bundle config | HTTP 200、deep-link 回同一 SPA entry、health healthy、bundle 含指定公開 API URL |
| Web cache | 檢查 response headers | `index.html` 回 `Cache-Control: no-store` |
| Bundle secret scan | 搜尋 release bundle | 沒有 `LIANGJIE_API_KEY`、`DATABASE_URL`、`postgresql://` 或 placeholder password |
| Browser QA | 2026-07-15 本機 Docker + in-app Browser | 桌面與 375×812：既有主線，以及投資練習場來源／日期、虛擬買入、持倉配置、事件骰子與 AI 陪讀；無明顯重疊或控制項溢位 |

本機 Docker 是 ARM64；最終 Dockerfiles 使用 multi-architecture Debian／Node／Nginx base，Flutter SDK 依建置主機下載相符 toolchain，但仍需在實際 Coolify VPS architecture 完成一次正式 build。

## 測試覆蓋重點

### API

- Register／login／logout／revoked session、相同 generic invalid-credential error。
- 帳號 ownership：帳號 B 看不到帳號 A 的事件。
- Budget、split、subscription monthly cost、六個月 cashflow、提醒、FutureSeed zero rate、三情境曲線與 drawdown calculation。
- FutureSeed 1.5%／5%／8% 合成路徑的十年幾何平均校準，以及不被每月投入稀釋的報酬指數 drawdown。
- TWSE 日資料 schema／民國日期／change percent／cache fallback／同時 cache miss 合併；虛擬現金、買入、賣出、持有量、配置、idempotency、同帳號併發下單與可重現事件牌組。
- Parse 不保存、確認保存、idempotency、query filters、malformed JSON、request body 過大與 validation envelope。
- CORS allowed／denied preflight／預檢快取、安全 headers、AI route rate limit、not found、health dependency failure；production origin 缺失、尾端 `/` 或非 HTTPS 時 fail-fast。
- Lessons completion body schema、同時註冊同 email 的 conflict response。
- Runtime 設定缺失／不合法時明確失敗；production 只允許完整的 `liangjie + postgres` provider pair。
- 量界 adapter：OpenAI-compatible request、nullable fields、type／category／intent semantics、Markdown JSON fence、invalid JSON／schema、timeout、429 retry budget、學習規劃與安全陪讀回覆。
- AI 文字安全：英文 lesson output 會被 `ai_invalid_output` schema 拒絕；coach 支援回答方式契約；家庭 service 驗證邀請碼、家長／孩子角色與摘要權限。
- PostgreSQL mapping、parameterized queries、event idempotency、sessions、lessons、health 與 close。

### Flutter

- Model JSON 與 `liangjie-ai` source mapping。
- Register／login envelope、Bearer header、首次設定、訪客不保存 session。
- API timeout／problem envelope、明確 timezone、空資料不虛構 subscription、session 還原時的暫時網路失敗／未授權分流。
- Capture 三階段、多 draft、修正、單筆確認、儲存後清空輸入、partial refresh recovery。
- Dashboard、phone／desktop direct navigation、subscription、lesson action、需要／想要控制、無延遲分析圖表與三路徑 FutureSeed。
- 投資練習場 route、盤後來源、訪客虛擬買入、超賣拒絕、事件骰子與 200% text scale。
- 200% text scale、short landscape rail、Design System components 與 responsive bento；FutureSeed sliders 的名稱與值語意、light-surface feature heading 4.5:1 text contrast。

## 30 筆合成解析評估

Fixture：`backend/test/fixtures/capture-evaluation.json`；報告：

- `backend/reports/capture-evaluation.md`
- `backend/reports/capture-evaluation.json`

涵蓋收入、單／多筆支出、相對日期、缺金額、訂閱、分帳、否定句、無關文字、折扣與合成通知。它評估 `deterministic-demo`，用途是 regression，不是量界真實模型準確率；簡報不可把 100% 混稱量界成效。

## 尚未驗證

- 量界正式 API key、帳號可用 model、費率、quota、資料條款、真實 output quality、P95 latency 與 outage 行為。
- GitHub App、webhook／Auto Deploy；workspace 已有 remote，但本次尚未 push 或連接 Coolify。
- GitHub Actions workflow 已加入，但本次尚未在 GitHub hosted runner 實際執行；需下一次 push／Pull Request 觀察。
- 實際 Coolify VPS 的 AMD64／ARM64 image build、domains、TLS、CORS、health routing、resource limits 與 rollback。
- Coolify PostgreSQL internal URL、production capacity、scheduled S3 backup 與隔離 restore。
- Production log retention、磁碟告警與 server／Coolify 自身備份。
- Flutter Web integration drive；Flutter CLI 的 Web integration test 仍需相容 ChromeDriver。等價主線已有 Widget／HTTP／container tests，不冒充 drive 通過。
- Android 實機、iOS build／signing 未驗證。
- 正式螢幕閱讀器、完整鍵盤、色覺與 reduced-motion 人工驗收。
- Production identity hardening：email verification、password reset、MFA、帳號刪除、session cleanup、shared rate limit、同意與資料保留。

## 重現方式

API：

```bash
cd backend
npm ci
npm test
npm run typecheck
npm run build
npm run evaluate:captures
npm audit --omit=dev
docker build -t futuremint-api .
```

Flutter：

```bash
cd app
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter build web --release \
  --dart-define=API_BASE_URL=https://api.example.com/api/
flutter build apk --debug
docker build \
  --build-arg API_BASE_URL=https://api.example.com/api/ \
  -t futuremint-web .
```

PostgreSQL migration 與 E2E 需使用獨立 local test database，`DATABASE_URL` 只透過 shell／ignored `.env` 注入，不把 credential 寫入文件或 repository。
