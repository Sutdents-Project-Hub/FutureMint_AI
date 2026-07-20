import 'dart:async';

import 'package:flutter/material.dart';

import '../core/future_mint_repository.dart';
import '../core/models.dart';
import '../data/api_repository.dart';

class AppController extends ChangeNotifier {
  AppController({
    required this.repository,
    required this.mode,
    this.accountEmail,
    this.onExit,
    this.onUnauthorized,
  });

  FutureMintRepository repository;
  final AppMode mode;
  final String? accountEmail;
  final Future<void> Function()? onExit;
  final Future<void> Function()? onUnauthorized;
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

  Future<bool> _perform(Future<void> Function() operation) async {
    if (busy) return false;
    busy = true;
    errorMessage = null;
    notifyListeners();
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
      }
      return false;
    } finally {
      busy = false;
      notifyListeners();
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
    notifyListeners();
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
      notifyListeners();
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

  Future<void> parseCapture(String text, {DateTime? referenceTime}) =>
      _run(() async {
        lastSavedEvent = null;
        captureResult = null;
        captureResult = await repository.parseCapture(
          text,
          referenceTime: referenceTime ?? DateTime.now(),
        );
      });

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

  Future<void> completeLesson(String selectedOption) => _run(() async {
    if (lesson == null) return;
    lesson = await repository.completeLesson(lesson!, selectedOption);
  });

  Future<void> loadLesson() async {
    if (lesson != null || busy) return;
    await _run(() async {
      lesson = await repository.generateLesson();
    });
  }

  Future<void> loadLearningPlan() async {
    if (learningPlan != null || busy) return;
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
  }) => _run(() async {
    coachReply = await repository.askCoach(
      topic: topic,
      question: question,
      style: style,
      scenarioId: scenarioId,
      selectedYear: selectedYear,
    );
  });

  Future<void> askLearningCoach({
    required String topic,
    required String question,
    String style = 'example',
  }) => _run(() async {
    learningCoachReply = await repository.askCoach(
      topic: topic,
      question: question,
      style: style,
    );
  });

  Future<void> loadFamily() => _run(() async {
    familyOverview = await repository.getFamilyOverview();
  });

  Future<void> createFamilyInvite() => _run(() async {
    familyOverview = await repository.createFamilyInvite();
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
    notifyListeners();
  }

  void clearMessages() {
    errorMessage = null;
    noticeMessage = null;
    notifyListeners();
  }
}
