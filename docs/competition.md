# 競賽與展示準備

## 比賽定位與基礎設施變更

- 賽事：第六屆中學生黑客松（2026）
- 主題：生活化人工智慧加值雲端應用
- 官方網站：[2026 中學生黑客松](https://sites.google.com/view/hsh2026/)
- 主辦方 Azure 系統已關閉；團隊改用自己的 VPS／Coolify、PostgreSQL 與量界智算。

既有規格仍把「Azure 概念驗證」列為 25%。團隊必須在繳交前向主辦方取得書面確認：Azure 關閉後是否接受其他雲端／自架 PoC、評分項目是否調整。簡報應如實揭露替代原因，不可把 Coolify 或量界稱為 Azure。

## 評分證據對應

| 項目 | 既有權重 | FutureMint AI 證據 |
|---|---:|---|
| 問題理解度 | 10% | 青少年情境、訪談／可用性測試、問題前後差異 |
| 創新性 | 10% | 真實事件 → 當下決策 → 個人化學習 → 行動閉環 |
| 企劃完整度 | 20% | Persona、範圍、資料、AI 邊界、安全、指標與替代部署一致 |
| Azure 概念驗證 | 25% | 先向主辦方確認替代規則；展示可重現 AI、PostgreSQL persistence、錯誤處理與測試，不虛構 Azure |
| 簡報表達 | 35% | 故事、穩定 Demo、清楚分工、計時演練與備援 |

## Demo 主線

1. 中學生收到零用錢，卻沒有先分配目標。
2. 輸入「今天午餐跟飲料 185」，量界 AI 拆成可修改結構化草稿。
3. 使用者確認後才寫 PostgreSQL；確定性規則更新預算。
4. 比較合成訂閱方案的月負擔、節省差額與資格。
5. 量界 AI 把事件轉成微課；schema 與限制由 API 驗證。
6. FutureSeed 以程式公式顯示教育情境。
7. 簡短展示 Coolify 的 Web／API healthy 與 PostgreSQL Resource，但不露 secrets。

## PoC 最小證據

- Deterministic provider：30 筆全合成繁中 fixture、schema 與欄位回歸；不可當成量界準確率。
- 量界 provider：同一組或代表性合成案例的成功率、人工修正率、平均／P95 latency、429／timeout 與 invalid-output 統計。
- Database：register → save → API restart／redeploy → login → read，證明使用 PostgreSQL 而非 memory。
- Deployment：兩個 Application health checks、private database、GitHub `main` auto deploy、rollback 與 backup／restore。
- Security：UI／log／簡報不顯示 email、password、token、key、database URL、prompt 或完整財務原文。
- 所有數字標示「本機實測」、「Coolify 實測」或「目標」，不混用。

## Demo 備援

- 正常：合成測試帳號登入 Coolify Web，API 使用 PostgreSQL + 量界。
- 第一層：量界失敗時顯示真實安全錯誤；可另開明確標示的 deterministic demo，不冒充同一次 AI 成功。
- 第二層：完全無網路時用 Flutter 訪客模式；說明資料不保存、不與帳號同步。
- 第三層：最後一個成功 Web build／預錄影片與測試報告。
- 不在台上打開會顯示 GitHub private URL、Coolify secret、database credential 或量界 key 的頁面。

## 提交前清單

- [ ] 主辦方已書面確認替代 Azure 的評分與提交方式。
- [ ] Coolify Web／API／PostgreSQL 三 Resources、domains、TLS、health 正常。
- [ ] GitHub App 只授權單一 private repository，`main` Auto Deploy 經實際 push 驗證。
- [ ] 量界 model／quota／資料條款確認，合成案例實測完成。
- [ ] PostgreSQL 不公開；backup 與隔離 restore 實測完成。
- [ ] Register／profile／capture／save／restart／login／read 主線通過。
- [ ] 簡報、README、畫面與實際功能一致，不宣稱 Azure、真實金融串接或 production 法遵。
- [ ] 每位成員完成至少三輪計時演練，Demo 帳號、網路、充電、轉接器與錄影備援就緒。
- [ ] Repository 與 bundle 完成 secret／個資／合約掃描。

操作台詞見 [Demo 腳本](demo-script.md)，部署見 [Coolify 部署說明](deployment.md)，實測見 [測試與證據](testing-and-evidence.md)。
