# 測試與證據

## 最新本機驗證

驗證日期：2026-07-14（Asia/Taipei）。以下只記錄實際執行結果，不代表 Azure production 驗收。

| 元件 | 指令 | 結果 |
|---|---|---|
| Functions | `npm test` | 11 個 test files、57 項 tests 通過 |
| Functions | `npm run typecheck` | 通過 |
| Functions | `npm run build` | 通過 |
| Functions | `npm audit --omit=dev` | 0 vulnerabilities |
| Cosmos seed safety | 未設 `ALLOW_DEMO_SEED=true` 執行 `npm run seed:cosmos-demo` | 建置通過後在建立 Cosmos client 前明確拒絕，exit code 1；未寫雲端 |
| Functions Host | Core Tools + Node 22，memory／demo provider | 實際註冊、首次 profile 寫入、dashboard 讀取、登出與撤銷後 session 驗證依序回傳 201／200／200／200／401；未使用雲端資源 |
| Capture evaluation | `npm run evaluate:captures` | 30/30 案例完整通過、225/225 欄位檢查通過、30/30 schema 合法 |
| Flutter | `dart format --output=none --set-exit-if-changed lib test integration_test` | 0 個檔案需要重新格式化 |
| Flutter | `flutter analyze` | 0 issues |
| Flutter | `flutter test` | 57 項 tests 通過 |
| Flutter Web | `flutter build web --release` | 通過，產物在 `apps/client/build/web` |
| Browser QA | Playwright CLI + local debug Web | 註冊／登入入口已在 Chrome 實際載入並檢查畫面；帳號流程以 Functions Host 端對端請求驗證。訪客與互動式 UI 流程另由 Widget tests 覆蓋。 |
| Text scale | Widget test | 375px、200% text scale 無 layout exception |
| Short landscape rail | Widget test + Browser QA | 812×375 重現並修正 NavigationRail 71px overflow；低高度側欄可捲動，`未來` 目的地可顯示及點擊 |
| Flutter integration | `flutter test integration_test` | Flutter CLI 回報 Web devices 尚不支援 integration tests，因此未完成執行 |
| Android debug | `flutter build apk --debug` | Gradle 執行至 `mergeDebugNativeLibs`，因磁碟空間不足失敗；未取得 APK，不宣稱 Android build 通過 |

數量若在後續增加測試時改變，應以當次命令輸出更新本表。

## 30 筆合成解析評估

Fixture：`services/api/test/fixtures/capture-evaluation.json`。

涵蓋餐飲、交通、娛樂、教育、購物、收入、訂閱、中文／阿拉伯數字分帳、缺金額、否定／取消、無關文字、折扣實付、昨天／前天、合成通知與多筆支出。報告輸出：

- `services/api/reports/capture-evaluation.md`
- `services/api/reports/capture-evaluation.json`

評估的是 `deterministic-demo` provider，用途是本機 Functions 與可重現回歸測試，不是 Client 離線資料來源。不得在簡報中把 100% 說成 Azure OpenAI 真實模型準確率；Azure provider 仍需在取得 endpoint、deployment、RBAC／key 與部署授權後，以同一 fixture 另行實測 latency、429 與模型欄位正確率。

## 測試覆蓋重點

Functions：

- 預算、分帳、訂閱月成本、FutureSeed 零利率與複利。
- Parse 不保存、確認保存、idempotency、分帳重算與 reset 邊界。
- HTTP routes 的成功、query 篩選、malformed JSON、CORS preflight、validation 與安全錯誤格式。
- Azure OpenAI strict structured output、nullable 欄位、type／category 語意驗證、未驗證數量文案拒絕、schema invalid、timeout 與 Headers 格式 429 budget。
- Cosmos partition query、並行 idempotency conflict 回讀、latest lesson 與資料 mapping。
- Provider 選擇設定缺失／不合法時明確失敗。

Flutter：

- Model JSON、recurrence／split 編輯重算、訪客資料不跨 session 保存、否定句／非財務句、多筆、折扣與 date-picker clamp。
- 註冊／登入 API envelope、只保存 session token、Bearer header、首次設定、訪客不寫 session token、訪客入口與資料不保存提示。
- API envelope、問題格式、網路 timeout、明確 timezone offset、空帳本不虛構訂閱、current／stale lesson 與來自帳本的比較 payload。
- Controller 初始化、parse 不保存、多草稿單筆確認保留其餘草稿、保存後 partial refresh recovery、訂閱比較更新與 profile 失敗回報。
- Dashboard、手機／桌面導覽、Capture 三階段、訂閱來源、lesson action、FutureSeed 本金與假設成長。
- `SoftCard` 平面／hairline 變體、`MoneyBuddy` semantics、Dashboard 內容寬度 bento 切換、Capture 焦點轉移、單一紀錄表面、Learning 高文字倍率退回正常堆疊、FutureSeed 自然高度空狀態，以及短 landscape NavigationRail 可達性。
- 200% text scaling；深色 Dashboard 與 Settings 已用本機 release Web 人工檢查。

## 尚未驗證

- 真實 Azure OpenAI endpoint、deployment、模型回應、quota 與 P95 latency。
- 真實 Cosmos DB、Managed Identity／RBAC、Application Insights 與 CORS。
- Azure Static Web Apps／Functions deployment、domain、TLS 與 rollback。
- Android build／實機安裝；本次 debug build 受磁碟空間不足阻塞。iOS build／簽章也尚未驗證。
- Flutter Web integration drive；需補上與 Chrome 150 相容的 ChromeDriver。等價主線已有 Widget tests 與 Playwright 人工瀏覽器檢查，但不冒充 integration test 通過。
- 正式螢幕閱讀器、完整鍵盤導覽、色覺模擬與 reduced-motion 人工驗收；目前只有 semantics／layout widget tests 與瀏覽器畫面檢查。
- 正式未成年人帳號 hardening、email 驗證、忘記密碼、rate limit、同意、保存期限與資料刪除流程；這些不在 MVP。

## 重現方式

```bash
cd services/api
PATH="/opt/homebrew/opt/node@22/bin:$PATH" npm ci
PATH="/opt/homebrew/opt/node@22/bin:$PATH" npm test
PATH="/opt/homebrew/opt/node@22/bin:$PATH" npm run typecheck
PATH="/opt/homebrew/opt/node@22/bin:$PATH" npm run build
PATH="/opt/homebrew/opt/node@22/bin:$PATH" npm run evaluate:captures
PATH="/opt/homebrew/opt/node@22/bin:$PATH" npm audit --omit=dev

cd ../../apps/client
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter build web --release
```
