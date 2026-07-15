# FutureMint Flutter Client

Android、iOS 與 Web 共用 Client。正式 Web deployment 是 Coolify 中獨立的 `futuremint-web` Application，由 Flutter release build 產生靜態檔，再由 Nginx 服務。

## 技術與流程

- Flutter 3.41.x、Dart 3.11.x；manifest 是 `pubspec.yaml`，lockfile 是 `pubspec.lock`。
- Provider、go_router、http、SharedPreferences、intl；Client 不安裝資料庫或 AI SDK。
- 註冊、登入、首次預算／目標設定、登出與 Bearer session。
- 響應式 dashboard、Quick Capture、事件、訂閱比較、金融微課與 FutureSeed 試算。
- 訪客模式只使用當次記憶體；重新整理或離開後清除。
- 已登入資料只經 HTTPS API 保存；Client 不接受或傳送可竄改的 user ID。

## 本機執行

先啟動根 README 所述的 Fastify API：

```bash
flutter pub get
flutter run -d chrome \
  --web-port=4173 \
  --dart-define=API_BASE_URL=http://localhost:3000/api/
```

`API_BASE_URL` 是公開設定，必須以 `/api/` 結尾。API 的 `ALLOWED_ORIGINS` 必須包含 `http://localhost:4173`。API request timeout 為 12 秒；失敗時顯示可重試錯誤，不會偽造已保存資料。

## Docker／Coolify

```bash
docker build \
  --build-arg API_BASE_URL=https://api.example.com/api/ \
  -t futuremint-web .
```

Coolify Application 設定：

- Base directory：`/apps/client`
- Build pack：Dockerfile
- Port：`3000`
- Health check：`/`
- Build variable：`API_BASE_URL=https://<api-domain>/api/`
- Domain：正式 frontend HTTPS domain

Nginx 會將 deep links fallback 到 `index.html`，入口檔設為 no-store，hashed assets 可快取。`API_BASE_URL` 已編譯進 bundle，變更 API domain 後必須重新 build／deploy 前端。不得把 `LIANGJIE_API_KEY`、`DATABASE_URL` 或任何秘密放入 Dart define。

## 品質

```bash
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter build web --release \
  --dart-define=API_BASE_URL=https://api.example.com/api/
```

`integration_test/demo_flow_test.dart` 驗證訪客暫存流程。Web integration 另需相容 ChromeDriver：

```bash
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/demo_flow_test.dart \
  -d chrome
```

## 資料與限制

- 原始輸入只用於當次解析，不寫入 MoneyEvent。
- Session token 儲存在本機；目前 prototype 尚未實作 email 驗證、忘記密碼、帳號刪除、家長共管或 production 未成年人法遵。
- 不連銀行、支付或真實金融帳戶。
- Android／iOS 不是目前 Coolify deployment resources；原生 build／簽章狀態見 [測試證據](../../docs/testing-and-evidence.md)。

視覺規則見 [Design System](../../design-system/README.md)；架構、安全與部署見 [系統架構](../../docs/architecture.md)、[安全與隱私](../../docs/security-and-privacy.md)、[部署說明](../../docs/deployment.md)。
