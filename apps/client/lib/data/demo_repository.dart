import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/future_mint_repository.dart';
import '../core/models.dart';
import '../shared/date_text.dart';

class DemoRepository implements FutureMintRepository {
  DemoRepository._(this._preferences);

  static const _profileKey = 'futuremint.demo.profile.v1';
  static const _eventsKey = 'futuremint.demo.events.v1';
  static const _lessonKey = 'futuremint.demo.lesson.v1';

  final SharedPreferences _preferences;

  static Future<DemoRepository> create() async {
    final repository = DemoRepository._(await SharedPreferences.getInstance());
    await repository._ensureSeeded();
    return repository;
  }

  Future<void> _ensureSeeded() async {
    if (!_preferences.containsKey(_profileKey)) {
      await _preferences.setString(
        _profileKey,
        jsonEncode(_seedProfile.toJson()),
      );
    }
    if (!_preferences.containsKey(_eventsKey)) {
      await _writeEvents(_seedEvents);
    }
  }

  static final _seedProfile = UserProfile(
    userId: 'demo-user',
    monthlyBudgetMinor: 6000,
    weeklyBudgetMinor: 1500,
    goalName: '校外活動基金',
    goalTargetMinor: 12000,
    goalSavedMinor: 4200,
    goalDate: DateTime(2026, 10, 31),
  );

  static final _seedEvents = [
    _event(
      'seed-income',
      MoneyEventType.income,
      1500,
      MoneyCategory.income,
      '打工收入',
      DateTime.parse('2026-07-05T18:00:00+08:00'),
    ),
    _event(
      'seed-drink',
      MoneyEventType.expense,
      75,
      MoneyCategory.food,
      '珍奶',
      DateTime.parse('2026-07-08T16:30:00+08:00'),
    ),
    _event(
      'seed-game',
      MoneyEventType.expense,
      450,
      MoneyCategory.entertainment,
      '遊戲點數',
      DateTime.parse('2026-07-09T20:10:00+08:00'),
    ),
    MoneyEvent(
      id: 'seed-subscription',
      userId: 'demo-user',
      type: MoneyEventType.subscription,
      amountMinor: 390,
      currency: 'TWD',
      category: MoneyCategory.subscription,
      merchant: '影音訂閱',
      occurredAt: DateTime.parse('2026-07-01T08:00:00+08:00'),
      recurrence: RecurrenceDetails(
        billingCycle: BillingCycle.monthly,
        nextBillingAt: DateTime.parse('2026-08-01T08:00:00+08:00'),
      ),
      split: const SplitDetails(participants: 4, userShareMinor: 98),
      createdAt: DateTime.parse('2026-07-01T08:00:00+08:00'),
      updatedAt: DateTime.parse('2026-07-01T08:00:00+08:00'),
    ),
  ];

  static MoneyEvent _event(
    String id,
    MoneyEventType type,
    int amount,
    MoneyCategory category,
    String merchant,
    DateTime at,
  ) => MoneyEvent(
    id: id,
    userId: 'demo-user',
    type: type,
    amountMinor: amount,
    currency: 'TWD',
    category: category,
    merchant: merchant,
    occurredAt: at,
    createdAt: at,
    updatedAt: at,
  );

  Future<void> _writeEvents(List<MoneyEvent> events) => _preferences.setString(
    _eventsKey,
    jsonEncode(events.map((event) => event.toJson()).toList()),
  );

  @override
  Future<UserProfile> getProfile() async => UserProfile.fromJson(
    jsonDecode(_preferences.getString(_profileKey)!) as Map<String, dynamic>,
  );

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async {
    await _preferences.setString(_profileKey, jsonEncode(profile.toJson()));
    return profile;
  }

  @override
  Future<List<MoneyEvent>> listMoneyEvents() async =>
      (jsonDecode(_preferences.getString(_eventsKey)!) as List<dynamic>)
          .map((item) => MoneyEvent.fromJson(item as Map<String, dynamic>))
          .toList();

  @override
  Future<DashboardSummary> getDashboard() async {
    final profile = await getProfile();
    final events = await listMoneyEvents();
    final now = toTaipeiTime(DateTime.now());
    final current = events.where((event) {
      final occurredAt = toTaipeiTime(event.occurredAt);
      return occurredAt.year == now.year && occurredAt.month == now.month;
    });
    final income = current
        .where((event) => event.type == MoneyEventType.income)
        .fold<int>(0, (sum, event) => sum + event.amountMinor);
    final expenses = current
        .where((event) => event.type == MoneyEventType.expense)
        .fold<int>(0, (sum, event) => sum + event.effectiveAmountMinor);
    final subscriptions = current
        .where((event) => event.type == MoneyEventType.subscription)
        .fold<int>(0, (sum, event) => sum + event.effectiveAmountMinor);
    final recent = [...events]
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return DashboardSummary(
      monthlyBudgetMinor: profile.monthlyBudgetMinor,
      incomeMinor: income,
      expenseMinor: expenses,
      subscriptionMinor: subscriptions,
      availableMinor: profile.monthlyBudgetMinor - expenses - subscriptions,
      goalRemainingMinor: max(
        0,
        profile.goalTargetMinor - profile.goalSavedMinor,
      ),
      goalProgress: min(
        1,
        profile.goalSavedMinor / max(1, profile.goalTargetMinor),
      ),
      recentEvents: recent.take(5).toList(),
    );
  }

  @override
  Future<CaptureResult> parseCapture(
    String text, {
    required DateTime referenceTime,
  }) async {
    final normalized = text.trim();
    if (RegExp(r'沒有買|沒買|取消交易|並未購買').hasMatch(normalized)) {
      return const CaptureResult(
        drafts: [],
        rejectedReason: '文字表示交易沒有發生，因此不會建立草稿。',
      );
    }
    int? amountFor(String value) {
      final paid = RegExp(
        r'(?:折扣後(?:實付)?|實付)\D{0,8}(\d[\d,]*)',
      ).firstMatch(value);
      final match =
          paid ??
          RegExp(r'(?:NT\$|[$＄])?\s*(\d[\d,]*)\s*(?:元)?').firstMatch(value);
      return match == null
          ? null
          : int.parse(match.group(1)!.replaceAll(',', ''));
    }

    MoneyCategory categoryFor(String value) {
      if (RegExp(r'薪水|零用錢|獎金|收入').hasMatch(value)) {
        return MoneyCategory.income;
      }
      if (RegExp(r'Netflix|Spotify|訂閱|扣款').hasMatch(value)) {
        return MoneyCategory.subscription;
      }
      if (RegExp(r'飲料|珍奶|早餐|午餐|晚餐|吃飯').hasMatch(value)) {
        return MoneyCategory.food;
      }
      if (RegExp(r'遊戲|點數|電影').hasMatch(value)) {
        return MoneyCategory.entertainment;
      }
      if (RegExp(r'車|捷運|公車|交通').hasMatch(value)) {
        return MoneyCategory.transport;
      }
      if (RegExp(r'課程|課本|書|文具').hasMatch(value)) {
        return MoneyCategory.education;
      }
      if (RegExp(r'衣服|鞋|耳機|購物').hasMatch(value)) {
        return MoneyCategory.shopping;
      }
      return MoneyCategory.other;
    }

    if (amountFor(normalized) == null &&
        categoryFor(normalized) == MoneyCategory.other &&
        !RegExp(r'買|花|付|消費|支出|收入|賣|收到|賺|訂閱|扣款').hasMatch(normalized)) {
      return const CaptureResult(drafts: [], rejectedReason: '這段文字不像已發生的金錢事件。');
    }

    CaptureDraft draftFor(String value, {String? splitContext}) {
      final amount = amountFor(value);
      final category = categoryFor(value);
      final type = category == MoneyCategory.income
          ? MoneyEventType.income
          : category == MoneyCategory.subscription
          ? MoneyEventType.subscription
          : MoneyEventType.expense;
      final context = splitContext ?? value;
      final arabic = RegExp(r'(\d+)\s*(?:個)?(?:人|同學)?分').firstMatch(context);
      final chinese = RegExp(r'([一二三四五六])\s*個?(?:人|同學)?分').firstMatch(context);
      const chineseNumbers = {'一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6};
      final participants = arabic != null
          ? int.parse(arabic.group(1)!)
          : chinese == null
          ? null
          : chineseNumbers[chinese.group(1)!];
      final occurredAt = RegExp(r'昨天|前天').hasMatch(value)
          ? referenceTime.subtract(Duration(days: value.contains('前天') ? 2 : 1))
          : referenceTime;
      final merchant = RegExp(r'珍奶|飲料').hasMatch(value)
          ? '飲料'
          : value.contains('Netflix')
          ? 'Netflix'
          : value.contains('Spotify')
          ? 'Spotify'
          : RegExp(r'薪水|打工').hasMatch(value)
          ? '打工收入'
          : null;
      return CaptureDraft(
        draftId:
            'demo-${DateTime.now().microsecondsSinceEpoch}-${value.hashCode}',
        type: type,
        amountMinor: amount,
        currency: 'TWD',
        category: category,
        merchant: merchant,
        occurredAt: occurredAt,
        recurrence: type == MoneyEventType.subscription
            ? const RecurrenceDetails(billingCycle: BillingCycle.monthly)
            : null,
        split: participants != null && amount != null
            ? SplitDetails(
                participants: participants,
                userShareMinor: (amount / participants).round(),
              )
            : null,
        confidence: amount == null ? 0.58 : 0.94,
        missingFields: amount == null ? const ['amountMinor'] : const [],
        needsConfirmation: true,
        source: CaptureSource.deterministicDemo,
      );
    }

    final separated = RegExp(r'折扣後|實付').hasMatch(normalized)
        ? <String>[]
        : normalized
              .split(RegExp(r'[，、；;]'))
              .map((part) => part.trim())
              .where(
                (part) =>
                    amountFor(part) != null &&
                    categoryFor(part) != MoneyCategory.other,
              )
              .toList();
    final drafts = separated.length > 1
        ? separated.take(5).map(draftFor).toList()
        : [draftFor(normalized, splitContext: normalized)];
    final missingAmount = drafts.any((draft) => draft.amountMinor == null);
    return CaptureResult(
      drafts: drafts,
      clarificationQuestion: missingAmount
          ? '這筆${drafts.first.merchant ?? '消費'}花了多少元？'
          : null,
    );
  }

  @override
  Future<MoneyEvent> saveDraft(
    CaptureDraft draft, {
    required String idempotencyKey,
  }) async {
    if (draft.amountMinor == null || draft.amountMinor! <= 0) {
      throw const FormatException('請先補上正確金額。');
    }
    final events = await listMoneyEvents();
    final existing = events
        .where((event) => event.idempotencyKey == idempotencyKey)
        .firstOrNull;
    if (existing != null) return existing;
    final now = DateTime.now();
    final event = MoneyEvent(
      id: 'event-${now.microsecondsSinceEpoch}',
      userId: 'demo-user',
      type: draft.type,
      amountMinor: draft.amountMinor!,
      currency: 'TWD',
      category: draft.category,
      merchant: draft.merchant,
      occurredAt: draft.occurredAt,
      recurrence: draft.recurrence,
      split: draft.split,
      idempotencyKey: idempotencyKey,
      createdAt: now,
      updatedAt: now,
    );
    events.add(event);
    await _writeEvents(events);
    return event;
  }

  @override
  Future<SubscriptionComparison> compareSubscriptions() async {
    final events = await listMoneyEvents();
    final subscriptions = events
        .where((event) => event.type == MoneyEventType.subscription)
        .toList();
    subscriptions.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final current = subscriptions.isEmpty ? null : subscriptions.first;
    final currentPrice = current?.effectiveAmountMinor ?? 390;
    final currentName = current?.merchant ?? '影音個人方案';
    final members = current?.split?.participants ?? 1;
    final sharedEligible = members >= 4;
    return SubscriptionComparison(
      currentName: currentName,
      currentMonthlyCostMinor: currentPrice,
      options: [
        SubscriptionOption(
          id: 'shared-four',
          name: '合法共享月繳方案',
          monthlyCostMinor: 520,
          userMonthlyCostMinor: 130,
          monthlySavingsMinor: sharedEligible ? currentPrice - 130 : null,
          eligible: sharedEligible,
          eligibilityMessage: sharedEligible
              ? '已有四人共同使用情境，採用前仍需確認官方資格與條款。'
              : '目前記錄不足四人，不把共享方案列為可行節省選項。',
          sourceType: 'synthetic',
        ),
        SubscriptionOption(
          id: 'student-yearly',
          name: '學生年繳方案',
          monthlyCostMinor: 200,
          userMonthlyCostMinor: 200,
          monthlySavingsMinor: currentPrice - 200,
          eligible: true,
          eligibilityMessage: '須符合學生資格，採用前仍需確認官方條款。',
          sourceType: 'synthetic',
        ),
      ],
      disclaimer: '方案價格與資格為合成展示資料，並非即時市場資訊。',
    );
  }

  @override
  Future<Lesson> generateLesson() async {
    final saved = _preferences.getString(_lessonKey);
    if (saved != null) {
      return Lesson.fromJson(jsonDecode(saved) as Map<String, dynamic>);
    }
    const lesson = Lesson(
      id: 'demo-lesson-fixed-cost',
      title: '固定支出，也能重新選擇',
      concept: '固定支出會每月重複發生。先換算成月成本，再比較使用頻率與方案資格，比單純退訂更接近真正的選擇。',
      example: '訂閱原價每月 390 元，四人分擔後約 98 元；比較方案時要用真正負擔，並確認資格與條款。',
      question: '下週你最想先嘗試哪一個小改變？',
      options: ['先檢查一項固定訂閱', '設定一個小額支出上限', '維持現況並持續記錄'],
      action: '選一個做得到的選項，七天後再看它是否真的幫上忙。',
      disclaimer: '內容僅供金融教育與反思，不構成投資或金融商品建議。',
      source: CaptureSource.deterministicDemo,
    );
    await _preferences.setString(_lessonKey, jsonEncode(lesson.toJson()));
    return lesson;
  }

  @override
  Future<Lesson> completeLesson(Lesson lesson, String selectedOption) async {
    if (!lesson.options.contains(selectedOption)) {
      throw const FormatException('請從課程提供的選項中選擇。');
    }
    final completed = Lesson(
      id: lesson.id,
      title: lesson.title,
      concept: lesson.concept,
      example: lesson.example,
      question: lesson.question,
      options: lesson.options,
      action: lesson.action,
      disclaimer: lesson.disclaimer,
      source: lesson.source,
      selectedOption: selectedOption,
    );
    await _preferences.setString(_lessonKey, jsonEncode(completed.toJson()));
    return completed;
  }

  @override
  Future<FutureSeedPreview> previewFutureSeed({
    required int monthlyContributionMinor,
    required int years,
    required double annualRatePercent,
  }) async {
    if (monthlyContributionMinor <= 0 || years < 1 || years > 50) {
      throw const FormatException('投入金額與期間不在允許範圍。');
    }
    int balanceAt(int months) {
      if (annualRatePercent == 0) return monthlyContributionMinor * months;
      final monthlyRate = annualRatePercent / 100 / 12;
      return (monthlyContributionMinor *
              ((pow(1 + monthlyRate, months) - 1) / monthlyRate))
          .round();
    }

    final months = years * 12;
    final principal = monthlyContributionMinor * months;
    final ending = balanceAt(months);
    return FutureSeedPreview(
      principalMinor: principal,
      growthMinor: ending - principal,
      endingBalanceMinor: ending,
      yearlyPoints: List.generate(years, (index) {
        final year = index + 1;
        return FutureSeedYearPoint(
          year: year,
          principalMinor: monthlyContributionMinor * year * 12,
          balanceMinor: balanceAt(year * 12),
        );
      }),
      disclaimer: '此結果為教育試算，採固定假設報酬率，不代表實際投資成果或報酬保證。',
    );
  }

  @override
  Future<void> resetDemo() async {
    await _preferences.remove(_profileKey);
    await _preferences.remove(_eventsKey);
    await _preferences.remove(_lessonKey);
    await _ensureSeeded();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
