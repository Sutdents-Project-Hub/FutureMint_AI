# 安全、身份與隱私

## 身份與授權

- Email/password registration 與 login 由 Fastify API 處理。
- Password 以 Node.js scrypt、每個帳號隨機 salt 與 timing-safe compare 驗證；資料庫不保存明文 password。
- Session token 使用 cryptographically random bytes，Client 只收到明文 token；PostgreSQL 只保存 SHA-256 token hash。
- Session 七天到期；logout 設 revoked timestamp。
- API 每次從 session 推導 account，所有 repository query 都依 account `user_id`；不接受 Client 指定 ownership。
- 已保存的 MoneyEvent 只能由擁有該 session 的帳號完整更新或刪除；更新不接受／改寫建立時的 idempotency key，查無該帳號紀錄時回相同 404。
- App 內帳號刪除需目前密碼再驗證與文字二次確認；成功後刪除 live account 及 FK cascade 資料、使現有 sessions 失效並清除 Client token。

帳號流程已補上 Email ownership verification、一次性 password reset 及重設後所有 session 失效；production 必須設定 SMTP，未驗證帳號只能恢復驗證、讀取自身帳號、登出或刪除帳號。仍未提供 MFA、獨立的所有裝置登出、breached-password screening 或家庭所有權轉移；這些功能不等於正式未成年人營運條件已獲確認。

### 家庭關聯與資料權限

- 家長帳號可建立 24 字元、區分大小寫的 base64url 邀請碼（144-bit 隨機）；孩子帳號輸入邀請碼後加入同一個 `family_id`。同一帳號不可加入兩個家庭。
- 家長只能取得孩子的 `childSummaries`：預算、收入／支出／訂閱彙總、可用金額、目標進度、提醒數量與教學摘要；API 不回傳孩子的交易事件、原始輸入、email 或投資訂單。
- 孩子只能看到家庭成員的角色標籤，不會取得家長的預算、流水或摘要。家長有孩子關聯時不可直接離開，避免留下無主家庭。
- 帳號加入家庭後角色會鎖定；若要從孩子改成家長或反過來，必須先解除家庭關聯，避免藉由修改 profile 繞過權限。
- 邀請碼只在建立／更新時回傳家長，資料庫只保存 SHA-256 hash；24 小時到期，可更新或停用。一般家庭查詢不回傳原碼；實際授權在 API 由 session 推導 user id 並再次檢查 account role，Client 不可自行指定被分享的 user id。

## API 邊界

- Fastify body limit 32 KiB；Zod 驗證 request。
- CORS 僅允許 `ALLOWED_ORIGINS` 完整 origins；production 只放正式 frontend HTTPS domain，缺少、帶 path／尾端 `/` 或格式錯誤即拒絕啟動。
- 全域 rate limit 120 requests／minute；auth routes 10 requests／minute；AI 產生／陪讀 routes 20 requests／minute。正式 PostgreSQL adapter 使用跨 instance 原子計數；另外限制同一 email 的帳號請求與同一 user 的 AI 請求，key 只存 hash。`TRUSTED_PROXY_CIDRS` 只接受實際連入的 proxy IP／CIDR，空值不信任 forwarding headers；不得用 hop count。VPS firewall 不得公開 container port。
- Response 使用 no-store、nosniff、frame deny、referrer policy 與 restrictive CSP。
- PostgreSQL query 全部使用 parameter placeholders。
- AI 回覆視為不可信任：去 fence／抽 JSON 後再做 schema、列舉、金額、日期與範圍驗證；教育回答只接受嚴格 topic ID／不重複的順序，不接受模型提供的正文、建議或 URL；畫面內容一律從受控繁體中文教材取得。解析建議理由、澄清與拒絕文案也映射為程式提供的說明，無效結構回 `ai_invalid_output`。
- 金額、預算、訂閱、六個月收支與三條投資情境由 deterministic code 計算；AI 不產生資產數值。
- 虛擬投資價格只由後端市場 adapter 選取，Client 不可自訂成交價；後端驗證現金、持有量、教學標的與 idempotency。
- 公開市場 route 只回傳已篩選的 TWSE 日資料並有獨立 rate limit；不含使用者、帳號或投資組合資訊。

## 秘密

只放 API Coolify runtime environment：

- `DATABASE_URL`
- `LIANGJIE_API_KEY`
- `SMTP_USER`、`SMTP_PASSWORD` 等郵件認證資料

可公開但仍需正確設定：

- Flutter build argument `API_BASE_URL`
- API `ALLOWED_ORIGINS`
- `LIANGJIE_BASE_URL` 與 model id（不是 authentication secret）

本機直接啟動 API 時，秘密只放已忽略的 `backend/.env`；本機 Docker Compose 則只放已忽略的根目錄 `.env`，由 Compose 在 API runtime 注入。歷史上可能存在的 ignored `local.settings.json` 不再使用，也不得讀取、提交或複製。GitHub repository、Dockerfile、build arguments、Flutter bundle、文件、測試 fixture 與 log 都不得含真實 key、password、token、connection URL 或學生資料。

## Log 與錯誤

- API log 只記 request ID、route outcome、provider event type 與安全的 latency／錯誤類型。
- 不記錄 Authorization header、email、password、session token、capture 原文、完整財務事件、prompt、AI response、SQL connection string 或 stack response。
- Client 只顯示可操作的安全錯誤；server error 不回 SDK／SQL／stack detail。
- 正式 reverse proxy access log、Coolify build log 與 PostgreSQL log 也需檢查 retention 與存取權限。

## 隱私與外部 AI

量界智算會收到單次文字 capture 原文；目前不提供圖片上傳或 OCR。學習規劃只送分類與目標是否存在等布林摘要，陪讀只送使用者問題與主題，不送完整流水或密碼。它仍是外部資料處理邊界。

已登入 Client 在首次啟用前會列出第三方名稱、資料類別、用途、拒絕後可用功能與撤回入口。同意以 `third-party-ai-v1` 保存；Client 未同意時不發出 AI request，量界 API routes 仍在 server-side 呼叫 provider 前強制檢查，撤回後立即恢復阻擋。

以上機制只處理產品內的明確同意與撤回，不等於量界／上游供應商條款、保留、訓練使用、subprocessors、資料地區或刪除能力已確認。比賽只輸入合成資料。任何真實未成年人資料使用前，都必須再確認 relay／上游模型的資料條款、設定保留與刪除流程，並完成法遵與 incident response。

TWSE OpenAPI 是另一個外部可用性邊界，但 request 只要求公開市場資料，不傳帳號、持倉、訂單或任何個資。內建標的與事件骰子都必須標示為教育範例，不得以推薦、勝率、排名或獎勵高風險交易的方式呈現。

## 部署 checklist

- Coolify 與 GitHub 帳號啟用 MFA，GitHub App 只授權單一 private repository。
- PostgreSQL 不公開 port；使用 internal URL 與唯一高強度 credentials。
- Frontend／API 強制 HTTPS；`ALLOWED_ORIGINS` 不含 `*` 或 preview wildcard。
- Secret 只設 runtime，部署或截圖前遮蔽。
- Scheduled backup 寫入團隊控制的 S3-compatible storage，並實際 restore。
- 上線前輪替任何曾貼在聊天、截圖、PDF 或 log 的測試 key。

## 帳號恢復與並行保護

驗證／重設 token 使用 256-bit 隨機值，資料庫只存 hash，30 分鐘到期且每個帳號／用途只保留最新一枚。密碼重設以交易消耗 token、更新密碼並使 sessions 失效；登入建立 session 也確認仍為同一版密碼。查無帳號與郵件失敗的重設申請均回相同 accepted，不回 token。郵件連結使用 URL fragment，GET 不消耗；頁面清除網址 fragment，按鈕 POST 才消耗 token，採 no-referrer、自有 CSP，不載入第三方資源。

原生 Client 使用 flutter_secure_storage（iOS Keychain）；從舊 SharedPreferences 遷移成功後才移除舊值。Web 仍使用瀏覽器 local storage，登出或到期會清除。Client 用 session epoch 防止舊 401／舊非同步結果清掉新登入，儲存操作依序執行。Android 關閉自動備份，避免備份加密 token 檔。

家庭角色、成員變更與讀取摘要使用固定排序的 per-user transaction locks，資料庫另有 role consistency triggers。家庭建立使用同一個 PoolClient 的 BEGIN／COMMIT／ROLLBACK；虛擬交易持有同一帳號的資料庫鎖後重算資金與持倉，支援多 API instances。

API 啟動及每小時分批清理到期／撤銷 sessions、到期 action tokens 與限流 counters（每類每輪最多 1000）。清理失敗只記安全訊息，下一輪重試；即使尚未清除，驗證仍立即拒絕過期 token。大量累積時需監控積壓與調整維運排程。

公開政策由設定產生；缺少營運者、客服、資料地區、備份期限、最低年齡、未成年人同意揭露、AI 資料條款或 `PRIVACY_POLICY_REVIEWED=true` 時 production 拒絕啟動。此旗標代表營運者確認，程式不會自行宣稱法遵完成。
