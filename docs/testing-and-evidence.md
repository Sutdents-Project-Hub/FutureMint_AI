# 測試與證據

## 最新本機驗證

驗證日期：2026-07-15（Asia/Taipei）。以下只記錄實際執行結果，不代表 Coolify production、量界正式帳號或真實未成年人服務驗收。

| 元件 | 指令／操作 | 結果 |
|---|---|---|
| Fastify API | `npm test` | 11 個 test files、59 tests 通過 |
| Fastify API | `npm run typecheck` | 通過 |
| Fastify API | `npm run build` | 通過 |
| Dependencies | `npm audit --omit=dev` | 0 vulnerabilities |
| Capture evaluation | `npm run evaluate:captures` | 30/30 cases、30/30 schema、225/225 field checks |
| PostgreSQL migration | PostgreSQL 17 clean test DB 執行兩次 `npm run migrate` | 第一次套用 `001_initial.sql`，第二次 applied 0；migration checksum 長度 64 |
| PostgreSQL seed guard | 未設 `ALLOW_DEMO_SEED=true` 執行 seed | 在建立 repository／寫入前拒絕，exit code 1 |
| PostgreSQL synthetic seed | 設安全開關後執行兩次 | 無法登入的 synthetic account／profile／4 events；idempotent，event count 仍為 4 |
| API Docker build | `docker build -t futuremint-api:codex services/api` | 通過；Node.js 22 multi-stage image |
| API Docker demo | `AI_PROVIDER=demo`、`DATA_PROVIDER=memory` | Container health 200；沒有要求 `DATABASE_URL` 或執行 migration |
| API Docker + PostgreSQL | `DATA_PROVIDER=postgres` 指向 PostgreSQL 17 | 啟動 migration applied 0、health 200，回報 hosted／postgres |
| Persistence E2E | Container register → profile → event → stop／new container → login → list | 通過；重啟後讀回 1 event |
| Flutter format | `dart format --output=none --set-exit-if-changed lib test integration_test` | 46 files，0 changed |
| Flutter analyze | `flutter analyze` | 0 issues |
| Flutter tests | `flutter test` | 58 tests 通過 |
| Flutter Web | `flutter build web --release --dart-define=API_BASE_URL=...` | 通過 |
| Frontend Docker build | `docker build --build-arg API_BASE_URL=... -t futuremint-web:codex apps/client` | 通過；固定 Flutter 3.41.9 commit，Nginx runtime image 約 34.4 MB |
| Frontend container | root／`/capture`、Docker health、bundle config | HTTP 200、deep-link 回同一 SPA entry、health healthy、bundle 含指定公開 API URL |
| Web cache | 檢查 response headers | `index.html` 回 `Cache-Control: no-store` |
| Bundle secret scan | 搜尋 release bundle | 沒有 `LIANGJIE_API_KEY`、`DATABASE_URL`、`postgresql://` 或 placeholder password |
| Earlier browser QA | 2026-07-14 本機 Chrome | 登入入口、responsive dashboard、dark settings 與短 landscape navigation 已人工檢查 |

本機 Docker 是 ARM64；最終 Dockerfiles 使用 multi-architecture Debian／Node／Nginx base，Flutter SDK 依建置主機下載相符 toolchain，但仍需在實際 Coolify VPS architecture 完成一次正式 build。

## 測試覆蓋重點

### API

- Register／login／logout／revoked session、相同 generic invalid-credential error。
- 帳號 ownership：帳號 B 看不到帳號 A 的事件。
- Budget、split、subscription monthly cost、FutureSeed zero rate 與 compound calculation。
- Parse 不保存、確認保存、idempotency、query filters、malformed JSON 與 validation envelope。
- CORS allowed／denied preflight、安全 headers、not found、health dependency failure。
- Runtime 設定缺失／不合法時明確失敗。
- 量界 adapter：OpenAI-compatible request、nullable fields、type／category semantics、Markdown JSON fence、invalid JSON／schema、timeout、429 retry budget。
- PostgreSQL mapping、parameterized queries、event idempotency、sessions、lessons、health 與 close。

### Flutter

- Model JSON 與 `liangjie-ai` source mapping。
- Register／login envelope、Bearer header、首次設定、訪客不保存 session。
- API timeout／problem envelope、明確 timezone、空資料不虛構 subscription。
- Capture 三階段、多 draft、修正、單筆確認、partial refresh recovery。
- Dashboard、phone／desktop navigation、subscription、lesson action、FutureSeed。
- 200% text scale、short landscape rail、Design System components 與 responsive bento。

## 30 筆合成解析評估

Fixture：`services/api/test/fixtures/capture-evaluation.json`；報告：

- `services/api/reports/capture-evaluation.md`
- `services/api/reports/capture-evaluation.json`

涵蓋收入、單／多筆支出、相對日期、缺金額、訂閱、分帳、否定句、無關文字、折扣與合成通知。它評估 `deterministic-demo`，用途是 regression，不是量界真實模型準確率；簡報不可把 100% 混稱量界成效。

## 尚未驗證

- 量界正式 API key、帳號可用 model、費率、quota、資料條款、真實 output quality、P95 latency 與 outage 行為。
- GitHub private remote、GitHub App、webhook／Auto Deploy；目前 workspace 沒有 remote。
- 實際 Coolify VPS 的 AMD64／ARM64 image build、domains、TLS、CORS、health routing、resource limits 與 rollback。
- Coolify PostgreSQL internal URL、production capacity、scheduled S3 backup 與隔離 restore。
- Production log retention、磁碟告警與 server／Coolify 自身備份。
- Flutter Web integration drive；Flutter CLI 的 Web integration test 仍需相容 ChromeDriver。等價主線已有 Widget／HTTP／container tests，不冒充 drive 通過。
- Android debug build先前因本機磁碟空間不足未產出 APK；Android 實機、iOS build／signing 未驗證。
- 正式螢幕閱讀器、完整鍵盤、色覺與 reduced-motion 人工驗收。
- Production identity hardening：email verification、password reset、MFA、帳號刪除、session cleanup、shared rate limit、同意與資料保留。

## 重現方式

API：

```bash
cd services/api
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
cd apps/client
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter build web --release \
  --dart-define=API_BASE_URL=https://api.example.com/api/
docker build \
  --build-arg API_BASE_URL=https://api.example.com/api/ \
  -t futuremint-web .
```

PostgreSQL migration 與 E2E 需使用獨立 local test database，`DATABASE_URL` 只透過 shell／ignored `.env` 注入，不把 credential 寫入文件或 repository。
