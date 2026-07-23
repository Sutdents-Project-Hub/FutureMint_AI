# AGENTS.md

## 適用範圍與優先順序

- 本檔適用於整個 `FutureMint AI` repository；子目錄若有更具體的 `AGENTS.md`，只在該範圍內補充本檔。
- 依序遵守使用者當次指示、本檔、根目錄 `README.md`、`docs/` 與元件 README；內容衝突時先停止並確認。
- 目前階段：第六屆中學生黑客松決賽原型。主辦方 Azure 環境已關閉；目前目標是由私人 GitHub repository 自動部署到團隊 VPS 的 Coolify，尚未部署。
- Git repository 名稱：`FutureMint_AI`。全新專案的初始 branch 為 `main`。
- Project slug：`futuremint-ai`。
- 本機 Docker Compose project：`futuremint_ai`；主要 `compose.yaml` 必須明確設定頂層 `name: futuremint_ai`。
- Coolify project：`futuremint-ai`；Coolify services：`futuremint-ai-web`、`futuremint-ai-api`、`futuremint-ai-postgres`。
- Compose services 使用 `web`、`api`、`postgres`，不設定 `container_name`；容器名稱由 Compose project 與 service role 產生。
- 根目錄 `compose.yaml` 只供本機三容器整合驗證；Coolify production 必須維持 `app/Dockerfile` 的 Web Application、`backend/Dockerfile` 的 API Application 與受管 PostgreSQL Resource 三個獨立 Resources，不得把本機 Compose 當正式入口。
- 產品型態：`hybrid`。
- Bootstrap 模式：`executable`；Flutter 與 Fastify API 均需以 manifest、lockfile、Dockerfile 與實際品質指令維持此狀態。

### 已確認功能領域

- 自然語言收入、支出與訂閱事件解析。
- 青少年預算回饋、訂閱方案比較與金錢決策教練。
- 個人化金融微課程。
- 教育性儲蓄與複利情境預覽。

### 專案限制

- 優先完成一條可重複、可降級的 Demo 主流程。
- 不串接支付、銀行、電子發票、證券交易或真實未成年人金融服務。
- 決賽只使用合成資料，或取得同意且完成去識別的資料。
- 技術、操作與部署證據必須能由學生團隊自行維護及說明。

### 假設與未決事項

- 主 Persona 是開始管理零用錢與數位消費的中學生；正式帳號與家長共管不在 MVP。
- 主要 Demo 面為 Flutter Web 或 Android；iOS 簽章、展示裝置、網路備援、正式 domain 與 VPS 備份仍待確認。
- 訂閱方案資料來源及青少年可用性測試的同意／去識別方式尚待團隊定案。

## 專案事實與邊界

青少年 AI 金錢決策教練，將主動輸入的收入、支出與訂閱轉為預算回饋、個人化金融微課程與教育性複利預覽。

- 已確認 executable components：`app/` 是 Flutter Android／iOS／Web Client；`backend/` 是 Fastify TypeScript／Node.js 22 後端。
- `design/` 是沒有 runtime、manifest 或部署生命週期的設計支援資產；`docs/` 是產品、架構、競賽、測試與部署依據，兩者不冒充 executable component。
- 專案結構採公司慣例的固定 component roots：`app/`、`backend/`、`design/` 與 `docs/`；`app/`、`backend/` 本身就是 framework root，manifest 直接位於 component 根目錄，不得再建立 project-name 或 framework-name wrapper。
- Flutter、Fastify、Node.js 22 與 npm 是已實作且可驗證的學生技術選型；除非另行核准遷移，不為了套用公司新專案基線而更換框架、runtime 或 package manager。
- 已選定 Coolify 三 Resource 架構：Flutter Web Application、Fastify API Application、PostgreSQL Database；AI 僅由 API 呼叫量界智算的 OpenAI-compatible endpoint。尚未建立的 VPS、Coolify、DNS、資料庫與外部 AI 連線不得描述成已完成。
- Repository 與專案根目錄名稱維持 `FutureMint_AI`；Coolify resources 與新技術識別優先使用 `futuremint-ai` 或平台既有命名慣例。
- 新 component id、路徑與一般文件名使用能表達責任的 lowercase kebab-case；固定角色優先使用 `app`、`web`、`cms`、`backend`、`packages`、`design` 與 `docs`。
- 保留現有且可工作的框架慣例；新增 executable component 時直接建立在對應固定 root，不新增無必要的分類包層。
- 不建立未使用的 component root 或部署資源；若需求確實需要非標準結構，必須在 `docs/project-profile.md` 記錄理由、影響與核准狀態。
- 不把不同執行環境、依賴或部署生命週期硬塞進同一元件；需要共用程式碼時，先確認至少有兩個真實使用者。
- Flutter／Web 不得直接持有量界智算 API key 或 PostgreSQL connection string；模型與資料存取一律經 Fastify API。AI 回覆必須經 schema／範圍驗證，金額、期限與複利使用確定性程式計算。
- Flutter UI 以 `design/futuremint-ai/MASTER.md` 為共用視覺、響應式與可及性依據；實作與規範衝突時先確認需求並同步兩邊，不靜默漂移。

## 工作方式

- 修改前先讀根 README、相關文件、manifest、設定與實際程式碼；不得只依資料夾名稱猜測。
- 小型文案或單點修正可直接處理；一般功能先說明假設、範圍與驗證；登入、權限、個資、資料庫、刪除、AI 外部服務、部署或跨元件變更先提出計畫與成功標準。
- 只做完成任務所需的最小一致修改；不要混入無關重構、格式化、重新命名、移檔或依賴升級。
- 發現不在範圍內的問題時記錄並回報，不要順手修。
- 以可觀察結果驗證：優先執行現有的 lint、typecheck、test、build 或實際操作；無法執行時明確回報原因與剩餘風險。
- 不得聲稱未實際執行的測試、部署、外部操作或人工驗收已完成。

## 變更分類與文件同步

- 工作中新增或發現功能、需求、流程、既有行為變更、缺陷、測試結果或實作事實時，先分類為釐清、缺陷修正、已核准範圍調整、範圍變更或新能力。
- 使用者當次明確要求即代表目前敘述方向已獲核准；一般範圍內實作與文件同步不需額外等待批准。只有結果會實質改變架構、權限／安全、保存資料、破壞性行為、外部服務／成本／授權、production／部署、競賽驗收或其他明示關卡時才停止確認。
- 實作前辨識受影響的權威文件，完成前在同一任務同步；文件同步是完成條件，不是之後再補的工作。
- 產品定位、功能範圍與驗收更新 `docs/product-spec.md`、`docs/project-overview.md`；專案分類、元件或部署狀態改變時同步 `docs/project-profile.md`。
- 元件邊界、API、資料、安全或外部整合更新 `docs/architecture.md`、`docs/data-and-storage.md`、`docs/security-and-privacy.md`、`docs/integrations.md` 及受影響的 `app/README.md`／`backend/README.md`。
- 啟動、指令、環境變數、Compose、部署、rollback 或 hosting resource 改變時，更新根 `README.md`、元件 README、`.env.example`、`docs/deployment.md` 與 `docs/hosting-resources.md` 中實際受影響的文件。
- Demo 流程、測試證據、競賽主張或限制改變時，更新 `docs/demo-script.md`、`docs/testing-and-evidence.md` 與 `docs/competition.md`；視覺規範或 UI 行為改變時同步 `design/README.md`、`design/futuremint-ai/MASTER.md` 與對應 Client 實作／測試。
- 優先更新既有權威文件，不為了形式新增空 Markdown；不把規劃、假設或未執行結果寫成已實作或已驗證。
- 完成回報列出變更分類與同步文件；若沒有文件需要變更，說明文件仍與實作一致的具體理由。

## README 與文件同步

- `README.md` 是專案入口，內容只記錄已確認的目標、功能、結構、技術、啟動、測試、環境變數名稱、部署狀態與文件連結。
- 未驗證的指令、port、URL、帳號、部署值或 healthcheck 必須標示為尚未驗證，不得猜測。
- 功能、架構、依賴、指令、環境變數、資料、部署或限制改變時，同步更新根 README、相關元件 README 與 `docs/`。
- 競賽專案若有 `docs/competition.md`，同步維護問題、對象、展示流程、證據來源、限制與提交清單。
- Profile 分類或元件邊界改變時同步更新 `docs/project-profile.md`；個資、資料庫、AI 或外部 API 改變時同步更新 `docs/security-and-privacy.md`、`docs/data-and-storage.md` 與 `docs/integrations.md`。
- 測試數量、建置結果、Demo 降級或平台限制改變時同步更新 `docs/testing-and-evidence.md`、`docs/demo-script.md` 與 `docs/competition.md`；設計規範改變時同步 `design/README.md`、`MASTER.md` 與 Client `lib/design/`。

## 資料、秘密與授權

- 真實 API key、token、secret、password、private key、cookie、憑證、Webhook URL、production `.env`、個資與未公開資料不得寫入程式、文件、log、commit 或範例。
- `.env.example` 只保留變數名稱與安全 placeholder；前端或 App 可見的設定不得被當成秘密，敏感操作必須由可信任後端或平台執行。
- `backend/.env.example` 是安全的變數名稱索引；本機實際值放在已忽略的 `.env`，部署值放 Coolify Environment Variables。`DATABASE_URL`、`LIANGJIE_API_KEY` 等秘密只能設為 runtime secret，不得設成前端 build argument 或寫入 repository。
- 合約、協議、報價、法務／商業文件、客戶或學生個資預設不提交；若專案確實需要公開的競賽文件，先逐檔確認內容與授權。
- 使用資料集、模型、圖片、字型、套件或程式碼前確認來源、授權與競賽規則；README 記錄必要 attribution，不自行選擇 LICENSE。

## Git、Commit 與 Pull Request

- 全新專案初始化的固定例外是：執行 `git init -b main`，安全掃描通過後只 stage 初始化產物，並建立 `chore(init): 初始化學生專案結構`。既有 Git repository 不適用此例外。
- 除上述固定初始 commit 外，只有使用者明確要求時才可 commit、push、建立 PR、merge、release 或部署；各項授權彼此獨立。
- 每次 branch、commit、merge、push 或 PR 前，先執行 `git status --short --branch`、`git branch --show-current` 與 `git remote -v`，確認目前分支、working tree、變更範圍、remote 與本次授權。
- **未設定 remote**：只執行本機 branch、commit 與 merge；不得虛構 push 或 PR，也不得自行建立 remote 或 GitHub repository。
- **已設定 remote**：遵守遠端保護規則；GitHub 團隊專案預設推送任務 branch、建立 Pull Request、完成檢查後 squash merge，再同步本機 `main`，不得直接 push `main`。
- 使用者只要求 `commit` 時，只提交目前任務中可獨立理解的 checkpoint，並**維持在目前分支**；不得 merge、刪除 branch、push、建立 PR、release 或 deployment。
- 使用者要求**合併進 `main`**時，視為目前任務收尾；安全檢查後可提交同一任務必要且範圍清楚的剩餘變更，再安全合併並驗證 `main`。若混有無關或不明變更，停止並詢問。
- 「合併進 `main` 並 push」可授權必要 commit、merge 與遠端同步，但**不代表已授權部署**或 release；仍須依 remote 模式使用既有安全流程。
- 合併成功、`main` 驗證通過，且任務 branch 已完整合併、沒有獨有 commit 或待續工作時，才使用 `git branch -d <branch>`；**不得使用 `git branch -D`**。Conflict、驗證失敗、dirty worktree 或任務未完成時保留 branch。
- 成功關閉後回到 `main`；**下一個獨立任務**從最新 `main` 建立新 branch，不混入已完成任務。
- commit 採 Conventional Commits：`<type>(<scope>): <繁體中文描述>`；`type`／`scope` 維持英文，Commit subject 描述與 Commit body 預設使用繁體中文，一次提交只包含一個可理解、可回滾的目的。
- Pull Request title 使用 `<type>(<scope>): <繁體中文描述>`，Pull Request 內文使用繁體中文並記錄目的、範圍、驗證、文件同步、風險、資料／環境、部署與 rollback 影響。
- 建議類型：`feat`、`fix`、`docs`、`chore`、`refactor`、`test`、`build`、`ci`、`style`、`perf`、`revert`。
- 提交前必須檢查 staged、unstaged、untracked 與 diff，排除秘密、`.env`、憑證、個資、內部文件、合約、報價與其他不應提交內容。
- 發現敏感內容時不得 commit 或 push：先 unstage、更新 `.gitignore`、改用 `.env.example`／placeholder；疑似外洩的憑證需提醒輪替。不確定檔案性質時先詢問。
- 只 stage 明確路徑，不使用 `git add .`；不得直接 push 到 `main`，團隊專案以短期 branch、PR 與通過的檢查交接。

## 部署與交接

- 部署不是初始化的一部分；未經明確要求，不建立 Coolify／雲端資源、資料庫、DNS、bucket、secret、release 或 production 連線。
- 有 `docs/deployment.md` 時以其為部署依據；設定尚未驗證時保持「尚未驗證」，不得複製其他專案的 port、domain、Docker 或 healthcheck。
- 若新增可獨立部署 component，先為它建立自己的 Dockerfile Resource 契約（base directory、port、healthcheck、公開路由、runtime／build variables、backup 與 rollback），而不是加入 production Compose。
- 交接給學生前，確認 README 能說明目前能做什麼、如何啟動與驗證、已知限制、環境變數來源、部署狀態及下一步。

## 完成回報

- 回報變更分類、變更檔案、行為差異、實際執行的驗證與結果、同步文件、未驗證事項、剩餘風險及需要人工決定的項目；若沒有文件變更，說明理由。
