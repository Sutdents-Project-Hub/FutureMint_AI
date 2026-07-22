import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/app/future_mint_app.dart';
import 'package:futuremint_app/core/models.dart';
import 'package:futuremint_app/data/guest_repository.dart';
import 'package:futuremint_app/design/tokens.dart';
import 'package:futuremint_app/state/app_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppController> createController({
  AppMode mode = AppMode.guest,
  String? accountEmail,
}) async {
  SharedPreferences.setMockInitialValues({});
  final controller = AppController(
    repository: await GuestRepository.create(),
    mode: mode,
    accountEmail: accountEmail,
  );
  await controller.initialize();
  return controller;
}

void main() {
  testWidgets('shows the competition dashboard and guest disclosure', (
    tester,
  ) async {
    final controller = await createController();
    await tester.pumpWidget(FutureMintApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('FutureMint AI'), findsOneWidget);
    expect(find.text('訪客資料不會儲存'), findsOneWidget);
    expect(find.text('本月安心可用'), findsOneWidget);
    expect(find.text('記一筆'), findsWidgets);
    expect(find.byKey(const Key('dashboard-mascot')), findsOneWidget);
    expect(find.text('教練提醒'), findsOneWidget);
    expect(find.text('成長目標'), findsOneWidget);
    expect(find.text('近期紀錄'), findsOneWidget);
    expect(find.text('訂閱小檢查'), findsOneWidget);
  });

  testWidgets('uses bottom navigation on phone and rail on desktop', (
    tester,
  ) async {
    final controller = await createController();
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(FutureMintApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byKey(const Key('mobile-navigation-shell')), findsOneWidget);
    expect(
      tester
          .widget<NavigationBar>(find.byType(NavigationBar))
          .animationDuration,
      Duration.zero,
    );
    final navigationShell = tester.widget<DecoratedBox>(
      find.byKey(const Key('mobile-navigation-shell')),
    );
    final navigationDecoration = navigationShell.decoration as BoxDecoration;
    expect(navigationDecoration.borderRadius, isNotNull);
    expect(navigationDecoration.color, isNotNull);
    expect(find.text('訪客資料不會儲存'), findsOneWidget);

    tester.view.physicalSize = const Size(1200, 900);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('uses explicit solid label styles for the dark account chip', (
    tester,
  ) async {
    final controller = await createController(
      mode: AppMode.authenticated,
      accountEmail: 'demo@example.com',
    );
    controller.setThemeMode(ThemeMode.dark);
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(FutureMintApp(controller: controller));
    await tester.pumpAndSettle();

    final label = tester.widget<Text>(find.text('已登入').first);
    expect(label.style?.color, FutureMintTokens.paper);
    expect(label.style?.foreground, isNull);
    final chip = tester.widget<Chip>(find.byType(Chip).first);
    expect(chip.labelStyle?.color, FutureMintTokens.paper);
    expect(chip.labelStyle?.foreground, isNull);
  });

  testWidgets('keeps the neon budget hero and its progress accessible', (
    tester,
  ) async {
    final controller = await createController();
    await tester.pumpWidget(FutureMintApp(controller: controller));
    await tester.pumpAndSettle();

    final progress = tester.widget<SizedBox>(
      find.byKey(const Key('dashboard-budget-progress')),
    );
    expect(progress.height, 14);
    expect(
      find.descendant(
        of: find.byKey(const Key('dashboard-budget-progress')),
        matching: find.byType(FractionallySizedBox),
      ),
      findsOneWidget,
    );
    final heroRect = tester.getRect(
      find.byKey(const Key('dashboard-budget-hero')),
    );
    final mascotRect = tester.getRect(
      find.byKey(const Key('dashboard-mascot')),
    );
    expect(mascotRect.left, greaterThanOrEqualTo(heroRect.left));
    expect(mascotRect.right, lessThanOrEqualTo(heroRect.right));
    expect(mascotRect.top, greaterThanOrEqualTo(heroRect.top));
    expect(mascotRect.bottom, lessThanOrEqualTo(heroRect.bottom));
  });

  testWidgets('keeps the phone dashboard usable at 200% text scale', (
    tester,
  ) async {
    final controller = await createController();
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(FutureMintApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('本月安心可用'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps every rail destination reachable in short landscape', (
    tester,
  ) async {
    final controller = await createController();
    tester.view.physicalSize = const Size(812, 375);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(FutureMintApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('short-rail-scroll')), findsOneWidget);
    await tester.ensureVisible(find.text('未來'));
    await tester.pumpAndSettle();
    expect(find.text('未來').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses compact dashboard when post-rail content is below 900', (
    tester,
  ) async {
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

  testWidgets('uses bento dashboard when content width reaches 900', (
    tester,
  ) async {
    final controller = await createController();
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(FutureMintApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard-bento-layout')), findsOneWidget);
    expect(find.byKey(const Key('dashboard-mascot')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps records in one bounded quiet list surface', (
    tester,
  ) async {
    final controller = await createController();
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(FutureMintApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('紀錄').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('records-list-surface')), findsOneWidget);
    expect(find.text('遊戲點數'), findsOneWidget);
    expect(find.text('珍奶'), findsOneWidget);
    expect(find.text('打工收入'), findsOneWidget);
    expect(find.text('影音訂閱'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps records usable on a phone at 200% text scale', (
    tester,
  ) async {
    final controller = await createController();
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(FutureMintApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('紀錄').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('records-list-surface')), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('groups settings in one quiet surface', (tester) async {
    final controller = await createController();
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(FutureMintApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('設定'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-grouped-surface')), findsOneWidget);
    expect(find.text('系統'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
}
