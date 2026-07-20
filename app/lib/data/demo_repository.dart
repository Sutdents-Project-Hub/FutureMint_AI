import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../core/future_mint_repository.dart';
import '../core/models.dart';
import '../shared/date_text.dart';

abstract interface class _KeyValueStore {
  bool containsKey(String key);
  String? getString(String key);
  Future<bool> setString(String key, String value);
  Future<bool> remove(String key);
}

class _MemoryStore implements _KeyValueStore {
  final Map<String, String> _values = {};

  @override
  bool containsKey(String key) => _values.containsKey(key);

  @override
  String? getString(String key) => _values[key];

  @override
  Future<bool> remove(String key) async => _values.remove(key) != null;

  @override
  Future<bool> setString(String key, String value) async {
    _values[key] = value;
    return true;
  }
}

class GuestRepository implements FutureMintRepository {
  GuestRepository.transient({Uri? marketBaseUri, http.Client? client})
    : _preferences = _MemoryStore(),
      _marketBaseUri = marketBaseUri,
      _client = client ?? http.Client();

  static const _profileKey = 'futuremint.demo.profile.v1';
  static const _eventsKey = 'futuremint.demo.events.v1';
  static const _lessonKey = 'futuremint.demo.lesson.v1';

  final _KeyValueStore _preferences;
  final Uri? _marketBaseUri;
  final http.Client _client;
  int? _investmentStartingCashMinor;
  final List<VirtualInvestmentOrder> _investmentOrders = [];

  static Future<GuestRepository> create({
    Uri? marketBaseUri,
    http.Client? client,
  }) async {
    final repository = GuestRepository.transient(
      marketBaseUri: marketBaseUri,
      client: client,
    );
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
    userId: 'guest-user',
    accountRole: AccountRole.child,
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
      spendingIntent: SpendingIntent.want,
      intentReason: 'AI 建議：這筆較像可以延後或替代的享受型支出。',
    ),
    _event(
      'seed-game',
      MoneyEventType.expense,
      450,
      MoneyCategory.entertainment,
      '遊戲點數',
      DateTime.parse('2026-07-09T20:10:00+08:00'),
      spendingIntent: SpendingIntent.want,
      intentReason: 'AI 建議：娛樂有價值，但通常可以先確認本月預算。',
    ),
    MoneyEvent(
      id: 'seed-subscription',
      userId: 'guest-user',
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
      spendingIntent: SpendingIntent.want,
      intentReason: 'AI 建議：訂閱是否值得，要搭配實際使用頻率判斷。',
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
    DateTime at, {
    SpendingIntent? spendingIntent,
    String? intentReason,
  }) => MoneyEvent(
    id: id,
    userId: 'guest-user',
    type: type,
    amountMinor: amount,
    currency: 'TWD',
    category: category,
    merchant: merchant,
    spendingIntent: spendingIntent,
    intentReason: intentReason,
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
      final spendingIntent = type == MoneyEventType.income
          ? null
          : switch (category) {
              MoneyCategory.education ||
              MoneyCategory.transport => SpendingIntent.need,
              MoneyCategory.food =>
                RegExp(r'正餐|早餐|午餐|晚餐').hasMatch(value)
                    ? SpendingIntent.need
                    : SpendingIntent.want,
              MoneyCategory.entertainment ||
              MoneyCategory.shopping ||
              MoneyCategory.subscription => SpendingIntent.want,
              _ => SpendingIntent.uncertain,
            };
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
        spendingIntent: spendingIntent,
        intentReason: switch (spendingIntent) {
          SpendingIntent.need => 'AI 建議：這筆較像支持日常生活或學習的需要。',
          SpendingIntent.want => 'AI 建議：這筆較像能帶來享受、但可以比較或延後的想要。',
          SpendingIntent.uncertain => 'AI 還不確定，請依當時情境自行判斷。',
          null => null,
        },
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
      userId: 'guest-user',
      type: draft.type,
      amountMinor: draft.amountMinor!,
      currency: 'TWD',
      category: draft.category,
      merchant: draft.merchant,
      occurredAt: draft.occurredAt,
      recurrence: draft.recurrence,
      split: draft.split,
      spendingIntent: draft.spendingIntent,
      intentReason: draft.intentReason,
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
  Future<FinancialInsights> getInsights() async {
    final profile = await getProfile();
    final events = await listMoneyEvents();
    final now = toTaipeiTime(DateTime.now());
    final months = List.generate(6, (index) {
      final month = DateTime(now.year, now.month - 5 + index);
      return '${month.year}-${month.month.toString().padLeft(2, '0')}';
    });
    String monthOf(DateTime value) {
      final date = toTaipeiTime(value);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}';
    }

    final cashflow = months.map((month) {
      final items = events.where((event) => monthOf(event.occurredAt) == month);
      final income = items
          .where((event) => event.type == MoneyEventType.income)
          .fold<int>(0, (sum, event) => sum + event.effectiveAmountMinor);
      final expense = items
          .where((event) => event.type == MoneyEventType.expense)
          .fold<int>(0, (sum, event) => sum + event.effectiveAmountMinor);
      final subscription = items
          .where((event) => event.type == MoneyEventType.subscription)
          .fold<int>(0, (sum, event) => sum + event.effectiveAmountMinor);
      return MonthlyCashflowPoint(
        month: month,
        incomeMinor: income,
        expenseMinor: expense,
        subscriptionMinor: subscription,
        netMinor: income - expense - subscription,
      );
    }).toList();
    final current = events.where(
      (event) => monthOf(event.occurredAt) == months.last,
    );
    int intentTotal(SpendingIntent intent) => current
        .where(
          (event) =>
              event.type != MoneyEventType.income &&
              (event.spendingIntent ?? SpendingIntent.uncertain) == intent,
        )
        .fold<int>(0, (sum, event) => sum + event.effectiveAmountMinor);
    final need = intentTotal(SpendingIntent.need);
    final want = intentTotal(SpendingIntent.want);
    final uncertain = intentTotal(SpendingIntent.uncertain);
    final subscriptions = events.where(
      (event) => event.type == MoneyEventType.subscription,
    );
    final subscription = subscriptions.fold<int>(0, (sum, event) {
      final amount = event.effectiveAmountMinor;
      return sum +
          (event.recurrence?.billingCycle == BillingCycle.yearly
              ? (amount / 12).round()
              : amount);
    });
    final notices = <InsightNotice>[];
    final upcoming = subscriptions.where((event) {
      final next = event.recurrence?.nextBillingAt;
      if (next == null) return false;
      final days = next.difference(DateTime.now()).inDays;
      return days >= 0 && days <= 30;
    }).firstOrNull;
    if (upcoming != null) {
      notices.add(
        InsightNotice(
          id: 'subscription-renewal-${upcoming.id}',
          kind: InsightKind.subscription,
          level: InsightLevel.attention,
          title: '續訂前先問一次：最近真的有在用嗎？',
          message: '${upcoming.merchant ?? '這項訂閱'}即將續訂；這是檢查提醒，不代表它一定浪費。',
          actionPath: '/subscriptions',
          amountMinor: upcoming.effectiveAmountMinor,
        ),
      );
    }
    if (want > need && want > 0) {
      notices.add(
        InsightNotice(
          id: 'want-balance-${months.last}',
          kind: InsightKind.spending,
          level: InsightLevel.info,
          title: '本月的想要支出比需要支出高',
          message: '這不是對錯判斷；挑一筆延後 24 小時，再看它是否仍值得。',
          actionPath: '/records',
          amountMinor: want,
        ),
      );
    }
    if (uncertain > 0) {
      notices.add(
        InsightNotice(
          id: 'intent-review-${months.last}',
          kind: InsightKind.learning,
          level: InsightLevel.info,
          title: '還有一些支出需要你自己判斷',
          message: 'AI 只能提供建議；是否必要仍要看當時情境與你的選擇。',
          actionPath: '/records',
          amountMinor: uncertain,
        ),
      );
    }
    notices.add(
      InsightNotice(
        id: 'saving-simulation',
        kind: InsightKind.saving,
        level: InsightLevel.positive,
        title: '把已存下來的金額放進時間模擬',
        message: '比較紀律投入與不同風險路徑，不代表未來一定會得到相同結果。',
        actionPath: '/future-seed',
        amountMinor: profile.goalSavedMinor,
      ),
    );
    final classified = need + want;
    return FinancialInsights(
      generatedAt: DateTime.now(),
      monthlyCashflow: cashflow,
      needMinor: need,
      wantMinor: want,
      uncertainMinor: uncertain,
      subscriptionMinor: subscription,
      summary: classified == 0
          ? '先完成幾筆需要／想要判斷，這裡就會開始形成你的金錢模式。'
          : '本月已分類支出中，想要約占 ${((want / classified) * 100).round()}%；先看趨勢，再決定下一個小行動。',
      notices: notices,
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
  Future<LearningPlan> getLearningPlan() async {
    final profile = await getProfile();
    final insights = await getInsights();
    return LearningPlan(
      title: profile.accountRole == AccountRole.parent
          ? '親子共學理財路線'
          : '我的理財學習路線',
      summary: '${insights.summary} 每次只完成一個小練習，不追求一次全部學會。',
      modules: const [
        LearningPlanModule(
          id: 'intent',
          title: '分清需要、想要與情境',
          reason: '看懂選擇，比把所有想要都刪掉更重要。',
          nextAction: '從本月挑一筆支出，寫下當時為什麼買。',
          status: 'current',
        ),
        LearningPlanModule(
          id: 'subscription',
          title: '看懂固定支出',
          reason: '訂閱金額不大，但會每月重複。',
          nextAction: '檢查一項訂閱的使用頻率與下次扣款日。',
          status: 'next',
        ),
        LearningPlanModule(
          id: 'compound',
          title: '時間與複利',
          reason: '投入紀律、時間與報酬率會一起改變結果。',
          nextAction: '用已存下的金額跑一次三情境模擬。',
          status: 'next',
        ),
        LearningPlanModule(
          id: 'risk',
          title: '波動、分散與風險',
          reason: '平均報酬不代表每一年都上漲。',
          nextAction: '比較三條曲線中最大的下跌。',
          status: 'next',
        ),
      ],
      source: CaptureSource.deterministicDemo,
      disclaimer: '此規劃僅供金融教育，不構成個人化投資建議。',
    );
  }

  @override
  Future<InvestmentSimulation> simulateInvestments({
    required int initialAmountMinor,
    required int monthlyContributionMinor,
    required int years,
  }) async {
    if (initialAmountMinor < 0 ||
        monthlyContributionMinor <= 0 ||
        years < 1 ||
        years > 30) {
      throw const FormatException('投入金額與期間不在允許範圍。');
    }
    const definitions = [
      (
        InvestmentScenarioId.steady,
        '穩穩存',
        '用儲蓄與定存概念觀察時間和紀律，波動較小。',
        1.5,
        '低波動示意',
        [1.4, 1.6, 1.5, 1.7, 1.3],
      ),
      (
        InvestmentScenarioId.balanced,
        '慢慢長',
        '用長期分散概念體驗上漲、回落與持續投入。',
        5.0,
        '中度波動示意',
        [8.0, -4.0, 10.0, 3.0, 6.0, -12.0, 9.0, 5.0, 8.0, 2.0],
      ),
      (
        InvestmentScenarioId.highRisk,
        '高風險資產',
        '用更大的漲跌體驗報酬不確定性與承受風險。',
        8.0,
        '高度波動示意',
        [18.0, -12.0, 26.0, -35.0, 22.0, 9.0, 14.0, -18.0, 30.0, 7.0],
      ),
    ];
    final scenarios = definitions.map((definition) {
      var balance = initialAmountMinor;
      var principal = initialAmountMinor;
      var peak = max(balance, 1);
      var maxDrawdown = 0.0;
      final points = <InvestmentYearPoint>[
        InvestmentYearPoint(
          year: 0,
          principalMinor: principal,
          balanceMinor: balance,
          annualReturnPercent: 0,
        ),
      ];
      for (var year = 1; year <= years; year++) {
        final annualReturn = definition.$6[(year - 1) % definition.$6.length];
        final monthlyRate = pow(1 + annualReturn / 100, 1 / 12) - 1;
        for (var month = 0; month < 12; month++) {
          balance += monthlyContributionMinor;
          principal += monthlyContributionMinor;
          balance = max(0, (balance * (1 + monthlyRate)).round());
        }
        peak = max(peak, balance);
        maxDrawdown = max(maxDrawdown, ((peak - balance) / peak) * 100);
        final eventLabel = switch ((definition.$1, year)) {
          (InvestmentScenarioId.balanced, 2) => '市場回落，但每月投入仍持續',
          (InvestmentScenarioId.balanced, 6) => '較明顯的回檔，分散不代表不會下跌',
          (InvestmentScenarioId.highRisk, 2) => '快速回落，高風險資產可能短期虧損',
          (InvestmentScenarioId.highRisk, 4) => '大幅下跌，較高假設報酬不代表每年都上漲',
          (InvestmentScenarioId.highRisk, 8) => '再次回檔，紀律也不能消除風險',
          _ => null,
        };
        points.add(
          InvestmentYearPoint(
            year: year,
            principalMinor: principal,
            balanceMinor: balance,
            annualReturnPercent: annualReturn,
            eventLabel: eventLabel,
          ),
        );
      }
      return InvestmentScenario(
        id: definition.$1,
        title: definition.$2,
        description: definition.$3,
        assumedAnnualRatePercent: definition.$4,
        riskLabel: definition.$5,
        principalMinor: principal,
        growthMinor: balance - principal,
        endingBalanceMinor: balance,
        maxDrawdownPercent: double.parse(maxDrawdown.toStringAsFixed(1)),
        yearlyPoints: points,
      );
    }).toList();
    return InvestmentSimulation(
      initialAmountMinor: initialAmountMinor,
      monthlyContributionMinor: monthlyContributionMinor,
      years: years,
      scenarios: scenarios,
      assumptionVersion: 'education-scenarios-2026-07-v1',
      disclaimer: '三條曲線使用版本化合成報酬路徑，僅供理解時間、紀律與風險；不是即時行情、投資建議或報酬保證。',
    );
  }

  @override
  Future<CoachReply> askCoach({
    required String topic,
    required String question,
    String style = 'example',
    InvestmentScenarioId? scenarioId,
    int? selectedYear,
  }) async {
    final answer = switch (topic) {
      'risk' when question.contains('分散') =>
        '分散是把風險放在不同地方，避免單一資產決定全部結果；它能降低集中風險，但不能保證不虧損。',
      'risk' => '曲線往下代表這段期間資產價值下降。報酬較高的情境通常也可能有較大的短期跌幅。',
      'compound' => '複利是原本的本金和累積成果一起參與下一段成長。時間越長，差異通常越容易被看見。',
      _ => '先比較投入本金、期末金額與最大跌幅，再想想自己能不能承受中間的變化。',
    };
    return CoachReply(
      answer: answer,
      takeaway: '平均報酬不是每年固定報酬；先理解風險，再談可能成長。',
      suggestions: const ['切換另一條曲線比較', '看看下跌年份仍持續投入會發生什麼', '把期間拉長後再觀察'],
      source: CaptureSource.deterministicDemo,
      disclaimer: '陪讀內容只解釋教育模擬，不提供買賣建議。',
    );
  }

  @override
  Future<FamilyOverview?> getFamilyOverview() async => null;

  @override
  Future<FamilyOverview> createFamilyInvite() async =>
      throw const FormatException('訪客模式無法建立家庭關聯，請先登入。');

  @override
  Future<FamilyOverview> joinFamily(String inviteCode) async =>
      throw const FormatException('訪客模式無法加入家庭，請先登入。');

  @override
  Future<void> leaveFamily() async =>
      throw const FormatException('訪客模式沒有家庭關聯。');

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

  MarketSnapshot _educationalMarketSnapshot() => MarketSnapshot(
    quotes: [
      MarketQuote(
        symbol: '0050',
        name: '元大台灣50',
        kind: 'etf',
        sector: '大型股分散 ETF',
        price: 104.4,
        change: -1.6,
        changePercent: -1.51,
        asOf: DateTime(2026, 7, 14),
        source: MarketQuoteSource.educationalSnapshot,
      ),
      MarketQuote(
        symbol: '1301',
        name: '台塑',
        kind: 'stock',
        sector: '塑膠工業',
        price: 63.6,
        change: 3.4,
        changePercent: 5.65,
        asOf: DateTime(2026, 7, 14),
        source: MarketQuoteSource.educationalSnapshot,
      ),
      MarketQuote(
        symbol: '2330',
        name: '台積電',
        kind: 'stock',
        sector: '半導體',
        price: 2420,
        change: -20,
        changePercent: -0.82,
        asOf: DateTime(2026, 7, 14),
        source: MarketQuoteSource.educationalSnapshot,
      ),
      MarketQuote(
        symbol: '2603',
        name: '長榮',
        kind: 'stock',
        sector: '航運業',
        price: 194.5,
        change: -0.5,
        changePercent: -0.26,
        asOf: DateTime(2026, 7, 14),
        source: MarketQuoteSource.educationalSnapshot,
      ),
      MarketQuote(
        symbol: '2886',
        name: '兆豐金',
        kind: 'stock',
        sector: '金融業',
        price: 47,
        change: 0,
        changePercent: 0,
        asOf: DateTime(2026, 7, 14),
        source: MarketQuoteSource.educationalSnapshot,
      ),
    ],
    fetchedAt: DateTime.now(),
    source: MarketQuoteSource.educationalSnapshot,
    sourceLabel: '內建教育快照（證交所盤後格式）',
    sourceUrl: 'https://openapi.twse.com.tw/',
    isFallback: true,
    disclaimer: '目前顯示明確標示的教育快照，不是即時行情；只供虛擬練習，不代表推薦。',
  );

  @override
  Future<MarketSnapshot> getMarketSnapshot() async {
    final baseUri = _marketBaseUri;
    if (baseUri == null) return _educationalMarketSnapshot();
    try {
      final response = await _client
          .get(baseUri.resolve('market/quotes'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _educationalMarketSnapshot();
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return MarketSnapshot.fromJson(decoded['data'] as Map<String, dynamic>);
    } catch (_) {
      return _educationalMarketSnapshot();
    }
  }

  InvestmentLab _buildInvestmentLab(MarketSnapshot market) {
    final positions = <String, _GuestPosition>{};
    var cashMinor = _investmentStartingCashMinor!;
    for (final order in [
      ..._investmentOrders,
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt))) {
      final current = positions.putIfAbsent(
        order.symbol,
        () => _GuestPosition(order.symbol, order.name),
      );
      if (order.side == InvestmentOrderSide.buy) {
        current.quantity += order.quantity;
        current.costMinor += order.totalMinor;
        cashMinor -= order.totalMinor;
      } else {
        final averageCost = current.quantity == 0
            ? 0
            : current.costMinor / current.quantity;
        current.costMinor = max(
          0,
          (current.costMinor - averageCost * order.quantity).round(),
        );
        current.quantity -= order.quantity;
        cashMinor += order.totalMinor;
      }
    }
    final quotes = {for (final quote in market.quotes) quote.symbol: quote};
    final active = positions.values.where((item) => item.quantity > 0).toList();
    final marketValues = <String, int>{};
    for (final position in active) {
      final price =
          quotes[position.symbol]?.price ??
          position.costMinor / position.quantity;
      marketValues[position.symbol] = (price * position.quantity).round();
    }
    final marketValueMinor = marketValues.values.fold<int>(0, (a, b) => a + b);
    final holdings = active.map((position) {
      final quote = quotes[position.symbol];
      final currentPrice =
          quote?.price ?? position.costMinor / position.quantity;
      final marketValue = marketValues[position.symbol]!;
      return VirtualHolding(
        symbol: position.symbol,
        name: position.name,
        quantity: position.quantity,
        averageCost: position.costMinor / position.quantity,
        currentPrice: currentPrice,
        costMinor: position.costMinor,
        marketValueMinor: marketValue,
        gainLossMinor: marketValue - position.costMinor,
        allocationPercent: marketValueMinor == 0
            ? 0
            : marketValue / marketValueMinor * 100,
      );
    }).toList();
    final largestAllocation = holdings.fold<double>(
      0,
      (largest, holding) => max(largest, holding.allocationPercent),
    );
    final diversificationScore = switch (holdings.length) {
      0 => 0,
      1 => 25,
      2 => largestAllocation <= 65 ? 60 : 45,
      _ => largestAllocation <= 50 ? 90 : 70,
    };
    final learningSummary = switch (holdings.length) {
      0 => '先選一個標的觀察，再決定是否用少量虛擬資金開始練習。',
      _ when largestAllocation > 70 => '目前資產集中在單一標的，先觀察集中風險，不需要為了分數頻繁交易。',
      1 || 2 => '你已開始配置資產；下一步可以比較不同產業或 ETF 的波動差異。',
      _ => '目前配置較分散，接下來請觀察分散是否降低整體波動，而不是只看單日漲跌。',
    };
    final totalAssetMinor = cashMinor + marketValueMinor;
    final gainLossMinor = totalAssetMinor - _investmentStartingCashMinor!;
    return InvestmentLab(
      startingCashMinor: _investmentStartingCashMinor!,
      cashMinor: cashMinor,
      marketValueMinor: marketValueMinor,
      totalAssetMinor: totalAssetMinor,
      gainLossMinor: gainLossMinor,
      returnPercent:
          gainLossMinor / max(1, _investmentStartingCashMinor!) * 100,
      diversificationScore: diversificationScore,
      learningSummary: learningSummary,
      holdings: holdings,
      orders: [..._investmentOrders]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      market: market,
      disclaimer: '這是教育用虛擬帳戶，不會送出真實委託，也不是投資建議。價格可能延遲，未計入手續費、稅與股利。',
    );
  }

  @override
  Future<InvestmentLab> getInvestmentLab() async {
    final profile = await getProfile();
    _investmentStartingCashMinor ??= profile.goalSavedMinor > 0
        ? profile.goalSavedMinor
        : 1000;
    return _buildInvestmentLab(await getMarketSnapshot());
  }

  @override
  Future<InvestmentLab> placeInvestmentOrder({
    required String symbol,
    required InvestmentOrderSide side,
    required int quantity,
    required String idempotencyKey,
  }) async {
    final current = await getInvestmentLab();
    if (_investmentOrders.any(
      (order) => order.idempotencyKey == idempotencyKey,
    )) {
      return current;
    }
    final quote = current.market.quotes.firstWhere(
      (item) => item.symbol == symbol,
      orElse: () => throw const FormatException('目前找不到這個教學標的。'),
    );
    final totalMinor = (quote.price * quantity).round();
    if (side == InvestmentOrderSide.buy && totalMinor > current.cashMinor) {
      throw const FormatException('虛擬現金不足，請減少數量後再試。');
    }
    final owned = current.holdings
        .where((holding) => holding.symbol == symbol)
        .fold<int>(0, (sum, holding) => sum + holding.quantity);
    if (side == InvestmentOrderSide.sell && quantity > owned) {
      throw const FormatException('持有數量不足，不能賣出超過目前的虛擬持股。');
    }
    final now = DateTime.now();
    _investmentOrders.add(
      VirtualInvestmentOrder(
        id: 'guest-order-${now.microsecondsSinceEpoch}',
        symbol: quote.symbol,
        name: quote.name,
        side: side,
        quantity: quantity,
        unitPrice: quote.price,
        totalMinor: totalMinor,
        quoteAsOf: quote.asOf,
        quoteSource: quote.source,
        idempotencyKey: idempotencyKey,
        createdAt: now,
      ),
    );
    return _buildInvestmentLab(current.market);
  }

  @override
  Future<PracticeDiceEvent> rollInvestmentDice({required int rollIndex}) async {
    const deck = [
      (
        'market-drop',
        '市場突然回檔',
        '整體市場短期下跌，新聞標題變得很緊張。',
        '先比較整體配置與單一標的跌幅，再決定是否需要任何動作。',
        '市場突然下跌時，為什麼不一定要立刻賣出？',
        'risk',
      ),
      (
        'allowance-gap',
        '這個月暫停投入',
        '臨時支出增加，這個月沒有多餘的錢可以投入。',
        '保留生活預備金，觀察少投入一個月與長期紀律的關係。',
        '暫停投入一個月，為什麼不等於長期計畫失敗？',
        'discipline',
      ),
      (
        'hot-topic',
        '熱門話題快速上漲',
        '同學都在討論某個快速上漲的標的，你開始擔心錯過。',
        '先檢查資訊來源、持有比例與能承受的損失，不因熱度直接追價。',
        '為什麼只因為大家都在談，就買進可能有風險？',
        'risk',
      ),
      (
        'concentration-check',
        '集中度檢查',
        '你的多數虛擬資產都集中在同一家公司或產業。',
        '比較單一股票與分散型 ETF 的配置差異，記錄波動感受。',
        '什麼是集中風險？分散為什麼仍不能保證不會虧損？',
        'diversification',
      ),
      (
        'fee-drag',
        '交易成本出現',
        '你發現頻繁買賣即使方向猜對，也可能累積手續費與稅。',
        '本回合不交易，先計算如果每次都收費，長期會少多少。',
        '為什麼頻繁交易的成本會拖累長期成果？',
        'fees',
      ),
    ];
    final event = deck[(rollIndex * 7 + 3) % deck.length];
    return PracticeDiceEvent(
      id: event.$1,
      rollIndex: rollIndex,
      title: event.$2,
      situation: event.$3,
      practicePrompt: event.$4,
      coachQuestion: event.$5,
      learningFocus: event.$6,
      deckVersion: 'investment-lab-events-v1',
      disclaimer: '事件卡是教育情境，不是市場預測或買賣訊號。',
    );
  }

  @override
  Future<void> resetDemo() async {
    await _preferences.remove(_profileKey);
    await _preferences.remove(_eventsKey);
    await _preferences.remove(_lessonKey);
    _investmentStartingCashMinor = null;
    _investmentOrders.clear();
    await _ensureSeeded();
  }
}

class _GuestPosition {
  _GuestPosition(this.symbol, this.name);

  final String symbol;
  final String name;
  int quantity = 0;
  int costMinor = 0;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
