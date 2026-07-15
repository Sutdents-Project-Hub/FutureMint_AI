import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/core/models.dart';
import 'package:futuremint_app/data/guest_repository.dart';

void main() {
  late GuestRepository repository;

  setUp(() async {
    repository = await GuestRepository.create();
  });

  test('starts with a complete temporary guest profile and ledger', () async {
    final profile = await repository.getProfile();
    final events = await repository.listMoneyEvents();

    expect(profile.userId, 'guest-user');
    expect(profile.monthlyBudgetMinor, 6000);
    expect(events.any((event) => event.type == MoneyEventType.income), isTrue);
    expect(
      events.any((event) => event.type == MoneyEventType.subscription),
      isTrue,
    );
  });

  test('parsing does not persist until a draft is confirmed', () async {
    final before = await repository.listMoneyEvents();
    final result = await repository.parseCapture(
      '今天買珍奶 75',
      referenceTime: DateTime.parse('2026-07-13T12:00:00+08:00'),
    );
    final after = await repository.listMoneyEvents();

    expect(result.drafts.single.amountMinor, 75);
    expect(result.drafts.single.source.name, 'deterministicDemo');
    expect(result.drafts.single.spendingIntent, SpendingIntent.want);
    expect(result.drafts.single.intentReason, contains('AI 建議'));
    expect(after, before);
  });

  test('confirmed saves are idempotent within a guest session', () async {
    final result = await repository.parseCapture(
      '今天買珍奶 75',
      referenceTime: DateTime.parse('2026-07-13T12:00:00+08:00'),
    );

    final first = await repository.saveDraft(
      result.drafts.single,
      idempotencyKey: 'same-demo-capture',
    );
    final second = await repository.saveDraft(
      result.drafts.single,
      idempotencyKey: 'same-demo-capture',
    );
    final events = await repository.listMoneyEvents();

    expect(second.id, first.id);
    expect(
      events.where((event) => event.idempotencyKey == 'same-demo-capture'),
      hasLength(1),
    );
  });

  test(
    'negative purchase text is rejected instead of becoming an expense',
    () async {
      final result = await repository.parseCapture(
        '本來想買耳機 3000，但沒有買',
        referenceTime: DateTime.parse('2026-07-13T12:00:00+08:00'),
      );

      expect(result.drafts, isEmpty);
      expect(result.rejectedReason, contains('沒有發生'));
    },
  );

  test('ordinary non-financial conversation is rejected', () async {
    final result = await repository.parseCapture(
      '今天心情很好',
      referenceTime: DateTime.parse('2026-07-13T12:00:00+08:00'),
    );

    expect(result.drafts, isEmpty);
    expect(result.rejectedReason, contains('不像'));
  });

  test(
    'separates multiple purchases and respects an explicitly paid price',
    () async {
      final multiple = await repository.parseCapture(
        '早餐 65，飲料 40',
        referenceTime: DateTime.parse('2026-07-13T12:00:00+08:00'),
      );
      final discounted = await repository.parseCapture(
        '文具原價 200，折扣後實付 150',
        referenceTime: DateTime.parse('2026-07-13T12:00:00+08:00'),
      );

      expect(multiple.drafts.map((draft) => draft.amountMinor), [65, 40]);
      expect(discounted.drafts.single.amountMinor, 150);
    },
  );

  test('resolves yesterday from the provided reference time', () async {
    final result = await repository.parseCapture(
      '昨天晚餐 180',
      referenceTime: DateTime.parse('2026-07-13T12:00:00+08:00'),
    );

    expect(result.drafts.single.occurredAt.day, 12);
  });

  test(
    'does not retain a selected micro-lesson action in a new guest session',
    () async {
      final lesson = await repository.generateLesson();
      await repository.completeLesson(lesson, lesson.options.first);

      final reloaded = await GuestRepository.create();
      final persisted = await reloaded.generateLesson();

      expect(persisted.selectedOption, isNull);
    },
  );

  test('uses the recorded subscription share as the current cost', () async {
    final comparison = await repository.compareSubscriptions();

    expect(comparison.currentName, '影音訂閱');
    expect(comparison.currentMonthlyCostMinor, 98);
    expect(
      comparison.options.every(
        (option) => (option.monthlySavingsMinor ?? 0) <= 0,
      ),
      isTrue,
    );
  });

  test(
    'does not present a shared plan as eligible without four members',
    () async {
      final result = await repository.parseCapture(
        'Netflix 390',
        referenceTime: DateTime.parse('2026-07-13T18:00:00+08:00'),
      );
      await repository.saveDraft(
        result.drafts.single,
        idempotencyKey: 'single-member-subscription',
      );

      final comparison = await repository.compareSubscriptions();
      final shared = comparison.options.first;

      expect(shared.eligible, isFalse);
      expect(shared.monthlySavingsMinor, isNull);
      expect(shared.userMonthlyCostMinor, 130);
    },
  );

  test(
    'builds analysis from confirmed need and want classifications',
    () async {
      final insights = await repository.getInsights();

      expect(insights.monthlyCashflow, hasLength(6));
      expect(insights.wantMinor, greaterThan(0));
      expect(insights.summary, contains('想要'));
      expect(
        insights.notices.any((notice) => notice.kind == InsightKind.saving),
        isTrue,
      );
    },
  );

  test(
    'simulates three versioned paths with visible risk differences',
    () async {
      final simulation = await repository.simulateInvestments(
        initialAmountMinor: 4200,
        monthlyContributionMinor: 500,
        years: 10,
      );

      expect(simulation.scenarios, hasLength(3));
      expect(simulation.assumptionVersion, 'education-scenarios-2026-07-v1');
      expect(
        simulation.scenarios
            .firstWhere(
              (scenario) => scenario.id == InvestmentScenarioId.highRisk,
            )
            .maxDrawdownPercent,
        greaterThan(0),
      );
      expect(simulation.disclaimer, contains('不是即時行情'));
    },
  );

  test('tailors the learning plan to a parent companion role', () async {
    final profile = await repository.getProfile();
    await repository.updateProfile(
      UserProfile(
        userId: profile.userId,
        accountRole: AccountRole.parent,
        monthlyBudgetMinor: profile.monthlyBudgetMinor,
        weeklyBudgetMinor: profile.weeklyBudgetMinor,
        goalName: profile.goalName,
        goalTargetMinor: profile.goalTargetMinor,
        goalSavedMinor: profile.goalSavedMinor,
        goalDate: profile.goalDate,
      ),
    );

    final plan = await repository.getLearningPlan();

    expect(plan.title, contains('親子'));
    expect(plan.modules.map((module) => module.id), contains('compound'));
  });

  test(
    'uses saved money for an idempotent virtual investment practice',
    () async {
      final initial = await repository.getInvestmentLab();
      final bought = await repository.placeInvestmentOrder(
        symbol: '0050',
        side: InvestmentOrderSide.buy,
        quantity: 2,
        idempotencyKey: 'guest-buy-0050',
      );
      final repeated = await repository.placeInvestmentOrder(
        symbol: '0050',
        side: InvestmentOrderSide.buy,
        quantity: 2,
        idempotencyKey: 'guest-buy-0050',
      );

      expect(initial.startingCashMinor, 4200);
      expect(initial.market.isFallback, isTrue);
      expect(bought.holdings.single, isA<VirtualHolding>());
      expect(bought.holdings.single.quantity, 2);
      expect(repeated.orders, hasLength(1));
    },
  );

  test('rejects selling more than the virtual holding', () async {
    await expectLater(
      repository.placeInvestmentOrder(
        symbol: '0050',
        side: InvestmentOrderSide.sell,
        quantity: 1,
        idempotencyKey: 'guest-sell-too-much',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('returns a versioned market event card', () async {
    final event = await repository.rollInvestmentDice(rollIndex: 0);

    expect(event.deckVersion, 'investment-lab-events-v1');
    expect(event.practicePrompt, isNotEmpty);
    expect(event.disclaimer, contains('不是市場預測'));
  });
}
