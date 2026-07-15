import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/design/soft_components.dart';
import 'package:futuremint_app/design/theme.dart';
import 'package:futuremint_app/design/tokens.dart';

void main() {
  testWidgets('SoftCard is flat and borderless by default', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FutureMintTheme.light(),
        home: const Scaffold(body: SoftCard(child: Text('預算'))),
      ),
    );

    final decorated = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(SoftCard),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final decoration = decorated.decoration as BoxDecoration;
    expect(decoration.border, isNull);
    expect(decoration.boxShadow, isNull);
  });

  testWidgets('PageHeading keeps kicker plain and exposes hierarchy', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FutureMintTheme.light(),
        home: const Scaffold(
          body: PageHeading(
            kicker: 'Today',
            title: '先看清楚，再做選擇',
            description: '每一筆都能成為下一步。',
          ),
        ),
      ),
    );

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('TODAY'), findsNothing);
    expect(find.text('先看清楚，再做選擇'), findsOneWidget);
  });

  testWidgets('MoneyBuddy describes the FutureMint companion', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MoneyBuddy(shape: MoneyBuddyShape.flower)),
      ),
    );

    expect(find.bySemanticsLabel('FutureMint 金錢夥伴'), findsOneWidget);
  });

  testWidgets('MoneyBuddy keeps a square canvas inside a stretched column', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [MoneyBuddy(size: 76)],
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(
        find.descendant(
          of: find.byType(MoneyBuddy),
          matching: find.byType(CustomPaint),
        ),
      ),
      const Size.square(76),
    );
  });

  test('global content width is bounded to 1200', () {
    expect(FutureMintTokens.pageMaxWidth, 1200);
  });

  test('light theme uses indigo for primary actions and selections', () {
    final theme = FutureMintTheme.light();

    expect(theme.colorScheme.primary, FutureMintTokens.mint);
    expect(theme.colorScheme.onPrimary, FutureMintTokens.paper);
    expect(theme.navigationBarTheme.indicatorColor, FutureMintTokens.mintSoft);
  });
}
