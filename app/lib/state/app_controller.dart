import 'dart:async';

import 'package:flutter/material.dart';

import '../core/future_mint_repository.dart';
import '../core/models.dart';
import '../data/api_repository.dart';
import '../auth/auth_models.dart';

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
  });

  FutureMintRepository repository;
  final AppMode mode;
  final String? accountEmail;
  final Future<void> Function()? onExit;
  final Future<void> Function()? onUnauthorized;
  final Future<AiConsentStatus> Function(bool granted)? onAiConsentChanged;
  final Future<void> Function(String password)? onDeleteAccount;
  ThemeMode themeMode = ThemeMode.system;

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

  bool get isAiEnabled => mode != AppMode.authenticated || aiConsent.granted;
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
    captureResult = null;
    lesson = null;
    learningPlan = null;
    coachReply = null;
    learningCoachReply = null;
  }

  Future<bool> _perform(Future<void> Function() operation) async {
    if (busy) return false;
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
      } else if (error case ApiException(code: 'ai_consent_required')) {
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

  Future<void> _run(Future<void> Function() operation) async {
    await _perform(operation);
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
    final results = await Future.wait<Object>([
      repository.getProfile(),
      repository.listMoneyEvents(),
      repository.getDashboard(),
      repository.getInsights(),
    ]);
    profile = results[0] as UserProfile;
    events = results[1] as List<MoneyEvent>;
    dashboard = results[2] as DashboardSummary;
    insights = results[3] as FinancialInsights;
    initialized = true;
    _notifyListeners();
    unawaited(_loadSubscriptionComparison());
  });

  Future<void> refresh() async {
    final results = await Future.wait<Object>([
      repository.getProfile(),
      repository.listMoneyEvents(),
      repository.getDashboard(),
      repository.getInsights(),
    ]);
    profile = results[0] as UserProfile;
    events = results[1] as List<MoneyEvent>;
    dashboard = results[2] as DashboardSummary;
    insights = results[3] as FinancialInsights;
  }

  Future<void> _loadSubscriptionComparison({String? unavailableMessage}) async {
    try {
      subscriptionComparison = await repository.compareSubscriptions();
    } catch (error) {
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
    initialized = true;
  });

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
  });

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
  });

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

  Future<void> completeLesson(String selectedOption) => _run(() async {
    if (lesson == null) return;
    lesson = await repository.completeLesson(lesson!, selectedOption);
  });

  Future<void> loadLesson() async {
    if (_blockAiWhenDisabled() || lesson != null || busy) return;
    await _run(() async {
      lesson = await repository.generateLesson();
    });
  }

  Future<void> loadLearningPlan() async {
    if (_blockAiWhenDisabled() || learningPlan != null || busy) return;
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

  Future<void> loadFamily() => _run(() async {
    familyOverview = await repository.getFamilyOverview();
  });

  Future<void> createFamilyInvite() => _run(() async {
    familyOverview = await repository.createFamilyInvite();
  });

  Future<void> rotateFamilyInvite() => _run(() async {
    familyOverview = await repository.rotateFamilyInvite();
  });

  Future<void> revokeFamilyInvite() => _run(() async {
    familyOverview = await repository.revokeFamilyInvite();
  });

  Future<void> joinFamily(String inviteCode) => _run(() async {
    familyOverview = await repository.joinFamily(inviteCode);
  });

  Future<void> leaveFamily() => _run(() async {
    await repository.leaveFamily();
    familyOverview = null;
  });

  Future<void> loadInvestmentLab() => _run(() async {
    investmentLab = await repository.getInvestmentLab();
  });

  Future<void> placeInvestmentOrder({
    required String symbol,
    required InvestmentOrderSide side,
    required int quantity,
  }) => _run(() async {
    investmentLab = await repository.placeInvestmentOrder(
      symbol: symbol,
      side: side,
      quantity: quantity,
      idempotencyKey:
          'order-${DateTime.now().microsecondsSinceEpoch}-$symbol-${side.name}',
    );
  });

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

  void clearMessages() {
    errorMessage = null;
    noticeMessage = null;
    _notifyListeners();
  }
}
