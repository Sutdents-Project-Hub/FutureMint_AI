import 'dart:async';
import 'dart:convert';
import '../auth/session_store.dart';

import 'package:flutter/material.dart';

import '../core/future_mint_repository.dart';
import '../core/models.dart';
import '../data/api_repository.dart';
import '../auth/auth_models.dart';
import '../auth/service_policy.dart';
import '../core/launch_models.dart';
import '../reminders/subscription_reminders.dart';

class AppController extends ChangeNotifier {
  AppController({
    required this.repository,
    required this.mode,
    this.accountEmail,
    this.onExit,
    this.onUnauthorized,
    this.aiConsent = const AiConsentStatus.notGranted(),
    this.onAiConsentChanged,
    this.onDeleteAccount,
    this.servicePolicy,
    this.reminders,
    this.onGuardianWithdrawn,
    this.onEligibilityChanged,
    this.canWrite = true,
    this.onViewEligibility,
    this.intentStore,
    this.intentOwner,
  });

  FutureMintRepository repository;
  final AppMode mode;
  final String? accountEmail;
  final Future<void> Function()? onExit;
  final Future<void> Function()? onUnauthorized;
  final Future<AiConsentStatus> Function(bool granted)? onAiConsentChanged;
  final Future<void> Function(String password)? onDeleteAccount;
  final ServicePolicy? servicePolicy;
  final SubscriptionReminders? reminders;
  final Future<void> Function()? onGuardianWithdrawn;
  final Future<void> Function()? onEligibilityChanged;
  final VoidCallback? onViewEligibility;
  final bool canWrite;
  final PendingIntentPersistence? intentStore;
  final String? intentOwner;
  ThemeMode themeMode = ThemeMode.system;
  SubscriptionCollection subscriptions = const SubscriptionCollection(
    items: [],
    legacyCandidates: [],
  );
  String? nextEventsCursor;
  bool summariesLoaded = false;
  int _snapshotGeneration = 0;
  int _comparisonGeneration = 0;
  ({String symbol, InvestmentOrderSide side, int quantity, String key})?
  _pendingOrder;
  bool get hasPendingOrder => _pendingOrder != null;
  ({
    SubscriptionInput input,
    CaptureDraft? initialPayment,
    String? legacyPaymentId,
    String key,
    String fingerprint,
  })?
  _pendingSubscription;
  bool get hasPendingSubscription => _pendingSubscription != null;
  String _subscriptionFingerprint(
    SubscriptionInput input,
    CaptureDraft? payment,
    String? legacy,
  ) => jsonEncode({
    'input': input.toJson(),
    'payment': payment?.toJson(),
    'legacy': legacy,
  });
  Future<void> restorePendingIntents() async {
    final owner = intentOwner, store = intentStore;
    if (owner == null || store == null) return;
    final raw = await store.readPending(owner);
    if (raw == null) return;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    if (j['owner'] != owner) throw const FormatException('待確認操作的帳號不一致，請重新登入。');
    if (j['order'] case final Map<String, dynamic> o) {
      _pendingOrder = (
        symbol: o['symbol'] as String,
        side: InvestmentOrderSide.values.byName(o['side'] as String),
        quantity: o['quantity'] as int,
        key: o['key'] as String,
      );
    }
    if (j['subscription'] case final Map<String, dynamic> s) {
      final i = s['input'] as Map<String, dynamic>;
      final input = SubscriptionInput(
        name: i['name'] as String,
        amountMinor: i['amountMinor'] as int,
        billingCycle: BillingCycle.values.byName(i['billingCycle'] as String),
        anchorDate: DateTime.parse(i['anchorDate'] as String),
      );
      final payment = s['payment'] == null
          ? null
          : CaptureDraft.fromJson(s['payment'] as Map<String, dynamic>);
      final legacy = s['legacy'] as String?;
      _pendingSubscription = (
        input: input,
        initialPayment: payment,
        legacyPaymentId: legacy,
        key: s['key'] as String,
        fingerprint: _subscriptionFingerprint(input, payment, legacy),
      );
    }
  }

  Future<void> _persistPendingIntents() async {
    final owner = intentOwner, store = intentStore;
    if (owner == null || store == null) return;
    final order = _pendingOrder, subscription = _pendingSubscription;
    if (order == null && subscription == null) {
      await store.clearPending(owner);
      return;
    }
    await store.writePending(
      owner,
      jsonEncode({
        'owner': owner,
        if (order != null)
          'order': {
            'symbol': order.symbol,
            'side': order.side.name,
            'quantity': order.quantity,
            'key': order.key,
          },
        if (subscription != null)
          'subscription': {
            'input': subscription.input.toJson(),
            'payment': subscription.initialPayment?.toJson(),
            'legacy': subscription.legacyPaymentId,
            'key': subscription.key,
          },
      }),
    );
  }

  bool initialized = false;
  bool busy = false;
  String? errorMessage;
  String? noticeMessage;
  UserProfile? profile;
  DashboardSummary? dashboard;
  List<MoneyEvent> events = const [];
  CaptureResult? captureResult;
  MoneyEvent? lastSavedEvent;
  SubscriptionComparison? subscriptionComparison;
  Lesson? lesson;
  FinancialInsights? insights;
  LearningPlan? learningPlan;
  FutureSeedPreview? futureSeedPreview;
  InvestmentSimulation? investmentSimulation;
  InvestmentLab? investmentLab;
  PracticeDiceEvent? practiceDiceEvent;
  CoachReply? coachReply;
  CoachReply? learningCoachReply;
  FamilyOverview? familyOverview;
  AiConsentStatus aiConsent;
  bool _disposed = false;

  void _notifyListeners() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  bool get isAiEnabled =>
      canWrite && (mode != AppMode.authenticated || aiConsent.granted);
  bool get canManageAiConsent =>
      mode == AppMode.authenticated && onAiConsentChanged != null;
  bool get canDeleteAccount =>
      mode == AppMode.authenticated && onDeleteAccount != null;

  bool _blockAiWhenDisabled() {
    if (isAiEnabled) return false;
    errorMessage = '尚未啟用 AI。你仍可使用非 AI 功能，請在設定查看資料用途後再決定。';
    _notifyListeners();
    return true;
  }

  void _clearAiState() {
    if (captureResult?.drafts.any(
          (draft) => draft.source != CaptureSource.manual,
        ) ==
        true) {
      captureResult = null;
    }
    lesson = null;
    learningPlan = null;
    coachReply = null;
    learningCoachReply = null;
  }

  Future<bool> _perform(
    Future<void> Function() operation, {
    bool write = false,
  }) async {
    if (_disposed || busy) return false;
    if (write && !canWrite) {
      errorMessage = '目前僅可查看既有資料；請先完成年齡與監護人同意。';
      _notifyListeners();
      return false;
    }
    busy = true;
    errorMessage = null;
    _notifyListeners();
    try {
      await operation();
      return true;
    } catch (error) {
      errorMessage = switch (error) {
        FormatException(:final message) => message,
        ApiException(:final message) => message,
        _ => '目前無法完成操作，請稍後再試。',
      };
      if (error case ApiException(code: 'unauthorized')) {
        await onUnauthorized?.call();
      } else if (error is ApiException &&
          (error.code == 'age_declaration_required' ||
              error.code == 'guardian_consent_required')) {
        await reminders?.clear();
        await onEligibilityChanged?.call();
      } else if (error is ApiException &&
          (error.code == 'ai_consent_required' ||
              error.code == 'ai_policy_changed')) {
        // The server is authoritative when a policy version changes while the
        // app is open. Fail closed locally and ask for fresh consent.
        aiConsent = const AiConsentStatus.notGranted();
        _clearAiState();
      }
      return false;
    } finally {
      busy = false;
      _notifyListeners();
    }
  }

  Future<void> _run(
    Future<void> Function() operation, {
    bool write = false,
  }) async {
    await _perform(operation, write: write);
  }

  Future<void> _handlePartialFailure(
    Object error, {
    required String notice,
  }) async {
    if (error case ApiException(code: 'unauthorized')) {
      await onUnauthorized?.call();
      return;
    }
    noticeMessage = notice;
  }

  Future<void> initialize() => _run(() async {
    await refresh();
    initialized = true;
    if (!canWrite) {
      noticeMessage = '目前為唯讀模式；你可以查看、匯出、刪除既有紀錄及停用訂閱。請先完成監護人同意才可新增資料。';
    }
    unawaited(_loadSubscriptionComparison());
  });

  Future<void> refresh() async {
    final generation = ++_snapshotGeneration;
    final launch = repository is LaunchRepository
        ? repository as LaunchRepository
        : null;
    final results = await Future.wait<Object>([
      repository.getProfile(),
      launch == null
          ? repository.listMoneyEvents()
          : launch.listMoneyEventPage(),
      repository.getDashboard(),
      repository.getInsights(),
      if (launch != null) launch.getSubscriptions(),
    ]);
    if (_disposed || generation != _snapshotGeneration) return;
    profile = results[0] as UserProfile;
    if (results[1] is MoneyEventPage) {
      final page = results[1] as MoneyEventPage;
      events = page.items;
      nextEventsCursor = page.nextCursor;
    } else {
      events = results[1] as List<MoneyEvent>;
    }
    dashboard = results[2] as DashboardSummary;
    insights = results[3] as FinancialInsights;
    if (launch != null) subscriptions = results[4] as SubscriptionCollection;
    summariesLoaded = true;
    if (reminders != null) {
      try {
        await reminders!.synchronize(subscriptions.items);
      } catch (_) {
        noticeMessage = '本機提醒暫時無法更新；App 內仍可查看訂閱。';
      }
    }
  }

  Future<void> loadMoreEvents() => _run(() async {
    final cursor = nextEventsCursor, launch = repository;
    if (cursor == null || launch is! LaunchRepository) return;
    final generation = _snapshotGeneration;
    final page = await (launch as LaunchRepository).listMoneyEventPage(
      cursor: cursor,
    );
    if (_disposed || generation != _snapshotGeneration) return;
    final ids = events.map((e) => e.id).toSet();
    events = [...events, ...page.items.where((e) => !ids.contains(e.id))];
    nextEventsCursor = page.nextCursor;
  });
  void startManualCapture() {
    if (busy || !canWrite) return;
    clearMessages();
    lastSavedEvent = null;
    captureResult = CaptureResult(
      drafts: [
        CaptureDraft(
          draftId: 'manual-${DateTime.now().microsecondsSinceEpoch}',
          type: MoneyEventType.expense,
          currency: 'TWD',
          category: MoneyCategory.other,
          occurredAt: DateTime.now(),
          confidence: 1,
          missingFields: const ['amountMinor'],
          needsConfirmation: true,
          source: CaptureSource.manual,
        ),
      ],
    );
    _notifyListeners();
  }

  Future<bool> saveSubscription(
    SubscriptionInput input, {
    String? id,
    String? idempotencyKey,
    String? legacyPaymentId,
    CaptureDraft? initialPayment,
  }) => _perform(() async {
    final launch = repository as LaunchRepository;
    if (id != null) {
      await launch.updateSubscription(id, input);
    } else {
      final originalPayment = initialPayment;
      final normalizedPayment = originalPayment == null
          ? null
          : CaptureDraft.fromJson({
              ...originalPayment.toJson(),
              'occurredAt': originalPayment.occurredAt
                  .toUtc()
                  .toIso8601String(),
            });
      final fingerprint = _subscriptionFingerprint(
            input,
            normalizedPayment,
            legacyPaymentId,
          ),
          pending = _pendingSubscription;
      if (pending != null && pending.fingerprint != fingerprint) {
        throw const FormatException('上一筆訂閱仍待確認；請先按「重試原訂閱」確認結果，再建立新的訂閱。');
      }
      final intent =
          pending ??
          (
            input: input,
            initialPayment: normalizedPayment,
            legacyPaymentId: legacyPaymentId,
            key:
                idempotencyKey ??
                'subscription-${DateTime.now().microsecondsSinceEpoch}',
            fingerprint: fingerprint,
          );
      _pendingSubscription = intent;
      await _commitPendingSubscription();
    }
    try {
      await refresh();
      await _loadSubscriptionComparison();
    } catch (e) {
      await _handlePartialFailure(e, notice: '訂閱已儲存；摘要暫時無法更新，請重新整理。');
    }
  }, write: true);
  Future<void> _commitPendingSubscription() async {
    final intent = _pendingSubscription!;
    await _persistPendingIntents();
    try {
      await (repository as LaunchRepository).createSubscription(
        intent.input,
        idempotencyKey: intent.key,
        legacyPaymentId: intent.legacyPaymentId,
        initialPayment: intent.initialPayment,
      );
      _pendingSubscription = null;
      try {
        await _persistPendingIntents();
      } catch (_) {
        noticeMessage = '訂閱已儲存，但裝置尚未清除待確認資訊；下次會以原操作確認結果。';
      }
    } on ApiException catch (e) {
      if (!e.retryable &&
          e.code != 'request_timeout' &&
          e.code != 'network_error' &&
          e.code != 'invalid_response') {
        _pendingSubscription = null;
        await _persistPendingIntents();
      }
      rethrow;
    }
  }

  Future<bool> retryPendingSubscription() => _perform(() async {
    if (_pendingSubscription == null) return;
    await _commitPendingSubscription();
    try {
      await refresh();
      await _loadSubscriptionComparison();
    } catch (e) {
      await _handlePartialFailure(e, notice: '訂閱已儲存；摘要暫時無法更新，請重新整理。');
    }
  }, write: true);
  Future<bool> deactivateSubscription(String id) => _perform(() async {
    await (repository as LaunchRepository).deactivateSubscription(id);
    await refresh();
    await _loadSubscriptionComparison();
  });
  Future<bool> setRemindersEnabled(bool enabled) => _perform(() async {
    if (reminders == null || !reminders!.supported) {
      throw const FormatException('此平台保留 App 內提醒。');
    }
    await reminders!.setEnabled(enabled);
    await reminders!.synchronize(subscriptions.items);
    if (enabled && !reminders!.enabled) {
      noticeMessage = '尚未允許通知；請到 iPhone 設定開啟 FutureMint 通知。';
    }
  });
  Future<Map<String, dynamic>?> exportSelf() async {
    Map<String, dynamic>? result;
    await _perform(() async {
      result = await (repository as LaunchRepository).exportSelf();
    });
    return result;
  }

  Future<void> _loadSubscriptionComparison({String? unavailableMessage}) async {
    final generation = ++_comparisonGeneration;
    final snapshot = _snapshotGeneration;
    try {
      final result = await repository.compareSubscriptions();
      if (_disposed ||
          generation != _comparisonGeneration ||
          snapshot != _snapshotGeneration) {
        return;
      }
      subscriptionComparison = result;
    } catch (error) {
      if (_disposed ||
          generation != _comparisonGeneration ||
          snapshot != _snapshotGeneration) {
        return;
      }
      await _handlePartialFailure(
        error,
        notice: unavailableMessage ?? '訂閱比較暫時無法載入，其他資料仍可使用。',
      );
    } finally {
      _notifyListeners();
    }
  }

  Future<void> refreshWithFeedback() => _run(refresh);

  Future<bool> updateProfile(UserProfile nextProfile) => _perform(() async {
    profile = await repository.updateProfile(nextProfile);
    try {
      await refresh();
    } catch (error) {
      await _handlePartialFailure(error, notice: '設定已儲存，但摘要暫時無法更新；請稍後重新整理。');
    }
    initialized = summariesLoaded;
  }, write: true);

  Future<void> parseCapture(String text, {DateTime? referenceTime}) async {
    if (_blockAiWhenDisabled()) return;
    await _run(() async {
      lastSavedEvent = null;
      captureResult = null;
      captureResult = await repository.parseCapture(
        text,
        referenceTime: referenceTime ?? DateTime.now(),
      );
    });
  }

  Future<void> saveDraft(CaptureDraft draft) => _run(() async {
    final currentCapture = captureResult;
    lastSavedEvent = await repository.saveDraft(
      draft,
      idempotencyKey: 'capture-${draft.draftId}',
    );
    final remainingDrafts =
        currentCapture?.drafts
            .where((item) => item.draftId != draft.draftId)
            .toList() ??
        const <CaptureDraft>[];
    captureResult = remainingDrafts.isEmpty
        ? null
        : CaptureResult(drafts: remainingDrafts);
    try {
      await refresh();
    } catch (error) {
      events = [
        lastSavedEvent!,
        ...events.where((event) => event.id != lastSavedEvent!.id),
      ];
      await _handlePartialFailure(
        error,
        notice: '這筆已保存，但摘要暫時無法更新；請稍後在紀錄頁重新整理。',
      );
    }
    if (draft.type == MoneyEventType.subscription) {
      await _loadSubscriptionComparison(
        unavailableMessage: '訂閱已保存，但方案比較暫時無法更新。',
      );
    }
  }, write: true);

  Future<bool> updateMoneyEvent(
    String eventId,
    CaptureDraft draft,
  ) => _perform(() async {
    final updated = await repository.updateMoneyEvent(eventId, draft);
    lesson = null;
    learningPlan = null;
    try {
      await refresh();
    } catch (error) {
      events = [updated, ...events.where((event) => event.id != updated.id)];
      await _handlePartialFailure(error, notice: '紀錄已更新，但摘要暫時無法更新；請稍後重新整理。');
    }
    await _loadSubscriptionComparison(unavailableMessage: '紀錄已更新，但訂閱比較暫時無法更新。');
  }, write: true);

  Future<bool> deleteMoneyEvent(String eventId) => _perform(() async {
    await repository.deleteMoneyEvent(eventId);
    lesson = null;
    learningPlan = null;
    try {
      await refresh();
    } catch (error) {
      events = events.where((event) => event.id != eventId).toList();
      await _handlePartialFailure(error, notice: '紀錄已刪除，但摘要暫時無法更新；請稍後重新整理。');
    }
    await _loadSubscriptionComparison(unavailableMessage: '紀錄已刪除，但訂閱比較暫時無法更新。');
  });

  Future<void> completeLesson(String selectedOption) async {
    final current = lesson;
    if (current == null) return;
    final controlled =
        current.id.startsWith('catalog-') &&
        current.source == CaptureSource.manual;
    await _run(() async {
      if (!current.options.contains(selectedOption)) {
        throw const FormatException('請從課程提供的選項中選擇。');
      }
      lesson = controlled
          ? Lesson.fromJson({
              ...current.toJson(),
              'selectedOption': selectedOption,
            })
          : await repository.completeLesson(current, selectedOption);
    }, write: !controlled);
  }

  Future<void> loadLesson() async {
    if (lesson != null || busy) return;
    if (!isAiEnabled || !canWrite) {
      if (repository case ControlledEducationRepository controlled) {
        await _run(() async {
          lesson = await controlled.getControlledLesson();
        });
      }
      return;
    }
    await _run(() async {
      lesson = await repository.generateLesson();
    });
  }

  Future<void> loadLearningPlan() async {
    if (!isAiEnabled || !canWrite || learningPlan != null || busy) return;
    await _run(() async {
      learningPlan = await repository.getLearningPlan();
    });
  }

  Future<void> simulateInvestments({
    required int initialAmountMinor,
    required int monthlyContributionMinor,
    required int years,
  }) => _run(() async {
    investmentSimulation = await repository.simulateInvestments(
      initialAmountMinor: initialAmountMinor,
      monthlyContributionMinor: monthlyContributionMinor,
      years: years,
    );
    coachReply = null;
  });

  Future<void> runInvestmentSimulation({
    required int initialAmountMinor,
    required int monthlyContributionMinor,
    required int years,
  }) => simulateInvestments(
    initialAmountMinor: initialAmountMinor,
    monthlyContributionMinor: monthlyContributionMinor,
    years: years,
  );

  Future<void> askCoach({
    required String topic,
    required String question,
    String style = 'example',
    InvestmentScenarioId? scenarioId,
    int? selectedYear,
  }) async {
    if (_blockAiWhenDisabled()) return;
    await _run(() async {
      coachReply = await repository.askCoach(
        topic: topic,
        question: question,
        style: style,
        scenarioId: scenarioId,
        selectedYear: selectedYear,
      );
    });
  }

  Future<void> askLearningCoach({
    required String topic,
    required String question,
    String style = 'example',
  }) async {
    if (_blockAiWhenDisabled()) return;
    await _run(() async {
      learningCoachReply = await repository.askCoach(
        topic: topic,
        question: question,
        style: style,
      );
    });
  }

  Future<bool> loadFamily() => _perform(() async {
    familyOverview = await repository.getFamilyOverview();
  });

  Future<void> createFamilyInvite() => _run(() async {
    familyOverview = await repository.createFamilyInvite();
  }, write: true);

  Future<void> rotateFamilyInvite() => _run(() async {
    familyOverview = await repository.rotateFamilyInvite();
  }, write: true);

  Future<void> revokeFamilyInvite() => _run(() async {
    familyOverview = await repository.revokeFamilyInvite();
  });

  Future<void> joinFamily(String inviteCode) => _run(() async {
    familyOverview = await repository.joinFamily(inviteCode);
  }, write: true);

  Future<void> leaveFamily() => _run(() async {
    await repository.leaveFamily();
    familyOverview = null;
  });

  Future<void> loadInvestmentLab() => _run(() async {
    investmentLab = await repository.getInvestmentLab();
    final pending = _pendingOrder;
    if (pending != null &&
        investmentLab!.orders.any((o) => o.idempotencyKey == pending.key)) {
      _pendingOrder = null;
      await _persistPendingIntents();
    }
  });

  Future<void> retryPendingOrder() async {
    final intent = _pendingOrder;
    if (intent == null) return;
    await placeInvestmentOrder(
      symbol: intent.symbol,
      side: intent.side,
      quantity: intent.quantity,
    );
  }

  Future<void> placeInvestmentOrder({
    required String symbol,
    required InvestmentOrderSide side,
    required int quantity,
  }) => _run(() async {
    final pending = _pendingOrder;
    if (pending != null &&
        (pending.symbol != symbol ||
            pending.side != side ||
            pending.quantity != quantity)) {
      throw const FormatException('上一筆訂單仍待確認；請先重試原訂單或重新整理。');
    }
    final intent =
        pending ??
        (
          symbol: symbol,
          side: side,
          quantity: quantity,
          key:
              'order-${DateTime.now().microsecondsSinceEpoch}-$symbol-${side.name}',
        );
    _pendingOrder = intent;
    await _persistPendingIntents();
    try {
      investmentLab = await repository.placeInvestmentOrder(
        symbol: symbol,
        side: side,
        quantity: quantity,
        idempotencyKey: intent.key,
      );
      _pendingOrder = null;
      try {
        await _persistPendingIntents();
      } catch (_) {
        noticeMessage = '訂單已保存，但裝置待確認資訊尚未清除；重新開啟時會先確認原訂單。';
      }
    } on ApiException catch (e) {
      if (!e.retryable &&
          e.code != 'request_timeout' &&
          e.code != 'network_error' &&
          e.code != 'invalid_response') {
        _pendingOrder = null;
        await _persistPendingIntents();
      }
      rethrow;
    }
  }, write: true);

  Future<void> rollInvestmentDice() => _run(() async {
    final nextRoll = (practiceDiceEvent?.rollIndex ?? -1) + 1;
    coachReply = null;
    practiceDiceEvent = await repository.rollInvestmentDice(
      rollIndex: nextRoll,
    );
  });

  Future<void> previewFutureSeed({
    required int monthlyContributionMinor,
    required int years,
    required double annualRatePercent,
  }) => _run(() async {
    futureSeedPreview = await repository.previewFutureSeed(
      monthlyContributionMinor: monthlyContributionMinor,
      years: years,
      annualRatePercent: annualRatePercent,
    );
  });

  void setThemeMode(ThemeMode value) {
    themeMode = value;
    _notifyListeners();
  }

  Future<bool> updateAiConsent(bool granted) async {
    final update = onAiConsentChanged;
    if (mode != AppMode.authenticated || update == null) return false;
    return _perform(() async {
      aiConsent = await update(granted);
      if (!aiConsent.granted) _clearAiState();
    });
  }

  Future<bool> revokeAiConsent() => updateAiConsent(false);

  Future<bool> deleteAccount(String password) async {
    final delete = onDeleteAccount;
    if (mode != AppMode.authenticated || delete == null) return false;
    return _perform(() async {
      await delete(password);
    });
  }

  void applyAiConsent(AiConsentStatus status) {
    aiConsent = status;
    if (!status.granted) _clearAiState();
    _notifyListeners();
  }

  void clearMessages() {
    errorMessage = null;
    noticeMessage = null;
    _notifyListeners();
  }
}
