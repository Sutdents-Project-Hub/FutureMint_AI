# FutureMint AI 決賽 Demo 腳本

## 展示前準備

1. 開啟 Coolify production Flutter Web，確認登入畫面與 HTTPS。
2. 使用專為決賽建立的 synthetic test account；台上不顯示 email、password、token、key、database URL 或 Coolify secrets。
3. 確認 `/api/health` 為 ok、PostgreSQL healthy、`ALLOWED_ORIGINS` 正確。
4. 先用合成文字確認量界 model 可用；若無網路，改用明確標示的訪客／deterministic demo。
5. 投影解析度先測 1440×900；手機備援測 375px。

## 四分鐘主線

### 0:00–0:25　登入與資料界線

「FutureMint 讓每個帳號只看到自己的預算、紀錄與微課。資料由後端 session 驗證並保存到 PostgreSQL；訪客模式不保存。」

登入 synthetic account，指出已登入狀態，不露 credentials。

### 0:25–0:55　問題與首頁

「小恩開始管理零用錢與數位訂閱，但大部分工具只記帳，不會在選擇當下幫他看懂影響。」

指出本月安心可用、目標、近期紀錄與非責備式提醒。明說資料是合成。

### 0:55–1:45　Quick Capture

輸入：

```text
今天買珍奶 75
```

按「幫我整理」，停在草稿：

- 指出來源是「量界智算 AI 解析」；備援若是 deterministic demo 必須照實說。
- 說明 parse 不等於保存，可改金額、項目與分類。
- 按「確認並記下」後，API 才寫 PostgreSQL 並更新預算。

加分可輸入 `Netflix 390，四個人分` 或 `早餐 65，飲料 40`。

### 1:45–2:25　訂閱教練

比較方案。說明價格是合成展示資料，成本與排序由程式計算；AI 只解釋，資格與條款仍需查官方。

### 2:25–3:00　個人化微課

進入學習，選一項行動。說明課程只用必要事件摘要，量界輸出仍經 schema 驗證，不是投資建議。

### 3:00–3:35　FutureSeed

以每月 500 元、5 年、假設 3% 試算。分開說投入本金、假設成長與期末可能金額；這是 deterministic 普通年金公式，不保證報酬。

### 3:35–4:00　技術收尾

「前端與 API 是 Coolify 上兩個獨立 container，資料是第三個 PostgreSQL Resource。Flutter 以 Bearer token 呼叫 Fastify，後端才可接觸量界金鑰與資料庫；AI 回覆先過 schema，金額與複利由程式計算。Coolify 從 private GitHub 的 main 自動部署，不會讀我的電腦。」

若評審仍問 Azure，明確說明主辦方已關閉環境、團隊改用自有 VPS 替代，並出示已取得的規則確認；不可把替代架構稱為 Azure。

## 降級展示

| 情境 | 畫面與說法 |
|---|---|
| 量界 timeout／429／invalid output | 顯示安全錯誤與重試；不宣稱解析成功 |
| PostgreSQL unavailable | API health 503，不顯示保存成功；保留尚未送出的草稿 |
| 完全無網路 | 訪客模式只用記憶體，不保存、不與帳號同步 |
| 新 deployment unhealthy | Coolify rollback 到上一個 healthy Web／API image |
| 主機不可用 | 用最後成功 build／錄影；口頭說明服務中斷 |
| 資料錯誤 | 停止寫入，從已驗證 backup 還原到新 database |

## 不可宣稱

- 不可說目前使用 Azure，或把 Coolify／量界稱成 Azure service。
- 不可把 deterministic 30/30 當成量界模型準確率。
- 不可說訂閱價格即時、方案一定符合資格、FutureSeed 是報酬預測。
- 不可說已完成 production 法遵、正式未成年人身份或真實金融串接。
- 不可展示任何真實學生資料、credentials、private repository 內容或 Portal secrets。
