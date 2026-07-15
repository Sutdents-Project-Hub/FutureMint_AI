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
  });

  FutureMintRepository repository;
  final AppMode mode;
  final String? accountEmail;
  final Future<void> Function()? onExit;
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

  Future<bool> _perform(Future<void> Function() operation) async {
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
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _run(Future<void> Function() operation) async {
    await _perform(operation);
  }

  Future<void> initialize() => _run(() async {
    profile = await repository.getProfile();
    events = await repository.listMoneyEvents();
    dashboard = await repository.getDashboard();
    insights = await repository.getInsights();
    initialized = true;
    notifyListeners();
    try {
      subscriptionComparison = await repository.compareSubscriptions();
    } catch (_) {
      noticeMessage = '訂閱比較暫時無法載入，其他資料仍可使用。';
    }
  });

  Future<void> refresh() async {
    profile = await repository.getProfile();
    events = await repository.listMoneyEvents();
    dashboard = await repository.getDashboard();
    insights = await repository.getInsights();
  }

  Future<void> refreshWithFeedback() => _run(refresh);

  Future<bool> updateProfile(UserProfile nextProfile) => _perform(() async {
    profile = await repository.updateProfile(nextProfile);
    await refresh();
    initialized = true;
  });

  Future<void> parseCapture(String text, {DateTime? referenceTime}) =>
      _run(() async {
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
    } catch (_) {
      events = [
        lastSavedEvent!,
        ...events.where((event) => event.id != lastSavedEvent!.id),
      ];
      noticeMessage = '這筆已保存，但摘要暫時無法更新；請稍後在紀錄頁重新整理。';
    }
    if (draft.type == MoneyEventType.subscription) {
      try {
        subscriptionComparison = await repository.compareSubscriptions();
      } catch (_) {
        noticeMessage = '訂閱已保存，但方案比較暫時無法更新。';
      }
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

  Future<void> askCoach({
    required String topic,
    required String question,
    InvestmentScenarioId? scenarioId,
    int? selectedYear,
  }) => _run(() async {
    coachReply = await repository.askCoach(
      topic: topic,
      question: question,
      scenarioId: scenarioId,
      selectedYear: selectedYear,
    );
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
