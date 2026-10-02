import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/app/future_mint_app.dart';
import 'package:futuremint_app/auth/auth_api.dart';
import 'package:futuremint_app/auth/auth_models.dart';
import 'package:futuremint_app/auth/session_store.dart';
import 'package:futuremint_app/auth/service_policy.dart';
import 'package:futuremint_app/core/models.dart';
import 'package:futuremint_app/core/launch_models.dart';
import 'package:futuremint_app/data/api_repository.dart';
import 'package:futuremint_app/data/demo_repository.dart';
import 'package:futuremint_app/reminders/subscription_reminders.dart';
import 'package:futuremint_app/state/app_controller.dart';
import 'package:futuremint_app/state/session_controller.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'state/session_controller_test.dart'
    show FakeAuthGateway, FakeStore, session;

UserProfile profile() => UserProfile(
  userId: 'account-1',
  monthlyBudgetMinor: 6000,
  goalName: '合成目標',
  goalTargetMinor: 20000,
  goalSavedMinor: 10000,
  goalDate: DateTime(2027),
);
const policy = ServicePolicy(
  aiPolicyVersion: 'current-v2',
  aiDisplayName: '測試供應商',
  aiProvider: 'test',
  dataRecipients: ['test'],
  dataTerms: '合成條款',
  guardianConsentMethod: 'in-app',
  mailEnabled: false,
  emailVerificationRequired: false,
);

class Repo extends GuestRepository {
  Repo() : super.transient(now: () => DateTime.utc(2026, 10, 1));
  UserProfile saved = profile();
  bool fail = false, lose = false;
  final keys = <String>[];
  Completer<SubscriptionComparison?>? initialComparison;
  int comparisonCalls = 0;
  @override
  Future<SubscriptionComparison?> compareSubscriptions() async {
    if (comparisonCalls++ == 0 && initialComparison != null) {
      return initialComparison!.future;
    }
    return super.compareSubscriptions();
  }

  final subscriptionKeys = <String>[];
  bool loseSubscription = false;
  VoidCallback? beforeRequest;
  @override
  Future<void> createSubscription(
    SubscriptionInput input, {
    required String idempotencyKey,
    String? legacyPaymentId,
    CaptureDraft? initialPayment,
  }) async {
    beforeRequest?.call();
    subscriptionKeys.add(idempotencyKey);
    await super.createSubscription(
      input,
      idempotencyKey: idempotencyKey,
      legacyPaymentId: legacyPaymentId,
      initialPayment: initialPayment,
    );
    if (loseSubscription) {
      loseSubscription = false;
      throw const ApiException(
        code: 'request_timeout',
        message: '訂閱回應遺失',
        retryable: true,
      );
    }
  }

  @override
  Future<UserProfile> getProfile() async => saved;
  @override
  Future<UserProfile> updateProfile(UserProfile p) async => saved = p;
  @override
  Future<List<MoneyEvent>> listMoneyEvents() async {
    try {
      return await super.listMoneyEvents();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<DashboardSummary> getDashboard() async {
    if (fail) {
      throw const ApiException(
        code: 'network_error',
        message: '摘要失敗',
        retryable: true,
      );
    }
    return super.getDashboard();
  }

  @override
  Future<InvestmentLab> placeInvestmentOrder({
    required String symbol,
    required InvestmentOrderSide side,
    required int quantity,
    required String idempotencyKey,
  }) async {
    beforeRequest?.call();
    keys.add(idempotencyKey);
    final lab = await super.placeInvestmentOrder(
      symbol: symbol,
      side: side,
      quantity: quantity,
      idempotencyKey: idempotencyKey,
    );
    if (lose) {
      lose = false;
      throw const ApiException(
        code: 'request_timeout',
        message: '回應遺失',
        retryable: true,
      );
    }
    return lab;
  }
}

class MemoryIntents extends FakeStore implements PendingIntentPersistence {
  final values = <String, String>{};
  bool failWrite = false;
  @override
  Future<String?> readPending(String id) async => values[id];
  @override
  Future<void> writePending(String id, String value) async {
    if (failWrite) throw StateError('secure storage failed');
    values[id] = value;
  }

  @override
  Future<void> clearPending(String id) async {
    values.remove(id);
  }
}

class Auth extends FakeAuthGateway {
  Auth({bool complete = true}) : super(session(profileComplete: complete));
  EligibilityStatus eligibility = const EligibilityStatus(
    status: 'guardian-required',
    canWrite: false,
    ageBand: '15-17',
    guardianStatus: 'pending',
  );
  ServicePolicy metadata = policy;
  String? email, version;
  int inAppConfirmations = 0;
  @override
  Future<ServicePolicy?> getServicePolicy() async => metadata;
  @override
  Future<EligibilityStatus?> getEligibility(String token) async => eligibility;
  @override
  Future<void> requestGuardian(String token, String value) async {
    email = value;
  }

  @override
  Future<void> confirmGuardianInApp(String token) async {
    inAppConfirmations++;
    eligibility = const EligibilityStatus(
      status: 'eligible',
      canWrite: true,
      ageBand: '15-17',
      guardianStatus: 'approved',
    );
  }

  @override
  Future<void> withdrawGuardian(String token) async {
    eligibility = const EligibilityStatus(
      status: 'guardian-withdrawn',
      canWrite: false,
      ageBand: '15-17',
      guardianStatus: 'withdrawn',
    );
  }

  @override
  Future<AiConsentStatus> updateVersionedAiConsent({
    required String token,
    required bool granted,
    String? policyVersion,
  }) async {
    version = policyVersion;
    return AiConsentStatus(granted: granted, policyVersion: policyVersion);
  }
}

SessionController controller(Auth a, Repo r) => SessionController(
  auth: a,
  store: FakeStore()..token = 'a' * 43,
  authenticatedRepository: (_) => r,
  guestRepository: GuestRepository.create,
  reminders: SubscriptionReminders(supported: false),
);
CaptureDraft draft(String id, int amount) => CaptureDraft(
  draftId: id,
  type: MoneyEventType.expense,
  amountMinor: amount,
  currency: 'TWD',
  category: MoneyCategory.other,
  occurredAt: DateTime.utc(2026, 10, 1),
  confidence: 1,
  missingFields: const [],
  needsConfirmation: true,
  source: CaptureSource.manual,
);
ActiveSubscription active({
  String id = 's',
  DateTime? next,
  int day = 31,
  int month = 1,
  BillingCycle cycle = BillingCycle.monthly,
}) => ActiveSubscription(
  id: id,
  userId: 'account-1',
  name: '保密商家',
  amountMinor: 1200,
  billingCycle: cycle,
  anchorDate: DateTime(2024, month, day),
  originalBillingDay: day,
  originalBillingMonth: month,
  nextBillingDate: next ?? DateTime(2026, 1, 31),
  active: true,
);
void main() {
  test('service policy preserves requested model and detects its change', () {
    final payload = <String, dynamic>{
      'ai': {
        'policyVersion': 'policy-v1',
        'provider': 'synthetic',
        'displayName': '合成供應商',
        'model': 'requested-model-v1',
        'dataTerms': '合成條款',
      },
    };
    final original = ServicePolicy.fromJson(payload);
    expect(original.model, 'requested-model-v1');
    (payload['ai'] as Map<String, dynamic>)['model'] = 'requested-model-v2';
    expect(
      ServicePolicy.fromJson(payload).signature,
      isNot(original.signature),
    );
    (payload['ai'] as Map<String, dynamic>).remove('model');
    expect(ServicePolicy.fromJson(payload).model, isNull);
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'manual source works without AI and saves only after confirmation',
    () async {
      final r = Repo(),
          c = AppController(repository: Repo(), mode: AppMode.authenticated);
      c.repository = r;
      await c.initialize();
      c.startManualCapture();
      expect(c.captureResult!.drafts.single.source, CaptureSource.manual);
      expect(await r.listMoneyEvents(), isEmpty);
      await c.saveDraft(
        c.captureResult!.drafts.single.copyWith(amountMinor: 75),
      );
      expect(c.events.single.source, CaptureSource.manual);
      expect(c.isAiEnabled, isFalse);
    },
  );
  test(
    'subscriptions keep commitments separate, create idempotent, explicit adoption and deactivate preserve payment',
    () async {
      final r = Repo(),
          input = SubscriptionInput(
            name: '年費',
            amountMinor: 1200,
            billingCycle: BillingCycle.yearly,
            anchorDate: DateTime(2026, 10, 31),
          );
      expect(await r.compareSubscriptions(), isNull);
      await r.createSubscription(input, idempotencyKey: 'create-key');
      await r.createSubscription(input, idempotencyKey: 'create-key');
      expect((await r.getSubscriptions()).items.length, 1);
      expect((await r.getDashboard()).monthlyCommitmentMinor, 100);
      expect(await r.listMoneyEvents(), isEmpty);
      expect((await r.compareSubscriptions())!.currentMonthlyCostMinor, 100);
      final payment = await r.saveDraft(
        draft('payment', 1200).copyWith(
          type: MoneyEventType.subscription,
          recurrence: const RecurrenceDetails(
            billingCycle: BillingCycle.yearly,
          ),
        ),
        idempotencyKey: 'payment-key',
      );
      await r.createSubscription(
        input,
        idempotencyKey: 'adopt-key',
        legacyPaymentId: payment.id,
      );
      expect((await r.getSubscriptions()).legacyCandidates, isEmpty);
      await r.deactivateSubscription(
        (await r.getSubscriptions()).items.first.id,
      );
      expect((await r.listMoneyEvents()).single.id, payment.id);
      expect((await r.getSubscriptions()).monthlyCommitmentMinor, 100);
    },
  );
  test('page max50 loadmore keeps unique records and full summary', () async {
    final r = Repo();
    for (var i = 0; i < 55; i++) {
      await r.saveDraft(draft('$i', 1), idempotencyKey: 'p$i');
    }
    final c = AppController(repository: r, mode: AppMode.guest);
    await c.initialize();
    expect(c.events.length, 50);
    expect(c.dashboard!.expenseMinor, 55);
    await c.loadMoreEvents();
    expect(c.events.length, 55);
    expect(c.events.map((e) => e.id).toSet().length, 55);
    expect(c.nextEventsCursor, isNull);
  });
  test(
    'response lost order retries same key; altered intent blocked; reconcile stops pending',
    () async {
      final r = Repo()..lose = true,
          c = AppController(repository: Repo(), mode: AppMode.guest);
      c.repository = r;
      await c.initialize();
      await c.placeInvestmentOrder(
        symbol: '2330',
        side: InvestmentOrderSide.buy,
        quantity: 1,
      );
      expect(c.hasPendingOrder, isTrue);
      await c.placeInvestmentOrder(
        symbol: '2330',
        side: InvestmentOrderSide.buy,
        quantity: 2,
      );
      expect(r.keys.length, 1);
      await c.placeInvestmentOrder(
        symbol: '2330',
        side: InvestmentOrderSide.buy,
        quantity: 1,
      );
      expect(r.keys.toSet().length, 1);
      expect(c.investmentLab!.orders.length, 1);
      expect(c.hasPendingOrder, isFalse);
      r.lose = true;
      await c.placeInvestmentOrder(
        symbol: '2330',
        side: InvestmentOrderSide.buy,
        quantity: 1,
      );
      await c.loadInvestmentLab();
      expect(c.hasPendingOrder, isFalse);
      expect(c.investmentLab!.orders.length, 2);
    },
  );
  test(
    'saved onboarding failed summary is recoverable instead of empty dashboard',
    () async {
      final a = Auth(complete: false)
            ..eligibility = const EligibilityStatus(
              status: 'eligible',
              canWrite: true,
              ageBand: '18-plus',
            ),
          r = Repo()..fail = true,
          s = controller(Auth(), Repo());
      s.dispose();
      final sessionController = controller(a, r);
      await sessionController.start();
      expect(sessionController.status, SessionStatus.onboarding);
      expect(await sessionController.completeOnboarding(profile()), isFalse);
      expect(sessionController.account!.profileComplete, isTrue);
      expect(sessionController.status, SessionStatus.restorationFailed);
      expect(sessionController.app, isNull);
      a.result = AuthSession(
        token: 'a' * 43,
        account: a.result.account.copyWith(profileComplete: true),
      );
      r.fail = false;
      await sessionController.start();
      expect(sessionController.status, SessionStatus.authenticated);
      expect(sessionController.app!.dashboard, isNotNull);
    },
  );
  test(
    'guardian pending resend approval withdrawal retain readonly export and block changes',
    () async {
      final a = Auth(), r = Repo();
      final s = controller(a, r);
      await s.start();
      expect(s.status, SessionStatus.eligibilityRequired);
      await s.requestGuardian('guardian@example.test');
      expect(a.email, 'guardian@example.test');
      await s.enterReadOnly();
      expect(s.app!.canWrite, isFalse);
      expect(await s.app!.updateProfile(profile()), isFalse);
      expect(await s.app!.exportSelf(), isNotNull);
      a.eligibility = const EligibilityStatus(
        status: 'eligible',
        canWrite: true,
        ageBand: '15-17',
        guardianStatus: 'approved',
      );
      await s.refreshEligibility();
      expect(s.app!.canWrite, isTrue);
      await s.withdrawGuardian();
      expect(s.status, SessionStatus.eligibilityRequired);
      await s.enterReadOnly();
      expect(s.app!.canWrite, isFalse);
    },
  );
  test(
    'current policy invalidates older consent and sends version on grant',
    () async {
      final a = Auth()
        ..eligibility = const EligibilityStatus(
          status: 'eligible',
          canWrite: true,
          ageBand: '18-plus',
        )
        ..consent = const AiConsentStatus(granted: true, policyVersion: 'old');
      final s = controller(a, Repo());
      await s.start();
      expect(s.app!.isAiEnabled, isFalse);
      await s.app!.updateAiConsent(true);
      expect(a.version, 'current-v2');
      expect(s.app!.isAiEnabled, isTrue);
    },
  );
  test(
    'demo eligibility bypass keeps missing declaration visible as missing',
    () async {
      final a = Auth()
        ..metadata = const ServicePolicy(
          aiPolicyVersion: 'test',
          aiDisplayName: 'test',
          aiProvider: 'test',
          dataRecipients: [],
          dataTerms: 'test',
          eligibilityRequired: false,
        )
        ..eligibility = const EligibilityStatus(
          status: 'declaration-required',
          canWrite: false,
        );
      final s = controller(a, Repo());
      await s.start();
      expect(s.status, SessionStatus.authenticated);
      expect(s.eligibility!.ageBand, isNull);
    },
  );
  test(
    'Taipei 09 day-before keeps original monthend and leapday, generic payload earliest60',
    () {
      final monthly = reminderOccurrences([active()], DateTime.utc(2026, 1, 1));
      expect(monthly.first['at'], '2026-01-30T01:00:00.000Z');
      expect(monthly[1]['at'], '2026-02-27T01:00:00.000Z');
      expect(monthly[2]['at'], '2026-03-30T01:00:00.000Z');
      final leap = reminderOccurrences([
        active(
          next: DateTime(2027, 2, 28),
          day: 29,
          month: 2,
          cycle: BillingCycle.yearly,
        ),
      ], DateTime.utc(2027, 1, 1));
      expect(leap.first['at'], '2027-02-27T01:00:00.000Z');
      expect(leap[1]['at'], '2028-02-28T01:00:00.000Z');
      expect(leap.length, 60);
      expect(jsonEncode(leap), isNot(contains('保密商家')));
      final list = reminderOccurrences([
        active(id: 'a'),
        active(id: 'b'),
      ], DateTime.utc(2026, 1, 1));
      expect(list.length, 60);
      expect(list.last['at'], '2028-06-29T01:00:00.000Z');
    },
  );
  test(
    'permission callback cannot reactivate after logout/accountswitch',
    () async {
      const channel = MethodChannel('test-reminders');
      final gate = Completer<Map<String, Object>>(), calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            if (call.method == 'setEnabled') return gate.future;
            return {'enabled': false, 'permission': 'notDetermined'};
          });
      final service = SubscriptionReminders(channel: channel, supported: true);
      await service.bind('account-1');
      final enabled = service.setEnabled(true);
      await Future<void>.delayed(Duration.zero);
      final clear = service.clear();
      gate.complete({'enabled': true, 'permission': 'authorized'});
      await enabled;
      await clear;
      expect(service.enabled, isFalse);
      expect(calls, ['bind', 'setEnabled', 'bind']);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    },
  );
  test('API pagination carries cursor and bearer token', () async {
    final requests = <http.Request>[],
        api = ApiRepository(
          baseUri: Uri.parse('https://example.test/api'),
          accessToken: 'synthetic-token',
          client: MockClient((r) async {
            requests.add(r);
            return http.Response(
              jsonEncode({
                'data': {'items': [], 'nextCursor': 'next'},
              }),
              200,
            );
          }),
        );
    await api.listMoneyEventPage(cursor: 'abc+/=');
    expect(requests.single.url.queryParameters, {
      'limit': '50',
      'cursor': 'abc+/=',
    });
    expect(requests.single.headers['authorization'], 'Bearer synthetic-token');
  });
  test(
    'age registration and current consent carry versioned declaration',
    () async {
      final payloads = <Map<String, dynamic>>[],
          api = AuthApi(
            baseUri: Uri.parse('https://example.test/api'),
            client: MockClient((r) async {
              payloads.add(jsonDecode(r.body) as Map<String, dynamic>);
              return http.Response(
                jsonEncode({
                  'data': r.url.path.endsWith('register')
                      ? {
                          'token': 'a' * 43,
                          'account': {
                            'id': 'account-1',
                            'email': 'synthetic@example.test',
                            'profileComplete': false,
                            'createdAt': '2026-10-01T00:00:00Z',
                          },
                        }
                      : {'granted': true, 'policyVersion': 'current-v2'},
                }),
                200,
              );
            }),
          );
      await api.registerWithAge(
        email: 'synthetic@example.test',
        password: 'synthetic-password',
        ageBand: '15-17',
      );
      expect(payloads.first['ageDeclaration'], {
        'ageBand': '15-17',
        'policyVersion': agePolicyVersion,
        'accepted': true,
      });
      await api.updateVersionedAiConsent(
        token: 'a' * 43,
        granted: true,
        policyVersion: 'current-v2',
      );
      expect(payloads.last, {'granted': true, 'policyVersion': 'current-v2'});
    },
  );
  test(
    'pending subscription persists BEFORE HTTP, survives reopen restart and blocks changed payload',
    () async {
      final store = MemoryIntents(), r = Repo()..loseSubscription = true;
      r.beforeRequest = () {
        expect(store.values['account-1'], isNotNull);
      };
      final input = SubscriptionInput(
        name: '合成訂閱',
        amountMinor: 100,
        billingCycle: BillingCycle.monthly,
        anchorDate: DateTime(2026, 10, 31),
      );
      final c = AppController(
        repository: r,
        mode: AppMode.authenticated,
        intentStore: store,
        intentOwner: 'account-1',
      );
      await c.initialize();
      expect(
        await c.saveSubscription(input, idempotencyKey: 'original-create-key'),
        isFalse,
      );
      expect(c.hasPendingSubscription, isTrue);
      c.dispose();
      final reopened = AppController(
        repository: r,
        mode: AppMode.authenticated,
        intentStore: store,
        intentOwner: 'account-1',
      );
      await reopened.restorePendingIntents();
      await reopened.initialize();
      expect(reopened.hasPendingSubscription, isTrue);
      expect(
        await reopened.saveSubscription(
          SubscriptionInput(
            name: '改內容',
            amountMinor: 200,
            billingCycle: BillingCycle.monthly,
            anchorDate: DateTime(2026, 10, 31),
          ),
          idempotencyKey: 'new-key',
        ),
        isFalse,
      );
      expect(r.subscriptionKeys.length, 1);
      expect(await reopened.retryPendingSubscription(), isTrue);
      expect(r.subscriptionKeys, [
        'original-create-key',
        'original-create-key',
      ]);
      expect((await r.getSubscriptions()).items.length, 1);
      expect(store.values, isEmpty);
    },
  );
  test(
    'subscription server commit is success even when summary refresh fails',
    () async {
      final r = Repo(),
          c = AppController(repository: Repo(), mode: AppMode.guest);
      c.repository = r;
      await c.initialize();
      r.fail = true;
      expect(
        await c.saveSubscription(
          SubscriptionInput(
            name: '合成',
            amountMinor: 100,
            billingCycle: BillingCycle.monthly,
            anchorDate: DateTime(2026, 10, 1),
          ),
          idempotencyKey: 'commit-key',
        ),
        isTrue,
      );
      expect(c.hasPendingSubscription, isFalse);
      expect(c.noticeMessage, contains('已儲存'));
      expect((await r.getSubscriptions()).items.length, 1);
    },
  );
  test(
    'order persists before request and restart recovers same key without crossing accounts',
    () async {
      final store = MemoryIntents(), r = Repo()..lose = true;
      r.beforeRequest = () {
        expect(store.values['account-1'], isNotNull);
      };
      final c = AppController(
        repository: r,
        mode: AppMode.authenticated,
        intentStore: store,
        intentOwner: 'account-1',
      );
      await c.initialize();
      await c.placeInvestmentOrder(
        symbol: '2330',
        side: InvestmentOrderSide.buy,
        quantity: 1,
      );
      c.dispose();
      final other = AppController(
        repository: r,
        mode: AppMode.authenticated,
        intentStore: store,
        intentOwner: 'different-user',
      );
      await other.restorePendingIntents();
      expect(other.hasPendingOrder, isFalse);
      final restored = AppController(
        repository: r,
        mode: AppMode.authenticated,
        intentStore: store,
        intentOwner: 'account-1',
      );
      await restored.restorePendingIntents();
      await restored.initialize();
      await restored.placeInvestmentOrder(
        symbol: '2330',
        side: InvestmentOrderSide.buy,
        quantity: 1,
      );
      expect(r.keys.toSet().length, 1);
      expect(restored.investmentLab!.orders.length, 1);
      expect(store.values, isEmpty);
    },
  );
  test(
    'secure store failure prevents sending orders and subscription creates',
    () async {
      final store = MemoryIntents()..failWrite = true, r = Repo();
      final c = AppController(
        repository: r,
        mode: AppMode.authenticated,
        intentStore: store,
        intentOwner: 'account-1',
      );
      await c.initialize();
      await c.placeInvestmentOrder(
        symbol: '2330',
        side: InvestmentOrderSide.buy,
        quantity: 1,
      );
      expect(r.keys, isEmpty);
      expect(
        await c.saveSubscription(
          SubscriptionInput(
            name: '合成',
            amountMinor: 100,
            billingCycle: BillingCycle.monthly,
            anchorDate: DateTime(2026, 10, 1),
          ),
          idempotencyKey: 'storage-failed-key',
        ),
        isFalse,
      );
      expect(r.subscriptionKeys, isEmpty);
    },
  );
  test(
    'readonly permits delete and deactivate while new records contract profile orders stay blocked',
    () async {
      final r = Repo();
      final event = await r.saveDraft(
        draft('remove', 10),
        idempotencyKey: 'remove-key',
      );
      final input = SubscriptionInput(
        name: '停用',
        amountMinor: 100,
        billingCycle: BillingCycle.monthly,
        anchorDate: DateTime(2026, 10, 1),
      );
      await r.createSubscription(input, idempotencyKey: 'deactivate-key');
      final id = (await r.getSubscriptions()).items.single.id;
      final c = AppController(
        repository: r,
        mode: AppMode.authenticated,
        canWrite: false,
      );
      await c.initialize();
      expect(await c.deleteMoneyEvent(event.id), isTrue);
      expect(await c.deactivateSubscription(id), isTrue);
      expect((await r.listMoneyEvents()), isEmpty);
      expect((await r.getSubscriptions()).monthlyCommitmentMinor, 0);
      expect(await c.updateProfile(profile()), isFalse);
      expect(
        await c.saveSubscription(input, idempotencyKey: 'forbidden-key'),
        isFalse,
      );
      await c.placeInvestmentOrder(
        symbol: '2330',
        side: InvestmentOrderSide.buy,
        quantity: 1,
      );
      expect(r.keys, isEmpty);
      c.startManualCapture();
      expect(c.captureResult, isNull);
    },
  );
  test(
    'linked payment edit retains subscriptionId until explicitly changing type',
    () async {
      final linked = draft(
        'linked',
        100,
      ).copyWith(type: MoneyEventType.subscription);
      final j = linked.toJson()..['subscriptionId'] = 'contract-1';
      final payment = CaptureDraft.fromJson(j);
      expect(payment.copyWith(amountMinor: 200).subscriptionId, 'contract-1');
      expect(
        payment.copyWith(type: MoneyEventType.expense).subscriptionId,
        isNull,
      );
      final requests = <Map<String, dynamic>>[],
          api = ApiRepository(
            baseUri: Uri.parse('https://example.test/api'),
            client: MockClient((r) async {
              requests.add(jsonDecode(r.body) as Map<String, dynamic>);
              return http.Response(
                jsonEncode({
                  'data': {
                    'id': 'payment-1',
                    'userId': 'account-1',
                    ...requests.last,
                    'occurredAt': '2026-10-01T00:00:00Z',
                    'createdAt': '2026-10-01T00:00:00Z',
                    'updatedAt': '2026-10-01T00:00:00Z',
                  },
                }),
                200,
              );
            }),
          );
      await api.updateMoneyEvent(
        'payment-1',
        payment.copyWith(amountMinor: 200),
      );
      expect(requests.single['subscriptionId'], 'contract-1');
    },
  );
  test(
    'foreground resume retains controller theme and pending order with same account policy',
    () async {
      final a = Auth()
            ..eligibility = const EligibilityStatus(
              status: 'eligible',
              canWrite: true,
              ageBand: '18-plus',
            ),
          r = Repo()..lose = true;
      final s = controller(a, r);
      await s.start();
      final original = s.app!;
      original.setThemeMode(ThemeMode.dark);
      await original.placeInvestmentOrder(
        symbol: '2330',
        side: InvestmentOrderSide.buy,
        quantity: 1,
      );
      expect(original.hasPendingOrder, isTrue);
      await s.resume();
      expect(identical(s.app, original), isTrue);
      expect(s.app!.themeMode, ThemeMode.dark);
      expect(s.app!.hasPendingOrder, isTrue);
      await s.app!.placeInvestmentOrder(
        symbol: '2330',
        side: InvestmentOrderSide.buy,
        quantity: 1,
      );
      expect(r.keys.toSet().length, 1);
    },
  );
  test(
    'late initial subscription comparison cannot overwrite newer committed snapshot',
    () async {
      final gate = Completer<SubscriptionComparison?>(), r = Repo();
      r.initialComparison = gate;
      final c = AppController(repository: r, mode: AppMode.guest);
      await c.initialize();
      await c.saveSubscription(
        SubscriptionInput(
          name: '最新方案',
          amountMinor: 100,
          billingCycle: BillingCycle.monthly,
          anchorDate: DateTime(2026, 10, 31),
        ),
        idempotencyKey: 'latest-key',
      );
      expect(c.subscriptionComparison!.currentName, '最新方案');
      gate.complete(null);
      await Future<void>.delayed(Duration.zero);
      expect(c.subscriptionComparison!.currentName, '最新方案');
    },
  );
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'in-app guardian requires an unchecked explicit choice at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final a = Auth(complete: false);
        final s = controller(a, Repo());
        addTearDown(s.dispose);
        await s.start();
        await tester.pumpWidget(FutureMintApp(session: s));
        await tester.pumpAndSettle();
        expect(find.text('監護人電子郵件'), findsNothing);
        expect(find.text('寄送／重寄同意信'), findsNothing);
        final button = find.widgetWithText(FilledButton, '確認同意並繼續');
        expect(tester.widget<FilledButton>(button).onPressed, isNull);
        final checkbox = find.byKey(const Key('guardian-in-app-consent'));
        expect(tester.widget<CheckboxListTile>(checkbox).value, isFalse);
        await tester.ensureVisible(checkbox);
        await tester.tap(checkbox);
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(a.inAppConfirmations, 1);
        expect(a.email, isNull);
        expect(s.status, SessionStatus.onboarding);
        expect(a.version, isNull);
        expect(a.consent.granted, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('pending guardian keeps logout delete help accessible', (
    tester,
  ) async {
    final s = controller(Auth(complete: false), Repo());
    await s.start();
    await tester.pumpWidget(FutureMintApp(session: s));
    await tester.pumpAndSettle();
    expect(find.text('請監護人確認'), findsOneWidget);
    expect(find.text('刪除這個帳號'), findsOneWidget);
    expect(find.text('登出'), findsOneWidget);
    expect(find.text('使用說明與協助'), findsOneWidget);
  });
}
