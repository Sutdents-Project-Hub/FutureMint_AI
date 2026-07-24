import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    expect(find.textContaining('決賽版本僅使用合成資料'), findsOneWidget);
    expect(find.textContaining('交易明細、原始輸入'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
