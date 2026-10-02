# 資料與儲存

## 資料原則

- 正式帳號資料目標保存於 Coolify PostgreSQL 17（production 尚未驗收）；Client 不直接連資料庫。
- 自然語言原文只存在於單次 parse request 生命週期，不寫入 PostgreSQL、MoneyEvent、SharedPreferences 或一般 log。
- API 從 Bearer session 推導 `user_id`；所有 profile、event、lesson query 都以該帳號篩選。MoneyEvent 的讀取、完整更新與刪除均以 `(user_id, event_id)` 篩選，跨帳號一律不透露是否存在。
- 訪客模式只存在 Flutter process memory，重新整理、關閉或切換帳號後消失。
- 只使用合成競賽資料；未取得同意與去識別前，不輸入真實未成年人財務資料。

## PostgreSQL schema

Schema 由 `backend/migrations/001` 至 `012` 的版本化 SQL 管理；008 新增訂閱與執行順序、009 新增服務資格／監護人 token、010 新增共享 AI 額度／leases，011 新增最小帳號刪除 journal，012 新增 nullable guardian consent method 欄位。012 將既有已核准且有 Email 的紀錄標為 `email`，不改舊 migration checksum：

| Table | 內容 | 重要約束 |
|---|---|---|
| `accounts` | Email、scrypt password hash/salt、profile 完成狀態 | email／user_id unique |
| `sessions` | Token hash、建立／到期／撤銷時間 | token hash unique，account cascade delete |
| `ai_consents` | 第三方 AI policy version、當前授權狀態、最近授權／撤回時間 | 一個 user 一筆；account cascade delete；非 append-only ledger |
| `profiles` | 月／週預算、目標、偏好語氣、孩子／家長內容角色 | 一個 user 一筆；金額、tone、account role checks |
| `money_events` | 收入、支出、訂閱、日期、recurrence、split、需要／想要判斷與理由 | `(user_id, idempotency_key)` unique；收入不得有 spending intent |
| `lessons` | 個人化課程、options、action、完成狀態、來源 | user FK；source 支援量界、官方 OpenAI、demo 與 manual；metadata 保存選題依據 |
| `virtual_investment_accounts` | 每個登入帳號的起始虛擬現金 | 一個 user 一筆；起始金額不可為負 |
| `virtual_investment_orders` | 教學標的、買賣方向、數量、成交快照價格／來源／日期 | `(user_id, idempotency_key)` unique；方向、數量與來源 checks |
| `family_groups` | 家庭關聯、24 字元隨機邀請碼的 hash／到期／有效狀態 | hash unique；建立者 FK；cascade delete |
| `family_members` | 家庭與帳號的關聯、加入時間 | 一個 user 只能加入一個 family；family／account cascade |
| `schema_migrations` | 已套用 migration name 與 checksum | migration runner 管理 |

金額以 TWD 最小單位整數保存，不使用浮點數；虛擬成交單價用固定精度 decimal 保存。Recurrence、split、lesson options 與 source IDs 使用 JSONB，但讀寫仍經 Zod 型別驗證。圖表、通知、學習規劃、FutureSeed 與虛擬持倉可由既有 profile／events／orders 即時計算，不保存 AI 推論，也不建立市場行情歷史表。家庭頁的 `childSummaries` 由孩子自己的 profile／events／insights 即時計算，只回傳家長可見的彙總，不另存跨帳號流水副本。

登入帳號的虛擬投資帳戶與訂單保存於 PostgreSQL，重啟 API 後仍可重建持倉。訪客模式的虛擬現金、訂單與事件骰子只留在 Flutter process memory，重新整理後清除。

## Migration

`npm run migrate` 會：

1. 連到 `DATABASE_URL`。
2. 取得 PostgreSQL advisory lock，避免多個新 container 同時部署互撞。
3. 建立 `schema_migrations`。
4. 依檔名執行尚未套用的 SQL，每個檔案使用 transaction。
5. 記錄檔名與 checksum；既有 migration 被改動時拒絕啟動。

API Docker image 先做不連資料庫或 SMTP 的 pure preflight，通過後在 `DATA_PROVIDER=postgres` 時於 Fastify 啟動前執行 migration。Migration 失敗時 container 退出，由 Coolify 保留先前可用 deployment；不要直接修改已上 production 的 migration，應新增下一號 SQL。

## Connection

Production 的 `DATABASE_URL` 使用 Coolify PostgreSQL Resource 提供的 internal URL，且 `DATABASE_SSL=false`。Database port 不對 Internet 公開。若未來改用外部 TLS database，才設 `DATABASE_SSL=true` 並確認供應商 CA／連線要求。

Pool 目前上限 10 connections，connection／idle timeout 由 repository 設定。單一 competition API instance 足夠；增加 replicas 前需重新計算 PostgreSQL connection budget 與 rate limit 策略。

## 合成 seed

`ALLOW_DEMO_SEED=true npm run seed:postgres-demo` 只建立無法登入的 synthetic account、profile 與四筆固定事件。Seed 使用 idempotency keys，可重複執行；預設安全開關未開時拒絕寫入。Production demo 是否需要 seed 由團隊人工決定，不應放入每次自動部署。

## 備份、還原與保留

本輪使用者選擇不建立定期資料庫備份，BACKUP_RETENTION_DAYS 預設0；不刪除既有資料卷、備份或最小刪除journal。日後若啟用備份，需設定符合實際排程的保留期限與受控儲存。排程／儲存整合與隔離還原演練尚未驗證；macOS credential store 及 Discord 通知不是已完成整合。還原需處理刪除紀錄，避免已刪帳號復活；backup job 成功不能代替此驗收。

帳號刪除需目前密碼，同 transaction 保存 SHA-256 account ID 雜湊／刪除時間至 `deleted_account_journal`，成功後刪除 live account 與 cascade 資料（含訂閱、資格、監護人 token、個人 AI 計數／leases）。備份到期清理及實際還原仍需營運落實。個人 JSON 匯出只包含本人資料、資格及同意狀態，不包含密碼、session/token、秘密或其他家庭成員明細。

## 006／007 migration 與部署影響

`006_concurrency_and_family_hardening.sql` 將既有短邀請碼停用並清除明文，保留家庭成員；家長必須更新新碼。依家庭建立者修正歷史角色（建立者為 parent，其餘成員為 child），並對齊 profile，避免保留過去角色競態造成的錯誤權限；新增邀請 hash／到期／有效狀態、成員角色快照與角色一致性 trigger，以及 `rate_limit_counters`。`007_auth_recovery.sql` 新增帳號 Email 驗證時間與 `account_action_tokens`（hash、用途、到期、account FK cascade）。舊帳號不會自動宣稱 Email 已驗證，啟用 SMTP 後需完成驗證。

本輪不備份；migration 維持既有 checksum 與向前相容，不刪原資料卷。若日後採備份還原方案，先在隔離 DB 跑 migration 與還原演練。不可直接切回依賴明文邀請碼的舊 API；應 forward-fix 或經核准還原完整備份。自動清理僅處理過期認證／限流資料，不刪除使用者帳務。

## 008／009／010／011 additive migrations 與資料契約

`subscriptions` 保存穩定 ID／owner、名稱、TWD 整數金額、月／年週期、anchor DATE、原扣款日／月、active、idempotency key 及完整請求 fingerprint。續訂日由日曆確定計算並保證在未來；不存在月份的日期先截至月末，下一週期仍使用原扣款日。`money_events.subscription_id` 使用複合 owner FK；合約停止不刪除歷史實付。

`service_eligibilities` 保存 age band、政策版本、監護人狀態、同意方式與 revision；`guardian_action_tokens` 只保存 token hash／用途／到期／revision。App 內核准記錄 `guardian_consent_method=in-app` 並清空 guardian email；舊 Email 核准記錄 `email`。既有帳號不會自動填成年聲明。`ai_usage_daily` 以台北日曆及雜湊 user subject 原子計數，`ai_operation_leases` 支援跨 instance 並行上限及到期回收。

`virtual_investment_orders.execution_sequence` 在帳號鎖內遞增，重建依此序列；008 為舊資料回填序列。日後若啟用備份，升級前需在隔離資料庫確認 migration／restore；不修改舊 migration，不以舊 API rollback 宣稱完整新資料語意。

最小刪除 journal 不含 Email、帳務或密碼，無 account FK；保留到所有舊備份副本到期銷毀，供隔離還原對帳。011 之前的刪除沒有此紀錄。工具／防呆／最後切換前對帳流程見 [部署文件](deployment.md#9-隔離還原與刪除帳號對帳)；本機合成測試不代表正式備份已配置。

Client 為重試一致性保存帳號綁定的待確認訂閱／虛擬訂單 payload 與 key；原生系統安全儲存、Web browser storage。同帳號重新登入／重啟恢復原操作，登出保留，App 內刪除帳號清除；儲存失敗會停止首次送出，不以新 key 繼續不確定操作。

SMTP 關閉時註冊仍保存帳號，但不寫入 `emailVerifiedAt`；未驗證 Email 僅作登入識別，不作為郵件重設或客服恢復帳號的唯一憑據。現行 15–17 歲 guardian consent 由登入帳號的 App 內端點寫入，不依賴 SMTP；已核准紀錄保存方式但不保存監護人 Email。舊 Email token 仍受政策版本、revision、到期與一次性限制。012 是新增 nullable 欄位，既有已核准 Email 紀錄回填 `email`，不改 schema 的帳號資料邊界或秘密處理。備份0不代表最小刪除journal立即清除；仍需涵蓋尚存的舊備份副本。

## 原生提醒裝置資料（2026-10-02）

iOS UserDefaults、Android 私有 SharedPreferences 保存每帳號提醒偏好；Android 另保存當前 owner、隨機綁定 token、通知 occurrence id／UTC 時間及是否請求過權限，以供非精準排程與開機恢復。沒有保存名稱、金額或原始輸入，也不新增伺服器資料表。登出／切換／刪除清除排程及已送通知；每帳號偏好與系統授權各自獨立，未授權時有效開關為關閉。
