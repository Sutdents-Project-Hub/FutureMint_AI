# 外部整合與 AI

## 整合狀態

| 整合 | 已實作 | 已驗證 | 尚未驗證 |
|---|---|---|---|
| 量界智算 | OpenAI-compatible adapter、timeout／429／schema handling、JSON fence 容錯 | fake client unit tests | 正式 key、model access、quota、內容品質、production latency |
| PostgreSQL | accounts／sessions／profiles／events／lessons repository、migration、idempotency | PostgreSQL 17 本機容器與 API 重啟持久化 | Coolify internal URL、backup／restore、production capacity |
| Coolify | 兩個 Dockerfile、ports、health checks、三 Resource 設定文件 | 本機 image／container 驗證 | Private GitHub App、webhook、domains、TLS、rollback |
| GitHub | private repository `main`、`.github/workflows/ci.yml` CI | workflow 已加入 repository；本機可執行相同檢查 | 尚未在 GitHub hosted runner 執行，也尚未連 Coolify 或驗證 Auto Deploy |
| 家庭帳號 | PostgreSQL family groups／members、邀請碼與摘要權限 | InMemory／PostgreSQL repository 契約與 service tests | 尚未做 production 多帳號實機驗收與邀請撤銷／轉移 |
| TWSE 市場資料 | 官方 OpenAPI adapter、timeout、schema、15 分鐘 cache、明確 fallback | 本機實際取得 2026-07-14 每日成交快照 | Coolify outbound HTTPS、上游可用性與長期欄位穩定性 |
| 虛擬投資 | 教學標的、虛擬買賣、持倉／成本／配置／訂單、事件骰子 | API／Flutter tests、PostgreSQL 重啟持久化 | 不含即時行情、配息、手續費、公司行動或真實成交撮合 |

## 量界智算契約

- API base URL 預設 `https://liangjiewis.com/v1`，由 `LIANGJIE_BASE_URL` 注入。
- Model id 由 `LIANGJIE_MODEL` 注入；範例值只是設定格式，實際可用 model 必須以團隊帳號驗證。
- `LIANGJIE_API_KEY` 只存在 Fastify API runtime environment；Flutter、Nginx、GitHub 與 Docker build log 都不應取得。
- Adapter 使用 OpenAI-compatible chat completions。因 relay 不保證所有 provider-specific parameters，程式以 prompt 要求 JSON，再自行去除 Markdown fence、抽取 object、做 schema 與語意驗證。
- Lesson、learning plan、coach、capture 的使用者可見文字會再驗證繁體中文與常見簡體字；schema 失敗時回 `ai_invalid_output`，不把英文內容直接顯示給使用者。Coach 另接受 `brief`、`example`、`steps` 個人化回答方式。
- Timeout、429、invalid JSON、schema mismatch 都回安全且可觀察的 domain error；不記錄 prompt、原文、key 或完整 provider body。
- 不自動 fallback 到 deterministic provider，避免把 Demo 結果冒充即時 AI。

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

目前 workspace 已設定 remote，但本次功能尚未 push，也沒有在 Coolify 建立 App。詳細設定見 [部署說明](deployment.md)。

## 明確不整合

不整合支付、銀行、電子發票、證券下單、Apple Pay、LINE Pay、Email、SMS、圖片上傳／OCR 或真實未成年人金融服務。TWSE OpenAPI 只提供公開延遲行情，不會建立真實證券帳戶或交易。主辦方 Azure 關閉後，runtime 也不再依賴任何 Azure service。
