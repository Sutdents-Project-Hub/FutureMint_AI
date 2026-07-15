# 資料與儲存

## 資料原則

- 正式帳號資料保存於 Coolify PostgreSQL 17；Client 不直接連資料庫。
- 自然語言原文只存在於單次 parse request 生命週期，不寫入 PostgreSQL、MoneyEvent、SharedPreferences 或一般 log。
- API 從 Bearer session 推導 `user_id`；所有 profile、event、lesson query 都以該帳號篩選。
- 訪客模式只存在 Flutter process memory，重新整理、關閉或切換帳號後消失。
- 只使用合成競賽資料；未取得同意與去識別前，不輸入真實未成年人財務資料。

## PostgreSQL schema

Schema 由 `services/api/migrations/001_initial.sql`、`002_roles_and_intents.sql` 與 `003_investment_lab.sql` 管理：

| Table | 內容 | 重要約束 |
|---|---|---|
| `accounts` | Email、scrypt password hash/salt、profile 完成狀態 | email／user_id unique |
| `sessions` | Token hash、建立／到期／撤銷時間 | token hash unique，account cascade delete |
| `profiles` | 月／週預算、目標、偏好語氣、孩子／家長內容角色 | 一個 user 一筆；金額、tone、account role checks |
| `money_events` | 收入、支出、訂閱、日期、recurrence、split、需要／想要判斷與理由 | `(user_id, idempotency_key)` unique；收入不得有 spending intent |
| `lessons` | 個人化課程、options、action、完成狀態、來源 | user FK；source 只允許量界或 demo |
| `virtual_investment_accounts` | 每個登入帳號的起始虛擬現金 | 一個 user 一筆；起始金額不可為負 |
| `virtual_investment_orders` | 教學標的、買賣方向、數量、成交快照價格／來源／日期 | `(user_id, idempotency_key)` unique；方向、數量與來源 checks |
| `schema_migrations` | 已套用 migration name 與 checksum | migration runner 管理 |

金額以 TWD 最小單位整數保存，不使用浮點數；虛擬成交單價用固定精度 decimal 保存。Recurrence、split、lesson options 與 source IDs 使用 JSONB，但讀寫仍經 Zod 型別驗證。圖表、通知、學習規劃、FutureSeed 與虛擬持倉可由既有 profile／events／orders 即時計算，不保存 AI 推論，也不建立市場行情歷史表。

登入帳號的虛擬投資帳戶與訂單保存於 PostgreSQL，重啟 API 後仍可重建持倉。訪客模式的虛擬現金、訂單與事件骰子只留在 Flutter process memory，重新整理後清除。

## Migration

`npm run migrate` 會：

1. 連到 `DATABASE_URL`。
2. 取得 PostgreSQL advisory lock，避免多個新 container 同時部署互撞。
3. 建立 `schema_migrations`。
4. 依檔名執行尚未套用的 SQL，每個檔案使用 transaction。
5. 記錄檔名與 checksum；既有 migration 被改動時拒絕啟動。

API Docker image 在 `DATA_PROVIDER=postgres` 時會於 Fastify 啟動前自動執行 migration。Migration 失敗時 container 退出，由 Coolify 保留先前可用 deployment；不要直接修改已上 production 的 migration，應新增下一號 SQL。

## Connection

Production 的 `DATABASE_URL` 使用 Coolify PostgreSQL Resource 提供的 internal URL，且 `DATABASE_SSL=false`。Database port 不對 Internet 公開。若未來改用外部 TLS database，才設 `DATABASE_SSL=true` 並確認供應商 CA／連線要求。

Pool 目前上限 10 connections，connection／idle timeout 由 repository 設定。單一 competition API instance 足夠；增加 replicas 前需重新計算 PostgreSQL connection budget 與 rate limit 策略。

## 合成 seed

`ALLOW_DEMO_SEED=true npm run seed:postgres-demo` 只建立無法登入的 synthetic account、profile 與四筆固定事件。Seed 使用 idempotency keys，可重複執行；預設安全開關未開時拒絕寫入。Production demo 是否需要 seed 由團隊人工決定，不應放入每次自動部署。

## 備份、還原與保留

部署前必須在 Coolify 為 PostgreSQL 設定 scheduled backup 到團隊控制的 S3-compatible storage，並完成至少一次實際 restore rehearsal。只有看到 backup job 成功不等於可還原。

尚待決定：

- 備份頻率、保留天數與異地儲存。
- 帳號刪除、資料匯出與 session 清理排程。
- Competition environment 結束後的整庫刪除日期。
- 真實未成年人資料的同意、年齡、家長、存取與 incident response 流程。

目前 MVP 沒有帳號刪除 UI、忘記密碼、email 驗證、自動 session cleanup 或 production retention；不可用於正式金融或未成年人服務。
