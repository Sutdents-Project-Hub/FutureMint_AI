import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/app/future_mint_app.dart';

import '../widget_test.dart';

void main() {
  testWidgets('FutureSeed separates principal from assumed growth', (
    tester,
  ) async {
    final controller = await createController();
    await tester.pumpWidget(FutureMintApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('未來').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('這不是報酬預測'), findsOneWidget);
    await tester.tap(find.text('開始教育試算'));
    await tester.pumpAndSettle();

    expect(find.text('投入本金'), findsOneWidget);
    expect(find.text('假設成長'), findsOneWidget);
    expect(find.text('期末可能金額'), findsOneWidget);
    expect(controller.futureSeedPreview?.principalMinor, 30000);
    expect(
      controller.futureSeedPreview!.endingBalanceMinor,
      greaterThan(controller.futureSeedPreview!.principalMinor),
    );
  });
}
