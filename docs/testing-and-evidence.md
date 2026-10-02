# 測試與證據

## 公開團隊、素材來源與行情顯名（2026-10-03）

分類：上架資料釐清與既有行情授權聲明補齊，不改 API／資料庫或投資計算。

- 使用者確認公開營運名稱「FutureMint AI 團隊」、原角色為團隊使用 ChatGPT 生成。ASC 版權已保存為 `2026 FutureMint AI 團隊`；本機忽略的 App 公開配置已更新，`validate_release_config.dart` 通過。線上 API 的營運名稱仍待同步，不能以本機配置冒充部署完成。
- 已核對 OpenAI 輸出權利條款與政府資料開放平臺 TWSE 個股日成交資料集 11549。投資練習場來源區新增「行情資料授權」標準對話框，包含提供機關、資料集、年份、授權連結及非背書說明。
- `flutter analyze --no-pub lib test` 無問題；`flutter test --no-pub test/features/investment_lab_screen_test.dart` 3／3 通過，含 200% 字級與虛擬買賣既有回歸。最初全目錄 analyze 另讀入被忽略的舊 `output/guardian_preview.dart`，有 3 項缺少 override 的提示；未改動該暫存預覽檔。
- iPhone simulator debug build 成功（Xcode 21.0 秒）；iPhone 17 Pro Max／iOS 26.4 訪客實際操作確認授權入口、完整對話框及關閉返回均正常。沒有執行真實下單、登入帳號或呼叫 AI；正式 signed archive 仍未執行。
- Xcode 已登入正確團隊，建立憑證選項載入後可用；本機仍為 0 valid identities，網站可見既有雲端管理的 Distribution 憑證。尚未新增或撤銷憑證，等待新增簽章能力的確認。
- 使用者確認原角色無未授權的第三方參考素材，並明確授權內容權利聲明；ASC 已保存，重新載入驗證保留。App Privacy 與年齡問卷仍未完成；來源查核不能代替未確認的 AI 供應商用途。商店狀態仍為準備提交。

## 上架接續與簽章配置（2026-10-03）

分類：已核准的 iPhone 發布配置與上架現況更新。Runner Debug／Profile／Release 設定 `CODE_SIGN_STYLE=Automatic` 與已確認的 Team；沒有修改功能或資料流程。

- `plutil -lint app/ios/Runner.xcodeproj/project.pbxproj` 通過；`xcodebuild -showBuildSettings` 確認 Automatic、Team、bundle `tw.futuremint.futuremintApp` 及 `TARGETED_DEVICE_FAMILY=1`。沒有執行 signed build 或產生憑證。
- Xcode Apple Accounts 當時為空；已開啟 Apple Account 登入視窗，等待帳號持有人直接登入及雙重驗證。有效 signing identity 仍未取得。
- 六張商店截圖上傳及重新載入驗證完成，見下節。App Privacy／年齡問卷尚未保存或發布；App 仍是準備提交。
- 本次不涉及 Dart／API 行為，未重跑完整功能測試；以 Xcode 配置解析及實際 ASC 上傳驗證本次改動。原截圖提交 `964b385` 的 API、Flutter、iOS unsigned archive、Docker 及秘密掃描 CI 均成功；不能將該結果當作後續簽章配置的 signed archive 驗收。

## iPhone 商店截圖準備（2026-10-03）

分類：使用者核准的上架素材製作與現況釐清；沒有變更 App 程式或介面。

- 從 `55d030f` 一般 App 入口執行 `flutter build ios --simulator --debug --no-pub`，帶入已忽略的公開 production defines；Xcode build 25.8 秒成功，實際 Info.plist 為 1.0.0(1)、`tw.futuremint.futuremintApp`、`UIDeviceFamily=[1]`。
- iPhone 17 Pro Max／iOS 26.4 實際啟動訪客模式，操作預算首頁、收支分析、記帳草稿、訂閱追蹤、學習路線及 FutureSeed 教育試算。六張 1320×2868 素材位於 [design/app-store](../design/app-store/README.md)，JPEG 無 alpha，未修改 UI 或使用真實帳號資料。
- 起初模擬器因磁碟空間不足無法安裝；只清理本專案可再生的 Android intermediates 與 Flutter build cache，保留原始碼及成品。重新啟動截圖用模擬器後成功安裝／操作。
- 公開 production `GET /api/service-policy` 現在回報 `tw-service-age-15-in-app-v2`、`guardianConsentMethod=in-app`、privacy `2026-10-03-in-app-guardian-v2`、mail disabled／registration enabled／email verification disabled。此為公開能力的現況確認，未直接驗證 migration 012 或新監護人寫入交易。
- 簽章仍為 0 valid identities；本輪尚無 signed archive／IPA、TestFlight 或正式送審。原生 iPhone target 不代表完全排除 iPad 相容模式。
- ASC 六張截圖已透過 Chrome 原生選檔器上傳，重新載入確認六張及 6.5 吋沿用 6.9 吋設定。App Privacy、年齡問卷、插圖權利、AI 上游資料用途與公開營運者仍需完成。

本輪只新增素材與文件，未重跑既有 200 Flutter／210 backend 測試；程式與先前測試狀態相同。遠端 main 規則要求 PR、一位 reviewer 及最後 push 的他人核准；以 PR 交付，不能用帳號 bypass 取代審查。

## App 內監護人確認與上架準備（2026-10-03）

分類：使用者核准的流程簡化、首次上架資料準備。保留孩子／家長角色與 Email／密碼登入；15–17 歲改由監護人在孩子裝置勾選確認，沒有監護人 Email 或寄信依賴。勾選不是身分驗證，家庭分享與 AI 同意仍分開。新政策 `tw-service-age-15-in-app-v2` 要求舊帳號依原 age band 重聲明，不能改成年。

| 本輪驗證 | 結果與界線 |
|---|---|
| Flutter | `flutter analyze --no-pub` 無問題；`flutter test --no-pub` **200／200** 通過。新增 API body 與 widget 回歸確認未預勾選、勾選後送出、沒有 guardian email、未自動啟用 AI，375×812／100% 與 200% 字級通過 |
| Backend Node 22 | `npm --prefix backend test` **210 通過、24 跳過**；typecheck／build 通過。含本人 session、嚴格欄位驗證、舊 policy／age band、冪等、撤回後重同意、舊 AI 不復活及 SQL 欄位映射 |
| PostgreSQL 限制 | 3 個整合 suite 共 24 tests 因未提供本機測試資料庫而跳過。Docker 查詢未取得可用服務；migration 012 尚未在真實 DB 執行，SQL 映射單元測試不能取代 migration 驗收 |
| 發布檢查 | Python readiness **15／15** 通過；disabled mail＋verification=false 可接受，但舊 policy 或沒有 in-app capability 會阻擋。先前 packaging **1／1** 與 shell syntax 通過；本輪未改 packaging shell |
| 畫面檢查 | 本機 Flutter Web 合成資格畫面、375×812 深色實際截圖確認文字與操作可讀，未勾選時主要按鈕停用。預覽不連正式 API；不代表真機或正式新帳號驗收 |
| 獨立唯讀審查 | 核對本人 session、transaction／account lock、跨帳號隔離、同意 revision、舊 policy、Flutter 路由及 release gate，未發現阻擋合併問題 |
| Apple | 帳號持有人完成協議後，註冊 `tw.futuremint.futuremintApp`，建立 App record `6818587553`。繁中描述／關鍵字／副標題、教育＋財經分類、審查帳密與依使用者指示沿用的聯絡人已保存；版本 1.0.0、手動發佈、免費／臺灣1地供應、Mac／Vision Pro 不供應已驗證。仍是準備提交，沒有 build 或送審 |
| 簽章 | Xcode build settings 為 1.0.0(1)、iPhone family1／iOS13，未套用 Team；`security find-identity -v -p codesigning` 為 0 valid identities。沒有可上傳 IPA／matching archive |

Flutter 日誌：`/tmp/futuremint-in-app-guardian-analyze.log`、`/tmp/futuremint-in-app-guardian-all-tests.log`。本機合成畫面預覽在忽略的 output 目錄；release 配置同樣被忽略且權限 0600，只含公開值，不含審查密碼。帳密與私人審查聯絡資訊不寫入 repository。

本輪開始時的正式 API 檢查：health／hosted／postgres、双語 privacy／support 及公開聯絡資訊可讀；mail disabled、不要求 Email 驗證，當時舊 readiness 因 SMTP gate 失敗。審查帳號 login／me／eligibility／profile／dashboard／subscriptions／education/catalog／logout 均 HTTP200，成年、eligible、canWrite、profileComplete；兩次均登出，未改業務資料或呼叫 AI。Python 預設 User-Agent 曾收到403，使用 release-readiness User-Agent 後200，不據此推論原生連線驗收。

目前 AI 公開 `reviewed=true` 說明仍明載上游名單、保存、訓練、地區與刪除方式的資訊缺口；格式檢查不等於正式條款查核。正式營運者目前仍為 Student Team，與版權需另確認。新版後端、migration012、runtime policy overrides、已簽章 App、新版審查帳號、商店截圖、App Privacy／年齡問卷與真機通知仍待完成；Git 同步不等同 backend 部署或 Apple 發布。

## iPhone／Android 本機提醒補齊與權限恢復（2026-10-02）

分類：iPhone 權限恢復與帳號切換缺陷修正、使用者核准的 Android 本機提醒新能力。首次啟用才要求通知權限；iPhone 拒絕後不會再次彈出系統授權，提供「開啟通知設定」。Android 13+ 明確操作可在系統允許時重試；永久拒絕、App／通知頻道關閉時從設定恢復。返回 App 後離線重新讀取權限；首次拒絕不保存啟用偏好，允許後需再啟用。Android 使用非精準 AlarmManager 與通知頻道，不要求 exact-alarm／電池豁免，開機／App 更新恢復有效排程。

帳號 bind 立即取消未完成的權限結果與舊提醒，後續操作等待清理；舊 generation／controller 不得將舊帳號的訂閱排到新帳號。Android 通知點擊及 receiver 驗證 owner／隨機綁定 token；iOS 前景通知只接受目前 owner。通知正文維持一般文字，不含名稱或金額。Android 啟用提醒能力後，JSON 原生分享入口仍只在有實作的 iOS 顯示。

| 最終本機驗證 | 結果與界線 |
|---|---|
| `flutter test --no-pub` | **197／197 通過**，含拒絕 → 開啟設定 → 返回 → 再啟用、375dp／200% 字級、離線權限刷新、權限／狀態延遲回覆、登出不等待視窗及舊 controller 不能跨帳號同步 |
| `flutter analyze --no-pub` | No issues found；最終 Dart 相關 6 檔 **65／65** 定向回歸通過 |
| Android `:app:testDebugUnitTest` | **8／8 通過**：UTC／裝置時區、非法／過去日期、最早 60 筆／ID 去重、首次拒絕／重試／永久拒絕、owner／generation／token／權限隔離 |
| Android debug APK | 最終 `flutter build apk --debug --no-pub` 成功；使用既有公開 API／政策設定。已有 secure_storage 對 compileSdk 37 的警告仍存在，未升級依賴或改 AGP |
| iPhone simulator debug build | 最終 `flutter build ios --debug --simulator --no-pub` 成功（14.0 秒）；重新安裝並恢復既有登入及合成資料 |
| iPhone 17／iOS 26.4 實際操作 | 看見共用提醒開關、拒絕原因及設定按鈕；按鈕開啟系統設定，返回時仍正確呈現拒絕。此模擬器設定沒有可調整的 FutureMint 通知選項，尚未實際恢復授權或驗證送達 |
| iOS XCTest | 已嘗試 `xcodebuild test ... -only-testing:RunnerTests CODE_SIGNING_ALLOWED=NO`，測試 host 安裝失敗（IXErrorDomain 2／Failed to create IXPlaceholder），**未執行**，不能算通過；其後重新啟動同一模擬器並安裝一般 App 成功 |
| 獨立唯讀 review | 找到舊 controller 在權限回覆後同步新帳號的問題；已加 binding／owner／disposed 檢查及回歸，最終全套通過。Android 明確重試為已選定的平台行為 |

日誌：`/tmp/futuremint-reminders-all-tests.log`、`/tmp/futuremint-reminders-final-tests.log`、`/tmp/futuremint-reminders-analyze.log`、`/tmp/futuremint-reminders-ios-build.log`、`/tmp/futuremint-reminders-ios-tests.log`、`/tmp/futuremint-reminders-android-build.log`；Android JUnit XML 位於 `app/build/app/test-results/testDebugUnitTest/`。

同步根／Client README、Product Spec／Overview、Architecture、Data／Security、Design README／MASTER、Demo／Competition。本輪沒有 API 或資料庫 schema 變更、新遠端通知服務、commit、push、部署或商店發布。Android 無已連線裝置，通知授權視窗、實際送達、點擊／冷啟動及重開機恢復仍待裝置驗收；iPhone 真機權限恢復與送達亦未完成。編譯／unit／widget tests 不代表 production 或商店驗收。

## AI 資料說明閱讀排版（2026-10-02）

分類：使用者核准的局部 UI 調整。`showAiConsentDisclosure` 分為供應商、傳送內容、啟用狀態及個人選擇四段，內文行高 1.5、段落間 24dp、段內間隔 8dp；供應商／接收方／模型分行。完整同意版本收進「詳細資訊」，隱私及支援連結靠左對齊正文，底部操作獨立於可捲動內文。原資料用途、選擇及啟用條件維持，沒有變更後端、授權或供應商設定。

| 本輪驗證 | 實際結果 |
|---|---|
| `flutter test --no-pub test/features/ai_disclosure_layout_test.dart test/features/settings_transparency_test.dart test/features/ai_notice_layout_test.dart` | 16／16 通過；375×812、亮／暗 × 100%／200% 字級可捲至各段及完整版本，連結左對齊及 48dp 高度正常，缺政策／未確認仍禁止啟用；既有同意失敗、取消及提示卡回歸通過 |
| `flutter analyze --no-pub lib/features/settings/settings_sheet.dart test/features/ai_disclosure_layout_test.dart` | No issues found |
| 兩個本輪 Dart 檔格式檢查 | 0 changed |
| iPhone 17／iOS 26.4 模擬器 | 一般入口 debug build 10.3 秒完成，既有登入與資料保留；實際開啟四段說明、向下捲動、連結對齊及版本展開皆確認，當前未核准政策的啟用按鈕維持停用 |

日誌：`/tmp/futuremint-disclosure-layout-tests.log`、`/tmp/futuremint-disclosure-layout-analyze.log`、`/tmp/futuremint-disclosure-layout-run.log`。同頁亮／暗及 200% 字級由 widget tests 驗證；本輪未重跑全套測試或變更同意，沒有呼叫真實 AI、commit、push 或遠端部署。同步根／Client README、Design README／MASTER、Demo 與競賽說明；資料、安全、API 及部署契約維持。

## 已登入 iPhone 實際操作與缺陷修正（2026-10-02）

分類：使用者核准的 AI 提示排版調整、實際操作測試與缺陷修正。使用使用者已登入、明示可操作的測試帳號，在 iPhone 17／iOS 26.4 模擬器的一般 `lib/main.dart` 入口連接既有 API；輸入皆為合成收支、訂閱與虛擬訂單。下列結果補充前輪只檢查首次設定、未送出表單的紀錄，不代表真機或 App Store 驗收。

| 功能 | 實際操作結果 |
|---|---|
| 首次設定、首頁及保存 | 空表單阻擋保存；完成孩子角色、月預算 3,000、目標 6,000／2026-12-31。模擬器重新啟動與 App 重新開啟後，登入、預算、紀錄及訂閱仍存在。後續編輯目標已存 600，首頁進度 10%／還差 5,400 |
| 手動收支、分類與分帳 | 支出 75 編輯為 `QA DRINK` 90／需要；另新增收入 1,500。`QA SPLIT` 390、4 人分帳的個人負擔保存為 98。紀錄篩選、需要 90／想要 98／未分類 1,200、已分類想要占比 52% 正確；最終月支出 1,388、剩餘 1,612。紀錄永久刪除只驗證確認與取消，未刪除 |
| 訂閱與提醒中心 | 新增月訂閱 120、不建立初次付款，編輯為 240；新增年訂閱 1,200 並建立一筆 1,200 的付款。月負擔為 340，停止月訂閱追蹤後為 100；付款未重複。合成方案比較與資格提示、提醒中心及跳至訂閱頁正常 |
| 學習與服務協助 | 固定教材可在 AI 未啟用時閱讀、答題並顯示下一步；使用步驟與腳本式服務諮詢可開啟。只驗證當次教材答題，未驗證課程進度跨裝置保存 |
| FutureSeed | 從零開始：每月 300、3 年、本金 10,800；低／中／高波動情境分別顯示期末 11,054／11,934／13,493，最大回落 0%／2.4%／8.6%，結果自動捲入可見區。皆為合成教育路徑 |
| 投資練習場 | 虛擬資金不足及無持股賣出被阻擋。0050 虛擬買入 2 股、賣出 1 股，以及修正後再次買入 1 股成功；最後現金 791、持有市值 226、總資產 1,017。新增成交回饋卡實際顯示單價 112.90、資料日 2026-10-01、金額 113。市場事件骰子返回教育情境；未啟用 AI 時點說明會要求查看用途，未呼叫第三方 AI |
| 設定、匯出與公開頁 | 預算 3,000→3,500→3,000、已存目標 600 保存，欄位仍有焦點時關閉亦正常。JSON 匯出顯示 API 結果並打開約 5 KB JSON 的 iOS 分享面板，隨後取消；未傳送資料、未驗證下載檔案內容。隱私及支援頁在模擬器 Safari 載入；亮／暗主題可切換，結束時回復系統主題 |
| 通知、家庭及帳號門檻 | 拒絕 iOS 通知權限後，提醒保持關閉，設定顯示重新開啟的路徑。空家庭邀請碼要求完整 24 碼。刪除帳號彈窗要求密碼與確切確認文字，空值禁止提交，焦點後取消可正常返回；未刪除帳號 |

修正與根因：

- 原黃色全寬 AI 提示改為有頁面留白的淡紫資訊卡，標題／補充文字分層，資料用途入口維持至少 48dp；窄畫面及放大字級改為上下排列。亮／暗主題已在模擬器確認，200% 字級由 widget tests 覆蓋。
- 訂閱保存後空白、紀錄頁 layout assertion，以及預算保存後 `TextEditingController was used after being disposed`，均由彈窗退場動畫尚未結束就釋放欄位 controller 引起。改由彈窗 State 真正卸載時釋放；新增、編輯、空值驗證後保存及有焦點取消已回歸。帳號刪除彈窗採同一生命週期修正。
- 虛擬訂單原文承諾畫面價格，但伺服器行情更新會改變執行價格。改為預估說明並在操作區呈現新訂單的實際金額／單價／資料日；價格、日期或來源改變時標示行情更新。既有 API／伺服器價格計算維持，重試既有訂單或失敗不顯示新的成功卡。
- 通知遭拒時增加設定內的恢復說明，避免僅看見開關回到關閉。

| 最終本機驗證 | 結果 |
|---|---|
| `flutter test --no-pub` | 185／185 通過，包含訂閱與設定彈窗生命週期、行情更新／失敗回饋、通知拒絕說明及 AI 提示的亮／暗與 200% 字級 |
| `flutter analyze --no-pub` | No issues found |
| `dart --suppress-analytics format --output=none --set-exit-if-changed lib test integration_test` | 77 files、0 changed |
| iPhone 17 debug | 一般 App build 成功，修正後熱重啟／熱重載及上述實際流程正常；原例外已另以回歸測試重現並驗證修正 |

日誌為本機暫存檔：`/tmp/futuremint-simulator-qa-final-all-tests.log`、`/tmp/futuremint-simulator-qa-final-analyze.log`、`/tmp/futuremint-simulator-qa-run.log`。run log 保留修正前的例外；不能把舊例外當作最新熱重載後仍發生。此次沒有 API、資料格式、資格／家庭權限、AI 供應商或同意契約變更；同步 README、Client README、Architecture、Design README／MASTER、Demo 與競賽說明。

剩餘限制：供應商資料處理說明未完成，AI 啟用被阻擋，沒有真實 AI 品質／解析驗收；未執行 SMTP、有效家庭配對及跨帳號分享、本機通知送達、JSON 下載檔案完整性、登出再登入或永久刪除。沒有建立新帳號或修改密碼。測試帳號與合成資料保留，通知權限仍為拒絕。本輪沒有 commit、push、PR、遠端部署、Apple 簽章或上架。

## SMTP 憑證通知查證（2026-10-02）

分類：釐清與測試 fixture 修正。GitGuardian 原始通知的 push 時間為 2026-10-02 00:22:30（Asia/Taipei），通知信於 00:24:02 寄出；寄件網域的 SPF、DKIM、DMARC 通過。通知指向 `d8fe11f900a78b184237291eb6f088b0165ce5c7` 的 `backend/test/config/startupConfig.test.ts`，diff 連結定位至 fixture 起始行 4，SMTP 組合位於原檔行 9。GitHub 原始檔與本機該 commit 一致：帳號及密碼為明示合成值，配上真實 SMTP 主機造成測試憑證通報；未發現此筆通知涉及真實供應商秘密。

查證範圍為本機所有 refs 可達的 36 個 commits 內 SMTP 變數與文字設定；唯讀 `git ls-remote` 確認遠端 4 個 branch heads 都與本機 tracking refs 一致、沒有 tag。具體 SMTP 帳密組合僅出現在兩個測試檔且皆為合成值，環境範本帳密為空。本機根目錄及 backend 均無 `.env`；未讀取 production／Coolify secrets、未嘗試用測試憑證登入 SMTP。此查證不涵蓋 GitHub 已刪除 refs、fork、PR 隱藏 refs、外部快取或 production 的真實設定。

兩個 SMTP fixtures 的 host 統一為 `smtp.example.invalid`，保留合成帳密及既有公開 URL 驗證條件。`validateStartupConfig`／`validateMailerConfig` 不建立 transport；寄信測試 mock `nodemailer.createTransport`／`sendMail`，不寄信或連外。只改測試及安全／證據文件，production runtime 行為不變。

| 驗證 | 實際結果 |
|---|---|
| Node.js 22.22.3：`npm test -- test/config/startupConfig.test.ts test/auth/accountMailer.test.ts` | 2 files、7 tests 通過 |
| Node.js 22.22.3：`npm run typecheck` | 通過 |
| `git diff --check` | 通過 |

判定此筆為合成測試憑證誤報，沒有因這筆通知輪替正式憑證或重寫歷史。GitGuardian 線上標記仍未完成，需由有權限的帳號登入後標記為測試憑證並確認結果。本節只記錄本機查證與修正；沒有 commit、push、PR 或部署。

## iPhone 逐頁排版優化（2026-10-02）

分類：已核准範圍內的 UI 調整與缺陷修正。沿用既有品牌與插圖，調整首次設定／資格等待／Email 驗證的表單、支援及帳號分區；記帳生成草稿後收起鍵盤並捲至確認表單，下一筆輸入在後；手動草稿移除不適用的解析信心與 AI 建議文案；FutureSeed 控制與結果優先於投資練習入口，手機試算成功後直接捲至結果。另整理訂閱表單間距、設定支援入口，修復預算編輯彈窗因 intrinsic layout 失敗而空白，以及提醒卡在大字級下橫向溢位。

| 驗證 | 本輪結果 |
|---|---|
| `flutter analyze --no-pub` | No issues found |
| `flutter test --no-pub` | 162 tests 全數通過；後續增加 FutureSeed 試算結果可見位置檢查，重跑受影響的 FutureSeed／手機版面 10 tests 全數通過。包含首次設定日期操作與分區、草稿可見位置及確認前不保存、FutureSeed 控制優先、亮／暗主題手機版面、200% 字級提醒／訂閱／投資頁及預算彈窗實際開啟與取消 |
| `dart --suppress-analytics format --output=none --set-exit-if-changed lib test integration_test` | 74 files，0 changed |
| iPhone 17／iOS 26.4 模擬器 | debug build 成功；巡檢首頁、紀錄、記一筆與手動草稿、學習與陪讀、FutureSeed 與投資練習場、通知、訂閱編輯、設定、預算編輯、使用導覽／客服，以及合成登入／註冊／首次設定／資格聲明／Email 驗證狀態。已確認草稿前置與手動文案、首次設定日期高度、資格／Email 驗證分區、訂閱間距、預算彈窗恢復，以及亮／暗 FutureSeed 排列與深色試算結果自動顯示 |
| 一般 App 入口恢復 | 從既有 FutureMint 公開頁分頁確認服務 origin，唯讀 `/api/health` 回應 `status=ok`。用 `lib/main.dart` 及暫存的公開網址設定重新 debug build（21.3 秒），恢復原登入的首次設定狀態；日期選擇開啟／取消正常，未提交表單 |

畫面預覽使用記憶體合成資料與注入的測試帳號狀態，不保存真實帳號資料、不執行真實 AI／寄信／刪除。Mac 解鎖後已補驗手動草稿文案、首次設定日期高度及資格頁；另用深色訪客預覽確認首頁與 FutureSeed 試算結果。200% 字級結果來自 widget tests。家庭、AI 同意、所有錯誤及帳號狀態未逐一原生操作，真機與正式帳號寫入等完整流程仍待驗收。

同步根／Client README、產品規格、專案概覽、Design README／MASTER、Demo 腳本與競賽證據說明。未修改 API、資料契約、權限或財務計算。本段只記錄本機畫面與 Flutter 驗證結果；commit、push、部署、正式簽章及 App Store 狀態以對應 Git 與發佈檢查紀錄為準。下方歷史結果各自對應原驗證狀態。

## 公開頁 App icon（2026-10-02）

分類：使用者核准的品牌圖示替換。公開頁共用 header 改用 iPhone 的金幣嫩芽圖示；部署副本與 iOS 120px catalog SHA-256 一致，顯示版位維持 40px。新增同源 `/app-icon.png` 與 CSP `img-src self`，build 同時複製 public 資產至 dist，Docker build context 包含 public。

已執行 `npm run build`、`git diff --check` 及本機公開頁畫面檢查；圖片 complete=true、naturalWidth/naturalHeight=120，正常顯示。沒有新增或執行自動化測試，沒有環境變數或資料庫變更。API README、根 README、部署文件及設計規範同步；線上生效以此版本的 deployment 與圖片載入另外確認。

## 免寄信帳號與雙語公開頁（2026-10-02）

分類：使用者核准的帳號流程與公開頁調整，並包含前述年齡選單／密碼確認修正。SMTP disabled 時 runtime 開放註冊／登入且不要求 Email 驗證；帳號保持未驗證，新的寄信端點回 `mail_disabled`。啟用寄信後，重設僅寄已驗證信箱，未知／未驗證信箱仍使用相同 accepted 回應。最低年齡、15–17 歲監護人門檻與 AI 同意維持；免寄信監護人確認管道尚未新增。

Client 讀取三項公開帳號能力並顯示停用寄信、保管密碼、未成年人待同意狀態。公開政策／支援頁使用 App 的色彩與圓角，提供繁中／英文、明暗主題，並描述實際資料、AI、保存、刪除及支援邊界。預設政策版本 `2026-10-02-optional-mail-v1`；已有 runtime 舊版本需同步，版本變動使 AI 需重新同意。

已執行：受影響 Dart 格式化及四檔 `flutter analyze --no-pub` 無問題；backend `npm run typecheck` 與 `npm run build` 通過。公開頁在本機使用明示的合成營運資訊、停用 mail／未啟用 AI 的 preview，桌面與 390×844 手機畫面確認可閱讀；繁中→English、明暗切換及支援連結可用。preview 未連 PostgreSQL、正式 AI 或 SMTP。iPhone 17／iOS 26.4 debug build 10.1 秒完成並安裝啟動；仍使用既有公開 API 網址。這些結果不代表線上帳號、寄信、AI 或 App Store 已驗收。

沒有新增或執行自動化測試；既有 recovery fixture 僅配合已驗證信箱契約更新。正式成年註冊／儲存／登入／刪除、未成年人受限寫入及重新啟用 SMTP 仍待實際流程驗收。Git／Coolify 發布以實際 commit 及 deployment 結果獨立確認，下方歷史「無 SMTP 不開放註冊」已由本節行為取代。

## 註冊年齡選單與密碼確認（2026-10-01）

分類：年齡選單浮動標籤的缺陷修正，以及使用者核准的密碼規則／確認欄位調整。註冊及資格確認選單改為欄位外標題；App 註冊新增確認密碼並阻擋空白或不一致，修改原密碼時會重查已有確認值。Client 註冊、API 共用 credentials schema 及公開重設頁面同步為 8–128 字元、英文字母與數字。確認值只在 Client 比對，不傳送或保存。

已執行：兩個受影響 Dart 檔案格式化；`flutter analyze --no-pub lib/features/auth/auth_screen.dart lib/features/auth/eligibility_screen.dart` 無問題；API `npm run build` 通過；`git diff --check` 通過。iPhone 17／iOS 26.4 模擬器 debug build（11.8 秒）與註冊畫面確認新規則及確認欄位可見、年齡選單可展開且選定值沒有浮動標籤；滑動後按鈕與公開連結可見。僅選擇本機表單選項，沒有送出年齡聲明或建立正式帳號。runner detach 後保留 App 供使用者查看。

Client／API README、`docs/security-and-privacy.md`、Design README 及 `MASTER.md` 已同步。本輪沒有新增或執行自動化測試，尚未驗證真機、大字級、實際註冊／密碼重設與 SMTP 寄送；未執行 commit、push 或遠端部署。線上 API 的新規則需發布此版本並重新部署才會生效。

## 學習路線構圖微調（2026-10-01，最新指示）

後續依使用者要求再整組上移 8dp：標題與角色／裝飾區的間距由 12dp 收至 4dp，角色大小、左右位置及貼邊錨點維持一致。靜態分析與格式檢查通過；iPhone 17 模擬器重新 build（14.2 秒），訪客學習頁已確認更新。`MASTER.md` 同步最新間距；此單一間距微調未執行單元測試或重新驗證其他裝置。

分類：使用者核准的局部視覺調整，取代下方上一版的額外紫色橫線。移除橫線與獨立裝飾列；角色由 128／156dp 縮至 112／136dp，左移讓出右側 52dp 裝飾列及 12dp 間距。兩個圓與一個菱形可見範圍均為 12dp，相鄰間距均為 8dp；菱形旋轉前按 sqrt(2) 縮小，避免可見邊界變大。標題下方間距由 24dp 縮至 12dp，頭部右側裝飾與角色共用卡片局部定位，整體區塊向上收。

已執行：兩個受影響 Dart 檔案格式化（無額外格式變動）、`flutter analyze --no-pub lib/features/learning/learning_screen.dart`（No issues found）、`git diff --check`，以及 iPhone 17／iOS 26.4 模擬器 debug build（16.4 秒）。訪客學習頁截圖確認紫線移除、角色縮小左移、裝飾等距且位於頭部右側，標題可讀。設計及 Client README 已同步；既有定位測試移除已不存在的橫線期待，沒有新增或執行單元測試。

此微調未重新執行上一版的四種 Web 寬度檢查；保留以卡片局部座標及縮放錨點定位的實作。未執行真機／深色／大字級驗收、Git commit／push 或遠端部署。

## 學習路線角色貼邊（2026-10-01）

分類：使用者核准的局部視覺調整。角色位於學習路線卡片右上方，透明 PNG 的水平身體底緣與卡片上邊界共用縮放錨點；卡片上界加上 2dp 橫線，頭部與雙手預留空間，不遮住標題。對應來源、提示與定位規則同步於 `design/README.md`、`MASTER.md` 及 `app/README.md`。

已執行：`dart format lib/features/learning/learning_screen.dart`、`flutter analyze lib/features/learning/learning_screen.dart`（No issues found）、`git diff --check`；iPhone 17／iOS 26.4 模擬器 debug build（15.1 秒）與訪客學習頁截圖；本機 Flutter Web 預覽 375×812、768×1024、1024×768、1440×900 均確認角色底緣貼齊卡片橫線且標題可讀。375px 初次截圖時角色圖片仍在載入，載入完成後再次確認正常。檢查未呼叫外部 AI，也未建立正式帳號或寫入後端資料。

既有 `learning_and_subscription_test.dart` 的定位預期同步為新底緣錨點，沒有新增或執行單元測試。尚未驗證此調整在真機、其他作業系統與 200% 字級／深色主題的實際呈現；Git commit／push 與遠端部署未執行。

## iPhone icon 更新（2026-10-01）

分類：已核准視覺資產調整。內建 imagegen 產生靛紫背景、金幣與嫩芽原稿，保存於 `design/futuremint-ai/assets/app-icon.png`；`app/tool/generate_ios_icons.py` 使用 macOS sips 重建現有 iOS catalog 的 15 個唯一 PNG。

已執行：檢查 catalog 全部 19 項的 PNG 尺寸與不透明背景；`git diff --check` 通過；以前一輪公開 production Dart defines 執行 `flutter run --debug`，iPhone 17／iOS 26.4 模擬器 Xcode build 27.8 秒完成，App 安裝與登入畫面啟動成功。回到系統主畫面截圖確認 FutureMint AI 顯示新圖示，runner detach 後保留安裝的 App。建置仍出現既有 `native_assets` SdkRoot 提示，但未阻止此輪建置及啟動。

未執行：單元測試、真機／App Store 圖示驗收、Git commit／push、後端重新部署。此次僅替換 iOS icon，App 內畫面與 API 功能沒有變更；模擬器成功不代表正式簽章或上架驗收完成。

## 本輪簡化部署（2026-10-01）

分類：已核准範圍調整。正式只需API／PostgreSQL，Web選用；可選SMTP、備份0、內建通用政策、供應商說明未完成時只停用外部AI。沒有新增migration、不修改前端UIUX。

已執行：backend的npm run typecheck與npm run build，以及git diff --check通過。本輪只更新既有設定測試的預期以符合新契約，沒有新增或執行測試；下方歷史測試／跨元件結果不代表本輪新分支已通過回歸。編譯不證明disabled寄信／註冊、政策門檻或正式連線已實際驗收。

未執行：Coolify設定／部署、Git commit／push、SMTP寄送、正式AI、Apple簽章／上傳／送審。無SMTP時無新註冊，未完成供應商說明時無外部AI；現有驗證／年齡／監護人門檻仍維持。使用者選擇不建立定期資料庫備份，既有journal及資料卷保留。

## 上一輪正式產品整合證據（2026-10-01，簡化設定前）

分類：新能力、缺陷修正與釐清。下方歷史測試數量僅對應各自日期／狀態。基線 `af7a5df` 的 GitHub CI 已確認成功：122 API tests、121 Flutter tests、未簽章 iOS 與 Web／API images；本輪新變更尚未跑遠端 CI，最新本機驗證結果需按本輪實際指令記錄。

使用者確認既有 Coolify 三 Resources 曾成功部署；目前 live health、DNS／TLS、runtime 設定與完整使用者流程尚未在本輪驗證。本次程式變更需由使用者自行重新部署並驗收。

本輪已覆蓋訂閱同交易／完整 payload 重試、舊付款採用、分頁全量統計、owner 隔離、臺灣年齡／監護人 token／撤回、provider fingerprint 再授權／雙供應商 gate、共享 AI 額度／lease、preflight 先於 migration、DATE／近零複利、虛擬執行順序及家庭捕獲成員變動 409。Client 本機測試另覆蓋手動流程／同 key retry、所有 onboarding 退出／刪除／help/retry、iPhone 提醒 permission／時區／清除／resume。測試通過只能證明被測的本機狀態；未使用真實 provider key。

未驗收：SMTP／domain／正式 AI 條款與品質、日後啟用備份時的隔離還原／刪除不復活、Apple Team／signed TestFlight／通知實機、App Privacy／年齡問卷。既有 CI 或未簽章產物不取代這些外部證據。

### 最終本機執行結果（2026-10-01）

| 項目 | 結果及界線 |
|---|---|
| API Node.js 22 | `npm test` 31 files／224 tests 全通過，含 localhost PostgreSQL 17 隔離 schema 整合；`npm run typecheck`、`npm run build` 通過 |
| PostgreSQL | 001–011 migrations 在空白測試 DB 套用成功；舊 001–007 checksum／源檔不變。覆蓋跨 Pool 交易、families、角色、DATE、訂閱採用／重試／owner、資格與 AI 額度。011 對帳測試驗證 preview 無變更、apply 清除已刪帳號及 sessions／profile、保留其他使用者、重跑與非法 journal；沒有執行 production restore |
| 啟動配置 | CLI demo 正例 exit 0；缺 production 設定 exit 1，只列階段及變數名稱；Docker 執行 preflight 後才套 11 migrations／啟動 API |
| Capture evaluation | deterministic-demo 30/30 合成案例、schema 30/30、欄位 225/225，未呼叫真實 AI |
| 依賴稽核 | `npm audit --json` 所有等級 0；修補 Fastify、Nodemailer、fast-uri、Vitest、brace-expansion 相容版本，未做無關 major upgrade。結果對應當下 npm 官方公告 |
| Flutter | `dart format --output=none --set-exit-if-changed lib test integration_test`：73 files／0 changed；`flutter analyze --no-pub`：0 issues；`flutter test --no-pub`：152/152，包含 OpenAI provenance 解析／UI 標籤與拒絕 AI／唯讀的受控教材及本機答題回歸 |
| Swift／Simulator | iPhone simulator debug 編譯成功；`xcodebuild test ... -only-testing:RunnerTests CODE_SIGNING_ALLOWED=NO`：2/2，驗證 Taipei calendar／generic content／account-bound tap。不是實機通知驗收 |
| iPhone unsigned Release | 最終 `bash app/tool/build_ios_validation.sh` 通過；31.0 MB，`UIDeviceFamily=[1]`、SDK `iphoneos26.4`、bundle `tw.futuremint.futuremintApp`、1.0.0（1）、4 privacy manifests、無 integration_test framework。未簽章、不作 App Store 產物 |
| Docker API／Web | 最終兩個 images 本機建置成功；Web 使用 BUILD_ENV=validation，Flutter Web Release／Wasm dry run 成功；Nginx 首頁／deep links 200、no-store。未推送 images、未驗證遠端平台 |
| 實際跨元件契約 | 用 App 實際 Dart `AuthApi`／`ApiRepository` 對 localhost Docker API＋PostgreSQL：年齡聲明、service policy、UTF-8 受控教材、訂閱＋初次付款同 key 重試、commitment、付款連結、分頁、JSON 匯出、停用保留付款、刪除帳號通過。不是 SMTP／真實 AI／production 驗收 |
| 安全與審查 | 全部非忽略文字檔高信心 private key／token／webhook patterns 0 命中；未讀真實 `.env` 或掃完整 history。`git diff --check` 通過。獨立來源審查發現的付款連結、partial refresh、resume retry、唯讀刪除與 restore URL 問題已修正／複驗 |

日誌：`/tmp/futuremint-launch-backend-tests.log`、`/tmp/client-tests.log`、`/tmp/client-analyze.log`、`/tmp/client-native-tests.log`、`/tmp/futuremint-launch-ios-release.log`、`/tmp/futuremint-launch-api-docker.log`、`/tmp/futuremint-launch-web-docker.log`。最終 iPhone artifact：`app/build/release-ios/futuremint-ios.Vl8A1H/iphoneos/Runner.app`；均為忽略的本機產物。

本輪專用 API、Web、PostgreSQL 測試容器及匿名測試 volume 已清除；其他容器／資料卷未變更。當前工作在 `main`，本輪程式／文件未 commit／push，未執行遠端 CI、Coolify 部署、真實 SMTP／AI、Apple 簽章／上傳或送審。

## 2026-09-30 iPhone 手機版 UI 優化驗證

分類：缺陷修正（深色／亮色對比）與已核准範圍內的手機版面調整；不變更資料、API、權限或商業邏輯。工作於 branch `style/mobile-ui-polish`；本次未涉及部署。

| 項目 | 結果與界線 |
|---|---|
| Flutter | `dart format --set-exit-if-changed` 0 changed；`flutter analyze` 0 issues；完整 `flutter test` 121 項通過（新增 `test/features/mobile_layout_test.dart`：375×812 亮／暗 × 1x／2x 字級走過五個主要頁面無溢位，並檢查亮色預算 Hero 使用靛紫表面） |
| 修正的缺陷 | 底部導覽選中項文字在深色膠囊上不可見；亮色主題預算 Hero 為白底白字；深色主題提醒頁圖示與卡片同色不可見；深色下靛紫 kicker、收入金額、圖表第一條線與漲跌色對比不足；200% 字級下紀錄列金額溢位 |
| 版面調整 | 首頁移除重複的訪客說明並讓預算卡進入首屏；首頁／紀錄／記一筆／學習／FutureSeed 的角色插圖在手機改為與標題或內文並排的獨立欄位（仍保留原插圖）；紀錄列重新排版、插圖列移到清單後；草稿表單類型與分類並排、日期欄與輸入框一致；訂閱卡、提醒卡、投資練習場來源列與設定抽屜安全區調整；選中的 chip 以勾選圖示取代重疊的勾勾 |
| iPhone 模擬器實測 | iPhone 17 Pro（iOS 26.4）debug build，訪客模式＋本機 demo API；逐頁截取優化前後畫面（深色為主，另含亮色首頁）。不是實機、VoiceOver 或 App Store 截圖驗收 |

## 2026-09-06 正式產品修正後驗證

以下為本次未提交工作區的實際結果；不覆寫下方歷史證據。分類：缺陷修正、使用者核准的正式產品功能補齊，以及文件狀態釐清。

| 項目 | 結果與界線 |
|---|---|
| Backend Node 22 | 18 test files、122 tests 全通過，包含 8 項隔離 PostgreSQL 17 整合；typecheck／build 通過 |
| PostgreSQL 17 | 7 migrations；隨機 schema 的測試自動清除。涵蓋 family rollback、跨 Pool 角色競態、歷史角色修復、invite hash／到期／更新／停用、跨 instance 超支／idempotency、reset／session 並行與共享限流 |
| 依賴安全 | `npm audit --json`：0 info／low／moderate／high／critical；當下 npm 公告狀態，不代表所有漏洞皆可排除 |
| Capture regression | deterministic-demo 合成案例 30/30、schema 30/30、欄位 225/225；沒有呼叫量界真實模型 |
| Flutter | `flutter analyze` 0 issues；完整 `flutter test` 116 項通過；包含 session epoch、儲存遷移、寄信失敗、主題／繁中、驗證／重設與邀請 UI |
| iPhone unsigned Release | 最終 `build_ios_validation.sh` 通過，30.7 MB；root 檢查 `UIDeviceFamily=[1]`、SDK iphoneos26.4、bundle `tw.futuremint.futuremintApp`、4 個隱私 manifests，無 integration_test framework |
| Web Release | 本機 `BUILD_ENV=validation` Web build 通過，使用 localhost API；不作正式環境驗收 |
| API Docker | `futuremint-api:local-hardening` 本機重建成功，Node 22 image；未推送 |
| Web Docker | `futuremint-web:local-hardening` 以完整 validation args 重建成功；不作正式發布產物 |
| 瀏覽器實際操作 | 390×844 Web 的訪客首頁／設定／亮色切換／記帳確認通過；加入合成支出 75 後可用金額 5377→5302。另檢查恢復頁缺 token 時停用提交；不是原生 iPhone／VoiceOver 驗收 |
| Packaging／配置 | bash syntax、staging isolation Python test、空 env 的 Compose config 與 diff whitespace 檢查通過 |
| 秘密掃描 | 235 個 tracked／untracked 非忽略文字檔的高信心 private-key／token patterns 0 命中；未讀真實 .env，未掃完整 Git history |

測試暫存紀錄：`/tmp/futuremint-backend-final-tests.log`、`/tmp/futuremint-backend-final-audit.json`、`/tmp/futuremint-app-analyze-final.log`、`/tmp/futuremint-app-tests-final.log`、`/tmp/futuremint-ios-validation-final.log`、`/tmp/futuremint-web-final-build.log`、`/tmp/futuremint-api-docker-hardening.log`、`/tmp/futuremint-web-docker-final.log`。iPhone 產物：`app/build/release-ios/futuremint-ios.vahF7U/iphoneos/Runner.app`（未簽章）。這些均是忽略的本機產物，可被系統清理。

正式 SMTP 送達、AI 條款／真實模型、正式 DNS／TLS／DB／備份還原、Apple Team／signed archive／TestFlight／商店截圖與表單均未完成。本次專用 PostgreSQL 合成測試容器、API／靜態測試伺服器及瀏覽器分頁已清理；原有專案資料卷未變更。本次沒有 commit、push、PR、部署或送審。

## 歷史本機驗證

歷史基線驗證日期：2026-08-30（Asia/Taipei）；2026-09-06 修正後證據見下方最新章節。以下只記錄實際執行結果，不代表 Coolify production、量界正式帳號、App Store Connect 或真實未成年人服務驗收。

### App Store P0 本機收斂（2026-08-30，Asia/Taipei）

| 元件 | 指令／操作 | 結果 |
|---|---|---|
| API 帳號刪除／AI 同意 | `cd backend && npm test && npm run typecheck && npm run build` | 15 個 test files、100 tests 通過；含密碼再驗證、session 失效、email 再註冊、家庭 cascade、consent 版本／授權／撤回，以及四個量界 routes 在 provider 呼叫前攔截。 |
| Flutter 同意／撤回／刪除 UI | `cd app && dart format lib test integration_test && flutter analyze && flutter test` | 53 files 格式檢查完成、analyze 0 issues、95 tests 通過；含 HTTP method／body、未同意不呼叫 repository、policy 升版後本機 fail closed、撤回清除 AI state、錯誤密碼保留 session 與雙重確認 UI。 |
| Guest 日期回歸 | 整套 `flutter test` 及固定 clock tests | 合成種子依當前台北年月產生，下次續訂在下月、目標日在未來；不再因日曆跨月讓 dashboard／insights 失真。 |
| App Store 本機設定安全 | `bash -n app/tool/build_ios_release.sh`、`.gitignore` 與 example env 檢查 | 腳本語法通過；會拒絕 localhost／placeholder／非 HTTPS API URL、無效 build number 與 Runner 不一致的 Bundle ID。`.p8`、provisioning profile 與憑證類型已忽略，example 無真實 secret。 |
| iOS unsigned Release | `flutter build ios --release --no-codesign --dart-define=API_BASE_URL=https://api.example.invalid/api/` | Xcode build 通過，產出 29.0 MB `Runner.app`；Bundle ID `tw.futuremint.futuremintApp`、版本 `1.0.0`、build `1`。內嵌 Flutter 與 `shared_preferences_foundation` privacy manifest；Client 只使用系統 HTTPS，`ITSAppUsesNonExemptEncryption=false`。此結果只證明本機可編譯，不代表已簽章或可上傳。 |

本輪沒有對外部 PostgreSQL 執行 `005_ai_consents.sql`，也沒有以真實量界帳號或已簽章 IPA 做 E2E；migration 與 repository SQL 目前只有契約測試。

### 帳務修改與刪除複驗（2026-07-25，Asia/Taipei）

| 元件 | 指令／操作 | 結果 |
|---|---|---|
| API ownership／更新／刪除 | `cd backend && npm test && npm run typecheck && npm run build` | 15 個 test files、90 tests 通過；驗證同帳號可修改／刪除、分帳重新計算，帳號 B 操作帳號 A 的事件一律 404，CORS 預檢允許 `DELETE`。 |
| Flutter guest data 與紀錄 UI | `cd app && flutter test test/widget_test.dart test/data/demo_repository_test.dart && flutter analyze` | 通過；驗證訪客單筆修改／刪除會更新餘額，以及紀錄列操作選單可開啟編輯表單。 |

### 本機量界智算整合複驗（2026-07-25，Asia/Taipei）

以下結果使用已忽略根目錄 `.env` 的 runtime secret；不記錄 key、prompt、完整 provider body 或使用者資料。本輪只驗證本機 Compose，尚未部署或連接 Coolify。

| 元件 | 指令／操作 | 結果 |
|---|---|---|
| Compose API | `docker compose up -d --build --wait api` | API 與 PostgreSQL healthcheck 通過；API 以 `liangjie`／`postgres` runtime pair 啟動。 |
| Runtime health | `GET /api/health` | HTTP 200，回報 `aiProvider=liangjie`、`dataProvider=postgres`。 |
| 實際 AI inference：記帳／陪讀 | API 容器內以合成記帳文字呼叫 capture，再以合成問題呼叫 coach | 兩個請求皆在首次嘗試成功；capture 回傳 1 筆 `liangjie-ai` 草稿，coach 回傳通過既有繁體中文與安全 schema 的 `liangjie-ai` 回覆。 |
| 實際 AI inference：微課／學習規劃 | API 容器內以合成 profile、事件與洞察呼叫 lesson 與 learning plan | 兩個請求皆在首次嘗試成功；lesson 回傳可顯示的繁中選項，learning plan 回傳 4 個不重複主題且恰有 1 個 next module。 |

上述 inference 不寫入資料庫。

### UI 合併修復複驗（2026-07-22，Asia/Taipei）

以下結果針對 `feat/replicate-homepage` 合併到本機工作目錄後的 UI 修復；已建立本機 `main` commit `d876147`，尚未 push 或部署。

| 元件 | 指令／操作 | 結果 |
|---|---|---|
| Flutter format | `dart format --output=none --set-exit-if-changed lib test integration_test` | 52 files，0 changed |
| Flutter analyze | `flutter analyze` | 0 issues |
| Flutter tests | `flutter test` | 74 tests 通過；包含 600dp 高度登入頁的訪客入口可見與可點擊檢查 |
| Flutter Web | `flutter build web --release --dart-define=API_BASE_URL=http://localhost:3000/api/` | 通過 |
| Short viewport visual QA | 本機 Web，375×600 瀏覽器畫面 | 登入標題未被角色圖遮住；訪客按鈕與「資料不會儲存」說明均在首屏可見；登入表單可向下捲動 |

### 全頁 RWD 與文字重疊修正複驗（2026-07-22，Asia/Taipei）

以下結果針對儀表板、記帳、紀錄、學習、FutureSeed、登入／首次設定、設定與底部導覽的 RWD 巡檢；該輪 UI 修復已建立本機 `main` commit `d876147`，尚未 push 或部署。

| 元件 | 指令／操作 | 結果 |
|---|---|---|
| 定位與控制項巡檢 | 逐一檢視所有前端路由的 `Positioned`、負位移與 `SegmentedButton` | 保留學生原有的角色、插圖與星點，並改放入保留版位或內容背景層，避免覆蓋內容；窄寬或 130% 以上字級的長選項改為可換行 chips。 |
| Flutter format | `dart format lib test integration_test` | 完成格式化。 |
| Flutter analyze | `flutter analyze` | 0 issues。 |
| Flutter tests | `flutter test` | 75 tests 通過；新增 375×812、200% 字級的紀錄頁／設定頁測試，以及 Dashboard 角色插圖保持在預算卡內的幾何檢查。 |
| Flutter Web | `flutter build web --release --dart-define=API_BASE_URL=http://localhost:3000/api/` | 通過，產出 `app/build/web`。 |
| 本機預覽快取復原 | `http://127.0.0.1:4173/?reset-cache` | 僅在明確帶入 `reset-cache` 時，解除該 origin 的 Flutter Service Worker 並清除 Cache Storage，接著回到正常網址；用於避免本機 rebuild 後仍執行舊 JavaScript。 |

### Desktop 網頁畫布複驗（2026-07-22，Asia/Taipei）

以下結果針對 signed-in／guest 主流程在寬螢幕瀏覽器不再呈現為置中的狹窄 App；本輪變更尚未建立新的 commit、push 或部署。

| 元件 | 指令／操作 | 結果 |
|---|---|---|
| Desktop canvas geometry | 新增 `ResponsivePageCanvas` 與 1920dp widget test | 寬螢幕 App Shell 使用扣除 264dp 側欄後的完整寬度；紀錄頁交易清單使用該畫布扣除左右 32dp gutter 的完整寬度。 |
| Flutter analyze | `flutter analyze` | 0 issues。 |
| Flutter tests | `flutter test` | 77 tests 通過；包含共用 desktop canvas 與首頁／紀錄頁幾何檢查。 |
| Flutter Web | `flutter build web --release --dart-define=API_BASE_URL=http://localhost:3000/api/` | 通過，產出 `app/build/web`。 |
| Browser visual QA | 本機 Web，1920×1080 | 首頁、紀錄、記一筆、學習與 FutureSeed 皆使用側欄右側完整畫布，保留 32dp gutter；角色插圖未遮住標題、金額、表單或操作。登入、說明與設定彈窗維持聚焦寬度。 |

### 登入／註冊垂直節奏複驗（2026-07-23，Asia/Taipei）

以下結果針對寬螢幕登入／註冊畫面中角色插圖與表單之間的非預期大量空白；本輪變更尚未建立新的 commit、push 或部署。

| 元件 | 指令／操作 | 結果 |
|---|---|---|
| Desktop geometry | 新增登入圖片槽與表單幾何 widget test | 圖片依 4:3 實際高度保留版位；桌面圖片槽與表單距離維持 8–32dp，不再依圖片寬度產生額外空白。 |
| Flutter analyze | `flutter analyze` | 0 issues。 |
| Flutter tests | `flutter test` | 78 tests 通過。 |
| Flutter Web | `flutter build web --release --dart-define=API_BASE_URL=http://localhost:3000/api/` | 通過，產出 `app/build/web`。 |
| Browser visual QA | 本機 Web，1920×1080 | 登入／註冊角色插圖與標題形成緊湊視覺群組，保留閱讀呼吸空間且未互相覆蓋。 |

### 決賽答辯可見證據複驗（2026-07-24，Asia/Taipei）

以下結果針對 AI 主導權、FutureSeed 教育邊界與家庭資料最少揭露的畫面說明；本輪變更尚未建立 commit、push 或部署。

| 元件 | 指令／操作 | 結果 |
|---|---|---|
| AI 草稿主導權 | `capture_screen_test.dart` | 草稿明示可修改所有欄位、確認後才更新分析、修正不會自動訓練 AI；確認前帳務筆數不變。 |
| FutureSeed／資料界線 | `settings_transparency_test.dart` | 設定畫面明示 FutureSeed 是教育模擬、決賽僅用合成資料，以及 AI provider／原文保存邊界。 |
| Flutter analyze | `flutter analyze` | 0 issues。 |
| Flutter tests | `flutter test` | 79 tests 通過。 |
| Flutter Web | `flutter build web --release --dart-define=API_BASE_URL=http://localhost:3000/api/` | 通過，產出 `app/build/web`。 |
| Browser visual QA | 本機 release Web，桌面與 375×812 | 草稿確認、設定抽屜與新說明可完整閱讀；沒有溢位或 console error。 |

| 元件 | 指令／操作 | 結果 |
|---|---|---|
| Fastify API | `npm test` | 15 個 test files、86 tests 通過 |
| Fastify API | `npm run typecheck` | 通過 |
| Fastify API | `npm run build` | 通過 |
| Dependencies | `npm audit --omit=dev` | 0 vulnerabilities |
| Capture evaluation | `npm run evaluate:captures` | 30/30 cases、30/30 schema、225/225 field checks |
| PostgreSQL migration | PostgreSQL 17 Compose 執行 migration | 套用 `001_initial.sql`、`002_roles_and_intents.sql`、`003_investment_lab.sql`、`004_family_accounts.sql`；家庭 groups／members、角色／意圖欄位與兩個虛擬投資 tables 存在 |
| PostgreSQL seed guard | 未設 `ALLOW_DEMO_SEED=true` 執行 seed | 在建立 repository／寫入前拒絕，exit code 1 |
| PostgreSQL synthetic seed | 設安全開關後執行兩次 | 無法登入的 synthetic account／profile／4 events；idempotent，event count 仍為 4 |
| API Docker build | `docker build -t futuremint-api:codex backend` | 通過；Node.js 22 multi-stage image |
| API Docker demo | `AI_PROVIDER=demo`、`DATA_PROVIDER=memory` | Container health 200；沒有要求 `DATABASE_URL` 或執行 migration |
| API Docker + PostgreSQL | `DATA_PROVIDER=postgres` 指向 PostgreSQL 17 | 啟動 migration applied 0、health 200，回報 hosted／postgres |
| Persistence E2E | Container register → profile → event → stop／new container → login → list | 通過；重啟後讀回 1 event |
| Investment persistence E2E | Container register → profile → virtual buy → restart API → login → investment lab | 通過；重啟後讀回 1 order、2 股與正確剩餘現金 |
| TWSE market adapter | 實際呼叫 `/v1/exchangeReport/STOCK_DAY_ALL` 與 `/api/market/quotes` | 取得 5 個內建教學標的、資料日 2026-07-14、`isFallback=false`；另有 timeout／fallback unit test |
| Docker Compose | `docker compose config`、`docker compose up -d --build --wait` | `futuremint_ai` 單一專案群組內 Web／API／PostgreSQL 三服務 healthy；Web 200、API health 200（hosted／demo／postgres） |
| Production fail-fast | 以 production Node image 注入 `demo + memory` | container 在 listen 前退出；unit test 同時驗證 production 只接受 `liangjie + postgres`、HTTPS CORS origin 為必填且合法 |
| Flutter format | `dart format --output=none --set-exit-if-changed lib test integration_test` | 52 files，0 changed |
| Flutter analyze | `flutter analyze` | 0 issues |
| Flutter tests | `flutter test` | 74 tests 通過 |
| Flutter Web | `flutter build web --release --dart-define=API_BASE_URL=...` | 通過 |
| Android debug | `flutter build apk --debug` | 通過，產出 debug APK；尚未進行實機驗收或 signing |
| UX visual QA | Docker Web + in-app Browser（1440×900、375×812、812×375） | 登入／訪客／dashboard 可用，底部導覽與 landscape rail 正常、沒有水平溢位與 console error；已確認新 PWA brand icon 可取得 |
| Frontend Docker build | `docker build --build-arg API_BASE_URL=... -t futuremint-web:codex app` | 通過；固定 Flutter 3.41.9 commit，Nginx runtime image 約 34.4 MB |
| Frontend container | root／`/capture`、Docker health、bundle config | HTTP 200、deep-link 回同一 SPA entry、health healthy、bundle 含指定公開 API URL |
| Web cache | 檢查 response headers | `index.html` 回 `Cache-Control: no-store` |
| Bundle secret scan | 搜尋 release bundle | 沒有 `LIANGJIE_API_KEY`、`DATABASE_URL`、`postgresql://` 或 placeholder password |
| Browser QA | 2026-07-15 本機 Docker + in-app Browser | 桌面與 375×812：既有主線，以及投資練習場來源／日期、虛擬買入、持倉配置、事件骰子與 AI 陪讀；無明顯重疊或控制項溢位 |

本機 Docker 是 ARM64；最終 Dockerfiles 使用 multi-architecture Debian／Node／Nginx base，Flutter SDK 依建置主機下載相符 toolchain，但仍需在實際 Coolify VPS architecture 完成一次正式 build。

## 歷史測試覆蓋重點（本輪新增覆蓋見開頭）

### API

- Register／login／logout／revoked session、相同 generic invalid-credential error、目前密碼再驗證帳號刪除與 cascade。
- 帳號 ownership：帳號 B 看不到帳號 A 的事件。
- Budget、split、subscription monthly cost、六個月 cashflow、提醒、FutureSeed zero rate、三情境曲線與 drawdown calculation。
- FutureSeed 1.5%／5%／8% 合成路徑的十年幾何平均校準，以及不被每月投入稀釋的報酬指數 drawdown。
- TWSE 日資料 schema／民國日期／change percent／cache fallback／同時 cache miss 合併；虛擬現金、買入、賣出、持有量、配置、idempotency、同帳號併發下單與可重現事件牌組。
- Parse 不保存、確認保存、idempotency、query filters、malformed JSON、request body 過大與 validation envelope。
- CORS allowed／denied preflight／預檢快取、安全 headers、AI route rate limit、not found、health dependency failure；production origin 缺失、尾端 `/` 或非 HTTPS 時 fail-fast。
- Lessons completion body schema、同時註冊同 email 的 conflict response。
- Runtime 設定缺失／不合法時明確失敗；production 只允許完整的 `liangjie + postgres` provider pair。
- 量界 adapter：OpenAI-compatible request、nullable fields、type／category／intent semantics、Markdown JSON fence、invalid JSON／schema、timeout、429 retry budget、學習規劃與安全陪讀回覆。
- AI 文字安全：英文 lesson output 會被 `ai_invalid_output` schema 拒絕；coach 支援回答方式契約；家庭 service 驗證邀請碼、家長／孩子角色與摘要權限。
- AI 同意：當前 policy version、授權／撤回 timestamps、舊版重新同意，以及量界 parse／lesson／plan／coach 的 provider-before-call gate。
- PostgreSQL mapping、parameterized queries、event idempotency、sessions、lessons、health 與 close。

### Flutter

- Model JSON 與 `liangjie-ai` source mapping。
- Register／login envelope、Bearer header、首次設定、訪客不保存 session、帳號刪除後清除 token。
- AI consent GET／PUT、揭露／啟用／撤回 UI、未同意時本機不發 AI request，以及撤回後的 AI-only state 清除。
- API timeout／problem envelope、明確 timezone、空資料不虛構 subscription、session 還原時的暫時網路失敗／未授權分流。
- Capture 三階段、多 draft、修正、單筆確認、儲存後清空輸入、partial refresh recovery。
- Dashboard、phone／desktop direct navigation、subscription、lesson action、需要／想要控制、無延遲分析圖表與三路徑 FutureSeed。
- 投資練習場 route、盤後來源、訪客虛擬買入、超賣拒絕、事件骰子與 200% text scale。
- 200% text scale、short landscape rail、Design System components 與 responsive bento；FutureSeed sliders 的名稱與值語意、light-surface feature heading 4.5:1 text contrast。

## 30 筆合成解析評估

Fixture：`backend/test/fixtures/capture-evaluation.json`；報告：

- `backend/reports/capture-evaluation.md`
- `backend/reports/capture-evaluation.json`

涵蓋收入、單／多筆支出、相對日期、缺金額、訂閱、分帳、否定句、無關文字、折扣與合成通知。它評估 `deterministic-demo`，用途是 regression，不是量界真實模型準確率；簡報不可把 100% 混稱量界成效。

## 尚未驗證

- 量界正式環境的費率、quota、資料條款、真實使用情境 output quality、P95 latency 與 outage 行為。
- 本輪重新部署的 GitHub App、webhook／Auto Deploy 仍需驗收；既有 Coolify 曾成功部署，不據此推定新程式已在平台運作。
- 基線 `af7a5df` 已在 GitHub hosted runner 成功；本輪新狀態需於後續 push／Pull Request 重新觀察。
- 實際 Coolify VPS 的 AMD64／ARM64 image build、domains、TLS、CORS、health routing、resource limits 與 rollback。
- Coolify PostgreSQL internal URL、production capacity、scheduled S3 backup 與隔離 restore。
- Production log retention、磁碟告警與 server／Coolify 自身備份。
- Flutter Web integration drive；Flutter CLI 的 Web integration test 仍需相容 ChromeDriver。等價主線已有 Widget／HTTP／container tests，不冒充 drive 通過。
- Android 實機與 iOS signing／archive／TestFlight 尚未驗證；iOS 26.4 SDK 的 unsigned release build 已在本機通過，不代表可上傳。
- iOS 已換用現有 FutureMint 品牌圖示及啟動畫面；真機呈現與品牌最終核定仍待驗收。
- 使用者已確認 iPhone-only；`TARGETED_DEVICE_FAMILY=1`，仍需實機與正式商店截圖驗收。
- 隔離建置腳本的 unsigned `Runner.app` 已排除 `integration_test.framework`；正式 signed archive／Apple validation 仍待執行。
- 正式螢幕閱讀器、完整鍵盤、色覺與 reduced-motion 人工驗收。
- 已實作 Email verification、password reset、session cleanup、shared rate limit 及可設定的公開政策／支援頁；SMTP 真實送達、MFA、備份保留／刪除 SLA、真實公開 URL、量界與上游資料條款、正式未成年人營運條件仍待確認。

## 重現方式

API：

```bash
cd backend
npm ci
npm test
npm run typecheck
npm run build
npm run evaluate:captures
npm audit --omit=dev
docker build -t futuremint-api .
```

Flutter：

```bash
cd app
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter build web --release \
  --dart-define=BUILD_ENV=validation \
  --dart-define=API_BASE_URL=http://localhost:3000/api/
flutter build apk --debug
docker build \
  --build-arg BUILD_ENV=validation \
  --build-arg API_BASE_URL=http://localhost:13000/api/ \
  --build-arg PRIVACY_POLICY_URL=http://localhost:13000/privacy \
  --build-arg SUPPORT_URL=http://localhost:13000/support \
  --build-arg SUPPORT_EMAIL=local-validation@example.invalid \
  --build-arg SERVICE_OPERATOR=FutureMint-local-validation \
  -t futuremint-web .
```

PostgreSQL migration 與 E2E 需使用獨立 local test database，`DATABASE_URL` 只透過 shell／ignored `.env` 注入，不把 credential 寫入文件或 repository。

## 2026-10-02 親子帳號與發布配置補強

分類：缺陷修正、既有流程釐清及新能力（只讀公開發布配置檢查）。本輪從 `d52b830` 的乾淨 `main` 建立本機 `codex/account-release-readiness` 分支；未 commit、push、部署或操作 Apple 帳號。

- 首次設定說明目前登入者的預算歸屬；家庭加入／離開增加確認，分享與監護人／AI 授權獨立。查詢失敗可重試；唯讀可退出／停用邀請，新增分享仍受資格限制。家長有孩子關聯時仍不可關閉家庭。
- 修正前，新增的唯讀孩子退出／家長停用邀請 widget 回歸皆失敗（repository 呼叫數為 0）；修正後通過。後端既有權限及路由未變更。
- 正式 IPA 腳本加入 `check_release_readiness.py`；只 GET health、service-policy、雙語 privacy／support，不寄信、不呼叫 AI、不寫遠端資料。CI 增加合成發布檢查測試，不連 production。

| 驗證 | 實際結果與範圍 |
|---|---|
| Flutter 格式與 `flutter analyze --no-pub` | 通過，未發現問題 |
| Flutter 指定 8 檔整合／版面／設定回歸 | **80 tests 通過**，含家庭、首次設定、登入、session、launch client、mobile layout、widget、release config |
| Node.js 22.22.3 的 Vitest 指定 7 檔 | **59 tests 通過**，含完整親子、復原及刪除；memory repository／fake mailer |
| TypeScript `tsc --noEmit` | 通過 |
| Python 發布配置回歸 | **13 tests 通過**，含無 SMTP、未核准 AI、null／錯誤型別、unsafe URL、Cloudflare 公開 Email 改寫及語系／公開設定不符 |
| Python release staging 隔離 | **1 test 通過**；`bash -n tool/build_ios_release.sh` 通過 |
| iPhone 17／iOS 26.4 debug build 與操作 | 合成、無網路家庭預覽完成加入確認 → 已連結 → 離開確認 → 恢復未加入；畫面文字及按鈕正常。完成後重建一般 App，原帳號仍停在尚未送出的首次設定；未保存真實 profile |
| 375dp／200% 字級 | 家長首次設定、分享取消確認及既有手機版面回歸通過 |
| 線上公開發布檢查 | health hosted／postgres、現行 15+ policy、雙語公開頁及 App 公開資訊一致性通過；寄信功能 disabled、AI reviewed=false 被阻擋，exit code 1 為預期配置阻擋 |

可重現的選定測試（非全套／遠端 CI）：

```bash
cd app
flutter test --no-pub test/features/family_invite_test.dart test/features/onboarding_layout_test.dart test/features/auth_screen_test.dart test/state/session_controller_test.dart test/launch_client_test.dart test/features/mobile_layout_test.dart test/widget_test.dart test/release_config_test.dart
python3 tool/test_release_readiness.py
python3 tool/test_release_packaging.py
```

在 `backend/` 使用 Node.js 22：

```bash
node node_modules/vitest/vitest.mjs run test/http/launchFlows.test.ts test/auth/serviceEligibility.test.ts test/auth/accountRecovery.test.ts test/http/auth.test.ts test/http/runtime.test.ts test/config/startupConfig.test.ts test/application/futureMintService.test.ts
node node_modules/typescript/bin/tsc --noEmit
```

本輪未驗證真實 SMTP 送達、PostgreSQL 跨重啟親子流程、外部 AI 連線、合法監護人身分、客服收信、signed IPA／TestFlight、App Privacy／年齡問卷或送審。Xcode 原始專案仍無 Development Team 設定。發布配置檢查只證明公開配置契約；營運者欄位與 Email 格式不證明身分或收信能力。

同步 README、Client／API README、產品／範圍、安全、部署、設計及展示文件。沒有新資料欄位、migration、API 路由、AI provider 或部署拓樸變更，既有 architecture／data-and-storage／integrations／hosting-resources 的邊界仍一致，未為本輪新增重複規範。

## 2026-10-02 量界離線文件與簡化測試設定

分類：已核准範圍調整及部署說明釐清。使用者提供 169 頁量界離線 PDF；已擷取全文、檢索隱私／保存／訓練／上游／日誌等關鍵字，並檢視目錄及第 164 頁 API 說明。文件確認中轉服務支援 OpenAI／Gemini 格式，未找到完整資料處理條款。登入網站的 IP 記錄開關關閉；此項不作 prompt 保存或訓練政策證據。

依使用者核准方向，部署文件提供明寫未知條件的三項 Runtime 範本。Node.js 22.22.3、dotenv 及實際 `parseAiConfig` 以合成 key 驗證：設定可解析且 reviewed=true；接收方為兩項；公開內容改變會更新 fingerprint；改成 false 仍不放行，清空說明會拋出 AiConfigurationError。最終範本的告知長度為 354 字元，沒有修改 parser 或授權 gate。

同步根 README、backend README、backend/.env.example 註解、部署、安全及整合文件。未提交、推送、修改 Coolify、部署、使用真實憑證或呼叫外部 AI；實際模型權限、額度、連線及 App 新同意流程仍須在使用者套用設定後驗收。此次文件與公開設定檢查不替代先前 Client 回歸或正式營運／上架驗收。
