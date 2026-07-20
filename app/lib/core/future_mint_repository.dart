import 'models.dart';

abstract interface class FutureMintRepository {
  Future<UserProfile> getProfile();
  Future<UserProfile> updateProfile(UserProfile profile);
  Future<List<MoneyEvent>> listMoneyEvents();
  Future<DashboardSummary> getDashboard();
  Future<FinancialInsights> getInsights();
  Future<CaptureResult> parseCapture(
    String text, {
    required DateTime referenceTime,
  });
  Future<MoneyEvent> saveDraft(
    CaptureDraft draft, {
    required String idempotencyKey,
  });
  Future<SubscriptionComparison?> compareSubscriptions();
  Future<Lesson> generateLesson();
  Future<Lesson> completeLesson(Lesson lesson, String selectedOption);
  Future<LearningPlan> getLearningPlan();
  Future<FutureSeedPreview> previewFutureSeed({
    required int monthlyContributionMinor,
    required int years,
    required double annualRatePercent,
  });
  Future<InvestmentSimulation> simulateInvestments({
    required int initialAmountMinor,
    required int monthlyContributionMinor,
    required int years,
  });
  Future<CoachReply> askCoach({
    required String topic,
    required String question,
    String style = 'example',
    InvestmentScenarioId? scenarioId,
    int? selectedYear,
  });
  Future<FamilyOverview?> getFamilyOverview();
  Future<FamilyOverview> createFamilyInvite();
  Future<FamilyOverview> joinFamily(String inviteCode);
  Future<void> leaveFamily();
  Future<MarketSnapshot> getMarketSnapshot();
  Future<InvestmentLab> getInvestmentLab();
  Future<InvestmentLab> placeInvestmentOrder({
    required String symbol,
    required InvestmentOrderSide side,
    required int quantity,
    required String idempotencyKey,
  });
  Future<PracticeDiceEvent> rollInvestmentDice({required int rollIndex});
  Future<void> resetDemo();
}
