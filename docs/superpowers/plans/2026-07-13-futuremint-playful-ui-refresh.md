# FutureMint AI Playful UI Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the existing Flutter Client presentation as an accessible, responsive, youth-oriented color-block interface derived from the approved reference-image analysis without changing product behavior.

**Architecture:** Extend the existing design layer with semantic color and shape tokens plus focused reusable presentation widgets. Restyle the shell and each feature screen on top of the existing controller, repository, router, and model boundaries; feature data flow remains unchanged.

**Tech Stack:** Flutter 3.41.x, Dart 3.11.x, Material 3, Provider, go_router, flutter_test.

## Global Constraints

- Do not change API contracts, repositories, routes, models, financial calculations, or demo data behavior.
- Do not add runtime dependencies, remote fonts, external images, or unlicensed assets.
- Preserve the 720dp NavigationRail breakpoint and 1100dp wide-dashboard breakpoint.
- Keep body-text contrast at least 4.5:1, touch targets at least 48×48dp, and preserve Semantics and keyboard focus.
- Support 375, 768, 1024, and 1440px widths, landscape, dark mode, and 200% text scale without horizontal overflow.
- Do not commit, push, or stage files unless the user separately authorizes that Git action.

---

### Task 1: Semantic tokens, theme, and shared brand primitives

**Files:**
- Modify: `app/lib/design/tokens.dart`
- Modify: `app/lib/design/theme.dart`
- Create: `app/lib/design/pop_components.dart`
- Create: `app/test/design/pop_components_test.dart`

**Interfaces:**
- Produces: `FutureMintTokens.ink`, `cream`, `mint`, `coral`, `sun`, `lavender`, `sky`, `hardShadowOffset`, `outlineWidth`.
- Produces: `PopCard({Widget child, Color? color, EdgeInsetsGeometry padding, bool shadow})`.
- Produces: `SectionHeading({String eyebrow, String title, String? description, Color accent})`.
- Produces: `SeedlingMascot({double size, Color color})`.

- [ ] **Step 1: Write failing primitive tests**

```dart
testWidgets('PopCard renders outlined colored content', (tester) async {
  await tester.pumpWidget(MaterialApp(
    theme: FutureMintTheme.light(),
    home: const Scaffold(body: PopCard(color: FutureMintTokens.sun, child: Text('目標'))),
  ));
  final decoration = tester.widget<DecoratedBox>(find.descendant(
    of: find.byType(PopCard), matching: find.byType(DecoratedBox),
  ).first).decoration as BoxDecoration;
  expect(decoration.color, FutureMintTokens.sun);
  expect(decoration.border, isNotNull);
  expect(find.text('目標'), findsOneWidget);
});

testWidgets('SeedlingMascot has a semantic label', (tester) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: SeedlingMascot())));
  expect(find.bySemanticsLabel('FutureMint 種子夥伴'), findsOneWidget);
});
```

- [ ] **Step 2: Run the new test and verify missing symbols fail**

Run: `cd app && flutter test test/design/pop_components_test.dart`
Expected: FAIL because `pop_components.dart`, `PopCard`, and `SeedlingMascot` do not exist.

- [ ] **Step 3: Implement tokens and primitives**

Implement the exact public constructors above. `PopCard` uses a 2.5dp ink/dark-outline border, a 20dp radius, and an `Offset(5, 6)` hard shadow; dark mode derives the outline from `colorScheme.outline`. `SeedlingMascot` uses only Flutter shapes or `CustomPainter` and wraps decoration in `Semantics(label: 'FutureMint 種子夥伴', image: true)`.

- [ ] **Step 4: Restyle ThemeData**

Set the warm canvas, high-weight type scale, outlined inputs, pill buttons, compact outlined chips, rounded segmented buttons, high-contrast focus, pop-style cards, snackbars, navigation bars, sheets, dialogs, progress indicators, and sliders. Preserve Material 3 state handling and disabled colors.

- [ ] **Step 5: Format and run focused tests**

Run: `cd app && dart format lib/design test/design && flutter test test/design/pop_components_test.dart`
Expected: PASS with no exceptions.

### Task 2: App shell and navigation

**Files:**
- Modify: `app/lib/app/app_shell.dart`
- Modify: `app/test/widget_test.dart`

**Interfaces:**
- Consumes: `PopCard`, semantic tokens, and themed NavigationBar/NavigationRail from Task 1.
- Preserves: `appDestinations`, paths, labels, `_selectedIndex`, and `showSettingsSheet` behavior.

- [ ] **Step 1: Strengthen responsive navigation tests**

Add assertions that phone navigation is inside a dark rounded `DecoratedBox`, selected Capture remains discoverable by text, desktop still renders `NavigationRail`, and both layouts expose `離線展示`.

- [ ] **Step 2: Run the focused test before implementation**

Run: `cd app && flutter test test/widget_test.dart`
Expected: FAIL on the new branded-navigation decoration assertion while existing navigation assertions pass.

- [ ] **Step 3: Implement the branded shell**

Keep the existing mobile/desktop branch. Wrap mobile bottom navigation in safe-area horizontal padding and a dark rounded container; give the Capture destination a coral emphasis through selected icon/theme state. Restyle `_Brand`, `_ModeChip`, desktop sidebar, selected rail indicator, settings action, and `_GlobalMessage` without changing callbacks or mode wording.

- [ ] **Step 4: Verify phone, desktop, and 200% text tests**

Run: `cd app && flutter test test/widget_test.dart`
Expected: PASS; `tester.takeException()` stays null at 375×812 and 200% scale.

### Task 3: Dashboard hierarchy and color-block story

**Files:**
- Modify: `app/lib/features/dashboard/dashboard_screen.dart`
- Modify: `app/lib/features/dashboard/widgets/budget_hero.dart`
- Modify: `app/test/widget_test.dart`

**Interfaces:**
- Consumes: `PopCard`, `SectionHeading`, `SeedlingMascot`, and semantic tokens.
- Preserves: all controller reads, routes, summary calculations, disclosure copy, and event ordering.

- [ ] **Step 1: Add dashboard brand and accessibility assertions**

Assert `FutureMint 種子夥伴`, `本月安心可用`, `教練提醒`, `成長目標`, `近期紀錄`, and `訂閱小檢查` are present after initialization, and retain the 200% text-scale no-exception assertion.

- [ ] **Step 2: Run dashboard tests before implementation**

Run: `cd app && flutter test test/widget_test.dart`
Expected: FAIL only because the new mascot semantics is absent.

- [ ] **Step 3: Rebuild dashboard presentation**

Use `SectionHeading` for the welcome header and keep the Capture action. Convert budget, coach, goal, subscription, record, and disclosure blocks to `PopCard` with teal, coral, sun, sky/lavender, cream, and muted colors chosen for contrast. Preserve wide two-column proportions and phone story order. Keep amount and progress Semantics from `BudgetHero`.

- [ ] **Step 4: Verify dashboard behavior**

Run: `cd app && flutter test test/widget_test.dart`
Expected: PASS on phone, desktop, and text-scale cases.

### Task 4: Capture, records, and shared async states

**Files:**
- Modify: `app/lib/features/capture/capture_screen.dart`
- Modify: `app/lib/features/capture/draft_editor.dart`
- Modify: `app/lib/features/records/records_screen.dart`
- Modify: `app/lib/shared/async_panel.dart`
- Modify: `app/test/features/capture_screen_test.dart`

**Interfaces:**
- Consumes: shared brand primitives and semantic tokens.
- Preserves: input keys, parse/save callbacks, draft validation, record filters, refresh behavior, and error/retry flow.

- [ ] **Step 1: Add presentation-safe behavior tests**

Retain existing Capture flow assertions and add a 375×812 case that finds `capture-input`, all three sample chips, and `幫我整理` with `tester.takeException() == null`. Add semantics assertions that parsed drafts still state they are not automatically saved.

- [ ] **Step 2: Run Capture tests before implementation**

Run: `cd app && flutter test test/features/capture_screen_test.dart`
Expected: PASS on existing behavior and FAIL if the new semantics label is not yet present.

- [ ] **Step 3: Restyle Capture and DraftEditor**

Use a coral eyebrow, cream `PopCard`, sticker-like sample chips, and strong primary button. Apply outlined fields and grouped sections to DraftEditor while retaining keys and all input controls. Add a semantic container label `AI 已整理草稿，尚未保存` around each draft.

- [ ] **Step 4: Restyle Records and AsyncPanel**

Use `SectionHeading`, pill segmented controls, colored category markers, and outlined record cards. Convert loading/error states to centered brand panels without changing retry behavior or error wording.

- [ ] **Step 5: Verify Capture and core widget suite**

Run: `cd app && flutter test test/features/capture_screen_test.dart test/widget_test.dart`
Expected: PASS with no overflow or state regression.

### Task 5: Learning, subscriptions, FutureSeed, and settings

**Files:**
- Modify: `app/lib/features/learning/learning_screen.dart`
- Modify: `app/lib/features/subscriptions/subscription_coach.dart`
- Modify: `app/lib/features/future_seed/future_seed_screen.dart`
- Modify: `app/lib/features/settings/settings_sheet.dart`
- Modify: `app/test/features/learning_and_subscription_test.dart`
- Modify: `app/test/features/future_seed_screen_test.dart`

**Interfaces:**
- Consumes: shared brand primitives and semantic tokens.
- Preserves: lesson loading/selection, subscription eligibility text, FutureSeed inputs/results, settings theme/mode/profile/reset actions.

- [ ] **Step 1: Add narrow-layout regression tests**

For Learning, Subscription, and FutureSeed tests, set the view to 375×812 and assert their primary headings plus `tester.takeException() == null`. Retain existing selection, disclaimer, principal, and assumed-growth assertions.

- [ ] **Step 2: Run feature tests before implementation**

Run: `cd app && flutter test test/features/learning_and_subscription_test.dart test/features/future_seed_screen_test.dart`
Expected: Existing behavior passes; any added branded-widget assertion fails before restyling.

- [ ] **Step 3: Restyle Learning and subscriptions**

Use lavender learning panels and numbered cream sections; selected answers retain icons and selection semantics. Use a dark current-plan summary and alternating sky/sun/coral option cards while keeping all eligibility and disclaimer text.

- [ ] **Step 4: Restyle FutureSeed and settings**

Use sun controls, sky/teal results, and outlined year bars. Ensure metric Wrap layouts can reflow at 200% text scale. Apply the same headers, outlined groups, theme segmented control, and warning styling to the settings sheet and dialogs.

- [ ] **Step 5: Verify feature tests**

Run: `cd app && flutter test test/features/learning_and_subscription_test.dart test/features/future_seed_screen_test.dart`
Expected: PASS without overflow exceptions.

### Task 6: Documentation, full validation, and visual QA

**Files:**
- Modify: `design/futuremint-ai/MASTER.md`
- Modify: `design/README.md`
- Modify: `app/README.md`
- Modify: `docs/testing-and-evidence.md`
- Verify: `README.md`

**Interfaces:**
- Documents: the exact tokens, components, responsive behavior, and checks implemented in Tasks 1–5.
- Does not change: deployment state, environment variables, data policy, or backend claims.

- [ ] **Step 1: Synchronize design and client documentation**

Replace the old restrained-card direction with the implemented color-block direction; record the palette, outline/shadow rules, mascot constraint, navigation treatment, accessibility rules, and that no external assets or runtime fonts were added. Update Client README only where the visible design responsibility changed.

- [ ] **Step 2: Run formatting and static checks**

Run: `cd app && dart format --output=none --set-exit-if-changed lib test integration_test && flutter analyze`
Expected: formatter reports no changes required; analyzer exits 0.

- [ ] **Step 3: Run all Flutter tests**

Run: `cd app && flutter test`
Expected: all tests pass with exit code 0.

- [ ] **Step 4: Build Flutter Web**

Run: `cd app && flutter build web`
Expected: release Web build completes with exit code 0.

- [ ] **Step 5: Perform browser visual QA**

Run the local Web app and inspect 375, 768, 1024, and 1440px widths. Visit `/`, `/capture`, `/records`, `/learning`, `/subscriptions`, `/future-seed`; open settings; check light and dark mode. Capture at least one phone and one desktop screenshot and verify no clipping, hidden navigation, unreadable contrast, or misleading state presentation.

- [ ] **Step 6: Record only observed evidence**

Update `docs/testing-and-evidence.md` with exact commands, pass counts/build result, browser widths and pages actually inspected, plus any device, keyboard, reader, or reduced-motion checks not performed. Run `git diff --check` and `git status --short` for the final handoff; do not stage or commit.
