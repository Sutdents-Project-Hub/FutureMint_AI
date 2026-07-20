# FutureMint AI 學生前端協作教學

> 對象：第一次使用 Git、GitHub、VS Code 與 Flutter 的前端組員。照著本文件操作，即可在自己的電腦預覽、修改與送出 FutureMint AI 的前端介面。本文件只涵蓋前端；後端、資料庫、Docker、部署與秘密由帶隊老師負責。

## 先知道這件事：你的工作邊界

FutureMint AI 的前端是 `app/` 資料夾裡的 **Flutter Web** 程式。它不是 React、Vue 或 Expo 專案，因此：

- 要安裝的是 **Flutter 3.41.x（Dart 3.11.x）**、Google Chrome、Git 與 VS Code。
- **不需要安裝 Expo，也不需要安裝 Node.js、npm、Docker、PostgreSQL、Android Studio 或 Xcode**，就可以修改與預覽網頁前端。
- 專案的後端確實使用 Node.js 22.x，但那是老師負責的 `backend/`；請勿為了本教學安裝或啟動它。若老師日後安排後端工作，才依老師指示安裝 Node.js 22.x，不要自行選擇其他版本。
- 你不會也不應該取得 API key、資料庫密碼、部署帳號或 production `.env`。前端唯一可能使用的 `API_BASE_URL` 是公開的 API 位址，且必須由老師提供。

本地預覽時，即使沒有後端，你仍可在登入畫面按 **「以訪客模式繼續」**。訪客模式的資料只存在這次網頁執行期間，重新整理就會清除；它適合檢查畫面、排版、文案與互動，不代表帳號登入或儲存功能已測試。

## 目錄

1. [名詞與協作規則](#名詞與協作規則)
2. [第一次安裝：Mac](#第一次安裝mac)
3. [第一次安裝：Windows](#第一次安裝windows)
4. [加入 GitHub 專案並複製程式](#加入-github-專案並複製程式)
5. [第一次啟動前端](#第一次啟動前端)
6. [認識前端程式結構與可修改範圍](#認識前端程式結構與可修改範圍)
7. [修改、熱重載與畫面檢查](#修改熱重載與畫面檢查)
8. [測試與提交前檢查](#測試與提交前檢查)
9. [協作完整流程：分支、commit、push、PR](#協作完整流程分支commitpushpr)
10. [處理 review、同步 main 與 rebase](#處理-review同步-main-與-rebase)
11. [常見問題排除](#常見問題排除)
12. [每日開工與收工清單](#每日開工與收工清單)

## 名詞與協作規則

先理解這些名詞，不用一次背起來；下面每個步驟都會實際操作它們。

| 名詞 | 白話意思 | 在本專案中的做法 |
| --- | --- | --- |
| Repository（repo／倉庫） | GitHub 上存放整個專案與歷史紀錄的地方 | 私人 GitHub repo `FutureMint_AI` |
| `main` | 團隊確認過、穩定的主線 | 受保護；學生不能直接推送或合併 |
| branch（分支） | 從 `main` 複製出的個人工作線 | 一個小任務一個短期分支，例如 `ui/dashboard-heading` |
| commit | 把一小段可說明的修改記成一個本機存檔點 | commit 前只加入本次要交的檔案 |
| push | 把自己的 branch／commit 上傳 GitHub | 只推送自己的工作分支，絕不推 `main` |
| Pull Request（PR） | 請團隊把你的分支修改看過並合進 `main` 的申請單 | 由老師或被授權的維護者 review 與 merge |
| review | 其他人檢查你的程式、畫面與風險後留下意見 | 在同一個 branch 修正、再 push；PR 會自動更新 |
| `origin` | 你電腦上 Git 對 GitHub 遠端 repo 的名稱 | clone 後通常已經存在，不要任意更改 |

### 團隊的固定規則

1. 每次動手前先確認老師分配的畫面與檔案，避免兩人同時大量修改同一支檔案。
2. 先從最新 `main` 開新 branch；不要在 `main` 直接寫程式，也不要直接 push `main`。
3. 一個 PR 只做一個清楚的小任務，例如「調整首頁預算區塊在手機版的間距」；不要順便改其他頁面、後端或設定。
4. 修改前後都要自己在 Chrome 看畫面。畫面變更至少檢查手機寬度與桌面寬度。
5. 不使用 `git add .`、不使用 `git push origin main`、不使用 `git reset --hard`、不使用 `git clean`，也不強制覆蓋別人的 branch。
6. 不把 `.env`、密碼、token、API key、學生／測試帳號資料、對話截圖中的個資，或合約與內部文件放進 commit、PR 或聊天室。
7. 收到不確定的 Git 衝突、陌生檔案或錯誤時先停下來問老師；不要為了讓指令「看起來成功」而刪檔、跳過 commit 或隨意選擇衝突內容。

## 第一次安裝：Mac

以下步驟只需第一次做一次。請使用自己的 macOS 帳號，將開發資料夾放在本機磁碟，例如「文件」或使用者資料夾；不要放在 USB 隨身碟、iCloud 同步中的工作資料夾，避免同步造成 Git 衝突。

### 1. 安裝 Google Chrome

1. 開啟 [Google Chrome](https://www.google.com/chrome/) 下載頁。
2. 下載並安裝 Chrome。
3. 安裝完成後至少開啟一次 Chrome，再關閉即可。Flutter 會把它當作本專案的 Web 預覽裝置。

### 2. 安裝 VS Code

1. 開啟 [VS Code 官方下載頁](https://code.visualstudio.com/download)。
2. 下載 macOS 對應的版本：Apple 晶片（M 系列）選 Apple Silicon；Intel Mac 選 Intel。
3. 依下載檔的提示把 VS Code 移到「應用程式」。
4. 第一次開啟 VS Code 時，若 macOS 詢問是否開啟，選擇「開啟」。

### 3. 在 VS Code 安裝 Flutter 擴充功能與 SDK

1. 開啟 VS Code。
2. 點左側的 **Extensions／擴充功能** 圖示（四個小方塊），或按 `⇧⌘X`。
3. 搜尋 `Flutter`，選擇發行者為 **Dart Code** 的 Flutter 擴充功能，按 **Install**。Dart 擴充功能會一併安裝。
4. 按 `⇧⌘P` 開啟 Command Palette（命令面板），輸入並選擇 `Flutter: New Project`。
5. 若 VS Code 顯示找不到 Flutter SDK，選擇 **Download SDK**，選擇一個固定且自己找得到的位置，例如使用者資料夾下的 `development`。不要選取專案資料夾 `FutureMint_AI` 本身。
6. 等待下載完成，依畫面提示把 Flutter 加入 PATH；完成後關閉並重新開啟 VS Code 的終端機。
7. 在 VS Code 選單 **Terminal → New Terminal** 開一個終端機，輸入：

   ```bash
   flutter --version
   flutter doctor
   dart --version
   ```

   `flutter --version` 應顯示 Flutter `3.41.x`，`dart --version` 應顯示 Dart `3.11.x`。`flutter doctor` 對 Chrome／VS Code 顯示可用即可；Android 或 Xcode 的黃色警告不影響本教學的 Web 前端工作。

> 若 VS Code 沒有提供 SDK 下載按鈕，請依 [Flutter 官方 VS Code 安裝說明](https://docs.flutter.dev/install/with-vs-code) 下載 Flutter SDK，再回 VS Code 按 `⇧⌘P`，選擇 `Flutter: Change SDK` 指向下載後的 Flutter 資料夾。

### 4. 安裝 Git 並設定作者名稱

1. 開啟 [Git 官方下載頁](https://git-scm.com/downloads)，下載 macOS 安裝程式並完成安裝。若 macOS 在第一次輸入 `git` 時要求安裝 Command Line Tools，也可依提示完成安裝。
2. 關閉並重新開啟 VS Code 終端機，輸入：

   ```bash
   git --version
   ```

3. 設定 commit 顯示的名字與 email。請用自己的名字；email 請用 GitHub 帳號已驗證的 email，或在 GitHub 設定後使用 GitHub 的 `noreply` email。把引號內文字改成你的資料：

   ```bash
   git config --global user.name "你的英文或中文名字"
   git config --global user.email "你的 GitHub email"
   ```

4. 用下面指令核對。這些資料會出現在你的 commit 作者資訊中：

   ```bash
   git config --global --get user.name
   git config --global --get user.email
   ```

## 第一次安裝：Windows

以下步驟只需第一次做一次。請使用本機的 Windows 使用者資料夾儲存專案；不要把正在開發的 repo 放在 USB 隨身碟、OneDrive 即時同步資料夾或壓縮檔內。

### 1. 安裝 Google Chrome

1. 開啟 [Google Chrome](https://www.google.com/chrome/) 下載頁。
2. 下載並完成安裝。
3. 開啟一次 Chrome 後再關閉即可。它是本專案的 Web 預覽裝置。

### 2. 安裝 VS Code

1. 開啟 [VS Code 官方下載頁](https://code.visualstudio.com/download)。
2. 下載 Windows 的 **User Installer**（大多數學生適用），依安裝精靈完成安裝。
3. 開啟 VS Code。

### 3. 在 VS Code 安裝 Flutter 擴充功能與 SDK

1. 點左側 **Extensions／擴充功能** 圖示，或按 `Ctrl+Shift+X`。
2. 搜尋 `Flutter`，選擇發行者為 **Dart Code** 的 Flutter 擴充功能，按 **Install**。Dart 擴充功能會一併安裝。
3. 按 `Ctrl+Shift+P`，輸入並選擇 `Flutter: New Project`。
4. 若 VS Code 顯示找不到 Flutter SDK，選擇 **Download SDK**，並選擇固定位置，例如你的使用者資料夾下的 `development`。不要選在 `Program Files`、專案資料夾或 OneDrive 同步資料夾。
5. 等待下載完成，依 VS Code 的 PATH 提示操作；關掉並重新開啟 VS Code 的終端機。
6. 選單 **Terminal → New Terminal** 開啟終端機（PowerShell 或 Git Bash 都可以），輸入：

   ```powershell
   flutter --version
   flutter doctor
   dart --version
   ```

   Flutter 應是 `3.41.x`，Dart 應是 `3.11.x`。本教學只跑 Chrome 網頁版；Android Studio、Visual Studio 或 Android SDK 的提示不是阻礙，可先忽略。

> 若 VS Code 沒有 SDK 下載選項，請依 [Flutter 官方 VS Code 安裝說明](https://docs.flutter.dev/install/with-vs-code) 安裝 Flutter SDK；回到 VS Code 按 `Ctrl+Shift+P`，選擇 `Flutter: Change SDK`，指定 Flutter 資料夾。

### 4. 安裝 Git 並設定作者名稱

1. 開啟 [Git 官方下載頁](https://git-scm.com/downloads)，下載 **Git for Windows**。
2. 執行安裝程式。沒有特別需求時使用預設選項；確認保留可在命令列使用 Git 的選項即可。安裝完成後會有 Git Bash，也可以繼續用 VS Code 內建終端機。
3. 關閉並重開 VS Code 終端機，輸入：

   ```powershell
   git --version
   ```

4. 設定 commit 作者資訊；把引號內文字替換成自己的資料：

   ```powershell
   git config --global user.name "你的英文或中文名字"
   git config --global user.email "你的 GitHub email"
   ```

5. 核對設定：

   ```powershell
   git config --global --get user.name
   git config --global --get user.email
   ```

## 加入 GitHub 專案並複製程式

### 1. 建立或登入 GitHub

1. 前往 [GitHub 註冊頁](https://github.com/signup) 建立帳號，或登入既有帳號。
2. 把自己的 GitHub 使用者名稱告訴老師。
3. 接受老師寄出的 FutureMint_AI 私人 repo 邀請。接受後，在瀏覽器打開 repo 時應該看得到檔案；看不到就先請老師確認邀請與帳號是否正確。
4. 在 VS Code 左下角／Accounts 圖示登入同一個 GitHub 帳號。若跳出瀏覽器授權頁，確認是 VS Code 的登入流程後按授權。

> 私人 repo 的網址與權限不能猜。本文件不提供或要求 token。需要 repo 網址時，請在 GitHub 的 FutureMint_AI 頁面按 **Code**，複製老師已授權給你的 **HTTPS** clone URL。

### 2. 用 VS Code 複製（推薦）

1. 開啟 VS Code，按 `⇧⌘P`（Mac）或 `Ctrl+Shift+P`（Windows）。
2. 選擇 `Git: Clone`。
3. 貼上剛才從 GitHub **Code → HTTPS** 複製的 repo URL。
4. 選擇你要放專案的本機資料夾，例如「文件／程式專案」。VS Code 會建立 `FutureMint_AI` 資料夾。
5. Clone 結束後按 **Open** 開啟專案。
6. 如果 VS Code 問「Do you trust the authors of the files?」，確認你開的是老師邀請的 FutureMint_AI repo 後選擇信任。

### 3. 用終端機複製（替代方法）

以下的 `<...>` 只是要替換的提示，**不要原樣輸入尖括號**。請把網址替換為你從 GitHub 複製的 HTTPS URL：

```bash
cd <你想放專案的資料夾>
git clone <從 GitHub Code → HTTPS 複製的 FutureMint_AI repo URL>
cd FutureMint_AI
```

若第一次連私人 repo 時 GitHub 開啟瀏覽器登入／授權，請使用自己的 GitHub 帳號完成它；不要把密碼或 token 貼到聊天室、程式碼或文件。完成後在 VS Code 用 **File → Open Folder…** 開啟剛剛的 `FutureMint_AI` 資料夾。

### 4. 開啟前先做三個確認

在 VS Code 選 **Terminal → New Terminal**，確定提示字元目前位於 `FutureMint_AI` 根目錄，依序輸入：

```bash
git status --short --branch
git branch --show-current
git remote -v
```

第一次 clone 後，通常會看到目前 branch 是 `main`，`origin` 指向 GitHub。若已經有你不認識的修改、錯誤的 repo、或 branch 不是預期的 `main`，先不要開始修改，截圖或複製輸出問老師；**不要執行 reset、clean 或刪檔**。

## 第一次啟動前端

### 1. 安裝 Flutter 前端套件

本專案的 Flutter manifest 在 `app/pubspec.yaml`，所以先從根目錄進入 `app`：

```bash
cd app
flutter pub get
```

這會依 `pubspec.lock` 下載專案已鎖定的 Flutter 套件。第一次可能需要一些時間；完成後不要手動刪除 `pubspec.lock`，也不要執行 `flutter pub upgrade`。

### 2. 確認 Chrome 被 Flutter 找到

仍在 `app` 資料夾時輸入：

```bash
flutter devices
```

清單中應有 `Chrome`。若沒有，先確認 Chrome 已安裝並至少開啟過一次，再關閉／重開 VS Code 後重試。

### 3. 啟動純前端預覽

在 `app` 資料夾輸入這個可直接使用的指令：

```bash
flutter run -d chrome --web-port=4173
```

Flutter 會開啟 Chrome，並在終端機保持執行。預設 API 位址是本機 `http://localhost:3000/api/`；學生不啟動後端時登入與帳號資料功能預期會連不上。請在首頁按 **「以訪客模式繼續」**，即可檢查大多數前端畫面；投資練習場會明確使用內建教育快照作為網路失敗的降級資料。

不要關閉這個終端機，否則預覽會停止。結束時在該終端機按 `q`。

### 4. 老師提供共用測試 API 時才使用的啟動方式

如果老師已提供可公開存取的測試 API 位址，並明確說可以連線，才將下面提示換成老師提供的完整值。位址**必須以 `/api/` 結尾**，例如老師給的實際位址；它不是密碼，但也不要自行猜網址。

```bash
flutter run -d chrome --web-port=4173 --dart-define=API_BASE_URL=<老師提供且以 /api/ 結尾的 API 位址>
```

這不是 `.env` 設定：Flutter Web 不會讀取 `app/.env`，本專案也沒有學生要建立的前端 `.env` 檔。`API_BASE_URL` 會編譯進前端；不要在它或任何 Dart 檔放入 API key、資料庫連線字串、token 或密碼。根目錄的 `.env` 是老師處理 Docker Compose 本機整合時的檔案，學生前端工作不需建立或修改它。

## 認識前端程式結構與可修改範圍

開啟 VS Code 左側 **Explorer／檔案總管**。前端程式都在 `app/`；一般 UI 任務主要修改 `app/lib/`。先從被分配的畫面檔案找起，並先讀該檔案再修改。

```text
app/
├── lib/
│   ├── main.dart                     # App 啟動與 API_BASE_URL；通常不要修改
│   ├── app/                          # App 外框、路由、手機／桌面導覽
│   ├── features/                     # 各功能畫面的 UI（學生最常修改）
│   ├── design/                       # 既有色彩、間距、主題與共用元件
│   ├── shared/                       # 小型共用顯示元件與格式化工具
│   ├── state/                        # UI 狀態與流程控制；非純 UI 任務先問老師
│   ├── data/、auth/、core/           # API、帳號與資料模型；不屬一般 UI 修改範圍
├── test/                             # Flutter widget／unit tests
├── integration_test/                 # 跨畫面流程測試
├── web/                              # 網頁圖示、HTML 與 PWA manifest；改素材前先確認授權
├── pubspec.yaml / pubspec.lock       # 套件與版本鎖定；不要自行改或升級
└── README.md                         # Flutter Client 技術與品質說明
```

### 對照需求找檔案

| 想改的畫面／項目 | 優先查看的檔案 |
| --- | --- |
| 登入、註冊 | `app/lib/features/auth/auth_screen.dart` |
| 首頁／預算摘要 | `app/lib/features/dashboard/dashboard_screen.dart`、`app/lib/features/dashboard/widgets/budget_hero.dart` |
| 記一筆、草稿編輯 | `app/lib/features/capture/capture_screen.dart`、`app/lib/features/capture/draft_editor.dart` |
| 收支紀錄與圖表 | `app/lib/features/records/records_screen.dart`、`app/lib/features/records/analysis_widgets.dart` |
| 學習頁 | `app/lib/features/learning/learning_screen.dart` |
| 通知中心 | `app/lib/features/notifications/notification_center_screen.dart` |
| 訂閱建議 | `app/lib/features/subscriptions/subscription_coach.dart` |
| FutureSeed 與投資練習場 | `app/lib/features/future_seed/future_seed_screen.dart`、`investment_chart.dart`、`investment_lab_screen.dart` |
| 設定、教學、客服 sheet | `app/lib/features/settings/settings_sheet.dart`、`help_sheets.dart` |
| 手機底部導覽、桌面側欄 | `app/lib/app/app_shell.dart` |
| 網址路由 | `app/lib/app/app_router.dart`（新增／改路由前先和老師確認） |
| 色彩、間距、深色主題、共用卡片 | 先重用 `app/lib/design/tokens.dart`、`theme.dart`、`soft_components.dart` |

### 視覺修改要遵守的既有規則

- 先閱讀 [Design System](../design/README.md) 與 `design/futuremint-ai/MASTER.md` 的色彩、間距、響應式與可及性規則。
- 優先重用 `FutureMintTokens`、`SoftCard`、`PageHeading`、`MoneyBuddy` 等現有元件；不要複製一份近似色彩或硬寫很多數字。
- 手機寬度小於 720dp 使用底部五項導覽，720dp 以上使用左側導覽列。不要只針對自己的電腦尺寸寫死版面。
- 按鈕／可點擊目標至少 48dp，文字不可只靠顏色傳達意思；亮／暗模式、長文字與手機版都要看過。
- 如果需求會改變整份視覺規範、導覽結構、資料流程或 API 行為，先和老師確認範圍。規格與實作需同步，不能偷偷只改其中一邊。

### 這些檔案或資料夾不要自行修改

| 請勿自行修改 | 原因與正確做法 |
| --- | --- |
| `backend/`、`compose.yaml`、Dockerfile、`nginx.conf` | 後端、資料庫與部署由老師負責；提出需求或問題即可 |
| `.env`、`backend/.env`、憑證、任何 key／token | 可能是秘密，不能讀取、複製、截圖、commit 或傳送 |
| `app/pubspec.yaml`、`app/pubspec.lock` | 不自行新增套件、升級 Flutter 套件或執行 `flutter pub upgrade`；需要套件先說明用途給老師 |
| `app/android/`、`app/ios/` | 本教學是 Flutter Web UI；原生設定不在學生前端任務範圍 |
| `app/lib/main.dart`、`auth/`、`data/`、`core/`、`state/` | 會影響登入、資料、權限、金融計算或 API；不是純畫面需求時先確認 |
| `.github/`、GitHub Actions、既有 CI 設定 | 改錯會影響全隊檢查流程；交給老師 |
| `build/`、`.dart_tool/`、`node_modules/`、log、IDE 設定 | 這些是工具產生物或個人環境，不應加入 commit |

## 修改、熱重載與畫面檢查

### 一次安全的小修改範例

1. 先確認老師分配的任務，例如「調整首頁卡片標題的間距」。
2. 在 Explorer 開啟對應檔案，例如 `app/lib/features/dashboard/dashboard_screen.dart`。
3. 先讀附近程式，看看是否已有 `FutureMintTokens` 或共用元件可以使用。
4. 只做這個任務需要的一小段修改，按 `⌘S`（Mac）或 `Ctrl+S`（Windows）儲存。
5. 回到正在執行 `flutter run` 的終端機：通常儲存後就會更新；沒有更新時按小寫 `r` 執行 **hot reload**。若新增了初始化狀態、路由或 hot reload 不夠，按大寫 `R` 執行 **hot restart**。
6. 回 Chrome 查看畫面。如果終端機已停止，重新在 `app/` 資料夾執行：

   ```bash
   flutter run -d chrome --web-port=4173
   ```

7. 修改的是 UI 時，至少檢查：

   - 訪客模式是否能進入畫面。
   - 手機寬度約 375px、平板約 768px、桌面約 1024px 及更寬畫面是否沒有水平溢位。
   - Chrome 視窗改成橫向較矮時，導覽與主要按鈕仍可看見。
   - 到設定切換亮／暗主題後，文字、按鈕與卡片仍清楚。
   - 點擊、鍵盤 Tab 焦點、載入／錯誤文案沒有被你的修改遮住。

Chrome 可以按 `⌘⌥I`（Mac）或 `F12`／`Ctrl+Shift+I`（Windows）開 Developer Tools，再按裝置工具列按鈕或 `⌘⇧M`／`Ctrl+Shift+M` 模擬不同寬度。這只是在本機檢查外觀，**不會發布網站**。

### VS Code 裡如何找檔案與看差異

- 按 `⌘P`（Mac）或 `Ctrl+P`（Windows），輸入檔名的一部分，例如 `dashboard_screen`，可以快速開檔。
- 按 `⌘⇧F`／`Ctrl+Shift+F` 搜尋畫面上已知的中文文案，通常能找到對應 widget；取代前確認搜尋範圍是 `app/lib/`，不要全專案大量取代。
- 點左側 **Source Control／原始檔控制** 圖示（分支形狀），可以看到修改過的檔案。點檔案可打開左右差異：紅色是刪除，綠色是新增。
- 如果瀏覽器沒有更新，先確認檔案已儲存；再按 `r`，最後才使用 Chrome 的強制重新整理 `⌘⇧R`／`Ctrl+Shift+R`。

## 測試與提交前檢查

在 `app/` 資料夾執行下列指令。它們不會發布、不會連資料庫，也不需要 Docker。

```bash
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
```

依序說明：

- 第一行只檢查 Dart 格式是否正確，**不會改檔案**。
- `flutter analyze` 檢查 Dart／Flutter 的靜態錯誤。
- `flutter test` 執行前端的單元與 widget 測試。

若格式檢查只指出你修改的某個檔案，可只格式化那一個檔案，再重新檢查並看 diff，例如：

```bash
dart format lib/features/dashboard/dashboard_screen.dart
```

不要為了方便而一次格式化整個專案、修改不屬於自己任務的檔案，或直接忽略失敗。若 `flutter analyze`／`flutter test` 失敗，先讀第一個與自己修改相關的錯誤；不確定是否為既有問題時，保留輸出並問老師。

本專案的正式 Web build 會把 `API_BASE_URL` 編進檔案。學生不需要自行做 production build；只有老師提供正式或測試 API URL 並要求你驗證 build 時，才用老師給的實際值執行：

```bash
flutter build web --release --dart-define=API_BASE_URL=<老師提供且以 /api/ 結尾的 API 位址>
```

產生的 `build/` 是工具輸出，不要加入 Git。

## 協作完整流程：分支、commit、push、PR

以下流程是一次「新的前端小任務」的完整做法。請在 VS Code 的終端機操作；偏好按鈕的同學可在後面的 Source Control 小節使用 VS Code 完成 stage、commit 與 push。

### A. 每個新任務都從最新 main 開分支

先確認沒有未處理的修改；若 `git status` 出現你不認識的檔案或修改，先停下來問老師。

```bash
cd <FutureMint_AI 根目錄；若你現在在 app，先輸入 cd ..>
git status --short --branch
git switch main
git pull --ff-only origin main
git switch -c ui/<英文短任務名稱>
```

例如首頁標題任務可使用：

```bash
git switch -c ui/dashboard-heading
```

分支名稱請用小寫英文、數字與連字號；可用 `ui/`（UI）、`fix/`（修正）或老師指定的前綴。不要在 branch 名稱放空白、中文或整句需求。

`git pull --ff-only` 的意思是只接受安全的直線更新；如果它說無法 fast-forward，不要改用危險指令，先問老師。

### B. 修改與檢查

1. 在 `app/lib/` 做老師交辦的 UI 修改。
2. 用 Chrome 進入訪客模式做手動畫面檢查。
3. 在 `app/` 執行格式、分析與測試指令。
4. 回到 repo 根目錄，檢查本次真正改了什麼：

   ```bash
   cd ..
   git status --short --branch
   git diff -- app/lib/features/dashboard/dashboard_screen.dart
   ```

上例的檔名要改成你實際修改的檔案。你應該看得懂每一行差異；看不懂或看到不屬於本任務的改動就先不要提交。

### C. 用終端機逐檔 stage、commit、push

請把下方路徑改成你的實際檔案。若改了兩個有關聯的前端檔案，可列兩個明確路徑；**不要使用 `git add .`**。

```bash
git add app/lib/features/dashboard/dashboard_screen.dart
git diff --cached
git status --short
git commit -m "feat(app): 調整首頁標題層級"
git push -u origin ui/dashboard-heading
```

每一行的意思：

1. `git add <檔案>`：把指定檔案放進下一次 commit，不會上傳。
2. `git diff --cached`：再次核對「即將 commit 的內容」。這是避免把秘密或無關變更交出去的最後一步。
3. `git status --short`：檢查 staged、unstaged 與 untracked 檔案；不要把 `.env`、log、build、陌生檔案加入。
4. `git commit -m ...`：建立本機紀錄。訊息採 `類型(範圍): 繁中說明`，例如 `fix(app): 修正手機版卡片溢位`、`docs(app): 補充學習頁文案說明`。
5. `git push -u origin <你的分支>`：把自己的 branch 上傳 GitHub。第一次加 `-u` 後，之後在同一 branch 可使用 `git push`。

### D. 用 VS Code Source Control 操作（按鈕版）

VS Code 按鈕版和上面的 Git 指令做的是同一件事；兩種方法擇一使用即可。

1. 點左側 **Source Control** 圖示，先逐檔點開差異確認。
2. 在要提交的檔案右邊按 `+`（Stage Changes）。不要按全部檔案旁的 `+`，除非你已經逐一確認每個檔案都屬於本任務。
3. 在 **Staged Changes** 再次點開檔案確認。
4. 在上方輸入 commit 訊息，例如 `feat(app): 調整首頁標題層級`。
5. 按 **Commit**。第一次 commit 前，VS Code 可能要求確認 Git 作者資料；回到前面的 Git 設定步驟完成後再試。
6. 按 **Publish Branch**（第一次）或 **Sync Changes**／**Push**（後續）。確認顯示的是你的 `ui/...` 或 `fix/...` 分支，絕不是 `main`。
7. 若按鈕顯示 `Commit & Push`，仍要先點開 Staged Changes 看完內容再按。

### E. 在 GitHub 建立 Pull Request

Push 成功後：

1. VS Code 通常會跳出「Create Pull Request」通知，可以點它；或回 GitHub repo 頁面，按 **Compare & pull request**。
2. 確認 **base** 是 `main`，**compare** 是你自己的 `ui/...` 或 `fix/...` branch。不要把 base 改成別人的分支。
3. PR 標題格式使用 `類型(範圍): 繁中說明`，例如：`feat(app): 調整首頁標題層級`。
4. GitHub 會自動帶入 repo 的 PR 範本。保留範本段落並誠實填寫；沒有做的檢查不要勾選。
5. 確認 Files changed 只有自己的前端檔案、必要測試或老師要求的文件。再次確認沒有 `.env`、憑證、帳號資料、log 或 build。
6. 按 **Create pull request**，在團隊約定的管道通知老師／reviewer。

可直接複製並依實際情況改寫的 PR 內容：

```markdown
## 目的

調整首頁預算區塊的標題層級，讓手機與桌面閱讀更清楚。

## 變更範圍

- `app/lib/features/dashboard/dashboard_screen.dart`：調整標題與間距。
- 未修改後端、資料庫、部署、套件或 API。

## 驗證

- [x] Chrome 訪客模式：檢查 375px、768px、1024px 寬度與亮／暗主題。
- [x] `dart format --output=none --set-exit-if-changed lib test integration_test`
- [x] `flutter analyze`
- [x] `flutter test`
- [x] 未包含秘密、`.env`、憑證、個資、內部／合約／商業文件。

## 風險與部署

- 僅調整前端呈現；未變更 API、資料、權限或部署。
- 未連共用測試 API；登入與保存流程未在本機測試，已用訪客模式確認 UI。
```

### F. PR 之後由誰合併？

學生的權限是建立 branch、push branch 與開 PR；**不要自行 merge，也不要想辦法繞過 main 保護規則**。老師或被指定的維護者會看 review、檢查結果與畫面後合併。PR 被合併前，不要刪除自己的 branch；合併後再依「每日收工」中的清理步驟整理本機。

## 處理 review、同步 main 與 rebase

### 收到 review 意見時

1. 打開原本那一張 PR，讀完所有 review 留言與 GitHub 檢查結果。
2. 回到**同一個 branch**，不要重新 clone、不要另開一張 PR：

   ```bash
   git switch ui/dashboard-heading
   git status --short --branch
   ```

3. 按留言修改、在 Chrome 檢查，再執行相關測試。
4. 逐檔 `git add`、檢查 staged diff、commit、`git push`。新 commit 會自動加入原本的 PR。
5. 在 GitHub 留言簡短回覆：改了什麼、如何驗證；若不同意或不懂，具體說明原因並問 reviewer，不要假裝已完成。

### main 有新變更時，先用 GitHub 按鈕更新（沒有衝突時最簡單）

PR 頁面若出現 **Update branch** 按鈕，且老師說可以更新，就按它。GitHub 會把最新 `main` 合入／更新你的 PR。更新後重新拉下本機 branch，並再看一次畫面與測試：

```bash
git switch ui/dashboard-heading
git pull --ff-only origin ui/dashboard-heading
```

如果 GitHub 沒有 Update branch、需要保持線性歷史，或老師指定使用 rebase，改用下一節的終端機流程。

### 用 rebase 同步最新 main（請慢慢做）

Rebase 是把你的 commit 重新接到最新 `main` 後面。它只應用在**你自己的尚未合併分支**。

1. 先確定所有修改已 commit 或已由老師確認可暫停；工作區不乾淨時不要 rebase：

   ```bash
   git status --short --branch
   git switch ui/dashboard-heading
   git fetch origin
   git rebase origin/main
   ```

2. 若 Git 顯示成功，執行 `flutter analyze`、`flutter test`，再將 rebase 後的 branch 推回 GitHub。因 commit 的歷史已改寫，所以這一次只能在自己的 branch 使用較安全的 force-with-lease：

   ```bash
   git push --force-with-lease origin ui/dashboard-heading
   ```

   `--force-with-lease` 仍會先檢查遠端是否有你沒看過的新內容；**不要改成 `--force`，更不能對 `main` 使用它**。

3. 若出現 conflict：VS Code 會在 Source Control 顯示衝突檔案，也可能開啟 Merge Editor。逐段看「目前 main 的內容」與「你的修改」，只保留兩者都需要的正確結果。不能判斷時不要亂選，先請老師協助。
4. 解完每個衝突後儲存，明確加入已修好的檔案，再繼續：

   ```bash
   git status
   git add <已確認修好的檔案路徑>
   git rebase --continue
   ```

   可能會重複出現衝突；每次都重複「確認內容 → 儲存 → `git add` → `git rebase --continue`」。
5. 如果發現方向不對、內容不確定，安全地回到 rebase 前的狀態：

   ```bash
   git rebase --abort
   ```

   然後把 `git status` 結果告訴老師。不要使用 `git rebase --skip` 跳過不懂的 commit。

## 常見問題排除

### `flutter: command not found`、找不到 Flutter SDK

1. 完全關閉 VS Code，重新開啟。
2. 在 VS Code 開 Command Palette：`Flutter: Change SDK`，確認選的是 Flutter SDK 根資料夾，不是 `bin` 資料夾，也不是 FutureMint_AI 專案資料夾。
3. 開新終端機再輸入 `flutter doctor`。
4. 還是不行時，截圖 Flutter extension 與 `flutter doctor` 結果問老師；不要隨機下載多個 Flutter 版本。

### `flutter devices` 沒有 Chrome

確認 Chrome 已安裝、可正常開啟；完整關閉並重開 VS Code 後再執行：

```bash
flutter devices
```

本專案不要求 Android 模擬器。不要因為找不到 Chrome 就去安裝 Docker、Android Studio 或 Xcode。

### `flutter pub get` 失敗

先確認網路可用、目前在 `FutureMint_AI/app`，再重試一次：

```bash
flutter pub get
```

不要手動下載套件、不要刪除 `pubspec.lock`、不要執行 `flutter pub upgrade`。如果錯誤持續，把第一段完整錯誤文字與 Flutter 版本交給老師。

### `4173` port 已被使用

先在另一個 VS Code 終端機確認是否有舊的 `flutter run` 正在執行，回到它按 `q`。若確實需要另一個前端預覽 port，可用：

```bash
flutter run -d chrome --web-port=4174
```

這樣只適合訪客模式 UI 檢查。若你要連老師提供的 API，請先通知老師新的 origin 是 `http://localhost:4174`，因為後端 CORS 必須明確允許它；不要自行改後端設定。

### 登入、註冊或保存資料失敗

學生沒有啟動後端時，這是預期行為。回登入頁按 **「以訪客模式繼續」** 做 UI 驗證。若老師提供測試 API，確認 `API_BASE_URL` 是老師給的完整公開值且以 `/api/` 結尾；不要嘗試下載 Docker、建立資料庫或尋找秘密。

### 修改後 Chrome 畫面沒有變

確認檔案已儲存，回 `flutter run` 終端機按 `r`；仍不行按 `R`，最後使用 Chrome 強制重新整理 `⌘⇧R`／`Ctrl+Shift+R`。若是編譯錯誤，先看終端機最前面的紅色錯誤與檔案行號。

### `git push` 被拒絕

先確認沒有要直接推 `main`：

```bash
git branch --show-current
git status --short --branch
```

如果你在自己的 branch，可能是 `main` 已更新或你剛做 rebase。依本文件的「同步 main 與 rebase」處理；不要改成推送 `main`，也不要用裸 `--force`。

### Git 顯示 conflict 或我看到不認識的修改

停止操作，執行：

```bash
git status
git diff
```

把結果和你剛剛做的事情告訴老師。不要使用 `git reset --hard`、`git clean`、`git rebase --skip`，也不要在不懂時按 VS Code 的 Discard Changes。

## 每日開工與收工清單

### 每日開工：新任務

1. 開啟 VS Code，選 **File → Open Folder…**，選自己的 `FutureMint_AI` 資料夾。
2. 開終端機，確認位置在 repo 根目錄，先看是否乾淨：

   ```bash
   git status --short --branch
   ```

3. 沒有未完成修改時，更新主線並開新 branch：

   ```bash
   git switch main
   git pull --ff-only origin main
   git switch -c ui/<英文短任務名稱>
   ```

4. 進入前端、安裝（第一次或套件更新後）並啟動：

   ```bash
   cd app
   flutter pub get
   flutter run -d chrome --web-port=4173
   ```

5. 在 Chrome 按「以訪客模式繼續」，確認起始畫面正常，再開始做被分配的任務。

### 每日開工：繼續自己的既有 PR

1. 不要重新開 branch；切回自己的 branch：

   ```bash
   git switch ui/<你原本的分支名稱>
   git status --short --branch
   ```

2. 若老師要求同步最新 `main`，依「同步 main 與 rebase」章節先更新；不要把別人的修改直接複製貼上。
3. 進入 `app` 執行 `flutter run -d chrome --web-port=4173`，在訪客模式檢查後繼續。

### 每日收工：尚未準備交 PR

1. 在 `app` 先完成畫面檢查與可執行的測試。
2. 回 repo 根目錄檢查差異：

   ```bash
   cd ..
   git status --short --branch
   git diff
   ```

3. 需要保留一段已完成的小進度時，逐檔 stage、查看 `git diff --cached`、commit，再 `git push` 到自己的 branch。不要在不懂差異時 commit。
4. 若尚未能安全 commit，就保留本機修改、在團隊管道說明做到哪裡；不要為了收工而把半成品推到 `main`。
5. 回正在跑 Flutter 的終端機按 `q` 停止預覽。

### PR 已合併後的本機整理

收到老師確認 PR 已合併後，再執行：

```bash
git switch main
git pull --ff-only origin main
git branch -d ui/<已合併的分支名稱>
```

只刪除已確定合併、且自己不再需要的本機 branch；不要使用 `git branch -D`。下一個獨立任務再從最新 `main` 開新 branch。

---

需要知道前端實際技術、品質指令或 API 邊界時，請再讀 [Flutter Client README](../app/README.md)、[Design System](../design/README.md) 與根目錄的 [團隊開發規則](../AGENTS.md)。如果本教學與老師的任務分配衝突，以老師的明確指示為準。
