# FutureMint AI Balanced Soft UI Fusion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current globally outlined neo-brutalist presentation with the approved balanced fusion of soft color blocks, organic Flutter-native companions, asymmetric dashboard composition, and restrained black interaction anchors without changing product behavior.

**Architecture:** Rebuild the shared design layer first, then migrate the shell and feature screens to the new primitives. Responsive decisions are based on available content width through `LayoutBuilder`; data flow, routes, models, repositories, calculations, and semantic state wording remain unchanged.

**Tech Stack:** Flutter 3.41.x, Dart 3.11.x, Material 3, Provider, go_router, `CustomPainter`, flutter_test.

## Global Constraints

- Do not change API contracts, repositories, routes, models, financial calculations, synthetic data, or the offline/connected behavior.
- Do not add runtime dependencies, external images, remote fonts, copied illustrations, or unlicensed assets.
- Keep the 720dp NavigationRail breakpoint; switch Dashboard bento by post-rail content width of at least 900dp.
- Use only the 4, 8, 12, 16, 24, 32, 48, 64dp spacing scale except documented optical drawing coordinates.
- Use 16dp phone gutters, 24dp tablet gutters, 32dp desktop gutters, and a global content max width of 1200dp.
- Keep body-text contrast at least 4.5:1, UI contrast at least 3:1, touch targets at least 48×48dp, visible Web focus, and existing Semantics/state labels.
- Support 375, 768, 1024, and 1440px widths, 812×375 landscape, dark mode, and 200% text scale without horizontal overflow.
- Do not stage, commit, push, create a PR, merge, release, or deploy; the user has not authorized any Git or deployment action.

---

### Task 1: Soft design primitives and theme

**Files:**
- Modify: `app/lib/design/tokens.dart`
- Create: `app/lib/design/soft_components.dart`
- Modify: `app/lib/design/theme.dart`
- Create: `app/test/design/soft_components_test.dart`
- Delete after migration: `app/lib/design/pop_components.dart`
- Delete after migration: `app/test/design/pop_components_test.dart`

**Interfaces:**
- Produces: `FutureMintTokens.space1` through `space8`, `pageGutter(BuildContext)`, `cardPadding(BuildContext)`, `pageMaxWidth = 1200`, `contentNarrow = 760`, `contentReading = 840`, `contentCanvas = 980`.
- Produces: `SoftCard({Key? key, required Widget child, Color? color, EdgeInsetsGeometry? padding, double radius, Color? borderColor, double borderWidth, bool elevated})`.
- Produces: `PageHeading({Key? key, required String kicker, required String title, String? description, Color accent, Widget? trailing})`.
- Produces: `MoneyBuddy({Key? key, double size, Color color, MoneyBuddyShape shape, bool excludeSemantics})` and `enum MoneyBuddyShape { blob, flower, spark }`.

- [ ] **Step 1: Write failing shared-component tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/design/soft_components.dart';
import 'package:futuremint_app/design/theme.dart';
import 'package:futuremint_app/design/tokens.dart';

void main() {
  testWidgets('SoftCard is flat and borderless by default', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: FutureMintTheme.light(),
      home: const Scaffold(body: SoftCard(child: Text('預算'))),
    ));
    final decorated = tester.widget<DecoratedBox>(
      find.descendant(of: find.byType(SoftCard), matching: find.byType(DecoratedBox)).first,
    );
    final decoration = decorated.decoration as BoxDecoration;
    expect(decoration.border, isNull);
    expect(decoration.boxShadow, isNull);
  });

  testWidgets('PageHeading keeps kicker plain and exposes hierarchy', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: FutureMintTheme.light(),
      home: const Scaffold(body: PageHeading(
        kicker: 'Today',
        title: '先看清楚，再做選擇',
        description: '每一筆都能成為下一步。',
      )),
    ));
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('TODAY'), findsNothing);
    expect(find.text('先看清楚，再做選擇'), findsOneWidget);
  });

  testWidgets('MoneyBuddy describes the FutureMint companion', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: MoneyBuddy(shape: MoneyBuddyShape.flower)),
    ));
    expect(find.bySemanticsLabel('FutureMint 金錢夥伴'), findsOneWidget);
  });

  test('global content width is bounded to 1200', () {
    expect(FutureMintTokens.pageMaxWidth, 1200);
  });
}
```

- [ ] **Step 2: Verify RED**

Run: `cd app && flutter test test/design/soft_components_test.dart`

Expected: FAIL because `soft_components.dart`, `SoftCard`, `PageHeading`, and `MoneyBuddy` do not exist and `pageMaxWidth` is still 1240.

- [ ] **Step 3: Implement the exact shared APIs**

```dart
enum MoneyBuddyShape { blob, flower, spark }

class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.color,
    this.padding,
    this.radius = FutureMintTokens.radiusMedium,
    this.borderColor,
    this.borderWidth = 0,
    this.elevated = false,
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Color? borderColor;
  final double borderWidth;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? scheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: borderWidth > 0
            ? Border.all(color: borderColor ?? scheme.outlineVariant, width: borderWidth)
            : null,
        boxShadow: elevated
            ? [BoxShadow(color: Colors.black.withValues(alpha: .08), offset: const Offset(0, 8), blurRadius: 24)]
            : null,
      ),
      child: Padding(
        padding: padding ?? FutureMintTokens.cardPadding(context),
        child: child,
      ),
    );
  }
}
```

Implement `PageHeading` as a `Column` or wrapping layout with plain kicker text, 8dp to title, 8dp to optional description, and a trailing widget that wraps below at narrow widths. Implement `MoneyBuddy` with Flutter `CustomPainter`; use only `blob`, `flower`, and `spark` paths, a subtle same-hue radial shader, and a black face. Wrap the primary instance in `Semantics(label: 'FutureMint 金錢夥伴', image: true)` and honor `excludeSemantics` for repeated decoration.

- [ ] **Step 4: Replace global theme intensity**

Set the light canvas to a teal-tinted near-white, neutral cards to white, global card outlines to none, input/outlined control hairlines to 1–1.25dp, focus borders to 2dp teal, title weights to 700–800, and light-mode filled buttons to a near-black background with white text. Keep the phone navigation indicator colorful and dark-mode depth surface-based with no shadow.

- [ ] **Step 5: Verify GREEN**

Run: `cd app && dart format lib/design test/design && flutter test test/design/soft_components_test.dart`

Expected: PASS with four tests and no exceptions.

### Task 2: Adaptive shell and Dashboard bento hierarchy

**Files:**
- Modify: `app/lib/app/app_shell.dart`
- Modify: `app/lib/features/dashboard/dashboard_screen.dart`
- Modify: `app/lib/features/dashboard/widgets/budget_hero.dart`
- Modify: `app/test/widget_test.dart`

**Interfaces:**
- Consumes: `SoftCard`, `PageHeading`, `MoneyBuddy`, semantic spacing and width tokens.
- Preserves: all routes, destinations, controller reads, mode labels, settings callback, budget semantics, recent-event ordering, and Capture action.
- Produces keys: `dashboard-compact-layout`, `dashboard-bento-layout`, `dashboard-mascot`, `mobile-navigation-shell`.

- [ ] **Step 1: Add failing responsive hierarchy tests**

```dart
testWidgets('uses compact dashboard when post-rail content is below 900', (tester) async {
  final controller = await createController();
  tester.view.physicalSize = const Size(1100, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(FutureMintApp(controller: controller));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('dashboard-compact-layout')), findsOneWidget);
  expect(find.byKey(const Key('dashboard-bento-layout')), findsNothing);
  expect(tester.takeException(), isNull);
});

testWidgets('uses bento dashboard when content width reaches 900', (tester) async {
  final controller = await createController();
  tester.view.physicalSize = const Size(1440, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(FutureMintApp(controller: controller));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('dashboard-bento-layout')), findsOneWidget);
  expect(find.bySemanticsLabel('FutureMint 金錢夥伴'), findsOneWidget);
  expect(tester.takeException(), isNull);
});
```

- [ ] **Step 2: Verify RED**

Run: `cd app && flutter test test/widget_test.dart`

Expected: FAIL because the new layout keys and MoneyBuddy semantics are absent.

- [ ] **Step 3: Rebuild the shell without changing navigation behavior**

Use `LayoutBuilder` for the 720dp navigation choice. Keep the dark rounded mobile navigation but remove the coral offset underline and hard-shadow treatment. Use a 1dp tinted divider on the desktop rail, 16/24/32dp page gutters, and the 1200dp global max width. Keep the short-landscape scroll path and every existing destination label.

- [ ] **Step 4: Build Dashboard from available width**

Wrap Dashboard content in `LayoutBuilder`. When `constraints.maxWidth >= 900`, render `Key('dashboard-bento-layout')` with Budget Hero as the dominant teal tile, goal as a taller orange tile, coach as a wide lavender tile, subscription as sky, a neutral cross-column recent list, and an inline disclosure. Otherwise render `Key('dashboard-compact-layout')` in Demo story order. Move the one `MoneyBuddy(key: Key('dashboard-mascot'))` into the Hero/header composition and keep Capture as the only strong CTA.

- [ ] **Step 5: Verify GREEN and responsive regressions**

Run: `cd app && flutter test test/widget_test.dart`

Expected: PASS for phone navigation, desktop rail, 1100 compact Dashboard, 1440 bento Dashboard, 200% text scale, and 812×375 rail reachability.

### Task 3: Capture flow, Records list, and shared states

**Files:**
- Modify: `app/lib/features/capture/capture_screen.dart`
- Modify: `app/lib/features/capture/draft_editor.dart`
- Modify: `app/lib/features/records/records_screen.dart`
- Modify: `app/lib/shared/async_panel.dart`
- Modify: `app/test/features/capture_screen_test.dart`
- Modify: `app/test/widget_test.dart`

**Interfaces:**
- Preserves: `capture-input`, parsing/saving callbacks, draft fields, `AI 已整理草稿，尚未保存`, filters, refresh, retry, error copy, and event values.
- Produces keys: `capture-hero`, `capture-draft-focus`, `records-list-surface`.

- [ ] **Step 1: Add failing structural tests**

```dart
expect(find.byKey(const Key('capture-hero')), findsOneWidget);
expect(find.byKey(const Key('capture-draft-focus')), findsOneWidget);
expect(find.bySemanticsLabel('AI 已整理草稿，尚未保存'), findsOneWidget);
```

Add a Records navigation case at 1200×900 that expects exactly one `records-list-surface`, all four demo event names, and `tester.takeException() == null`.

- [ ] **Step 2: Verify RED**

Run: `cd app && flutter test test/features/capture_screen_test.dart test/widget_test.dart`

Expected: FAIL on the new structural keys while existing Capture behavior remains green.

- [ ] **Step 3: Restyle Capture as an input-to-confirmation stack**

Use a teal/mint Hero with a small `MoneyBuddy`, a white input surface, low-border example chips, and a near-black `幫我整理` CTA. After parsing, keep the input section visible but visually quieter and place `DraftEditor(key: Key('capture-draft-focus'))` as the dominant neutral confirmation surface. Group draft fields into basic transaction, subscription/split details, and confirmation sections with 12/16dp within groups and 24/32dp between groups.

- [ ] **Step 4: Convert Records and async states to quiet surfaces**

Bound Records to `contentReading`, use one neutral `SoftCard(key: Key('records-list-surface'))`, separate events with tinted dividers, and keep category glyph, signed amount, type, and date. Convert loading/error/empty panels to neutral `SoftCard`s with one accent icon; do not change retry callbacks or wording.

- [ ] **Step 5: Verify GREEN**

Run: `cd app && flutter test test/features/capture_screen_test.dart test/widget_test.dart`

Expected: PASS; draft stays unsaved until confirmation, narrow Capture has no exception, and Records renders in a bounded single surface.

### Task 4: Learning stack, subscriptions, FutureSeed, and settings

**Files:**
- Modify: `app/lib/features/learning/learning_screen.dart`
- Modify: `app/lib/features/subscriptions/subscription_coach.dart`
- Modify: `app/lib/features/future_seed/future_seed_screen.dart`
- Modify: `app/lib/features/settings/settings_sheet.dart`
- Modify: `app/test/features/learning_and_subscription_test.dart`
- Modify: `app/test/features/future_seed_screen_test.dart`

**Interfaces:**
- Preserves: lesson selection, `learning-color-block`, subscription source/disclaimer, `subscription-current-card`, FutureSeed controls/results/disclaimer, theme/mode/profile/reset actions.
- Produces keys: `learning-soft-stack`, `future-seed-empty-state`, `settings-grouped-surface`.

- [ ] **Step 1: Add failing no-nested-card and narrow-layout tests**

```dart
expect(find.byKey(const Key('learning-soft-stack')), findsOneWidget);
final nestedSoftCards = find.descendant(
  of: find.byType(SoftCard),
  matching: find.byType(SoftCard),
);
expect(nestedSoftCards, findsNothing);
expect(tester.takeException(), isNull);
```

Add 200% text-scale cases for Subscription and FutureSeed at 375×812. Before calculation, assert `future-seed-empty-state` exists and its rendered height is below 280dp.

- [ ] **Step 2: Verify RED**

Run: `cd app && flutter test test/features/learning_and_subscription_test.dart test/features/future_seed_screen_test.dart`

Expected: FAIL because the new stack/empty-state keys and `SoftCard` migration are absent.

- [ ] **Step 3: Recompose Learning and Subscriptions**

Remove the outer-card/inner-card nesting. Render lesson summary, concept, example, and question as sibling sun/periwinkle/teal blocks in `Key('learning-soft-stack')`, with 8–12dp optical overlap only when text scale is below 1.5; otherwise use a normal 16dp vertical stack. Keep answer buttons in semantic order and the completed action in a separate teal surface. Preserve the single black current-plan anchor; render comparison options as neutral cards with small sky/orange/pink identifiers and change title/chip rows to `Wrap`.

- [ ] **Step 4: Recompose FutureSeed and Settings**

Keep the 4:6 wide composition but derive it from `LayoutBuilder`. Replace the 360dp empty result with a naturally sized `SoftCard(key: Key('future-seed-empty-state'))` below 280dp. At narrow width or 200% scale, wrap each year/value row instead of relying on fixed 42/110dp text widths. Consolidate Settings into `SoftCard(key: Key('settings-grouped-surface'))` with section dividers; reserve strong color only for service failure or destructive reset.

- [ ] **Step 5: Verify GREEN**

Run: `cd app && flutter test test/features/learning_and_subscription_test.dart test/features/future_seed_screen_test.dart`

Expected: PASS with no nested `SoftCard`, no overflow at 200% text scale, preserved lesson choice and subscription/FutureSeed disclaimers.

### Task 5: Migration cleanup, documentation, and full verification

**Files:**
- Delete: `app/lib/design/pop_components.dart`
- Delete: `app/test/design/pop_components_test.dart`
- Modify: all remaining imports under `app/lib/` from `pop_components.dart` to `soft_components.dart`
- Modify: `design/futuremint-ai/MASTER.md`
- Modify: `design/README.md`
- Modify: `app/README.md`
- Modify: `docs/testing-and-evidence.md`
- Verify: `README.md`

**Interfaces:**
- Documents only behavior and evidence actually implemented and run.
- Does not alter deployment status, environment variables, backend claims, or data policy.

- [ ] **Step 1: Remove the old visual language completely**

Run: `rg -n "PopCard|SectionHeading|SeedlingMascot|hardShadow|outlineWidth|pop_components" app/lib app/test`

Expected before cleanup: matches. Replace every production/test reference with the new primitives, then delete the obsolete source/test files.

Run the same command again.

Expected after cleanup: no matches.

- [ ] **Step 2: Synchronize design and client documentation**

Update `MASTER.md`, Design System README, and Client README to describe near-white canvas, flat/hairline cards, black interaction anchors, per-screen color dosage, `MoneyBuddy`, content-width Dashboard bento, 4dp spacing scale, and no external assets. Replace the first-round claim that coarse outlines and hard shadows are global defaults. Record only observed checks in `docs/testing-and-evidence.md`.

- [ ] **Step 3: Run formatting and static analysis**

Run: `cd app && dart format --output=none --set-exit-if-changed lib test integration_test && flutter analyze`

Expected: formatter exits 0 with no changes required; analyzer reports `No issues found!`.

- [ ] **Step 4: Run the full Flutter test suite**

Run: `cd app && flutter test`

Expected: exit 0 with all tests passing and zero failures.

- [ ] **Step 5: Build Flutter Web**

Run: `cd app && flutter build web --release`

Expected: release Web build completes with exit code 0.

- [ ] **Step 6: Perform browser visual QA**

Run the local Web app and inspect widths 375, 768, 1024, 1440, and 812×375. Visit `/`, `/capture`, `/records`, `/learning`, `/subscriptions`, `/future-seed`; open settings; switch light/dark. Verify browser console has zero errors, no content is hidden by navigation, and the Dashboard visually reads as teal Hero → supporting bento → quiet records. Capture fresh phone and desktop screenshots in the existing ignored `app/output/playwright/` directory.

- [ ] **Step 7: Record evidence and inspect the worktree**

Run: `git diff --check && git status --short --branch && git diff --stat`

Expected: `git diff --check` exits 0; status lists only the already-uncommitted first-round work plus this task's scoped UI/documentation changes. Do not stage or commit.
