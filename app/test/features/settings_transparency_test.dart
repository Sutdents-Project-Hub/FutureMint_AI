import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/auth/auth_models.dart';
import 'package:futuremint_app/core/models.dart';
import 'package:futuremint_app/features/settings/settings_sheet.dart';
import 'package:provider/provider.dart';

import '../widget_test.dart';

void main() {
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
    expect(find.textContaining('決賽展示與測試應只使用合成資料'), findsOneWidget);
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
    expect(find.textContaining('量界智算'), findsOneWidget);
    expect(find.textContaining('上游來源'), findsOneWidget);
    expect(find.textContaining('不含個資的原型測試'), findsOneWidget);
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
