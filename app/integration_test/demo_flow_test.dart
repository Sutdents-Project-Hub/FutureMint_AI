import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/app/future_mint_app.dart';
import 'package:futuremint_app/core/models.dart';
import 'package:futuremint_app/data/guest_repository.dart';
import 'package:futuremint_app/state/app_controller.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('temporary guest story completes without network storage', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppController(
      repository: await GuestRepository.create(),
      mode: AppMode.guest,
    );
    await controller.initialize();
    await tester.pumpWidget(FutureMintApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('訪客資料不會儲存'), findsOneWidget);
    expect(
      controller.events.any((event) => event.type == MoneyEventType.income),
      isTrue,
    );

    await tester.tap(find.text('記一筆').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('capture-input')), '今天買珍奶 75');
    await tester.tap(find.text('幫我整理'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('確認並記下'));
    await tester.tap(find.text('確認並記下'));
    await tester.pumpAndSettle();
    expect(controller.lastSavedEvent?.amountMinor, 75);

    await tester.tap(find.text('首頁').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('比較方案'));
    await tester.tap(find.text('比較方案'));
    await tester.pumpAndSettle();
    expect(find.text('合成方案'), findsNWidgets(2));

    await tester.tap(find.text('學習').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('先檢查一項固定訂閱'));
    await tester.tap(find.text('先檢查一項固定訂閱'));
    await tester.pumpAndSettle();
    expect(controller.lesson?.selectedOption, isNotNull);

    await tester.tap(find.text('未來').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('開始教育試算'));
    await tester.pumpAndSettle();
    expect(controller.futureSeedPreview?.endingBalanceMinor, greaterThan(0));
  });
}
