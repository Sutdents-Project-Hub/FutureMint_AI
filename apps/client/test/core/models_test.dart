import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/core/models.dart';

void main() {
  test('MoneyEvent round trips integer TWD values and optional split data', () {
    final event = MoneyEvent.fromJson({
      'id': 'event-1',
      'userId': 'demo-user',
      'type': 'subscription',
      'amountMinor': 390,
      'currency': 'TWD',
      'category': 'subscription',
      'merchant': '合成影音服務',
      'occurredAt': '2026-07-01T08:00:00+08:00',
      'recurrence': {
        'billingCycle': 'monthly',
        'nextBillingAt': '2026-08-01T08:00:00+08:00',
      },
      'split': {'participants': 4, 'userShareMinor': 98},
      'createdAt': '2026-07-01T08:00:00+08:00',
      'updatedAt': '2026-07-01T08:00:00+08:00',
    });

    expect(event.amountMinor, 390);
    expect(event.split?.userShareMinor, 98);
    expect(event.recurrence?.billingCycle, BillingCycle.monthly);
    expect(event.toJson()['amountMinor'], isA<int>());
    expect(MoneyEvent.fromJson(event.toJson()), event);
  });

  test('CaptureDraft copyWith keeps confirmation metadata', () {
    final draft = CaptureDraft.fromJson({
      'draftId': 'draft-1',
      'type': 'subscription',
      'amountMinor': 75,
      'currency': 'TWD',
      'category': 'subscription',
      'merchant': '原商家',
      'occurredAt': '2026-07-13T12:00:00+08:00',
      'recurrence': {
        'billingCycle': 'monthly',
        'nextBillingAt': '2026-08-01T08:00:00+08:00',
      },
      'split': {'participants': 4, 'userShareMinor': 19},
      'confidence': 0.94,
      'missingFields': <String>[],
      'needsConfirmation': true,
      'source': 'deterministic-demo',
    });

    final corrected = draft.copyWith(amountMinor: 80, merchant: '飲料店');
    expect(corrected.amountMinor, 80);
    expect(corrected.source, CaptureSource.deterministicDemo);
    expect(corrected.needsConfirmation, isTrue);
    expect(corrected.split?.userShareMinor, 20);
    expect(corrected.recurrence?.billingCycle, BillingCycle.monthly);
    expect(corrected.recurrence?.nextBillingAt, isNotNull);
    expect(draft.copyWith(clearMerchant: true).merchant, isNull);
    final changedToIncome = draft.copyWith(type: MoneyEventType.income);
    expect(changedToIncome.category, MoneyCategory.income);
    expect(changedToIncome.split, isNull);
    expect(changedToIncome.recurrence, isNull);
  });

  test('FutureSeedPreview preserves principal and growth separately', () {
    final preview = FutureSeedPreview.fromJson({
      'principalMinor': 30000,
      'growthMinor': 2395,
      'endingBalanceMinor': 32395,
      'yearlyPoints': [
        {'year': 1, 'principalMinor': 6000, 'balanceMinor': 6077},
      ],
      'disclaimer': '教育試算',
    });

    expect(
      preview.endingBalanceMinor,
      preview.principalMinor + preview.growthMinor,
    );
    expect(preview.yearlyPoints.single.year, 1);
  });
}
