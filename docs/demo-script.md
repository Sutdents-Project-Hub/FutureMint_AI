# FutureMint AI 決賽 Demo 腳本

## 展示前準備

1. 開啟 Coolify production Flutter Web，確認登入畫面與 HTTPS。
2. 使用專為決賽建立的 synthetic test account；台上不顯示 email、password、token、key、database URL 或 Coolify secrets。
3. 確認 `/api/health` 為 ok、PostgreSQL healthy、`ALLOWED_ORIGINS` 正確。
4. 先用合成文字確認量界 model 可用；若無網路，改用明確標示的訪客／deterministic demo。
5. 投影解析度先測 1440×900；手機備援測 375px。

## 四分鐘主線

這是團隊計時演練的精煉主線，不是主辦方已確認的上台時長；收到正式時長後，以這條「輸入 → 看懂 → 學習 → 行動」故事按比例縮放。投資練習場、角色與設定留給 Q&A，不在主線搶走問題與成果的時間。

### 0:00–0:25　登入與資料界線

「FutureMint 讓每個帳號只看到自己的預算、紀錄與微課。資料由後端 session 驗證並保存到 PostgreSQL；訪客模式不保存。」

登入 synthetic account，指出已登入狀態，不露 credentials。

### 0:25–0:45　問題與首頁

「小恩開始管理零用錢與數位訂閱，但大部分工具只記帳，不會在選擇當下幫他看懂影響。」

指出本月安心可用、目標、近期紀錄與非責備式提醒。明說資料是合成。

### 0:45–1:35　Quick Capture

輸入：

```text
今天買珍奶 75
```

按「幫我整理」，停在草稿：

- 指出來源是「量界智算 AI 解析」；備援若是 deterministic demo 必須照實說。
- 說明 parse 不等於保存，可改金額、項目、分類與 AI 建議的需要／想要。
- 按「確認並記下」後，API 才寫 PostgreSQL 並更新預算。

加分可改用 `Netflix 390，四個人分`，以同一筆資料自然帶出下一段的訂閱檢查。

### 1:35–2:05　分析與訂閱提醒

先看六個月收支與需要／想要比例，再開啟續訂提醒與方案比較。說明提醒是邀請檢查使用頻率，不代表一定浪費；價格是合成展示資料。

### 2:05–2:40　個人學習規劃

進入學習，指出需要／想要、固定支出、複利與風險四段路線，再選一項微課行動。說明量界只收到最小摘要，輸出仍經 schema 驗證。

### 2:40–3:25　FutureSeed 與 AI 陪讀員

以已省 4,200 元、每月 500 元、5 年比較三條版本化合成曲線。點「慢慢長」或「高風險資產」的回落，詢問「為什麼中間掉下去？」；說明金額與最大回落由程式計算，AI 只白話解釋，曲線不是即時行情、買賣建議或報酬保證。

### 3:25–4:00　技術收尾

「前端與 API 是 Coolify 上兩個獨立 container，資料是第三個 PostgreSQL Resource。Flutter 以 Bearer token 呼叫 Fastify，後端才可接觸量界金鑰與資料庫；AI 回覆先過 schema，金額與複利由程式計算。Coolify 從 private GitHub 的 main 自動部署，不會讀我的電腦。」

若評審仍問 Azure，明確說明主辦方已關閉環境、團隊改用自有 VPS 替代，並出示已取得的規則確認；不可把替代架構稱為 Azure。

## Q&A 備用展示

- 投資練習場：20 秒指出 TWSE 延遲日期、虛擬現金、事件骰子與不提供買賣建議；只在被問到風險教育或資料來源時打開。
- 孩子／家長角色與設定：展示家長建立 8 碼邀請碼、孩子加入，以及家長只看到預算／趨勢摘要、不看到交易明細；完整共管與撤銷仍是未來工作。
- Coolify：只展示 Web／API health 與 PostgreSQL Resource 的 healthy 狀態，不露 private repository、database URL 或 secrets。

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
- 不可把 TWSE 日資料稱為即時行情，也不可把內建標的、骰子或 AI 解釋稱為推薦。
- 不可說已完成 production 法遵、正式未成年人身份或真實金融串接。
- 不可展示任何真實學生資料、credentials、private repository 內容或 Portal secrets。
