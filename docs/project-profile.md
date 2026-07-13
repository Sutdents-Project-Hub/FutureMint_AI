# 學生專案 Profile

> Schema：Student Project Profile v1｜已使用更新版 Students Project Init 驗證｜Profile JSON 僅存於 repository 外的暫存位置，不提交原始規劃檔。

## 基本資訊

- Project name：FutureMint AI
- Repository name：`FutureMint_AI`
- Project slug：`futuremint-ai`
- Stage：`competition`
- Product type：`hybrid`
- Bootstrap mode：`executable`
- Deployment：`other`
- Team collaboration：`true`

## Bootstrap 證據

- `client`：Flutter `pubspec.yaml`、`pubspec.lock` 與 `analyze`／`test`／`build` 品質指令證據齊全。
- `api`：Azure Functions `package.json`、npm `package-lock.json` 與 `test`／`typecheck`／`build`／`evaluate:captures` scripts 證據齊全。
- `executable` 分類只保證框架與品質證據存在；實際執行結果以 [測試與證據](testing-and-evidence.md) 為準，且不代表真實 Azure 串接或部署已完成。

## 摘要

青少年 AI 金錢決策教練，將使用者主動輸入的收入、支出與訂閱轉為可理解的預算回饋、個人化金融微課程與教育性未來預覽。

## 元件

- `client`：path=`apps/client`，kind=`app`，framework=`Flutter`，package_manager=`flutter`，quality=analyze, test, build
- `api`：path=`services/api`，kind=`backend`，framework=`Azure Functions`，package_manager=`npm`，quality=test, typecheck, build, evaluate:captures

## 非執行型支援資產

- `design-system`：path=`design-system`；保存 FutureMint 的視覺 token、元件、響應式、動態與可及性規範，沒有 package manager、runtime 或獨立部署生命週期，因此不列入 executable components。
- `docs`：產品、架構、安全、測試、競賽與部署的交接依據，不是軟體 runtime。

## 功能領域

- 自然語言收入、支出與訂閱事件解析
- 青少年預算回饋與金錢決策教練
- 訂閱方案比較與最佳化建議
- 個人化金融微課程
- 教育性儲蓄與複利情境預覽

## 專案限制

- 優先完成可重複展示的原型
- 優先使用主辦方提供的 Microsoft Azure 環境與額度
- 不串接 Apple Pay、LINE Pay、銀行、電子發票或證券交易
- 不提供投資明牌、下單、保證報酬或未成年人金融商品服務
- 決賽展示使用合成或取得同意且去識別的資料
- 技術與流程必須能由學生團隊在有限時間內維護與說明

## 關注事項

- ai
- database
- external-api
- personal-data

## 假設

- 主 Persona 為開始自行管理零用錢與數位消費的中學生
- 決賽 MVP 以 Flutter Web 或 Android 作為主要展示面，iOS 為共用程式碼的延伸目標
- Azure OpenAI 與 Cosmos DB 只由 Azure Functions 後端存取
- 預算、金額、期限與複利計算由確定性程式處理
- 正式帳號、家長共管與真實金融串接不納入本次 MVP
- design-system 是非執行型支援資產，不列入 executable components

## 未決定事項

- 決賽主要展示裝置與現場網路備援順序
- 共享 Azure 模型 deployment、quota 與必要 RBAC 的最終配置
- 青少年訪談與可用性測試的人數、同意與去識別方式
- 訂閱方案資料採用合成資料、人工維護資料或具授權的公開來源
- iOS Apple Development Team 與簽章責任
