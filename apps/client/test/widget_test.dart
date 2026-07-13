import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/app/future_mint_app.dart';
import 'package:futuremint_app/core/models.dart';
import 'package:futuremint_app/data/demo_repository.dart';
import 'package:futuremint_app/state/app_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppController> createController() async {
  SharedPreferences.setMockInitialValues({});
  final controller = AppController(
    repository: await DemoRepository.create(),
    mode: AppMode.offlineDemo,
  );
  await controller.initialize();
  return controller;
}

void main() {
  testWidgets('shows the competition dashboard and offline source', (
    tester,
  ) async {
    final controller = await createController();
    await tester.pumpWidget(FutureMintApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('FutureMint AI'), findsOneWidget);
    expect(find.text('離線展示'), findsWidgets);
    expect(find.text('本月安心可用'), findsOneWidget);
    expect(find.text('記一筆'), findsWidgets);
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

    tester.view.physicalSize = const Size(1200, 900);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
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
}
