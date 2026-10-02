import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/auth/auth_models.dart';
import 'package:futuremint_app/app/future_mint_app.dart';
import 'package:futuremint_app/core/models.dart';
import 'package:futuremint_app/data/api_repository.dart';
import 'package:futuremint_app/features/settings/settings_sheet.dart';
import 'package:provider/provider.dart';

import '../widget_test.dart';

void main() {
  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('profile dialog opens and can be cancelled on a phone '
        '(${theme.name}, 2x text)', (tester) async {
      final controller = await createController();
      controller.setThemeMode(theme);
      final initialProfile = controller.profile;
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
      await tester.ensureVisible(find.text('編輯預算與目標'));
      await tester.tap(find.text('編輯預算與目標'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('設定預算與目標'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(4));
      await tester.ensureVisible(find.text('目標日期'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('設定預算與目標'), findsNothing);
      expect(controller.profile, same(initialProfile));
    });
  }

  testWidgets('consent failure stays visible inside the open disclosure', (
    tester,
  ) async {
    final controller = await createController(
      mode: AppMode.authenticated,
      onAiConsentChanged: (_) async => throw const ApiException(
        code: 'network_error',
        message: '連線失敗，請再試一次。',
        retryable: true,
      ),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showAiConsentDisclosure(context),
                child: const Text('AI 說明'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('AI 說明'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enable-ai-consent')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ai-consent-disclosure')), findsOneWidget);
    expect(find.text('連線失敗，請再試一次。'), findsOneWidget);
    expect(controller.aiConsent.granted, isFalse);
    expect(controller.busy, isFalse);
  });

  testWidgets('makes education and privacy boundaries visible in settings', (
    tester,
  ) async {
    final controller = await createController(mode: AppMode.authenticated);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => showSettingsSheet(context),
                child: const Text('開啟設定'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開啟設定'));
    await tester.pumpAndSettle();

    expect(find.textContaining('FutureSeed 是教育模擬'), findsOneWidget);
    expect(find.textContaining('請只記錄自己的預算與消費'), findsOneWidget);
    expect(find.textContaining('交易明細、原始輸入'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the AI disclosure and signed-in-only account deletion', (
    tester,
  ) async {
    final controller = await createController(
      mode: AppMode.authenticated,
      accountEmail: 'student@example.com',
      onAiConsentChanged: (granted) async =>
          AiConsentStatus(granted: granted, policyVersion: '2026-08-30'),
      onDeleteAccount: (_) async {},
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => showSettingsSheet(context),
                child: const Text('開啟設定'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開啟設定'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-ai-consent')), findsOneWidget);
    expect(find.byKey(const Key('delete-account-action')), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-ai-consent')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ai-consent-disclosure')), findsOneWidget);
    expect(find.text('第三方服務：量界智算。'), findsOneWidget);
    expect(find.text('合成政策測試資料'), findsOneWidget);
    expect(find.textContaining('test recipient'), findsOneWidget);
    expect(
      find.textContaining('請求模型：synthetic-requested-model'),
      findsOneWidget,
    );
    expect(find.textContaining('模型 ID 不代表已驗證上游模型權重'), findsOneWidget);
    expect(find.textContaining('請勿輸入帳號、聯絡方式'), findsOneWidget);
    expect(find.text('同意並啟用'), findsOneWidget);
    expect(find.text('暫不啟用'), findsOneWidget);
    await tester.tap(find.text('暫不啟用'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('delete-account-action')));
    await tester.tap(find.byKey(const Key('delete-account-action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('delete-account-dialog')), findsOneWidget);
    expect(find.byKey(const Key('delete-account-password')), findsOneWidget);
    expect(
      find.byKey(const Key('delete-account-confirmation')),
      findsOneWidget,
    );
    expect(find.textContaining('家庭關聯'), findsWidgets);
    expect(find.textContaining('目前資料庫'), findsOneWidget);
    expect(find.textContaining('備份與第三方服務'), findsOneWidget);
  });
}
