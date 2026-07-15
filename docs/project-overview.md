# 專案範圍與驗收

## 一句話定義

FutureMint AI 是專為青少年設計的 AI 金錢決策教練：把使用者主動輸入的收入、支出與訂閱，轉為當下可理解的選擇建議、個人化金融微課程與教育性未來預覽。

## 核心問題與使用者

青少年開始獨立面對零用錢、交通、飲食、遊戲與數位訂閱，卻常只有「月底才發現錢不夠」的記帳結果。主要 Persona 是開始自行管理日常開銷與數位消費的中學生；家長、上班族與銀髮族不進入本次 MVP。

## 決賽 MVP

1. 用自然語言輸入收入、支出與訂閱；登入帳號由 Fastify API 呼叫量界智算或明確標示的 deterministic provider。
2. Provider 回傳符合 schema 的可修改草稿；未確認前不寫資料庫。
3. PostgreSQL 保存帳號自己的 profile、events 與 lessons，API 重啟後仍可取回。
4. 程式以確定性規則計算預算、剩餘金額、分帳、訂閱成本與複利。
5. 微課只取得需要的事件摘要，提供一個觀念、一個例子與一個可行動選擇。
6. 訂閱比較使用版本化合成方案，不冒充即時市場資訊。
7. FutureSeed 明示投入、期間與假設利率，不等於金融商品或實際報酬。
8. 訪客模式可離線展示，但資料只留在 Flutter 記憶體。

## 非範圍

- Apple Pay、LINE Pay、悠遊卡、銀行、電子發票、Email 自動同步。
- 付款、轉帳、證券下單、開戶、金融商品推薦、信用評分或保證報酬。
- 家長監控、學校帳號、公開排行榜與跨世代完整產品線。
- 正式未成年人法遵、客服、付費、災難復原與大規模資料管線。
- 將可確定計算的金額與公式交給 AI。
- Azure runtime；主辦方 Azure 已關閉，現行部署目標是團隊 VPS／Coolify。

## 核心驗收

| 流程 | 可觀察完成條件 |
|---|---|
| Quick Capture | 30 筆 deterministic 合成繁中回歸通過；量界 adapter 的 JSON／timeout／429／schema 行為有 fake client tests，真實模型另行實測 |
| Authentication | Register／login／logout／session revoke；不同帳號無法讀寫彼此資料 |
| 交易保存 | Parse 不寫入；確認後重新整理與 API restart 仍能取回 |
| 預算回饋 | 相同輸入產生相同數學結果，金額與邊界條件有測試 |
| 訂閱教練 | 比較至少兩種合成方案，區分已知價格、使用者輸入與解釋 |
| 微課程 | 與最近確認事件相關、含限制提示；來源標示量界或 Demo |
| FutureSeed | 公式、期間、投入與假設利率可見；結果標示教育模擬 |
| AI 失敗 | Timeout、429、格式錯誤時不保存、不洩漏、不偷偷切 Demo |
| Coolify | 三 Resources 分離；Web／API health、PostgreSQL persistence、private database、backup／restore 可證明 |
| 決賽 Demo | 用合成資料完成固定腳本，另有訪客模式與錄影備援 |

## 已決定技術

- Client：Flutter 3.41.x，Web 由 Nginx container 服務。
- API：Fastify 5 + TypeScript + Node.js 22。
- Data：Coolify PostgreSQL 17，versioned SQL migrations。
- AI：量界智算 OpenAI-compatible adapter；deterministic provider 只供 Demo／測試。
- Hosting：private GitHub repository → Coolify Auto Deploy；Web、API、PostgreSQL 三個 Resources。
- Security：scrypt password、hashed session token、Bearer ownership、Zod、CORS allowlist、rate limit 與 parameterized SQL。
- Design：`design-system/futuremint-ai/MASTER.md` 是 Flutter 視覺、響應式與可及性共同依據，不是 runtime。

## 待團隊確認

- 正式 Web／API domains、VPS 容量、監測與現場網路備援。
- 量界帳號可用 model、費率、quota、資料條款與競賽允許性。
- PostgreSQL backup schedule、retention、S3 destination 與 restore 演練。
- 青少年訪談／可用性測試人數，以及監護與去識別方式。
- 訂閱方案資料來源與授權。
- iOS signing Team；Android／Web 為主要展示面。

完整策略見 [產品規格](product-spec.md)，實測見 [測試與證據](testing-and-evidence.md)，現場流程見 [Demo 腳本](demo-script.md)。
