# FutureMint Flutter Client

FutureMint AI 的 Android、iOS 與 Web 共用 Client。預設以明確標示的離線合成資料執行，也可用同一套 repository contract 連接 Functions API。

## 技術證據與前置需求

- Flutter 3.41.x、Dart 3.11.x；manifest 為 `pubspec.yaml`，lockfile 為 `pubspec.lock`。
- Web 執行需要 Chrome；Android／iOS 建置另依平台需要 Android SDK 或 Xcode／CocoaPods／簽章。
- 主要依賴：Provider、go_router、http、SharedPreferences、intl；不在 Client 安裝 Azure SDK。

## 已完成流程

- 響應式首頁：預算、目標、近期紀錄、教練提醒與訂閱機會。
- Quick Capture：文字輸入、解析進度、來源標籤、多草稿、修改與確認保存。
- 收入／支出／訂閱紀錄與篩選。
- 合成訂閱方案成本、節省與資格比較。
- 金融微課、選擇題與下一步行動。
- FutureSeed 本金／假設成長／期末值與年度摘要。
- 亮色／深色／系統主題、Connected／Offline 狀態、合成資料重設。
- 手機 NavigationBar 與平板／桌面 NavigationRail；支援 deep links。

## 執行

```bash
flutter pub get
flutter run -d chrome
```

預設不需要 secret：

```text
APP_MODE=offline-demo
```

Connected mode：

```bash
flutter run -d chrome \
  --web-port=4173 \
  --dart-define=APP_MODE=connected \
  --dart-define=API_BASE_URL=http://localhost:7071/api/
```

Functions 的 `ALLOWED_ORIGINS` 需包含 `http://localhost:4173`；固定 web port 可避免 Chrome 每次使用不同 origin 而被 CORS 拒絕。`API_BASE_URL` 是公開設定，不得把 Azure OpenAI 或 Cosmos secret 放進 Dart define 或 Client bundle。Connected request timeout 為 12 秒，錯誤不會自動改成假成功；使用者可在設定中明確切換 Offline demo。

## 品質

```bash
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter build web
```

`integration_test/demo_flow_test.dart` 走固定合成故事。Web integration 需先啟動相容版本 ChromeDriver（port 4444），再執行：

```bash
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/demo_flow_test.dart \
  -d chrome
```

## 資料

- Offline demo 只把合成 profile、已確認事件與微課選擇存進 SharedPreferences／browser local storage。
- 原始輸入只用於當次解析，不寫入 MoneyEvent。
- 「重設合成展示資料」只影響本裝置的離線 Demo。
- 本產品不連銀行、支付或真實金融帳戶。

相關文件：[測試證據](../../docs/testing-and-evidence.md)、[系統架構](../../docs/architecture.md)、[安全與隱私](../../docs/security-and-privacy.md)。

## 設計與部署責任

- 視覺、響應式、狀態與可及性遵循 [FutureMint Design System](../../design-system/README.md)，實際 tokens 位於 `lib/design/`。
- Flutter Web 目標為 Azure Static Web Apps，目前只完成本機 release build，沒有 production URL。
- Android build 仍受本機磁碟空間阻塞；iOS build／簽章尚未驗證，詳見測試證據。
