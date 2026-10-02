import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/auth/service_policy.dart';
import 'package:futuremint_app/core/models.dart';
import 'package:futuremint_app/features/settings/settings_sheet.dart';
import 'package:futuremint_app/state/app_controller.dart';
import 'package:provider/provider.dart';

import '../widget_test.dart';

const version = 'third-party-ai-v2-synthetic-disclosure-layout-policy';

ServicePolicy policy({bool reviewed = true}) => ServicePolicy(
  aiPolicyVersion: version,
  aiDisplayName: '量界智算',
  aiProvider: 'liangjie',
  dataRecipients: const ['合成接收方'],
  dataTerms: '合成資料處理說明；測試不會呼叫第三方 AI。',
  model: 'synthetic-model',
  reviewed: reviewed,
);

Future<void> openDisclosure(
  WidgetTester tester, {
  required ServicePolicy? servicePolicy,
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) async {
  final base = await createController();
  final controller = AppController(
    repository: base.repository,
    mode: AppMode.authenticated,
    servicePolicy: servicePolicy,
    onAiConsentChanged: (_) async => throw StateError('Must not grant consent'),
  );
  addTearDown(base.dispose);
  addTearDown(controller.dispose);
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: controller,
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAiConsentDisclosure(context),
              child: const Text('查看說明'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('查看說明'));
  await tester.pumpAndSettle();
}

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('disclosure remains readable and aligned '
          '(${brightness.name}, ${scale}x)', (tester) async {
        await openDisclosure(
          tester,
          servicePolicy: policy(),
          brightness: brightness,
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        for (final heading in ['使用哪個 AI', '會傳送哪些資料', '目前啟用狀態', '你的選擇']) {
          await tester.ensureVisible(find.text(heading));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        final links = find.byKey(const Key('ai-disclosure-links'));
        await tester.ensureVisible(links);
        await tester.pumpAndSettle();
        final left = tester.getTopLeft(links).dx;
        expect(
          tester.getTopLeft(find.byIcon(Icons.privacy_tip_outlined)).dx,
          closeTo(left, 1),
        );
        final privacyButton = find.ancestor(
          of: find.text('隱私權政策'),
          matching: find.byWidgetPredicate((widget) => widget is TextButton),
        );
        expect(tester.getSize(privacyButton).height, greaterThanOrEqualTo(48));
        expect(find.text('同意版本：$version'), findsNothing);
        final details = find.byKey(const Key('ai-disclosure-details'));
        await tester.ensureVisible(details);
        await tester.pumpAndSettle();
        await tester.tap(find.text('詳細資訊'));
        await tester.pumpAndSettle();
        final versionText = find.text('同意版本：$version');
        await tester.ensureVisible(versionText);
        await tester.pumpAndSettle();
        expect(versionText, findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('暫不啟用'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('ai-consent-disclosure')), findsNothing);
      });
    }
  }

  for (final unavailable in [null, policy(reviewed: false)]) {
    testWidgets('missing or unreviewed disclosure cannot enable AI '
        '(${unavailable?.reviewed})', (tester) async {
      await openDisclosure(tester, servicePolicy: unavailable);
      final action = tester.widget<FilledButton>(
        find.byKey(const Key('enable-ai-consent')),
      );
      expect(action.onPressed, isNull);
      await tester.tap(find.text('暫不啟用'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
