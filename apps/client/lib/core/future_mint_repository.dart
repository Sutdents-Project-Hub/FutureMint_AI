import 'models.dart';

abstract interface class FutureMintRepository {
  Future<UserProfile> getProfile();
  Future<UserProfile> updateProfile(UserProfile profile);
  Future<List<MoneyEvent>> listMoneyEvents();
  Future<DashboardSummary> getDashboard();
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
  Future<FutureSeedPreview> previewFutureSeed({
    required int monthlyContributionMinor,
    required int years,
    required double annualRatePercent,
  });
  Future<void> resetDemo();
}
