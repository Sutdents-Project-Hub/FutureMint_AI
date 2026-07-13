# FutureMint AI Competition MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the approved, testable Flutter + Azure Functions competition MVP with Connected and explicit Offline demo modes.

**Architecture:** Keep financial calculations and contracts deterministic, expose them through Azure Functions v4, and isolate Azure OpenAI/Cosmos behind ports. The Flutter client uses feature-focused screens and a repository abstraction so the same journey works against the API or a clearly labeled local demo provider.

**Tech Stack:** Flutter 3.41/Dart 3.11, Material 3, Provider, go_router, http, shared_preferences, intl, Azure Functions v4, TypeScript/Node.js 22, Zod, Vitest, Azure OpenAI, Cosmos DB.

## Global Constraints

- Use only synthetic data or consented de-identified data; never log full financial text.
- Store money as positive integer `amountMinor` in TWD; AI never performs authoritative arithmetic.
- Connected failures never silently substitute demo results; Offline demo requires an explicit user-visible mode.
- Client code never contains Azure OpenAI or Cosmos secrets.
- Do not create Azure resources, deploy, commit, push, or open a PR without separate user authorization.
- All human-readable product copy and project documentation use Traditional Chinese.
- UI follows `design-system/futuremint-ai/MASTER.md`, including 48dp targets, semantic colors, light/dark themes, responsive navigation, and accessible error recovery.

---

### Task 1: Functions contracts and deterministic finance domain

**Files:**
- Modify: `services/api/package.json`
- Modify: `services/api/tsconfig.json`
- Create: `services/api/src/contracts/models.ts`
- Create: `services/api/src/contracts/schemas.ts`
- Create: `services/api/src/contracts/errors.ts`
- Create: `services/api/src/domain/budget.ts`
- Create: `services/api/src/domain/futureSeed.ts`
- Create: `services/api/src/domain/subscriptions.ts`
- Create: `services/api/test/domain/budget.test.ts`
- Create: `services/api/test/domain/futureSeed.test.ts`
- Create: `services/api/test/domain/subscriptions.test.ts`

**Interfaces:**
- Produces: `MoneyEvent`, `UserProfile`, `DashboardSummary`, `FutureSeedPreview`, `SubscriptionComparison`, and Zod request schemas.
- Produces: `calculateDashboard(profile, events, now)`, `calculateFutureSeed(input)`, and `compareSubscription(input, catalog)` pure functions.

- [ ] **Step 1: Add the test and validation toolchain**

Run:

```bash
cd services/api
npm install zod
npm install --save-dev vitest
```

Add scripts: `test: vitest run`, `test:watch: vitest`, `typecheck: tsc --noEmit`, while retaining the existing build/start scripts.

- [ ] **Step 2: Write failing deterministic domain tests**

Cover exact examples:

```ts
expect(calculateFutureSeed({ monthlyContributionMinor: 100000, years: 1, annualRatePercent: 0 }).endingBalanceMinor).toBe(1200000);
expect(calculateDashboard(profile, events, new Date('2026-07-13T00:00:00+08:00')).availableMinor).toBe(256500);
expect(compareSubscription(input, catalog).options[0].monthlyCostMinor).toBeLessThan(compareSubscription(input, catalog).currentMonthlyCostMinor);
```

Run `npm test`; expect failure because the domain modules do not exist.

- [ ] **Step 3: Define exact models and schemas**

Use string unions for `income|expense|subscription`, controlled categories, ISO strings, positive integer money, maximum five drafts, and `ApiProblem` with `code`, `message`, `requestId`, `retryable`, and optional `fieldErrors`.

- [ ] **Step 4: Implement pure calculations**

Implement monthly budget aggregation, split handling, recurring monthly cost conversion, subscription option sorting, and ordinary-annuity FutureSeed including the zero-rate branch and yearly points.

- [ ] **Step 5: Verify Task 1**

Run:

```bash
npm test
npm run typecheck
npm run build
```

Expected: all domain tests pass, TypeScript emits no errors, and `dist` is generated.

### Task 2: Repository ports, demo AI, application service, and HTTP API

**Files:**
- Create: `services/api/src/application/ports.ts`
- Create: `services/api/src/application/futureMintService.ts`
- Create: `services/api/src/adapters/inMemoryRepository.ts`
- Create: `services/api/src/adapters/demoAiProvider.ts`
- Create: `services/api/src/adapters/demoCatalog.ts`
- Create: `services/api/src/http/responses.ts`
- Create: `services/api/src/http/runtime.ts`
- Create: `services/api/src/functions/health.ts`
- Create: `services/api/src/functions/profile.ts`
- Create: `services/api/src/functions/captures.ts`
- Create: `services/api/src/functions/moneyEvents.ts`
- Create: `services/api/src/functions/dashboard.ts`
- Create: `services/api/src/functions/subscriptions.ts`
- Create: `services/api/src/functions/lessons.ts`
- Create: `services/api/src/functions/futureSeed.ts`
- Create: `services/api/src/functions/demo.ts`
- Modify: `services/api/src/index.ts`
- Create: `services/api/test/application/futureMintService.test.ts`
- Create: `services/api/test/http/functions.test.ts`

**Interfaces:**
- Produces: `AiProvider.parseCapture()` and `AiProvider.generateLesson()`.
- Produces: `FutureMintRepository` profile/event/lesson operations with userId and idempotency boundaries.
- Produces: all `/api` routes in the approved design.

- [ ] **Step 1: Write failing service tests**

Tests must prove that parse creates no event, save requires a confirmed payload, duplicate idempotency keys return the original event, dashboard uses confirmed events, and reset is disabled when `DEMO_RESET_ENABLED=false`.

- [ ] **Step 2: Implement ports and in-memory adapters**

Use a `Map` keyed by userId and preserve deterministic fixture order. Seed the profile, income, drinks, game, and subscription events for `demo-user` without names or real account data.

- [ ] **Step 3: Implement deterministic Traditional Chinese parsing**

Support examples including `打工薪水 1500`, `今天買珍奶 75`, `Netflix 390，四個人分`, `Spotify 下個月要扣 149`, missing amount, non-financial text, and `本來想買耳機 3000，但沒有買`. Every output identifies `source: deterministic-demo`.

- [ ] **Step 4: Implement application use cases**

Parse, confirm/save, list, dashboard, compare, lesson, preview, and reset all validate through the same Zod contracts and never persist original capture text.

- [ ] **Step 5: Register and test Functions v4 routes**

Handlers parse `request.json()`, map known domain errors to the unified problem format, set JSON content type and configured CORS, and never expose stacks or environment values.

- [ ] **Step 6: Verify Task 2**

Run `npm test && npm run typecheck && npm run build`; expected all service and handler tests pass.

### Task 3: Azure OpenAI and Cosmos adapters

**Files:**
- Modify: `services/api/package.json`
- Modify: `services/api/.env.example`
- Create: `services/api/src/adapters/azureOpenAiProvider.ts`
- Create: `services/api/src/adapters/cosmosRepository.ts`
- Modify: `services/api/src/http/runtime.ts`
- Create: `services/api/test/adapters/azureOpenAiProvider.test.ts`
- Create: `services/api/test/adapters/cosmosRepository.test.ts`

**Interfaces:**
- Consumes: `AiProvider`, `FutureMintRepository`, and shared Zod schemas from Tasks 1–2.
- Produces: provider selection using `AI_PROVIDER=azure|demo` and `DATA_PROVIDER=cosmos|memory`.

- [ ] **Step 1: Install official Azure dependencies**

```bash
npm install openai @azure/identity @azure/cosmos
```

- [ ] **Step 2: Write failing adapter tests**

Inject fake chat and Cosmos clients. Cover valid structured output, invalid schema, timeout, 429 retry budget, partition-scoped reads, idempotency conflict, and sanitized logging.

- [ ] **Step 3: Implement Azure OpenAI adapter**

Use the configured endpoint/deployment/API version, `DefaultAzureCredential` token provider when no key is supplied, strict JSON Schema response format, 8-second per-call timeout, 12-second total budget, and one bounded retry.

- [ ] **Step 4: Implement Cosmos repository**

Use containers `profiles`, `moneyEvents`, and `learning`, partition key `/userId`, parameterized queries, and a deterministic idempotency document key. Never create cloud resources automatically.

- [ ] **Step 5: Add safe environment index and runtime validation**

Add names only: `AI_PROVIDER`, `DATA_PROVIDER`, `DEMO_RESET_ENABLED`, and optional `AZURE_OPENAI_API_KEY` for environments where Managed Identity is unavailable. Invalid/missing mode settings produce an explicit startup error.

- [ ] **Step 6: Verify Task 3**

Run all API tests, typecheck, build, and `npm audit --omit=dev`; record results without claiming live Azure connectivity.

### Task 4: Flutter foundation, models, repositories, and state

**Files:**
- Modify: `apps/client/pubspec.yaml`
- Replace: `apps/client/lib/main.dart`
- Create: `apps/client/lib/app/future_mint_app.dart`
- Create: `apps/client/lib/app/app_router.dart`
- Create: `apps/client/lib/app/app_shell.dart`
- Create: `apps/client/lib/design/theme.dart`
- Create: `apps/client/lib/design/tokens.dart`
- Create: `apps/client/lib/core/models.dart`
- Create: `apps/client/lib/core/future_mint_repository.dart`
- Create: `apps/client/lib/data/api_repository.dart`
- Create: `apps/client/lib/data/demo_repository.dart`
- Create: `apps/client/lib/state/app_controller.dart`
- Create: `apps/client/test/core/models_test.dart`
- Create: `apps/client/test/data/demo_repository_test.dart`
- Create: `apps/client/test/state/app_controller_test.dart`

**Interfaces:**
- Produces: client equivalents of API contracts and `FutureMintRepository` methods.
- Produces: `AppController` state/actions for profile, dashboard, events, capture, subscriptions, lessons, FutureSeed, errors, and mode switching.

- [ ] **Step 1: Add client dependencies**

```bash
flutter pub add provider go_router http shared_preferences intl
```

- [ ] **Step 2: Write failing model, repository, and state tests**

Cover JSON round trips, TWD/Asia-Taipei formatting, demo seed persistence, explicit provider source, parse without save, idempotent save, error preservation, reset, and connected-to-demo mode switching.

- [ ] **Step 3: Implement models and repository contract**

Manual immutable models expose `fromJson/toJson`, controlled enums, integer money, and copy helpers. No generated code is required.

- [ ] **Step 4: Implement API and local demo repositories**

API repository uses a 12-second timeout and maps `ApiProblem`; demo repository uses SharedPreferences JSON, seeded synthetic fixtures, and the same deterministic parser semantics as the API.

- [ ] **Step 5: Implement app state and bootstrap**

Default `APP_MODE` is `offline-demo` for a runnable no-secret checkout. `connected` requires a non-empty `API_BASE_URL`. Controller actions expose loading and recoverable errors without hiding existing data.

- [ ] **Step 6: Implement theme and routing foundation**

Create light/dark Material 3 themes from the curated teal/amber tokens, 48dp controls, responsive bottom navigation/NavigationRail, and deep-linkable paths `/`, `/records`, `/capture`, `/learning`, `/future-seed`.

- [ ] **Step 7: Verify Task 4**

Run `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, and targeted tests; expected all pass.

### Task 5: Complete Flutter product screens

**Files:**
- Create: `apps/client/lib/features/dashboard/dashboard_screen.dart`
- Create: `apps/client/lib/features/dashboard/widgets/budget_hero.dart`
- Create: `apps/client/lib/features/capture/capture_screen.dart`
- Create: `apps/client/lib/features/capture/draft_editor.dart`
- Create: `apps/client/lib/features/records/records_screen.dart`
- Create: `apps/client/lib/features/subscriptions/subscription_coach.dart`
- Create: `apps/client/lib/features/learning/learning_screen.dart`
- Create: `apps/client/lib/features/future_seed/future_seed_screen.dart`
- Create: `apps/client/lib/features/settings/settings_sheet.dart`
- Create: `apps/client/lib/shared/async_panel.dart`
- Create: `apps/client/lib/shared/money_text.dart`
- Replace: `apps/client/test/widget_test.dart`
- Create: `apps/client/test/features/capture_screen_test.dart`
- Create: `apps/client/test/features/responsive_shell_test.dart`
- Create: `apps/client/test/features/future_seed_screen_test.dart`

**Interfaces:**
- Consumes: `AppController`, design tokens, and repository contracts from Task 4.
- Produces: the complete approved user journey on phone, tablet, and desktop.

- [ ] **Step 1: Write failing screen tests**

Assert navigation labels, Offline demo status, dashboard values, capture input/parse/confirm states, editable amount/category, subscription option source, lesson action, principal/growth labels, and 375/768/1200 responsive shells.

- [ ] **Step 2: Build dashboard and responsive shell**

Show available budget, goal progress, one coach insight, recent events, subscription opportunity, explicit mode chip, and one primary capture CTA. Use written summaries with every progress/chart visual.

- [ ] **Step 3: Build capture and records**

Implement visible input label/helper, sample chips, loading status, one-or-more draft editors, source badge, save feedback, list filters, empty/error states, and semantic labels.

- [ ] **Step 4: Build subscription coach and learning loop**

Display current equivalent monthly cost, sorted options, savings, known/synthetic source, eligibility warning, one concept, one question, and one immediate action.

- [ ] **Step 5: Build FutureSeed and settings**

Use labeled sliders/inputs for monthly amount, years, and assumed rate; show principal, assumed growth, ending balance, yearly values, and the education disclaimer. Settings supports theme, service status, explicit Offline demo, and confirmed reset.

- [ ] **Step 6: Verify Task 5**

Run all Flutter tests, analyze, and Web build. Inspect at 375, 768, 1024, and 1440 widths with light/dark and 200% text scaling.

### Task 6: End-to-end contract and competition evidence

**Files:**
- Create: `services/api/test/fixtures/capture-evaluation.json`
- Create: `services/api/scripts/evaluateCaptures.ts`
- Modify: `services/api/package.json`
- Create: `apps/client/integration_test/demo_flow_test.dart`
- Modify: `apps/client/pubspec.yaml`
- Create: `docs/testing-and-evidence.md`
- Create: `docs/demo-script.md`

**Interfaces:**
- Produces: reproducible 30-case parse evaluation and full synthetic demo flow evidence.

- [ ] **Step 1: Add 30 synthetic Traditional Chinese cases**

Include clear expense, income, subscription, split, multiple items, missing amount, relative date, discount ambiguity, denial/no-purchase, irrelevant content, and synthetic notification formats. Each fixture contains expected type, amount/category when applicable, and whether confirmation/rejection is required.

- [ ] **Step 2: Implement evaluation report script**

Add `npm run evaluate:captures` to output JSON and Markdown summaries with schema validity, required-field accuracy, rejection correctness, and per-case failures. Never include real data.

- [ ] **Step 3: Implement Flutter integration demo**

Drive the fixed story: verify seeded income, parse and save `今天買珍奶 75`, open subscription comparison, complete lesson, and preview monthly savings. The test asserts Offline demo labels.

- [ ] **Step 4: Document normal and degraded demos**

Record exact commands, expected screens, AI/Cosmos failure behavior, offline switch, synthetic data disclosure, and statements the team must not make.

- [ ] **Step 5: Verify Task 6**

Run evaluation, API suite, Flutter suite, integration test where the environment supports Chrome, and Web build. Record any unavailable device-only checks as unverified.

### Task 7: Documentation synchronization and final verification

**Files:**
- Modify: `README.md`
- Modify: `apps/client/README.md`
- Modify: `services/api/README.md`
- Modify: `docs/architecture.md`
- Modify: `docs/data-and-storage.md`
- Modify: `docs/integrations.md`
- Modify: `docs/security-and-privacy.md`
- Modify: `docs/deployment.md`
- Modify: `docs/competition.md`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: verified commands, behavior, environment names, and limitations from Tasks 1–6.
- Produces: truthful handoff and deployment-ready documentation without claiming cloud deployment.

- [ ] **Step 1: Synchronize commands, contracts, and status**

Document actual prerequisites, offline default, connected Dart defines, Functions provider variables, tests, evaluation, build commands, local URLs only after verification, and unchanged Azure deployment status.

- [ ] **Step 2: Update security and competition evidence**

Document synthetic fixtures, original-text non-persistence, sanitized logging, AI source labels, Demo reset boundary, FutureSeed formula, and exact remaining Azure/RBAC decisions.

- [ ] **Step 3: Run complete verification**

```bash
cd services/api
PATH="/opt/homebrew/opt/node@22/bin:$PATH" npm ci
PATH="/opt/homebrew/opt/node@22/bin:$PATH" npm test
PATH="/opt/homebrew/opt/node@22/bin:$PATH" npm run typecheck
PATH="/opt/homebrew/opt/node@22/bin:$PATH" npm run build
PATH="/opt/homebrew/opt/node@22/bin:$PATH" npm run evaluate:captures

cd ../../apps/client
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter build web
```

- [ ] **Step 4: Inspect repository safety and scope without committing**

Run `git status --short --branch`, review all diffs and untracked paths, confirm no secret/legal/private files were introduced, and report changed files, verification, remaining cloud/device risks, and decisions requiring the team.
