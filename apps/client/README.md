# FutureMint Flutter Client

FutureMint AI 的 Android、iOS 與 Web 共用 Client。使用者可用電子郵件與密碼登入自己的資料，或以不保存資料的訪客模式先體驗。

## 技術證據與前置需求

- Flutter 3.41.x、Dart 3.11.x；manifest 為 `pubspec.yaml`，lockfile 為 `pubspec.lock`。
- Web 執行需要 Chrome；Android／iOS 建置另依平台需要 Android SDK 或 Xcode／CocoaPods／簽章。
- 主要依賴：Provider、go_router、http、SharedPreferences、intl；不在 Client 安裝 Azure SDK。

## 已完成流程

- 註冊、登入、首次預算／目標設定與登出。
- Session token 只保存於本機；帳號資料一律經 Bearer token 交給 Functions，Client 不傳可竄改的使用者 ID。
- 訪客模式使用當次記憶體資料；離開、重新整理或切換帳號後清除，不寫入 SharedPreferences 或後端。
- 響應式首頁、Quick Capture、收入／支出／訂閱紀錄、合成訂閱比較、金融微課與 FutureSeed 教育試算。
- 亮色／深色／系統主題、手機 NavigationBar 與平板／桌面 NavigationRail；支援 deep links。
- 柔和色塊品牌介面：近白畫布、扁平圓角功能區、黑色主行動與手機膠囊導覽、Flutter 原生幾何金錢夥伴，以及依內容寬度切換的桌面 bento 儀表板；沒有加入外部圖片或遠端字型。

## 執行

先依根目錄 README 啟動 Functions，接著：

```bash
flutter pub get
flutter run -d chrome \
  --web-port=4173 \
  --dart-define=API_BASE_URL=http://localhost:7071/api/
```

Functions 的 `ALLOWED_ORIGINS` 需包含 `http://localhost:4173`；固定 web port 可避免 Chrome 每次使用不同 origin 而被 CORS 拒絕。`API_BASE_URL` 是公開設定，不得把 Azure OpenAI 或 Cosmos secret 放進 Dart define 或 Client bundle。API request timeout 為 12 秒；斷網時顯示可重試訊息，不會自動切換或偽造已保存資料。

## 品質

```bash
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter build web --release
```

`integration_test/demo_flow_test.dart` 驗證訪客暫存流程。Web integration 需先啟動相容版本 ChromeDriver（port 4444），再執行：

```bash
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/demo_flow_test.dart \
  -d chrome
```

## 資料與限制

- 已登入帳號的 profile、events 與 lessons 只經 Functions 保存；資料邊界由後端帳號主體強制執行。
- 原始輸入只用於當次解析，不寫入 MoneyEvent。
- 訪客資料不保存，也不是離線同步或備份機制。
- 本產品不連銀行、支付或真實金融帳戶；目前沒有 email 驗證、忘記密碼、帳號刪除、家長共管或 production 未成年人法遵。

相關文件：[測試證據](../../docs/testing-and-evidence.md)、[系統架構](../../docs/architecture.md)、[安全與隱私](../../docs/security-and-privacy.md)。

## 設計與部署責任

- 視覺、響應式、狀態與可及性遵循 [FutureMint Design System](../../design-system/README.md)，實際 tokens 位於 `lib/design/`。
- Flutter Web 目標為 Azure Static Web Apps，目前只完成本機 release build，沒有 production URL。
- Android build 仍受本機磁碟空間阻塞；iOS build／簽章尚未驗證，詳見測試證據。
