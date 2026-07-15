import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/app/future_mint_app.dart';

import '../widget_test.dart';

void main() {
  testWidgets('FutureSeed separates principal from assumed growth', (
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

    await tester.tap(find.text('未來').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('future-seed-controls')), findsOneWidget);
    final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
    expect(sliders, hasLength(3));
    expect(sliders.every((slider) => slider.divisions == null), isTrue);
    final sliderThemes = tester
        .widgetList<SliderTheme>(find.byType(SliderTheme))
        .toList();
    expect(sliderThemes, hasLength(3));
    expect(
      sliderThemes.every(
        (theme) => theme.data.trackShape is RoundedRectSliderTrackShape,
      ),
      isTrue,
    );
    expect(find.byKey(const Key('future-seed-empty-state')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('future-seed-empty-state'))).height,
      lessThan(280),
    );
    expect(find.textContaining('這不是報酬預測'), findsOneWidget);
    await tester.ensureVisible(find.text('開始教育試算'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('開始教育試算'));
    await tester.pumpAndSettle();

    expect(find.text('投入本金'), findsOneWidget);
    expect(find.text('假設成長'), findsOneWidget);
    expect(find.text('期末可能金額'), findsOneWidget);
    expect(find.text('穩穩存'), findsWidgets);
    expect(find.text('慢慢長'), findsWidgets);
    expect(find.text('高風險資產'), findsWidgets);
    expect(find.text('AI 陪讀員'), findsOneWidget);
    expect(controller.investmentSimulation?.scenarios, hasLength(3));
    expect(controller.futureSeedPreview, isNull);
    expect(tester.takeException(), isNull);
  });
}
