# FutureMint AI

> 目前階段：競賽／展示｜部署：其他平台（待專案文件確認）

## 專案簡介

青少年 AI 金錢決策教練，將主動輸入的收入、支出與訂閱轉為預算回饋、個人化金融微課程與教育性複利預覽。

## 目標與主要功能

- 專案目標與使用對象尚待依需求確認。
- 只列入本階段已確認、可展示或可驗收的功能；構想與未來功能請明確標示為非本階段範圍。

## 技術與元件

目前尚未建立可辨識的執行元件；確認技術與產品表面後再建立必要結構。

## 專案結構

- 目前只記錄實際存在的元件；不建立未使用的空資料夾。
- 每個獨立元件依自己的 manifest、README 與框架慣例安裝、啟動、測試及建置。

## 快速開始

初始化未執行框架安裝或服務啟動，因此目前沒有經驗證的通用啟動指令。請從實際 manifest 與元件 README 驗證後補上前置需求、安裝、啟動方式、port 與本機 URL。

## 測試與品質

只記錄實際存在且已執行成功的 lint、typecheck、test、build 或手動驗收方式。若目前沒有自動化測試，請明確記錄主要人工驗收流程與限制。

## 環境變數與敏感資訊

- 真實值只存放於本機或部署平台，不提交 `.env`。
- 以 `.env.example` 記錄必要的變數名稱、用途與安全 placeholder；公開前端設定不可用來保存秘密。

## 部署狀態

目前狀態：其他平台（待專案文件確認）。只有在設定與流程實際驗證後，才補上平台、base directory、build/start command、port、healthcheck、資料與回滾方式。

## Git 與版本控制

- Repository 名稱：`FutureMint_AI`
- 全新專案由初始化器建立本機 `main` branch，並在安全掃描後以 `chore(init): 初始化學生專案結構` 提交本次初始化產物。
- 既有 Git repository 保留原 branch 與歷史，不自動 commit。
- 初始化不設定 `user.name`／`user.email`，不建立 remote，也不 push；後續 Git 操作遵守 [AGENTS.md](AGENTS.md)。
- 後續操作先以 `git remote -v` 判斷本機或遠端模式；只要求 commit 時維持目前分支，獲准合併並驗證 `main` 後才安全關閉已完整合併的任務 branch。

## 文件索引

- [專案範圍與驗收](docs/project-overview.md)
- [競賽與展示準備](docs/competition.md)
- [部署說明](docs/deployment.md)

## 維護與交接

- 開發規則請見 [AGENTS.md](AGENTS.md)。
- 功能、架構、指令、環境變數、部署或限制改變時，需同步更新相關文件。
- LICENSE、資料集、模型與素材授權須依作者、學校及競賽規則確認，不由初始化工具自行決定。
