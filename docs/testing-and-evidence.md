# 測試與證據

## 本輪證據界線（2026-10-01）

分類：新能力、缺陷修正與釐清。下方歷史測試數量僅對應各自日期／狀態。基線 `af7a5df` 的 GitHub CI 已確認成功：122 API tests、121 Flutter tests、未簽章 iOS 與 Web／API images；本輪新變更尚未跑遠端 CI，最新本機驗證結果需按本輪實際指令記錄。

使用者確認既有 Coolify 三 Resources 曾成功部署；目前 live health、DNS／TLS、runtime 設定與完整使用者流程尚未在本輪驗證。本次程式變更需由使用者自行重新部署並驗收。

本輪已覆蓋訂閱同交易／完整 payload 重試、舊付款採用、分頁全量統計、owner 隔離、臺灣年齡／監護人 token／撤回、provider fingerprint 再授權／雙供應商 gate、共享 AI 額度／lease、preflight 先於 migration、DATE／近零複利、虛擬執行順序及家庭捕獲成員變動 409。Client 本機測試另覆蓋手動流程／同 key retry、所有 onboarding 退出／刪除／help/retry、iPhone 提醒 permission／時區／清除／resume。測試通過只能證明被測的本機狀態；未使用真實 provider key。

未驗收：SMTP／domain／正式 AI 條款與品質、每日備份保留 30 天／隔離還原／刪除不復活、Apple Team／signed TestFlight／通知實機、App Privacy／年齡問卷。既有 CI 或未簽章產物不取代這些外部證據。

### 最終本機執行結果（2026-10-01）

| 項目 | 結果及界線 |
|---|---|
| API Node.js 22 | `npm test` 31 files／224 tests 全通過，含 localhost PostgreSQL 17 隔離 schema 整合；`npm run typecheck`、`npm run build` 通過 |
| PostgreSQL | 001–011 migrations 在空白測試 DB 套用成功；舊 001–007 checksum／源檔不變。覆蓋跨 Pool 交易、families、角色、DATE、訂閱採用／重試／owner、資格與 AI 額度。011 對帳測試驗證 preview 無變更、apply 清除已刪帳號及 sessions／profile、保留其他使用者、重跑與非法 journal；沒有執行 production restore |
| 啟動配置 | CLI demo 正例 exit 0；缺 production 設定 exit 1，只列階段及變數名稱；Docker 執行 preflight 後才套 11 migrations／啟動 API |
| Capture evaluation | deterministic-demo 30/30 合成案例、schema 30/30、欄位 225/225，未呼叫真實 AI |
| 依賴稽核 | `npm audit --json` 所有等級 0；修補 Fastify、Nodemailer、fast-uri、Vitest、brace-expansion 相容版本，未做無關 major upgrade。結果對應當下 npm 官方公告 |
| Flutter | `dart format --output=none --set-exit-if-changed lib test integration_test`：73 files／0 changed；`flutter analyze --no-pub`：0 issues；`flutter test --no-pub`：152/152，包含 OpenAI provenance 解析／UI 標籤與拒絕 AI／唯讀的受控教材及本機答題回歸 |
| Swift／Simulator | iPhone simulator debug 編譯成功；`xcodebuild test ... -only-testing:RunnerTests CODE_SIGNING_ALLOWED=NO`：2/2，驗證 Taipei calendar／generic content／account-bound tap。不是實機通知驗收 |
| iPhone unsigned Release | 最終 `bash app/tool/build_ios_validation.sh` 通過；31.0 MB，`UIDeviceFamily=[1]`、SDK `iphoneos26.4`、bundle `tw.futuremint.futuremintApp`、1.0.0（1）、4 privacy manifests、無 integration_test framework。未簽章、不作 App Store 產物 |
| Docker API／Web | 最終兩個 images 本機建置成功；Web 使用 BUILD_ENV=validation，Flutter Web Release／Wasm dry run 成功；Nginx 首頁／deep links 200、no-store。未推送 images、未驗證遠端平台 |
| 實際跨元件契約 | 用 App 實際 Dart `AuthApi`／`ApiRepository` 對 localhost Docker API＋PostgreSQL：年齡聲明、service policy、UTF-8 受控教材、訂閱＋初次付款同 key 重試、commitment、付款連結、分頁、JSON 匯出、停用保留付款、刪除帳號通過。不是 SMTP／真實 AI／production 驗收 |
| 安全與審查 | 全部非忽略文字檔高信心 private key／token／webhook patterns 0 命中；未讀真實 `.env` 或掃完整 history。`git diff --check` 通過。獨立來源審查發現的付款連結、partial refresh、resume retry、唯讀刪除與 restore URL 問題已修正／複驗 |

日誌：`/tmp/futuremint-launch-backend-tests.log`、`/tmp/client-tests.log`、`/tmp/client-analyze.log`、`/tmp/client-native-tests.log`、`/tmp/futuremint-launch-ios-release.log`、`/tmp/futuremint-launch-api-docker.log`、`/tmp/futuremint-launch-web-docker.log`。最終 iPhone artifact：`app/build/release-ios/futuremint-ios.Vl8A1H/iphoneos/Runner.app`；均為忽略的本機產物。

本輪專用 API、Web、PostgreSQL 測試容器及匿名測試 volume 已清除；其他容器／資料卷未變更。當前工作在 `main`，本輪程式／文件未 commit／push，未執行遠端 CI、Coolify 部署、真實 SMTP／AI、Apple 簽章／上傳或送審。

## 2026-09-30 iPhone 手機版 UI 優化驗證

分類：缺陷修正（深色／亮色對比）與已核准範圍內的手機版面調整；不變更資料、API、權限或商業邏輯。工作於 branch `style/mobile-ui-polish`；本次未涉及部署。

| 項目 | 結果與界線 |
|---|---|
| Flutter | `dart format --set-exit-if-changed` 0 changed；`flutter analyze` 0 issues；完整 `flutter test` 121 項通過（新增 `test/features/mobile_layout_test.dart`：375×812 亮／暗 × 1x／2x 字級走過五個主要頁面無溢位，並檢查亮色預算 Hero 使用靛紫表面） |
| 修正的缺陷 | 底部導覽選中項文字在深色膠囊上不可見；亮色主題預算 Hero 為白底白字；深色主題提醒頁圖示與卡片同色不可見；深色下靛紫 kicker、收入金額、圖表第一條線與漲跌色對比不足；200% 字級下紀錄列金額溢位 |
| 版面調整 | 首頁移除重複的訪客說明並讓預算卡進入首屏；首頁／紀錄／記一筆／學習／FutureSeed 的角色插圖在手機改為與標題或內文並排的獨立欄位（仍保留原插圖）；紀錄列重新排版、插圖列移到清單後；草稿表單類型與分類並排、日期欄與輸入框一致；訂閱卡、提醒卡、投資練習場來源列與設定抽屜安全區調整；選中的 chip 以勾選圖示取代重疊的勾勾 |
| iPhone 模擬器實測 | iPhone 17 Pro（iOS 26.4）debug build，訪客模式＋本機 demo API；逐頁截取優化前後畫面（深色為主，另含亮色首頁）。不是實機、VoiceOver 或 App Store 截圖驗收 |

## 2026-09-06 正式產品修正後驗證

以下為本次未提交工作區的實際結果；不覆寫下方歷史證據。分類：缺陷修正、使用者核准的正式產品功能補齊，以及文件狀態釐清。

| 項目 | 結果與界線 |
|---|---|
| Backend Node 22 | 18 test files、122 tests 全通過，包含 8 項隔離 PostgreSQL 17 整合；typecheck／build 通過 |
| PostgreSQL 17 | 7 migrations；隨機 schema 的測試自動清除。涵蓋 family rollback、跨 Pool 角色競態、歷史角色修復、invite hash／到期／更新／停用、跨 instance 超支／idempotency、reset／session 並行與共享限流 |
| 依賴安全 | `npm audit --json`：0 info／low／moderate／high／critical；當下 npm 公告狀態，不代表所有漏洞皆可排除 |
| Capture regression | deterministic-demo 合成案例 30/30、schema 30/30、欄位 225/225；沒有呼叫量界真實模型 |
| Flutter | `flutter analyze` 0 issues；完整 `flutter test` 116 項通過；包含 session epoch、儲存遷移、寄信失敗、主題／繁中、驗證／重設與邀請 UI |
| iPhone unsigned Release | 最終 `build_ios_validation.sh` 通過，30.7 MB；root 檢查 `UIDeviceFamily=[1]`、SDK iphoneos26.4、bundle `tw.futuremint.futuremintApp`、4 個隱私 manifests，無 integration_test framework |
| Web Release | 本機 `BUILD_ENV=validation` Web build 通過，使用 localhost API；不作正式環境驗收 |
| API Docker | `futuremint-api:local-hardening` 本機重建成功，Node 22 image；未推送 |
| Web Docker | `futuremint-web:local-hardening` 以完整 validation args 重建成功；不作正式發布產物 |
| 瀏覽器實際操作 | 390×844 Web 的訪客首頁／設定／亮色切換／記帳確認通過；加入合成支出 75 後可用金額 5377→5302。另檢查恢復頁缺 token 時停用提交；不是原生 iPhone／VoiceOver 驗收 |
| Packaging／配置 | bash syntax、staging isolation Python test、空 env 的 Compose config 與 diff whitespace 檢查通過 |
| 秘密掃描 | 235 個 tracked／untracked 非忽略文字檔的高信心 private-key／token patterns 0 命中；未讀真實 .env，未掃完整 Git history |

測試暫存紀錄：`/tmp/futuremint-backend-final-tests.log`、`/tmp/futuremint-backend-final-audit.json`、`/tmp/futuremint-app-analyze-final.log`、`/tmp/futuremint-app-tests-final.log`、`/tmp/futuremint-ios-validation-final.log`、`/tmp/futuremint-web-final-build.log`、`/tmp/futuremint-api-docker-hardening.log`、`/tmp/futuremint-web-docker-final.log`。iPhone 產物：`app/build/release-ios/futuremint-ios.vahF7U/iphoneos/Runner.app`（未簽章）。這些均是忽略的本機產物，可被系統清理。

正式 SMTP 送達、AI 條款／真實模型、正式 DNS／TLS／DB／備份還原、Apple Team／signed archive／TestFlight／商店截圖與表單均未完成。本次專用 PostgreSQL 合成測試容器、API／靜態測試伺服器及瀏覽器分頁已清理；原有專案資料卷未變更。本次沒有 commit、push、PR、部署或送審。

## 歷史本機驗證

歷史基線驗證日期：2026-08-30（Asia/Taipei）；2026-09-06 修正後證據見下方最新章節。以下只記錄實際執行結果，不代表 Coolify production、量界正式帳號、App Store Connect 或真實未成年人服務驗收。

### App Store P0 本機收斂（2026-08-30，Asia/Taipei）

| 元件 | 指令／操作 | 結果 |
|---|---|---|
| API 帳號刪除／AI 同意 | `cd backend && npm test && npm run typecheck && npm run build` | 15 個 test files、100 tests 通過；含密碼再驗證、session 失效、email 再註冊、家庭 cascade、consent 版本／授權／撤回，以及四個量界 routes 在 provider 呼叫前攔截。 |
| Flutter 同意／撤回／刪除 UI | `cd app && dart format lib test integration_test && flutter analyze && flutter test` | 53 files 格式檢查完成、analyze 0 issues、95 tests 通過；含 HTTP method／body、未同意不呼叫 repository、policy 升版後本機 fail closed、撤回清除 AI state、錯誤密碼保留 session 與雙重確認 UI。 |
| Guest 日期回歸 | 整套 `flutter test` 及固定 clock tests | 合成種子依當前台北年月產生，下次續訂在下月、目標日在未來；不再因日曆跨月讓 dashboard／insights 失真。 |
| App Store 本機設定安全 | `bash -n app/tool/build_ios_release.sh`、`.gitignore` 與 example env 檢查 | 腳本語法通過；會拒絕 localhost／placeholder／非 HTTPS API URL、無效 build number 與 Runner 不一致的 Bundle ID。`.p8`、provisioning profile 與憑證類型已忽略，example 無真實 secret。 |
| iOS unsigned Release | `flutter build ios --release --no-codesign --dart-define=API_BASE_URL=https://api.example.invalid/api/` | Xcode build 通過，產出 29.0 MB `Runner.app`；Bundle ID `tw.futuremint.futuremintApp`、版本 `1.0.0`、build `1`。內嵌 Flutter 與 `shared_preferences_foundation` privacy manifest；Client 只使用系統 HTTPS，`ITSAppUsesNonExemptEncryption=false`。此結果只證明本機可編譯，不代表已簽章或可上傳。 |

本輪沒有對外部 PostgreSQL 執行 `005_ai_consents.sql`，也沒有以真實量界帳號或已簽章 IPA 做 E2E；migration 與 repository SQL 目前只有契約測試。

### 帳務修改與刪除複驗（2026-07-25，Asia/Taipei）

| 元件 | 指令／操作 | 結果 |
|---|---|---|
| API ownership／更新／刪除 | `cd backend && npm test && npm run typecheck && npm run build` | 15 個 test files、90 tests 通過；驗證同帳號可修改／刪除、分帳重新計算，帳號 B 操作帳號 A 的事件一律 404，CORS 預檢允許 `DELETE`。 |
| Flutter guest data 與紀錄 UI | `cd app && flutter test test/widget_test.dart test/data/demo_repository_test.dart && flutter analyze` | 通過；驗證訪客單筆修改／刪除會更新餘額，以及紀錄列操作選單可開啟編輯表單。 |

### 本機量界智算整合複驗（2026-07-25，Asia/Taipei）

以下結果使用已忽略根目錄 `.env` 的 runtime secret；不記錄 key、prompt、完整 provider body 或使用者資料。本輪只驗證本機 Compose，尚未部署或連接 Coolify。

| 元件 | 指令／操作 | 結果 |
|---|---|---|
| Compose API | `docker compose up -d --build --wait api` | API 與 PostgreSQL healthcheck 通過；API 以 `liangjie`／`postgres` runtime pair 啟動。 |
| Runtime health | `GET /api/health` | HTTP 200，回報 `aiProvider=liangjie`、`dataProvider=postgres`。 |
| 實際 AI inference：記帳／陪讀 | API 容器內以合成記帳文字呼叫 capture，再以合成問題呼叫 coach | 兩個請求皆在首次嘗試成功；capture 回傳 1 筆 `liangjie-ai` 草稿，coach 回傳通過既有繁體中文與安全 schema 的 `liangjie-ai` 回覆。 |
| 實際 AI inference：微課／學習規劃 | API 容器內以合成 profile、事件與洞察呼叫 lesson 與 learning plan | 兩個請求皆在首次嘗試成功；lesson 回傳可顯示的繁中選項，learning plan 回傳 4 個不重複主題且恰有 1 個 next module。 |

上述 inference 不寫入資料庫。

### UI 合併修復複驗（2026-07-22，Asia/Taipei）

以下結果針對 `feat/replicate-homepage` 合併到本機工作目錄後的 UI 修復；已建立本機 `main` commit `d876147`，尚未 push 或部署。

| 元件 | 指令／操作 | 結果 |
|---|---|---|
| Flutter format | `dart format --output=none --set-exit-if-changed lib test integration_test` | 52 files，0 changed |
| Flutter analyze | `flutter analyze` | 0 issues |
| Flutter tests | `flutter test` | 74 tests 通過；包含 600dp 高度登入頁的訪客入口可見與可點擊檢查 |
| Flutter Web | `flutter build web --release --dart-define=API_BASE_URL=http://localhost:3000/api/` | 通過 |
| Short viewport visual QA | 本機 Web，375×600 瀏覽器畫面 | 登入標題未被角色圖遮住；訪客按鈕與「資料不會儲存」說明均在首屏可見；登入表單可向下捲動 |

### 全頁 RWD 與文字重疊修正複驗（2026-07-22，Asia/Taipei）

以下結果針對儀表板、記帳、紀錄、學習、FutureSeed、登入／首次設定、設定與底部導覽的 RWD 巡檢；該輪 UI 修復已建立本機 `main` commit `d876147`，尚未 push 或部署。

| 元件 | 指令／操作 | 結果 |
|---|---|---|
| 定位與控制項巡檢 | 逐一檢視所有前端路由的 `Positioned`、負位移與 `SegmentedButton` | 保留學生原有的角色、插圖與星點，並改放入保留版位或內容背景層，避免覆蓋內容；窄寬或 130% 以上字級的長選項改為可換行 chips。 |
| Flutter format | `dart format lib test integration_test` | 完成格式化。 |
| Flutter analyze | `flutter analyze` | 0 issues。 |
| Flutter tests | `flutter test` | 75 tests 通過；新增 375×812、200% 字級的紀錄頁／設定頁測試，以及 Dashboard 角色插圖保持在預算卡內的幾何檢查。 |
| Flutter Web | `flutter build web --release --dart-define=API_BASE_URL=http://localhost:3000/api/` | 通過，產出 `app/build/web`。 |
| 本機預覽快取復原 | `http://127.0.0.1:4173/?reset-cache` | 僅在明確帶入 `reset-cache` 時，解除該 origin 的 Flutter Service Worker 並清除 Cache Storage，接著回到正常網址；用於避免本機 rebuild 後仍執行舊 JavaScript。 |

### Desktop 網頁畫布複驗（2026-07-22，Asia/Taipei）

以下結果針對 signed-in／guest 主流程在寬螢幕瀏覽器不再呈現為置中的狹窄 App；本輪變更尚未建立新的 commit、push 或部署。

| 元件 | 指令／操作 | 結果 |
|---|---|---|
| Desktop canvas geometry | 新增 `ResponsivePageCanvas` 與 1920dp widget test | 寬螢幕 App Shell 使用扣除 264dp 側欄後的完整寬度；紀錄頁交易清單使用該畫布扣除左右 32dp gutter 的完整寬度。 |
| Flutter analyze | `flutter analyze` | 0 issues。 |
| Flutter tests | `flutter test` | 77 tests 通過；包含共用 desktop canvas 與首頁／紀錄頁幾何檢查。 |
| Flutter Web | `flutter build web --release --dart-define=API_BASE_URL=http://localhost:3000/api/` | 通過，產出 `app/build/web`。 |
| Browser visual QA | 本機 Web，1920×1080 | 首頁、紀錄、記一筆、學習與 FutureSeed 皆使用側欄右側完整畫布，保留 32dp gutter；角色插圖未遮住標題、金額、表單或操作。登入、說明與設定彈窗維持聚焦寬度。 |

### 登入／註冊垂直節奏複驗（2026-07-23，Asia/Taipei）

以下結果針對寬螢幕登入／註冊畫面中角色插圖與表單之間的非預期大量空白；本輪變更尚未建立新的 commit、push 或部署。

| 元件 | 指令／操作 | 結果 |
|---|---|---|
| Desktop geometry | 新增登入圖片槽與表單幾何 widget test | 圖片依 4:3 實際高度保留版位；桌面圖片槽與表單距離維持 8–32dp，不再依圖片寬度產生額外空白。 |
| Flutter analyze | `flutter analyze` | 0 issues。 |
| Flutter tests | `flutter test` | 78 tests 通過。 |
| Flutter Web | `flutter build web --release --dart-define=API_BASE_URL=http://localhost:3000/api/` | 通過，產出 `app/build/web`。 |
| Browser visual QA | 本機 Web，1920×1080 | 登入／註冊角色插圖與標題形成緊湊視覺群組，保留閱讀呼吸空間且未互相覆蓋。 |

### 決賽答辯可見證據複驗（2026-07-24，Asia/Taipei）

以下結果針對 AI 主導權、FutureSeed 教育邊界與家庭資料最少揭露的畫面說明；本輪變更尚未建立 commit、push 或部署。

| 元件 | 指令／操作 | 結果 |
|---|---|---|
| AI 草稿主導權 | `capture_screen_test.dart` | 草稿明示可修改所有欄位、確認後才更新分析、修正不會自動訓練 AI；確認前帳務筆數不變。 |
| FutureSeed／資料界線 | `settings_transparency_test.dart` | 設定畫面明示 FutureSeed 是教育模擬、決賽僅用合成資料，以及 AI provider／原文保存邊界。 |
| Flutter analyze | `flutter analyze` | 0 issues。 |
| Flutter tests | `flutter test` | 79 tests 通過。 |
| Flutter Web | `flutter build web --release --dart-define=API_BASE_URL=http://localhost:3000/api/` | 通過，產出 `app/build/web`。 |
| Browser visual QA | 本機 release Web，桌面與 375×812 | 草稿確認、設定抽屜與新說明可完整閱讀；沒有溢位或 console error。 |

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

## 歷史測試覆蓋重點（本輪新增覆蓋見開頭）

### API

- Register／login／logout／revoked session、相同 generic invalid-credential error、目前密碼再驗證帳號刪除與 cascade。
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
- AI 同意：當前 policy version、授權／撤回 timestamps、舊版重新同意，以及量界 parse／lesson／plan／coach 的 provider-before-call gate。
- PostgreSQL mapping、parameterized queries、event idempotency、sessions、lessons、health 與 close。

### Flutter

- Model JSON 與 `liangjie-ai` source mapping。
- Register／login envelope、Bearer header、首次設定、訪客不保存 session、帳號刪除後清除 token。
- AI consent GET／PUT、揭露／啟用／撤回 UI、未同意時本機不發 AI request，以及撤回後的 AI-only state 清除。
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

- 量界正式環境的費率、quota、資料條款、真實使用情境 output quality、P95 latency 與 outage 行為。
- 本輪重新部署的 GitHub App、webhook／Auto Deploy 仍需驗收；既有 Coolify 曾成功部署，不據此推定新程式已在平台運作。
- 基線 `af7a5df` 已在 GitHub hosted runner 成功；本輪新狀態需於後續 push／Pull Request 重新觀察。
- 實際 Coolify VPS 的 AMD64／ARM64 image build、domains、TLS、CORS、health routing、resource limits 與 rollback。
- Coolify PostgreSQL internal URL、production capacity、scheduled S3 backup 與隔離 restore。
- Production log retention、磁碟告警與 server／Coolify 自身備份。
- Flutter Web integration drive；Flutter CLI 的 Web integration test 仍需相容 ChromeDriver。等價主線已有 Widget／HTTP／container tests，不冒充 drive 通過。
- Android 實機與 iOS signing／archive／TestFlight 尚未驗證；iOS 26.4 SDK 的 unsigned release build 已在本機通過，不代表可上傳。
- iOS 已換用現有 FutureMint 品牌圖示及啟動畫面；真機呈現與品牌最終核定仍待驗收。
- 使用者已確認 iPhone-only；`TARGETED_DEVICE_FAMILY=1`，仍需實機與正式商店截圖驗收。
- 隔離建置腳本的 unsigned `Runner.app` 已排除 `integration_test.framework`；正式 signed archive／Apple validation 仍待執行。
- 正式螢幕閱讀器、完整鍵盤、色覺與 reduced-motion 人工驗收。
- 已實作 Email verification、password reset、session cleanup、shared rate limit 及可設定的公開政策／支援頁；SMTP 真實送達、MFA、備份保留／刪除 SLA、真實公開 URL、量界與上游資料條款、正式未成年人營運條件仍待確認。

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
  --dart-define=BUILD_ENV=validation \
  --dart-define=API_BASE_URL=http://localhost:3000/api/
flutter build apk --debug
docker build \
  --build-arg BUILD_ENV=validation \
  --build-arg API_BASE_URL=http://localhost:13000/api/ \
  --build-arg PRIVACY_POLICY_URL=http://localhost:13000/privacy \
  --build-arg SUPPORT_URL=http://localhost:13000/support \
  --build-arg SUPPORT_EMAIL=local-validation@example.invalid \
  --build-arg SERVICE_OPERATOR=FutureMint-local-validation \
  -t futuremint-web .
```

PostgreSQL migration 與 E2E 需使用獨立 local test database，`DATABASE_URL` 只透過 shell／ignored `.env` 注入，不把 credential 寫入文件或 repository。
