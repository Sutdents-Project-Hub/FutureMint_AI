# 外部整合與 AI

## 整合狀態

| 整合 | 已實作 | 已驗證 | 尚未驗證 |
|---|---|---|---|
| 量界智算 | OpenAI-compatible adapter、timeout／429／schema handling、JSON fence 容錯 | fake client unit tests | 正式 key、model access、quota、內容品質、production latency |
| PostgreSQL | accounts／sessions／profiles／events／lessons repository、migration、idempotency | PostgreSQL 17 本機容器與 API 重啟持久化 | Coolify internal URL、backup／restore、production capacity |
| Coolify | 兩個 Dockerfile、ports、health checks、三 Resource 設定文件 | 本機 image／container 驗證 | Private GitHub App、webhook、domains、TLS、rollback |
| GitHub | 目標為 private repository `main` 自動部署 | 本機 repository 存在 | 目前沒有 remote；尚未連 Coolify |

## 量界智算契約

- API base URL 預設 `https://liangjiewis.com/v1`，由 `LIANGJIE_BASE_URL` 注入。
- Model id 由 `LIANGJIE_MODEL` 注入；範例值只是設定格式，實際可用 model 必須以團隊帳號驗證。
- `LIANGJIE_API_KEY` 只存在 Fastify API runtime environment；Flutter、Nginx、GitHub 與 Docker build log 都不應取得。
- Adapter 使用 OpenAI-compatible chat completions。因 relay 不保證所有 provider-specific parameters，程式以 prompt 要求 JSON，再自行去除 Markdown fence、抽取 object、做 schema 與語意驗證。
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

## Private GitHub 自動部署

Coolify 應以 GitHub App（只授權 `FutureMint_AI` private repository）或該 repository 的唯讀 Deploy Key 取得程式碼。啟用 webhook／automatic deployment 後，`main` push 會觸發前端與 API applications 重新 build；PostgreSQL Resource 不從 GitHub build。

目前 workspace 沒有 remote，未執行 push，也沒有在 Coolify 建立 App。詳細設定見 [部署說明](deployment.md)。

## 明確不整合

不整合支付、銀行、電子發票、證券、Apple Pay、LINE Pay、Email、SMS 或真實未成年人金融服務。主辦方 Azure 關閉後，runtime 也不再依賴任何 Azure service。
