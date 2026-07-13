# FutureMint AI Design System

本資料夾是 FutureMint Flutter Client 的非執行型設計支援資產，沒有 package manager、runtime 或獨立部署生命週期，因此不列入 Student Project Profile 的 executable components。

## 權威文件

- [MASTER.md](futuremint-ai/MASTER.md)：全域色彩、字體、間距、元件、響應式、動態、狀態與可及性規範。
- 若未來建立 `futuremint-ai/pages/<page>.md`，頁面 override 只覆蓋該頁明確列出的規則，其餘仍以 `MASTER.md` 為準。

## 與程式碼的關係

- Flutter tokens 與 Material theme 位於 `apps/client/lib/design/`。
- 新畫面先重用既有 semantic colors、type scale、spacing 與 components，不自行新增近似 token。
- 規範與實作改變時必須同步兩邊；不得只改文件或只改 UI，造成交接內容漂移。

## 人工品質檢查

- 375px、768px、1024px、1440px 與 landscape 不溢位。
- 亮／暗主題 body text 對比至少 4.5:1，狀態不只靠顏色表達。
- 互動目標至少 48×48dp，Web focus 清楚，鍵盤順序合理。
- 200% text scale、reduced motion、loading／empty／error／offline／disabled 狀態可用。
- Connected 失敗不得靜默切換成合成 Demo；Offline demo 必須由使用者明確選擇並標示來源。

目前沒有自動化 design-system build；實測證據記錄於 [docs/testing-and-evidence.md](../docs/testing-and-evidence.md)。
