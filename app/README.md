# FutureMint Flutter Client

Android、iPhone 與 Web 共用 Client；App Store 只支援 iPhone。正式 Web deployment 是 Coolify 中獨立的 `futuremint-ai-web` Application，由 Flutter release build 產生靜態檔，再由 Nginx 服務。

## 技術與流程

- Flutter 3.41.x、Dart 3.11.x；manifest 是 `pubspec.yaml`，lockfile 是 `pubspec.lock`。
- Provider、go_router、http、flutter_secure_storage、SharedPreferences、flutter_localizations、intl、fl_chart；Client 不安裝資料庫或 AI SDK。
- 註冊、登入、Email 驗證、忘記密碼、首次預算／目標設定、登出、App 內帳號刪除與 Bearer session。
- 第三方 AI 資料說明、明確啟用／撤回，以及未同意時的 Client-side AI 功能攔截；設定與首頁提示都可再次開啟說明。
- 響應式 dashboard、自然語言 Capture、可修改需要／想要建議，以及可編輯／刪除已保存帳務的紀錄頁；另有收支圖表、圖形化通知、訂閱檢查、個人學習規劃、金融微課、三路徑 FutureSeed 模擬與延遲行情投資練習場。
- 學習頁與 FutureSeed 支援自由輸入問題、主題與回答方式個人化；設定可建立／加入家庭關聯，家長只看孩子的預算與趨勢摘要，不共享交易明細。
- Capture 目前只支援繁體中文文字／貼上輸入，不提供圖片上傳或 OCR，避免把個資影像送出。
- 訪客模式只使用當次記憶體；重新整理或離開後清除。
- Web PWA 與 Android launcher 使用本機 FutureMint 靛紫種子圖示；Web 不鎖直向，支援決賽投影與手機 landscape 備援。
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
  --build-arg BUILD_ENV=validation \
  --build-arg API_BASE_URL=http://localhost:13000/api/ \
  --build-arg PRIVACY_POLICY_URL=http://localhost:13000/privacy \
  --build-arg SUPPORT_URL=http://localhost:13000/support \
  --build-arg SUPPORT_EMAIL=local-validation@example.invalid \
  --build-arg SERVICE_OPERATOR=FutureMint-local-validation \
  -t futuremint-web .
```

Coolify Application 設定：

- Base directory：`/app`
- Build pack：Dockerfile
- Port：`3000`
- Health check：`/`
- Production build variables：`BUILD_ENV=production`、`API_BASE_URL=https://<api-domain>/api/`、`PRIVACY_POLICY_URL`、`SUPPORT_URL`、`SUPPORT_EMAIL`、`SERVICE_OPERATOR`（全部是公開資料）
- Domain：正式 frontend HTTPS domain

Nginx 會將 deep links fallback 到 `index.html`；`index.html`、Flutter loader／service worker、`main.dart.js` 與版本檔均設為 `no-store`，其餘帶指紋的靜態資產可快取，以避免更新後仍載入舊版 UI。`API_BASE_URL` 已編譯進 bundle，變更 API domain 後必須重新 build／deploy 前端。不得把 `LIANGJIE_API_KEY`、`DATABASE_URL` 或任何秘密放入 Dart define。

## 品質

```bash
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter build web --release \
  --dart-define=BUILD_ENV=validation \
  --dart-define=API_BASE_URL=http://localhost:3000/api/
```

`integration_test/demo_flow_test.dart` 驗證訪客暫存流程。Web integration 另需相容 ChromeDriver：

```bash
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/demo_flow_test.dart \
  -d chrome
```

iOS release 必須先把 `.env.appstore.example` 複製為已忽略的 `.env.appstore.local`，填入已驗證值後執行 `./tool/build_ios_release.sh`。腳本會拒絕 localhost／placeholder API URL、無效 build number 及與 Runner 不一致的 Bundle ID，但不會上傳 App Store Connect。

iOS Client 本身只使用系統 HTTPS／TLS，沒有實作自訂或非豁免加密，因此 `Info.plist` 已設定 `ITSAppUsesNonExemptEncryption=false`。若後續新增加密或安全相關 SDK，必須重新進行出口法規分類，不可沿用此結論。

## 資料與限制

- 原始輸入只用於當次解析，不寫入 MoneyEvent。
- Session token 儲存在本機；帳號刪除已實作目前密碼再驗證與雙重確認。Email 驗證、忘記密碼及家庭邀請更新／停用已實作；家庭所有權轉移與正式未成年人營運條件仍未完成。家庭摘要權限已由 API 驗證，家長不會取得孩子交易明細。
- FutureSeed 使用版本化合成報酬路徑；投資練習場另外讀取 API 提供的證交所每日成交快照，且始終顯示行情日期、來源與是否為降級資料。
- 投資練習場只建立虛擬訂單。登入帳號保存到 PostgreSQL；訪客持倉與訂單只留在記憶體，重新整理後清除。
- 畫面中的五個標的是跨產業教學範例，不是推薦清單；骰子只產生學習事件，不代替使用者決定買賣。
- 不連銀行、支付或真實金融帳戶。
- Android／iOS 不是目前 Coolify deployment resources；原生 build／簽章狀態見 [測試證據](../docs/testing-and-evidence.md)。

視覺規則見 [Design System](../design/README.md)；架構、安全與部署見 [系統架構](../docs/architecture.md)、[安全與隱私](../docs/security-and-privacy.md)、[部署說明](../docs/deployment.md)。

## iPhone Release 準備

原生 token 存於系統安全儲存，Web 使用瀏覽器儲存；舊原生 token 會安全遷移。MaterialApp 支援繁體中文系統元件與淺色／深色／系統主題；設定可開啟公開隱私與支援 URL。

本機編譯驗證：`bash tool/build_ios_validation.sh`。正式簽章：先由已確認的 Apple 帳號在 Xcode Runner 設定 Team，填妥已忽略的 `.env.appstore.local`（格式見 `.env.appstore.example`），再於獲授權後執行 `bash tool/build_ios_release.sh`。腳本驗證 Runner 的 bundle ID、Team、iPhone 裝置與 production 公開設定，然後在隔離副本排除 integration_test 插件。輸出在 `build/release-ios/`，不覆寫原始測試依賴。未簽章產物不能上傳 App Store。

直接 `flutter build web --release` 必須附正確 production defines；本機／CI 可以明確指定 `--dart-define=BUILD_ENV=validation`，此模式產物只供驗證。正式 Docker build 先執行相同 ReleaseConfig 檢查，placeholder 網域與缺少營運者資訊會失敗。
