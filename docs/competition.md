# 競賽與展示準備

## 比賽定位與基礎設施變更

- 賽事：第六屆中學生黑客松（2026）
- 主題：生活化人工智慧加值雲端應用
- 官方網站：[2026 中學生黑客松](https://sites.google.com/view/hsh2026/)
- 主辦方 Azure 系統已關閉；團隊改用自己的 VPS／Coolify、PostgreSQL 與量界智算。

截至 2026-07-16，公開競賽資訊仍把「Azure 概念驗證」列為 25%，也未見接受 Coolify／量界替代的公告。團隊必須在繳交前向主辦方取得書面確認：Azure 關閉後是否接受其他雲端／自架 PoC、評分項目是否調整。這是參賽資格與得分的 P0 外部關卡；簡報應如實揭露替代原因，不可把 Coolify 或量界稱為 Azure。

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
2. 輸入一筆小額消費，量界 AI 拆成可修改結構化草稿。
3. 使用者確認需要／想要建議後才寫 PostgreSQL；確定性規則更新預算與分析。
4. 從近期模式帶出一則訂閱檢查，而非把提醒說成浪費判決。
5. 所選 AI 依最小摘要選受控教材主題與順序；正文不是任意生成，微課按需使用，schema 與限制由 API 驗證。
6. FutureSeed 把當下省下的一小筆錢轉成三條版本化合成路徑，明說不是行情或預測。
7. 技術收尾只說明 Web／API／PostgreSQL 的安全邊界；投資練習場、角色與設定保留給 Q&A，不塞進主線。

## PoC 最小證據

- Deterministic provider：30 筆全合成繁中 fixture、schema 與欄位回歸；不可當成量界準確率。
- 量界 provider：同一組或代表性合成案例的成功率、人工修正率、平均／P95 latency、429／timeout 與 invalid-output 統計。
- Database：register → save → API restart／redeploy → login → read，證明使用 PostgreSQL 而非 memory。
- Market lab：TWSE source／日期／fallback 可見，虛擬訂單的 cash／holding／idempotency tests 通過，登入訂單重啟後仍存在。
- Deployment：兩個 Application health checks、private database、GitHub `main` auto deploy、rollback 與 backup／restore。
- Security：UI／log／簡報不顯示 email、password、token、key、database URL、prompt 或完整財務原文。
- Privacy controls：量界 AI 資料說明、明確啟用／撤回、provider 前後端雙層攔截與帳號刪除有自動化測試；production 供應商條款與 backup retention 另列未驗證。
- 所有數字標示「本機實測」、「Coolify 實測」或「目標」，不混用。

## Demo 備援

- 正常：合成測試帳號登入 Coolify Web，API 使用 PostgreSQL + 量界。
- 第一層：量界失敗時顯示真實安全錯誤；可另開明確標示的 deterministic demo，不冒充同一次 AI 成功。
- 第二層：完全無網路時用 Flutter 訪客模式；說明資料不保存、不與帳號同步。
- 第三層：最後一個成功 Web build／預錄影片與測試報告。
- 不在台上打開會顯示 GitHub private URL、Coolify secret、database credential 或量界 key 的頁面。

## 提交前清單

- [ ] 主辦方已書面確認替代 Azure 的評分與提交方式。
- [ ] 正式 iPhone 的 Coolify API／PostgreSQL、API domain、TLS、health 正常；Web 僅在選用展示時另驗收。
- [ ] GitHub App 只授權單一 private repository，`main` Auto Deploy 經實際 push 驗證。
- [ ] 量界 model／quota／資料條款確認，合成案例實測完成。
- [ ] PostgreSQL 不公開；backup 與隔離 restore 實測完成。
- [ ] Register／profile／capture／save／restart／login／read 主線通過。
- [ ] Synthetic account 的 AI 同意／撤回與帳號刪除在 production API 做端對端驗收，並確認備份保留說明一致。
- [ ] 簡報、README、畫面與實際功能一致，不宣稱 Azure、真實金融串接或 production 法遵。
- [ ] 每位成員完成至少三輪計時演練，Demo 帳號、網路、充電、轉接器與錄影備援就緒。
- [ ] Repository 與 bundle 完成 secret／個資／合約掃描。

操作台詞見 [Demo 腳本](demo-script.md)，部署見 [Coolify 部署說明](deployment.md)，實測見 [測試與證據](testing-and-evidence.md)。

## 產品化後的主張界線

2026-09 使用者已核准正式產品準備與 iPhone-only 上架範圍；競賽材料是歷史來源。Email 驗證／重設、邀請更新／停用與發布檢查已納入實作；SMTP 真實送達、未成年人營運條件與 App Store 接受未完成。AI 教育內容主張改為「選題與受控教材」，不得再宣稱自由生成任意投資解答。最新驗證以 [測試證據](testing-and-evidence.md) 為準。

2026-10-02 手機排版調整以 iPhone 模擬器合成資料巡檢與 Flutter 自動化檢查驗證，包含草稿優先、FutureSeed 順序、首次設定分區及表單／提醒修正；展示操作同步至 Demo 腳本。此證據不代表新增學生可用性研究、正式服務驗收或 App Store 發布。

## 正式產品準備與競賽歷史界線

新增訂閱合約／實付、年齡／監護人、provider 政策、手動紀錄／匯出與 iPhone 本機提醒屬於正式產品核准範圍；競賽 Azure 規則、得分及匿名成效研究仍是歷史或外部確認，不因上架程式完成而推定通過。正式門檻為臺灣 15 歲，15–17 歲監護人信件確認不證明法定代理人身分。

可描述基線 `af7a5df` 的 GitHub CI 成功（122 API／121 Flutter、未簽章 iOS／images），不得說本輪修改已經遠端 CI 或 production 驗收。既有 Coolify Resources 曾成功部署是使用者提供事實，現在 live health 尚未本輪驗證。本輪不建立定期備份；SMTP／domain、供應商政策與 signed TestFlight／App Privacy／年齡問卷依啟用範圍仍須實證。日後若啟用備份，另驗收還原與刪除不復活。

簡化部署仍保留原年齡與資料權限；未啟用寄信時可用未驗證 Email 註冊／登入，不能宣稱信箱驗證或監護人確認成功；未完成供應商說明時外部AI未開放。不得將訪客或API啟動成功描述為完整正式帳號／AI／App Store驗收。
