import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/core/models.dart';
import 'package:futuremint_app/data/demo_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DemoRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = await DemoRepository.create();
  });

  test('starts with a complete synthetic demo profile and ledger', () async {
    final profile = await repository.getProfile();
    final events = await repository.listMoneyEvents();

    expect(profile.userId, 'demo-user');
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
    expect(after, before);
  });

  test(
    'confirmed saves are idempotent and survive a new repository instance',
    () async {
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
      final reloaded = await DemoRepository.create();
      final events = await reloaded.listMoneyEvents();

      expect(second.id, first.id);
      expect(
        events.where((event) => event.idempotencyKey == 'same-demo-capture'),
        hasLength(1),
      );
    },
  );

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

  test('persists the selected micro-lesson action across reloads', () async {
    final lesson = await repository.generateLesson();
    await repository.completeLesson(lesson, lesson.options.first);

    final reloaded = await DemoRepository.create();
    final persisted = await reloaded.generateLesson();

    expect(persisted.selectedOption, lesson.options.first);
  });

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

  test('groups an event into the current month using Taipei time', () async {
    final taipeiNow = DateTime.now().toUtc().add(const Duration(hours: 8));
    final firstDayTaipeiInstant = DateTime.utc(
      taipeiNow.year,
      taipeiNow.month,
      1,
    ).subtract(const Duration(hours: 7, minutes: 30));
    SharedPreferences.setMockInitialValues({
      'futuremint.demo.events.v1': jsonEncode([
        {
          'id': 'month-boundary',
          'userId': 'demo-user',
          'type': 'expense',
          'amountMinor': 99,
          'currency': 'TWD',
          'category': 'food',
          'occurredAt': firstDayTaipeiInstant.toIso8601String(),
          'createdAt': firstDayTaipeiInstant.toIso8601String(),
          'updatedAt': firstDayTaipeiInstant.toIso8601String(),
        },
      ]),
    });
    final boundaryRepository = await DemoRepository.create();

    final dashboard = await boundaryRepository.getDashboard();

    expect(dashboard.expenseMinor, 99);
  });
}
