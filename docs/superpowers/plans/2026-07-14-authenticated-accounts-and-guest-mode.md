# Authenticated Accounts and Guest Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide email/password accounts with server-enforced data ownership, transient guest access, and login/onboarding UI across Flutter and Azure Functions.

**Architecture:** Functions own account credentials and opaque sessions. Each protected handler derives `userId` from a Bearer token before calling the existing domain service. Flutter persists only the opaque session token, constructs an authenticated repository after `GET /auth/me`, and uses an in-memory guest repository when the user explicitly chooses guest mode.

**Tech Stack:** Flutter 3.41/Dart 3.11, Provider, go_router, SharedPreferences, Node.js 22 crypto, Azure Functions v4, TypeScript, Zod, Vitest, Cosmos DB.

## Global Constraints

- Never store, log, return, commit, or expose passwords, raw session tokens, salts, hashes, Azure secrets, or real student data.
- Use Node.js `scrypt` with a random 16-byte salt; require a 12–128 character password containing a letter and a number.
- Use a random 32-byte opaque token; store only its SHA-256 hash and expire sessions after seven days.
- All protected API handlers must use a server-derived user ID; no request body, query parameter, or Flutter model may select a data owner.
- Guest data must remain in Dart memory only and be discarded on page refresh, sign-out, or mode change.
- No commit, branch, push, PR, Azure resource creation, or deployment is authorized.
- Preserve explicit network failure behaviour: a failed request must not appear to save data.

---

### Task 1: Define and test the server identity domain

**Files:**
- Create: `services/api/src/auth/authService.ts`
- Create: `services/api/test/auth/authService.test.ts`
- Modify: `services/api/src/contracts/models.ts`
- Modify: `services/api/src/contracts/schemas.ts`
- Modify: `services/api/src/application/ports.ts`

**Interfaces:**
- Produces `Account`, `PublicAccount`, `SessionRecord`, `AuthRepository`, and `AuthService`.
- `AuthService.register(input): Promise<AuthResult>` creates an account and session.
- `AuthService.login(input): Promise<AuthResult>` validates an account and creates a session.
- `AuthService.authenticate(token): Promise<PublicAccount>` validates an active session.
- `AuthService.logout(token): Promise<void>` revokes a session.

- [ ] **Step 1: Write failing auth-service tests**

```ts
it("creates a session without exposing password fields", async () => {
  const result = await service.register({
    email: "student@example.com",
    password: "futuremint2026",
  });

  expect(result.account.email).toBe("student@example.com");
  expect(result.account).not.toHaveProperty("passwordHash");
  await expect(service.authenticate(result.token)).resolves.toMatchObject({
    email: "student@example.com",
    profileComplete: false,
  });
});

it("rejects a token after logout", async () => {
  const { token } = await service.register({
    email: "student@example.com",
    password: "futuremint2026",
  });
  await service.logout(token);
  await expect(service.authenticate(token)).rejects.toMatchObject({
    code: "unauthorized",
  });
});
```

- [ ] **Step 2: Verify tests fail**

Run: `npm test -- authService.test.ts`

Expected: FAIL because the auth contracts and service do not exist.

- [ ] **Step 3: Implement minimum contracts, schemas, and AuthService**

```ts
export interface AuthRepository {
  findAccountByEmail(email: string): Promise<Account | null>;
  createAccount(account: Account): Promise<Account>;
  setProfileComplete(userId: string): Promise<void>;
  createSession(session: SessionRecord): Promise<void>;
  findSessionByTokenHash(tokenHash: string): Promise<SessionRecord | null>;
  revokeSession(tokenHash: string): Promise<void>;
}

const token = randomBytes(32).toString("base64url");
const tokenHash = createHash("sha256").update(token).digest("base64url");
const salt = randomBytes(16).toString("base64url");
const passwordHash = await scryptAsync(password, salt, 64).then((value) =>
  value.toString("base64url"),
);
```

Validate `email` with `z.string().trim().email().max(254)` and normalize it with `toLowerCase()`. Return one generic `invalid_credentials` 401 error for invalid login credentials. Implement password comparison with `timingSafeEqual`.

- [ ] **Step 4: Verify auth-service tests pass**

Run: `npm test -- authService.test.ts`

Expected: PASS.

### Task 2: Add account/session persistence to Memory and Cosmos adapters

**Files:**
- Modify: `services/api/src/adapters/inMemoryRepository.ts`
- Modify: `services/api/src/adapters/cosmosRepository.ts`
- Create: `services/api/test/adapters/authRepository.test.ts`

**Interfaces:**
- `InMemoryRepository` implements both `FutureMintRepository` and `AuthRepository` with maps keyed by normalized email, user ID, and token hash.
- `CosmosRepository` implements `AuthRepository` using `accounts` and `sessions` containers.

- [ ] **Step 1: Write failing adapter isolation tests**

```ts
it("keeps accounts and sessions independent", async () => {
  await repository.createAccount(accountA);
  await repository.createAccount(accountB);
  await repository.createSession(sessionA);

  expect(await repository.findAccountByEmail("a@example.com")).toMatchObject({
    id: accountA.id,
  });
  expect(await repository.findSessionByTokenHash(sessionA.tokenHash)).toEqual(sessionA);
  expect(await repository.findSessionByTokenHash("not-a-session")).toBeNull();
});
```

- [ ] **Step 2: Verify tests fail**

Run: `npm test -- authRepository.test.ts`

Expected: FAIL because the adapters do not implement `AuthRepository`.

- [ ] **Step 3: Implement adapter methods**

```ts
private accountsByEmail = new Map<string, Account>();
private accountsById = new Map<string, Account>();
private sessions = new Map<string, SessionRecord>();

async findSessionByTokenHash(tokenHash: string) {
  const session = this.sessions.get(tokenHash);
  if (!session || new Date(session.expiresAt) <= new Date()) return null;
  return { ...session };
}
```

For Cosmos, write account records as `{ id: account.id, ...account }` to `accounts` and session records as `{ id: session.tokenHash, ...session }` to `sessions`. Query account email with a parameterized `@normalizedEmail` query. Do not auto-create containers.

- [ ] **Step 4: Verify adapter tests pass**

Run: `npm test -- authRepository.test.ts`

Expected: PASS.

### Task 3: Add auth routes and protect every personal API route

**Files:**
- Create: `services/api/src/http/authentication.ts`
- Create: `services/api/src/functions/auth.ts`
- Modify: `services/api/src/http/runtime.ts`
- Modify: `services/api/src/http/responses.ts`
- Modify: `services/api/src/functions/profile.ts`
- Modify: `services/api/src/functions/moneyEvents.ts`
- Modify: `services/api/src/functions/captures.ts`
- Modify: `services/api/src/functions/dashboard.ts`
- Modify: `services/api/src/functions/lessons.ts`
- Modify: `services/api/src/functions/subscriptions.ts`
- Modify: `services/api/src/functions/futureSeed.ts`
- Modify: `services/api/src/functions/demo.ts`
- Modify: `services/api/src/index.ts`
- Create: `services/api/test/functions/auth.test.ts`
- Modify: existing route tests under `services/api/test/functions/`

**Interfaces:**
- `requireAuthenticatedUser(request, runtime): Promise<PublicAccount>` reads exactly one `Bearer <token>` header and rejects missing, malformed, expired, or revoked tokens with `DomainError("unauthorized", ..., 401)`.
- Runtime exposes `authService` as well as `service`.

- [ ] **Step 1: Write failing HTTP tests**

```ts
it("requires Bearer authentication before returning money events", async () => {
  const response = await listMoneyEventsHandler(requestWithoutAuthorization, context);
  expect(response.status).toBe(401);
});

it("uses the authenticated subject instead of demo-user", async () => {
  const response = await listMoneyEventsHandler(requestFor(accountAToken), context);
  expect(response.status).toBe(200);
  expect(response.jsonBody?.data).toEqual([]);
});
```

- [ ] **Step 2: Verify tests fail**

Run: `npm test -- auth.test.ts`

Expected: FAIL because handlers still pass `"demo-user"`.

- [ ] **Step 3: Implement authentication middleware and routes**

```ts
const authorization = request.headers.get("authorization");
const token = authorization?.match(/^Bearer ([A-Za-z0-9_-]{32,})$/)?.[1];
if (!token) throw new DomainError("unauthorized", "請先登入後再繼續。", 401);
return runtime.authService.authenticate(token);
```

Register `POST auth/register`, `POST auth/login`, `POST auth/logout`, and `GET auth/me`. Require authentication for profile, money events, captures, dashboard, lessons, subscriptions, and FutureSeed. Remove the demo reset route. Set `profileComplete` after successful `PUT profile`. Add `authorization` to CORS allow headers.

- [ ] **Step 4: Verify route tests pass**

Run: `npm test -- auth.test.ts`

Expected: PASS; tests demonstrate account A cannot read account B data.

### Task 4: Implement client auth API, token storage, and authenticated repository headers

**Files:**
- Create: `apps/client/lib/auth/auth_models.dart`
- Create: `apps/client/lib/auth/auth_api.dart`
- Create: `apps/client/lib/auth/session_store.dart`
- Modify: `apps/client/lib/data/api_repository.dart`
- Create: `apps/client/test/auth/auth_api_test.dart`
- Modify: `apps/client/test/data/api_repository_test.dart`

**Interfaces:**
- `AuthApi.register(email, password)`, `login(email, password)`, `logout(token)`, `me(token)`.
- `SessionStore.readToken()`, `writeToken(token)`, `clearToken()` use one versioned SharedPreferences key and no account data.
- `ApiRepository(accessToken: token)` adds `authorization: Bearer <token>` to every request.

- [ ] **Step 1: Write failing Flutter auth tests**

```dart
test('authenticated repository sends a Bearer token', () async {
  final repository = ApiRepository(
    baseUri: Uri.parse('https://example.test/api/'),
    accessToken: 'token-value',
    client: recordingClient,
  );

  await repository.getProfile();
  expect(recordingClient.lastHeaders['authorization'], 'Bearer token-value');
});
```

- [ ] **Step 2: Verify tests fail**

Run: `flutter test test/auth/auth_api_test.dart test/data/api_repository_test.dart`

Expected: FAIL because auth API, token store, and `accessToken` do not exist.

- [ ] **Step 3: Implement the auth client**

```dart
final headers = <String, String>{
  'content-type': 'application/json',
  if (accessToken != null) 'authorization': 'Bearer $accessToken',
};
```

Map 401 to `ApiException(code: 'unauthorized', message: '登入已過期，請重新登入。', retryable: false)`. Never persist email, profile, event, lesson, or capture text in `SessionStore`.

- [ ] **Step 4: Verify Flutter auth tests pass**

Run: `flutter test test/auth/auth_api_test.dart test/data/api_repository_test.dart`

Expected: PASS.

### Task 5: Add transient guest repository and session state controller

**Files:**
- Create: `apps/client/lib/data/guest_repository.dart`
- Create: `apps/client/lib/state/session_controller.dart`
- Modify: `apps/client/lib/state/app_controller.dart`
- Modify: `apps/client/lib/main.dart`
- Create: `apps/client/test/state/session_controller_test.dart`

**Interfaces:**
- `GuestRepository.create()` returns a repository whose profile, event, lesson, and parse state live only in Dart object fields.
- `SessionController` exposes `SessionStatus { loading, signedOut, authenticated, onboarding, guest }`, `AppController? app`, `PublicAccount? account`, `start()`, `login()`, `register()`, `continueAsGuest()`, `logout()`.

- [ ] **Step 1: Write failing state tests**

```dart
test('guest mode never writes a session token', () async {
  await controller.continueAsGuest();
  expect(controller.status, SessionStatus.guest);
  expect(await sessionStore.readToken(), isNull);
});

test('an account without a profile enters onboarding', () async {
  fakeAuth.meResult = account.copyWith(profileComplete: false);
  await controller.login('student@example.com', 'futuremint2026');
  expect(controller.status, SessionStatus.onboarding);
});
```

- [ ] **Step 2: Verify tests fail**

Run: `flutter test test/state/session_controller_test.dart`

Expected: FAIL because session state and guest repository do not exist.

- [ ] **Step 3: Implement no-persistence guest and session orchestration**

Use in-memory lists/maps in `GuestRepository`; do not import SharedPreferences there. Build an `ApiRepository` only after `AuthApi` succeeds. On network errors, retain `SessionStatus.signedOut` and surface the API error message. When switching/ending access, clear old AppController state before exposing the next repository.

- [ ] **Step 4: Verify state tests pass**

Run: `flutter test test/state/session_controller_test.dart`

Expected: PASS.

### Task 6: Add login, registration, onboarding, and protected routing UI

**Files:**
- Create: `apps/client/lib/features/auth/auth_screen.dart`
- Create: `apps/client/lib/features/auth/onboarding_screen.dart`
- Modify: `apps/client/lib/app/future_mint_app.dart`
- Modify: `apps/client/lib/app/app_router.dart`
- Modify: `apps/client/lib/app/app_shell.dart`
- Create: `apps/client/test/features/auth_screen_test.dart`
- Modify: `apps/client/test/widget_test.dart`

**Interfaces:**
- `/auth` is public; `/onboarding` is only for `SessionStatus.onboarding`; existing shell routes only exist for authenticated or guest state.
- Login screen calls `SessionController.login`; registration screen calls `SessionController.register`; guest button calls `continueAsGuest`.

- [ ] **Step 1: Write failing route and form tests**

```dart
testWidgets('blocks a signed-out user from the dashboard', (tester) async {
  await tester.pumpWidget(testApp(status: SessionStatus.signedOut));
  expect(find.text('登入 FutureMint'), findsOneWidget);
  expect(find.text('今天的金錢節奏'), findsNothing);
});

testWidgets('labels guest data as temporary', (tester) async {
  await tester.pumpWidget(testApp(status: SessionStatus.guest));
  expect(find.text('訪客資料不會儲存'), findsWidgets);
});
```

- [ ] **Step 2: Verify tests fail**

Run: `flutter test test/features/auth_screen_test.dart test/widget_test.dart`

Expected: FAIL because auth routes and screens do not exist.

- [ ] **Step 3: Implement the responsive auth flow**

The auth screen has semantic text labels for email, password, password visibility, submit state, error region, and guest mode. Reuse `SoftCard`, `PageHeading`, `MoneyBuddy`, black primary CTA, and existing phone/desktop gutters. Onboarding reuses the validated profile fields and writes through the authenticated repository. GoRouter redirects from protected routes to `/auth` or `/onboarding` based on `SessionController`.

- [ ] **Step 4: Verify UI tests pass**

Run: `flutter test test/features/auth_screen_test.dart test/widget_test.dart`

Expected: PASS at 375px and desktop sizes with no layout exception.

### Task 7: Replace offline-demo UI with account and guest controls

**Files:**
- Modify: `apps/client/lib/features/settings/settings_sheet.dart`
- Modify: `apps/client/lib/app/app_shell.dart`
- Modify: `apps/client/lib/core/models.dart`
- Delete: `apps/client/lib/data/demo_repository.dart`
- Modify: tests that assert `offline-demo` or `demo-user`

**Interfaces:**
- App shell presents `訪客模式` with the non-persistence explanation, or the authenticated account email with a logout action.
- Settings exposes account status, profile edit, and logout; it no longer changes repositories or resets demo data.

- [ ] **Step 1: Write failing settings tests**

```dart
testWidgets('shows logout for a signed-in account', (tester) async {
  await tester.pumpWidget(testApp(status: SessionStatus.authenticated));
  await tester.tap(find.byTooltip('設定'));
  await tester.pumpAndSettle();
  expect(find.text('登出'), findsOneWidget);
  expect(find.textContaining('離線展示'), findsNothing);
});
```

- [ ] **Step 2: Verify tests fail**

Run: `flutter test test/widget_test.dart`

Expected: FAIL because settings still shows Offline demo controls.

- [ ] **Step 3: Implement account-aware shell and settings**

Remove `AppMode.offlineDemo`, all switching, reset copy, and the DemoRepository import. Keep user-facing network errors through the existing message surface. Ensure guest mode exit deletes transient controller/repository objects only.

- [ ] **Step 4: Verify settings tests pass**

Run: `flutter test test/widget_test.dart`

Expected: PASS.

### Task 8: Synchronize docs, environment templates, and final verification

**Files:**
- Modify: `README.md`
- Modify: `apps/client/README.md`
- Modify: `services/api/README.md`
- Modify: `services/api/.env.example`
- Modify: `docs/architecture.md`
- Modify: `docs/security-and-privacy.md`
- Modify: `docs/data-and-storage.md`
- Modify: `docs/integrations.md`
- Modify: `docs/testing-and-evidence.md`

- [ ] **Step 1: Add runtime and storage documentation**

Document `AUTH_SESSION_DAYS=7` as a non-secret optional setting, `accounts`/`sessions` manually provisioned Cosmos containers, `Authorization` CORS header, guest non-persistence, and the remaining security/legal limitations. Remove claims that the current product has no login or only has `demo-user` data.

- [ ] **Step 2: Run backend verification**

Run: `npm test && npm run typecheck && npm run build`

Expected: all tests pass, TypeScript emits no errors, Functions build succeeds.

- [ ] **Step 3: Run Flutter verification**

Run: `dart format --output=none --set-exit-if-changed lib test integration_test && flutter analyze && flutter test && flutter build web --release`

Expected: no formatting changes, analyzer reports no issues, all tests pass, and the Web release build succeeds.

- [ ] **Step 4: Run browser QA**

Verify register validation, login failure, successful register → onboarding → dashboard, logout, token-expiry redirect, visitor banner, and 375/768/1440px visual layouts. Check browser console for errors and record only completed checks in `docs/testing-and-evidence.md`.
