import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/app/future_mint_app.dart';

import '../widget_test.dart';

void main() {
  testWidgets('lesson records one realistic next action', (tester) async {
    final controller = await createController();
    await tester.pumpWidget(FutureMintApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('學習').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('先檢查一項固定訂閱'));
    await tester.tap(find.text('先檢查一項固定訂閱'));
    await tester.pumpAndSettle();
    expect(find.textContaining('你的下一步'), findsOneWidget);
    expect(controller.lesson?.selectedOption, '先檢查一項固定訂閱');
  });

  testWidgets('subscription options identify synthetic sources', (
    tester,
  ) async {
    final controller = await createController();
    await tester.pumpWidget(FutureMintApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('比較方案'));
    await tester.tap(find.text('比較方案'));
    await tester.pumpAndSettle();
    expect(find.text('合成方案'), findsNWidgets(2));
    expect(find.textContaining('並非即時市場資訊'), findsOneWidget);
  });
}
