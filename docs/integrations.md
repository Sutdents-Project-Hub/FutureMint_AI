# 外部整合與 AI

## 整合狀態

| 整合 | 已實作 | 已驗證 | 尚未驗證 |
|---|---|---|---|
| 量界智算 | OpenAI-compatible adapter、timeout／429／schema handling、JSON fence 容錯 | fake client unit tests | 正式 key、model access、quota、內容品質、production latency |
| PostgreSQL | accounts／sessions／profiles／events／lessons repository、migration、idempotency | PostgreSQL 17 本機容器與 API 重啟持久化 | Coolify internal URL、backup／restore、production capacity |
| Coolify | 兩個 Dockerfile、ports、health checks、三 Resource 設定文件 | 使用者確認既有三 Resources 曾部署成功 | 本輪 live health、runtime／domain／SMTP、重新部署與完整主線待驗收 |
| GitHub | private repository `main`、`.github/workflows/ci.yml` CI | 基線 `af7a5df` CI 成功：122 API／121 Flutter、未簽章 iOS 與 images | 本輪新狀態尚未執行遠端 CI；Auto Deploy 新狀態待驗收 |
| 家庭帳號 | PostgreSQL family groups／members、邀請碼與摘要權限 | InMemory／PostgreSQL repository 契約與 service tests | 尚未做 production 多帳號實機驗收；已實作更新／停用，未提供家庭所有權轉移 |
| 第三方 AI 同意 | App 內 disclosure、啟用／撤回、versioned PostgreSQL state、量界 route server gate | Auth／HTTP／Flutter unit 與 widget tests | 量界／上游條款、retention、training、subprocessors 與 production E2E |
| TWSE 市場資料 | 官方 OpenAPI adapter、timeout、schema、15 分鐘 cache、明確 fallback | 本機實際取得 2026-07-14 每日成交快照 | Coolify outbound HTTPS、上游可用性與長期欄位穩定性 |
| 虛擬投資 | 教學標的、虛擬買賣、持倉／成本／配置／訂單、事件骰子 | API／Flutter tests、PostgreSQL 重啟持久化 | 不含即時行情、配息、手續費、公司行動或真實成交撮合 |

## 量界智算契約

- API base URL 預設 `https://liangjiewis.com/v1`，由 `LIANGJIE_BASE_URL` 注入。
- Model id 由 `LIANGJIE_MODEL` 注入；範例值只是設定格式，實際可用 model 必須以團隊帳號驗證。
- `LIANGJIE_API_KEY` 只存在 Fastify API runtime environment；Flutter、Nginx、GitHub 與 Docker build log 都不應取得。
- 本機 Compose 預設選擇 deterministic demo；要驗證真實量界連線時，僅在 ignored 根目錄 `.env` 設定 `AI_PROVIDER=liangjie` 與量界 runtime values，再重建 API。不得將 key 放進 `compose.yaml`、Docker build argument 或前端設定。
- Adapter 使用 OpenAI-compatible chat completions。因 relay 不保證所有 provider-specific parameters，程式以 prompt 要求 JSON，再自行去除 Markdown fence、抽取 object、做 schema 與語意驗證。
- Lesson、learning plan、coach、capture 的使用者可見文字會再驗證繁體中文與常見簡體字；schema 失敗時回 `ai_invalid_output`，不把英文內容直接顯示給使用者。Coach 另接受 `brief`、`example`、`steps` 個人化回答方式。
- 單次操作共用總 deadline（預設 12 秒），最多兩次上游嘗試、預設最多 2048 output tokens，429 與修復重試皆消耗同一 budget；invalid JSON 或 schema mismatch 時，adapter 會以相同最小化 context 重新要求一次完整合規 JSON，仍不合格才回安全且可觀察的 domain error。不記錄 prompt、原文、key 或完整 provider body。
- 不自動 fallback 到 deterministic provider，避免把 Demo 結果冒充即時 AI。
- 只有當前由公開政策 fingerprint 產生的 `third-party-ai-v2-<fingerprint>` 明確授權才可進入外部 AI provider；parse、lesson、learning plan 與 coach 的 HTTP routes 都在呼叫 provider 前檢查，未授權回 `ai_consent_required`。

量界智算是第三方 relay。部署前需確認帳號、模型供應來源、資料處理條款、費率、額度、內容政策、穩定性與競賽規則；不應假設它等同原模型供應商的 SLA 或隱私承諾。

## Deterministic demo provider

`AI_PROVIDER=demo` 用於：

- 本機無網路展示。
- 可重現 unit／integration tests。
- 30-case 合成繁中 regression evaluation。

它不是量界模型，也不是登入模式的自動 fallback。簡報需將 deterministic 30/30 與量界真實模型實測分開陳述。

## PostgreSQL

API 只透過 parameterized SQL 存取 Coolify PostgreSQL。`DATABASE_URL` 只放 API runtime secret。Database 不應有 public port；開發者若需管理，使用 Coolify console、受控 tunnel 或短時 allowlist，不把 connection URL 分享到群組或文件。

## 市場資料與模擬交易

- [臺灣證券交易所 OpenAPI](https://openapi.twse.com.tw/) 的 `/v1/exchangeReport/STOCK_DAY_ALL` 提供每日成交統計，不需在 Client 或 API 設定市場資料金鑰。本專案只取內建五個跨產業教學標的，保留來源日期，並在 API 記憶體快取 15 分鐘。
- 來源逾時、HTTP 失敗或 schema 改變時，API 回傳明確標示 `educational-snapshot` 的版本化快照；Client 同時顯示來源與「降級資料」，不把舊值當成即時行情。
- 虛擬訂單只更新 FutureMint 自己的 PostgreSQL／記憶體資料，不送往證交所、券商或任何 paper-trading account。程式驗證現金、持有數量與 idempotency，骰子只從版本化事件牌組選出學習題目。

其他研究：

- [Alpaca Paper Trading](https://docs.alpaca.markets/us/docs/paper-trading) 可提供模擬帳戶與交易 API，但仍需帳號與 API credentials；paper execution 也不等同真實成交。
- [Alpaca Market Data](https://docs.alpaca.markets/us/docs/about-market-data-api) 的 Basic 計畫主要提供 IEX 資料，資料範圍與正式市場完整行情不同。
- [Alpha Vantage](https://www.alphavantage.co/documentation/) 提供長期日線與多種技術資料，但需要 API key，部分即時／完整資料受 entitlement 或付費方案限制。
- Flutter 圖表使用 [fl_chart](https://pub.dev/packages/fl_chart)（MIT）在 Client 呈現本專案自行計算的資料，不由套件提供市場或金融邏輯。

目前需求不要求即時走時或真實下單，因此不接 Alpaca 或 Alpha Vantage。FutureSeed 繼續使用 `education-scenarios-2026-07-v1` 合成報酬路徑；投資練習場才使用 TWSE 延遲日資料。若未來增加歷史 K 線或海外市場，仍須由 server-side adapter 處理 cache、授權／歸因、延遲標示與 deterministic fixture，不可讓 Client 持有 key。

## Private GitHub 自動部署

Coolify 應以 GitHub App（只授權 `FutureMint_AI` private repository）或該 repository 的唯讀 Deploy Key 取得程式碼。啟用 webhook／automatic deployment 後，`main` push 會觸發前端與 API applications 重新 build；PostgreSQL Resource 不從 GitHub build。

使用者確認既有 Coolify 三 Resources 曾成功部署；目前 live health、DNS／TLS、runtime 設定與完整使用者流程尚未在本輪驗證。本次程式變更需由使用者自行重新部署並驗收，詳細設定見 [部署說明](deployment.md)。

## 明確不整合

不整合支付、銀行、電子發票、證券下單、Apple Pay、LINE Pay、SMS、圖片上傳／OCR 或真實未成年人金融服務。TWSE OpenAPI 只提供公開延遲行情，不會建立真實證券帳戶或交易。主辦方 Azure 關閉後，runtime 也不再依賴任何 Azure service。

## SMTP 與教育選題更新

SMTP adapter 已實作 TLS、一次性驗證／密碼重設信與 sanitized error；只以 fake mailer 測試，沒有寄出真實信件。正式 mail host／sender、DNS SPF／DKIM／DMARC、送達率、帳號權限及費用仍待確認。

量界教育功能改為 strict topic ID selection，教學內容來自受控教材；parse 仍抽取事件結構，金額需使用者確認。公開 `/privacy` 由營運設定提供第三方資料條款，未確認不得發布。

## 官方 OpenAI 與共享請求門檻

量界為預設選擇；使用者核准可透過 `AI_PROVIDER=openai` 明確切換官方 OpenAI，固定 `https://api.openai.com/v1`，拒任意 OpenAI base URL。使用 `OPENAI_MODEL`、`OPENAI_API_KEY`、`OPENAI_DATA_RECIPIENTS`、`OPENAI_DATA_TERMS_DISCLOSURE`、`OPENAI_DATA_TERMS_REVIEWED` 與共用 `PRIVACY_POLICY_VERSION`。量界使用相同 `LIANGJIE_` 前綴公開政策欄位。Secrets 只在 API runtime。實際 allowlist 以 `backend/src/config/aiConfig.ts` 為準，官方 adapter 使用 strict Structured Outputs；固定模型 snapshot 優先，加入新模型需先確認能力。

所有外部 provider 經共享 admission gate：台北每日 user 30／global 300 次，最多 5 個 operation leases；上限可由 `AI_DAILY_USER_LIMIT`、`AI_DAILY_GLOBAL_LIMIT`、`AI_MAX_CONCURRENCY` 設定。PostgreSQL 原子計數跨 instances 共用，lease 釋放失敗會到期回收，額度／資料庫確認失敗時阻擋請求，不放行。Client AI 20 秒，其餘 API 12 秒；server `AI_OPERATION_TIMEOUT_MS` 預設 12000、`AI_MAX_OUTPUT_TOKENS` 預設 2048。

本輪不使用真實 key 或供應商請求；本機 fake-client 結果不代表正式模型品質、費率或條款已驗收。GitHub Models 於 2026-07-30 退役，未列入替代供應商：[GitHub 官方文件](https://docs.github.com/en/github-models)。官方能力依據：[Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs)、[GPT-4.1 mini](https://developers.openai.com/api/docs/models/gpt-4.1-mini)。

拒絕／撤回 AI 授權或目前唯讀時，學習頁可經 `/api/education/catalog` 讀取固定受控教材；不產生外部 AI 請求。Catalog 不含個人摘要，完成標記僅在當前 Client 記憶體，不保存於帳戶；AI 個人化選題仍需當前資格及授權。

## 簡化部署的整合開關

分類：已核准範圍調整。正式 iPhone 只啟動 API／PostgreSQL，Web 為選用測試。SMTP 為部署可選項；未填／disabled 時開放註冊與登入、不要求 Email 驗證，Email 只作未驗證登入識別，不寫入 emailVerifiedAt。新的驗證／寄信重設／監護人寄信回 mail_disabled；App 清楚說明功能停用。最低年齡 15 與 15–17 歲監護人資格仍維持，未完成同意者不能寫入受限資料，可使用訪客；SMTP 重新啟用後仍需驗證信箱，密碼重設只寄給已驗證信箱。

供應商公開接收方／說明／reviewed 可放 backend/src/config/providerPolicies.ts；既有 PROVIDER_DATA_* env 可覆寫，覆寫說明後需重新確認。缺少說明／未確認時不阻擋 API 啟動，但阻擋外部 AI 授權與呼叫，保留手動及固定教材。模型與 key 仍為所選 live provider 必要值，不自動 fallback；量界上游承諾尚未確認，初始設定不虛構內容。

2026-10-02 核准的簡化測試方式使用[如實揭露未知條件的 Runtime 範本](deployment.md#量界資訊不完整時的測試設定2026-10-02)，沿用既有 parser 及帳號授權。`reviewed` 是營運者確認公開告知，不能當作供應商條款查核證據；本輪無真實外部請求，文件支援 OpenAI／Gemini 格式也不證明所選 model、額度或結構化回覆可用。
