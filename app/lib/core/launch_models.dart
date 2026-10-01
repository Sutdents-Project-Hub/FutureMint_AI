import 'models.dart';

abstract interface class ControlledEducationRepository {
  Future<Lesson> getControlledLesson();
}

class MoneyEventPage {
  const MoneyEventPage(this.items, this.nextCursor);
  final List<MoneyEvent> items;
  final String? nextCursor;
}

class ActiveSubscription {
  const ActiveSubscription({
    required this.id,
    required this.userId,
    required this.name,
    required this.amountMinor,
    required this.billingCycle,
    required this.anchorDate,
    required this.originalBillingDay,
    required this.originalBillingMonth,
    required this.nextBillingDate,
    required this.active,
  });
  final String id, userId, name;
  final int amountMinor, originalBillingDay, originalBillingMonth;
  final BillingCycle billingCycle;
  final DateTime anchorDate, nextBillingDate;
  final bool active;
  int get monthlyCommitmentMinor => billingCycle == BillingCycle.yearly
      ? (amountMinor / 12).round()
      : amountMinor;
  factory ActiveSubscription.fromJson(Map<String, dynamic> j) =>
      ActiveSubscription(
        id: j['id'] as String,
        userId: j['userId'] as String,
        name: j['name'] as String,
        amountMinor: j['amountMinor'] as int,
        billingCycle: BillingCycle.values.byName(j['billingCycle'] as String),
        anchorDate: DateTime.parse(j['anchorDate'] as String),
        originalBillingDay: j['originalBillingDay'] as int,
        originalBillingMonth: j['originalBillingMonth'] as int,
        nextBillingDate: DateTime.parse(j['nextBillingDate'] as String),
        active: j['active'] as bool,
      );
}

class SubscriptionInput {
  const SubscriptionInput({
    required this.name,
    required this.amountMinor,
    required this.billingCycle,
    required this.anchorDate,
  });
  final String name;
  final int amountMinor;
  final BillingCycle billingCycle;
  final DateTime anchorDate;
  Map<String, dynamic> toJson() => {
    'name': name,
    'amountMinor': amountMinor,
    'currency': 'TWD',
    'billingCycle': billingCycle.name,
    'anchorDate': dateOnly(anchorDate),
  };
}

String dateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class SubscriptionCollection {
  const SubscriptionCollection({
    required this.items,
    required this.legacyCandidates,
  });
  final List<ActiveSubscription> items;
  final List<MoneyEvent> legacyCandidates;
  int get monthlyCommitmentMinor => items
      .where((s) => s.active)
      .fold(0, (v, s) => v + s.monthlyCommitmentMinor);
}

abstract interface class LaunchRepository {
  Future<MoneyEventPage> listMoneyEventPage({String? cursor});
  Future<SubscriptionCollection> getSubscriptions();
  Future<void> createSubscription(
    SubscriptionInput input, {
    required String idempotencyKey,
    String? legacyPaymentId,
    CaptureDraft? initialPayment,
  });
  Future<void> updateSubscription(String id, SubscriptionInput input);
  Future<void> deactivateSubscription(String id);
  Future<Map<String, dynamic>> exportSelf();
}
