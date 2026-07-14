# FutureMint 帳號、資料隔離與訪客模式設計

## 目標

將目前固定使用 `demo-user` 的競賽原型改為可註冊與登入的帳號 MVP。登入帳號只能讀寫自己的預算、紀錄與微課資料；未登入者可選擇訪客模式，但資料僅存在當次 App 記憶體，不會寫入瀏覽器、本機儲存或後端。

## 已確認決策

- 登入方式為 email 加密碼；本期不導入 Google、Apple、Azure External ID 或其他第三方 OAuth。
- 移除 `offline-demo`、離線切換與固定展示資料重設。
- 網路或 API 不可用時，前端必須通知使用者、保留尚未送出的畫面輸入，且不得宣稱資料已保存。
- 訪客模式可操作同一套預算功能，但資料在關閉、重新整理、登出或切換帳號後清除。
- 正式帳號的資料只經 Functions API；Flutter 不保存帳本、profile、微課或原始 capture 文字。

## 使用者狀態與前台流程

1. App 啟動時讀取僅含 session token 的本機設定，向 `GET /auth/me` 驗證；token 不存在、過期或無效則進登入頁。
2. 登入頁提供「登入」、「建立帳號」與「以訪客模式繼續」。註冊只要求 email 與密碼；密碼需至少 12 字元，並包含英文字母與數字。
3. 新帳號登入後若尚未建立 profile，先進入預算／目標 onboarding。完成後才可使用受保護的首頁、紀錄、Capture、微課、訂閱與 FutureSeed。
4. 訪客模式使用 transient `GuestRepository`；App Shell 顯示「訪客資料不會儲存」標示，設定頁只提供離開訪客模式，不提供雲端同步或重設展示資料。
5. 已登入帳號在設定頁顯示 email、連線帳號狀態與登出操作；登出會呼叫後端撤銷 session，再清除 token 與記憶體資料。

## 後端設計

### Auth API

- `POST /api/auth/register`：驗證 email／密碼、建立帳號、建立初始 session，回傳公開帳號摘要與 opaque token。
- `POST /api/auth/login`：以 email／密碼驗證，回傳新的 opaque token。email 不存在與密碼不符使用相同 401 回應文案。
- `POST /api/auth/logout`：要求 Bearer token，撤銷目前 session。
- `GET /api/auth/me`：要求 Bearer token，回傳帳號 email、帳號 ID、建立時間與 `profileComplete`。

密碼使用 Node.js `scrypt` 加上 16-byte 隨機 salt 雜湊；資料庫只保存 hash、salt 與演算法版本。session token 使用 32-byte 隨機值，Client 保存原 token、Server 僅保存 SHA-256 hash。session 預設 7 天後到期，可被 logout 立即撤銷。登入 API、log 與 error response 不得回傳密碼、token、hash、salt 或帳號是否存在以外的內部細節。

### Ownership 與資料儲存

- 所有既有個人資料 API 都必須以 `Authorization: Bearer <token>` 取得 server-side `userId`；不接受 Client 傳入或指定 owner。
- `profile` 成功寫入後標記 `profileComplete=true`。新帳號沒有預設財務資料，也不取得 `demo-user` 的合成紀錄。
- Memory provider 支援多帳號與多 session，用於完整本機測試；Cosmos provider 新增手動管理的 `accounts` 與 `sessions` containers，不自動建立 Azure 資源。
- 現有 `profiles`、`moneyEvents`、`learning` 仍以 `/userId` partition key 儲存，所有讀寫持續帶經驗證的 user ID。
- CORS 的 allowed headers 增加 `authorization`；仍只接受明確列出的 origin，且回應維持 `no-store`。

## Client 設計

- 新增 Auth API、session token store、SessionController、登入／註冊畫面、onboarding 畫面與 transient GuestRepository。
- API repository 以 token 自動附加 Authorization header；收到 401 時清除 session 並回登入頁，顯示「登入已過期，請重新登入」。
- `AppController` 只管理已進入帳本的 repository 狀態；SessionController 管理 signed-out、authenticating、authenticated、onboarding 與 guest access 狀態。
- GoRouter 加入 `/auth`、`/onboarding`，所有既有帳本 routes 受 SessionController redirect 保護。
- App Shell 與 Settings 移除離線展示語意，改為帳號／訪客狀態、帳號 email 與登出。

## 錯誤與可及性

- 註冊／登入欄位顯示 label、密碼可見切換、提交中 disabled 狀態、可讀錯誤文字與鍵盤焦點順序。
- 401、session expiry、網路 timeout、連線失敗與 5xx 各自使用繁中明確訊息。capture、profile 或 event 保存失敗時保留畫面內容。
- 色彩不作為唯一狀態；訪客和登入帳號同時以文字、圖示與 Semantic label 表示。

## 不在本期範圍

- Email 驗證、忘記／重設密碼、改密碼、多因素驗證、第三方登入、帳號刪除、資料匯出、家長共管與正式未成年人同意。
- 雲端 container 建立、production secret、部署、法遵審查、分散式 rate limiting 與 production incident response。

因此此功能是可本機展示的帳號 MVP；在完成上述保護與法遵前，不得宣稱適合蒐集真實未成年人資料或 production 使用。
