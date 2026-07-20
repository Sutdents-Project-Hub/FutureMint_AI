enum AppMode { authenticated, guest }

enum MoneyEventType { income, expense, subscription }

enum MoneyCategory {
  food,
  transport,
  entertainment,
  education,
  shopping,
  income,
  subscription,
  other,
}

enum CaptureSource { liangjieAi, deterministicDemo }

enum BillingCycle { monthly, yearly }

enum AccountRole { child, parent }

enum SpendingIntent { need, want, uncertain }

enum InsightLevel { info, attention, positive }

enum InsightKind { subscription, spending, saving, learning }

enum InvestmentScenarioId { steady, balanced, highRisk }

enum InvestmentOrderSide { buy, sell }

enum MarketQuoteSource { twseOpenapi, educationalSnapshot }

MarketQuoteSource _marketSourceFromJson(String value) => switch (value) {
  'twse-openapi' => MarketQuoteSource.twseOpenapi,
  _ => MarketQuoteSource.educationalSnapshot,
};

String marketSourceToJson(MarketQuoteSource value) => switch (value) {
  MarketQuoteSource.twseOpenapi => 'twse-openapi',
  MarketQuoteSource.educationalSnapshot => 'educational-snapshot',
};

InvestmentScenarioId _scenarioFromJson(String value) => switch (value) {
  'high-risk' => InvestmentScenarioId.highRisk,
  'balanced' => InvestmentScenarioId.balanced,
  _ => InvestmentScenarioId.steady,
};

String scenarioToJson(InvestmentScenarioId value) => switch (value) {
  InvestmentScenarioId.highRisk => 'high-risk',
  _ => value.name,
};

T _enumByName<T extends Enum>(Iterable<T> values, String name) =>
    values.firstWhere((value) => value.name == name);

String _sourceToJson(CaptureSource source) => switch (source) {
  CaptureSource.liangjieAi => 'liangjie-ai',
  CaptureSource.deterministicDemo => 'deterministic-demo',
};

CaptureSource _sourceFromJson(String value) => switch (value) {
  'liangjie-ai' => CaptureSource.liangjieAi,
  _ => CaptureSource.deterministicDemo,
};

class SplitDetails {
  const SplitDetails({
    required this.participants,
    required this.userShareMinor,
  });

  final int participants;
  final int userShareMinor;

  factory SplitDetails.fromJson(Map<String, dynamic> json) => SplitDetails(
    participants: json['participants'] as int,
    userShareMinor: json['userShareMinor'] as int,
  );

  Map<String, dynamic> toJson() => {
    'participants': participants,
    'userShareMinor': userShareMinor,
  };

  @override
  bool operator ==(Object other) =>
      other is SplitDetails &&
      other.participants == participants &&
      other.userShareMinor == userShareMinor;

  @override
  int get hashCode => Object.hash(participants, userShareMinor);
}

class RecurrenceDetails {
  const RecurrenceDetails({required this.billingCycle, this.nextBillingAt});

  final BillingCycle billingCycle;
  final DateTime? nextBillingAt;

  factory RecurrenceDetails.fromJson(Map<String, dynamic> json) =>
      RecurrenceDetails(
        billingCycle: _enumByName(
          BillingCycle.values,
          json['billingCycle'] as String,
        ),
        nextBillingAt: json['nextBillingAt'] == null
            ? null
            : DateTime.parse(json['nextBillingAt'] as String),
      );

  Map<String, dynamic> toJson() => {
    'billingCycle': billingCycle.name,
    if (nextBillingAt != null)
      'nextBillingAt': nextBillingAt!.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is RecurrenceDetails &&
      other.billingCycle == billingCycle &&
      other.nextBillingAt == nextBillingAt;

  @override
  int get hashCode => Object.hash(billingCycle, nextBillingAt);
}

class MoneyEvent {
  const MoneyEvent({
    required this.id,
    required this.userId,
    required this.type,
    required this.amountMinor,
    required this.currency,
    required this.category,
    required this.occurredAt,
    required this.createdAt,
    required this.updatedAt,
    this.merchant,
    this.recurrence,
    this.split,
    this.spendingIntent,
    this.intentReason,
    this.idempotencyKey,
  });

  final String id;
  final String userId;
  final MoneyEventType type;
  final int amountMinor;
  final String currency;
  final MoneyCategory category;
  final String? merchant;
  final DateTime occurredAt;
  final RecurrenceDetails? recurrence;
  final SplitDetails? split;
  final SpendingIntent? spendingIntent;
  final String? intentReason;
  final String? idempotencyKey;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get effectiveAmountMinor => split?.userShareMinor ?? amountMinor;

  factory MoneyEvent.fromJson(Map<String, dynamic> json) => MoneyEvent(
    id: json['id'] as String,
    userId: json['userId'] as String,
    type: _enumByName(MoneyEventType.values, json['type'] as String),
    amountMinor: json['amountMinor'] as int,
    currency: json['currency'] as String? ?? 'TWD',
    category: _enumByName(MoneyCategory.values, json['category'] as String),
    merchant: json['merchant'] as String?,
    occurredAt: DateTime.parse(json['occurredAt'] as String),
    recurrence: json['recurrence'] == null
        ? null
        : RecurrenceDetails.fromJson(
            json['recurrence'] as Map<String, dynamic>,
          ),
    split: json['split'] == null
        ? null
        : SplitDetails.fromJson(json['split'] as Map<String, dynamic>),
    spendingIntent: json['spendingIntent'] == null
        ? null
        : _enumByName(SpendingIntent.values, json['spendingIntent'] as String),
    intentReason: json['intentReason'] as String?,
    idempotencyKey: json['idempotencyKey'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'type': type.name,
    'amountMinor': amountMinor,
    'currency': currency,
    'category': category.name,
    if (merchant != null) 'merchant': merchant,
    'occurredAt': occurredAt.toIso8601String(),
    if (recurrence != null) 'recurrence': recurrence!.toJson(),
    if (split != null) 'split': split!.toJson(),
    if (spendingIntent != null) 'spendingIntent': spendingIntent!.name,
    if (intentReason != null) 'intentReason': intentReason,
    if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is MoneyEvent &&
      other.id == id &&
      other.userId == userId &&
      other.type == type &&
      other.amountMinor == amountMinor &&
      other.currency == currency &&
      other.category == category &&
      other.merchant == merchant &&
      other.occurredAt == occurredAt &&
      other.recurrence == recurrence &&
      other.split == split &&
      other.spendingIntent == spendingIntent &&
      other.intentReason == intentReason &&
      other.idempotencyKey == idempotencyKey &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    type,
    amountMinor,
    currency,
    category,
    merchant,
    occurredAt,
    recurrence,
    split,
    spendingIntent,
    intentReason,
    idempotencyKey,
    createdAt,
    updatedAt,
  );
}

class UserProfile {
  const UserProfile({
    required this.userId,
    required this.monthlyBudgetMinor,
    required this.goalName,
    required this.goalTargetMinor,
    required this.goalSavedMinor,
    required this.goalDate,
    this.weeklyBudgetMinor,
    this.preferredTone = 'supportive',
    this.accountRole = AccountRole.child,
  });

  final String userId;
  final int monthlyBudgetMinor;
  final int? weeklyBudgetMinor;
  final String goalName;
  final int goalTargetMinor;
  final int goalSavedMinor;
  final DateTime goalDate;
  final String preferredTone;
  final AccountRole accountRole;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    userId: json['userId'] as String,
    monthlyBudgetMinor: json['monthlyBudgetMinor'] as int,
    weeklyBudgetMinor: json['weeklyBudgetMinor'] as int?,
    goalName: json['goalName'] as String,
    goalTargetMinor: json['goalTargetMinor'] as int,
    goalSavedMinor: json['goalSavedMinor'] as int,
    goalDate: DateTime.parse(json['goalDate'] as String),
    preferredTone: json['preferredTone'] as String? ?? 'supportive',
    accountRole: _enumByName(
      AccountRole.values,
      json['accountRole'] as String? ?? 'child',
    ),
  );

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'monthlyBudgetMinor': monthlyBudgetMinor,
    if (weeklyBudgetMinor != null) 'weeklyBudgetMinor': weeklyBudgetMinor,
    'goalName': goalName,
    'goalTargetMinor': goalTargetMinor,
    'goalSavedMinor': goalSavedMinor,
    'goalDate': goalDate.toIso8601String().split('T').first,
    'preferredTone': preferredTone,
    'accountRole': accountRole.name,
  };
}

class DashboardSummary {
  const DashboardSummary({
    required this.monthlyBudgetMinor,
    required this.incomeMinor,
    required this.expenseMinor,
    required this.subscriptionMinor,
    required this.availableMinor,
    required this.goalRemainingMinor,
    required this.goalProgress,
    required this.recentEvents,
  });

  final int monthlyBudgetMinor;
  final int incomeMinor;
  final int expenseMinor;
  final int subscriptionMinor;
  final int availableMinor;
  final int goalRemainingMinor;
  final double goalProgress;
  final List<MoneyEvent> recentEvents;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) =>
      DashboardSummary(
        monthlyBudgetMinor: json['monthlyBudgetMinor'] as int,
        incomeMinor: json['incomeMinor'] as int,
        expenseMinor: json['expenseMinor'] as int,
        subscriptionMinor: json['subscriptionMinor'] as int,
        availableMinor: json['availableMinor'] as int,
        goalRemainingMinor: json['goalRemainingMinor'] as int,
        goalProgress: (json['goalProgress'] as num).toDouble(),
        recentEvents: (json['recentEvents'] as List<dynamic>? ?? [])
            .map((item) => MoneyEvent.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}

class CaptureDraft {
  const CaptureDraft({
    required this.draftId,
    required this.type,
    required this.currency,
    required this.category,
    required this.occurredAt,
    required this.confidence,
    required this.missingFields,
    required this.needsConfirmation,
    required this.source,
    this.amountMinor,
    this.merchant,
    this.recurrence,
    this.split,
    this.spendingIntent,
    this.intentReason,
  });

  final String draftId;
  final MoneyEventType type;
  final int? amountMinor;
  final String currency;
  final MoneyCategory category;
  final String? merchant;
  final DateTime occurredAt;
  final RecurrenceDetails? recurrence;
  final SplitDetails? split;
  final SpendingIntent? spendingIntent;
  final String? intentReason;
  final double confidence;
  final List<String> missingFields;
  final bool needsConfirmation;
  final CaptureSource source;

  factory CaptureDraft.fromJson(Map<String, dynamic> json) => CaptureDraft(
    draftId: json['draftId'] as String,
    type: _enumByName(MoneyEventType.values, json['type'] as String),
    amountMinor: json['amountMinor'] as int?,
    currency: json['currency'] as String? ?? 'TWD',
    category: _enumByName(MoneyCategory.values, json['category'] as String),
    merchant: json['merchant'] as String?,
    occurredAt: DateTime.parse(json['occurredAt'] as String),
    recurrence: json['recurrence'] == null
        ? null
        : RecurrenceDetails.fromJson(
            json['recurrence'] as Map<String, dynamic>,
          ),
    split: json['split'] == null
        ? null
        : SplitDetails.fromJson(json['split'] as Map<String, dynamic>),
    spendingIntent: json['spendingIntent'] == null
        ? null
        : _enumByName(SpendingIntent.values, json['spendingIntent'] as String),
    intentReason: json['intentReason'] as String?,
    confidence: (json['confidence'] as num).toDouble(),
    missingFields: List<String>.from(json['missingFields'] as List? ?? []),
    needsConfirmation: json['needsConfirmation'] as bool? ?? true,
    source: _sourceFromJson(json['source'] as String),
  );

  CaptureDraft copyWith({
    MoneyEventType? type,
    int? amountMinor,
    String? merchant,
    bool clearMerchant = false,
    MoneyCategory? category,
    DateTime? occurredAt,
    RecurrenceDetails? recurrence,
    bool clearRecurrence = false,
    SplitDetails? split,
    bool clearSplit = false,
    SpendingIntent? spendingIntent,
    String? intentReason,
  }) {
    final nextAmount = amountMinor ?? this.amountMinor;
    final nextType = type ?? this.type;
    final requestedCategory = category ?? this.category;
    final nextCategory = switch (nextType) {
      MoneyEventType.income => MoneyCategory.income,
      MoneyEventType.subscription => MoneyCategory.subscription,
      MoneyEventType.expense =>
        requestedCategory == MoneyCategory.income ||
                requestedCategory == MoneyCategory.subscription
            ? MoneyCategory.other
            : requestedCategory,
    };
    final requestedSplit = clearSplit ? null : split ?? this.split;
    final nextSplit = nextType == MoneyEventType.income
        ? null
        : requestedSplit == null || nextAmount == null
        ? requestedSplit
        : SplitDetails(
            participants: requestedSplit.participants,
            userShareMinor: (nextAmount / requestedSplit.participants).round(),
          );
    return CaptureDraft(
      draftId: draftId,
      type: nextType,
      amountMinor: nextAmount,
      currency: currency,
      category: nextCategory,
      merchant: clearMerchant ? null : merchant ?? this.merchant,
      occurredAt: occurredAt ?? this.occurredAt,
      recurrence: nextType == MoneyEventType.subscription
          ? clearRecurrence
                ? null
                : recurrence ??
                      this.recurrence ??
                      const RecurrenceDetails(
                        billingCycle: BillingCycle.monthly,
                      )
          : null,
      split: nextSplit,
      spendingIntent: nextType == MoneyEventType.income
          ? null
          : spendingIntent ?? this.spendingIntent ?? SpendingIntent.uncertain,
      intentReason: nextType == MoneyEventType.income
          ? null
          : intentReason ?? this.intentReason,
      confidence: confidence,
      missingFields: amountMinor != null
          ? missingFields.where((field) => field != 'amountMinor').toList()
          : missingFields,
      needsConfirmation: needsConfirmation,
      source: source,
    );
  }

  Map<String, dynamic> toJson() => {
    'draftId': draftId,
    'type': type.name,
    if (amountMinor != null) 'amountMinor': amountMinor,
    'currency': currency,
    'category': category.name,
    if (merchant != null) 'merchant': merchant,
    'occurredAt': occurredAt.toIso8601String(),
    if (recurrence != null) 'recurrence': recurrence!.toJson(),
    if (split != null) 'split': split!.toJson(),
    if (spendingIntent != null) 'spendingIntent': spendingIntent!.name,
    if (intentReason != null) 'intentReason': intentReason,
    'confidence': confidence,
    'missingFields': missingFields,
    'needsConfirmation': needsConfirmation,
    'source': _sourceToJson(source),
  };
}

class CaptureResult {
  const CaptureResult({
    required this.drafts,
    this.clarificationQuestion,
    this.rejectedReason,
  });

  final List<CaptureDraft> drafts;
  final String? clarificationQuestion;
  final String? rejectedReason;
}

class SubscriptionOption {
  const SubscriptionOption({
    required this.id,
    required this.name,
    required this.monthlyCostMinor,
    required this.userMonthlyCostMinor,
    required this.monthlySavingsMinor,
    required this.eligible,
    required this.eligibilityMessage,
    required this.sourceType,
  });

  final String id;
  final String name;
  final int monthlyCostMinor;
  final int userMonthlyCostMinor;
  final int? monthlySavingsMinor;
  final bool eligible;
  final String eligibilityMessage;
  final String sourceType;
}

class SubscriptionComparison {
  const SubscriptionComparison({
    required this.currentName,
    required this.currentMonthlyCostMinor,
    required this.options,
    required this.disclaimer,
  });

  final String currentName;
  final int currentMonthlyCostMinor;
  final List<SubscriptionOption> options;
  final String disclaimer;
}

class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.concept,
    required this.example,
    required this.question,
    required this.options,
    required this.action,
    required this.disclaimer,
    required this.source,
    this.selectedOption,
  });

  final String id;
  final String title;
  final String concept;
  final String example;
  final String question;
  final List<String> options;
  final String action;
  final String disclaimer;
  final CaptureSource source;
  final String? selectedOption;

  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
    id: json['id'] as String,
    title: json['title'] as String,
    concept: json['concept'] as String,
    example: json['example'] as String,
    question: json['question'] as String,
    options: List<String>.from(json['options'] as List<dynamic>),
    action: json['action'] as String,
    disclaimer: json['disclaimer'] as String,
    source: _sourceFromJson(json['source'] as String),
    selectedOption: json['selectedOption'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'concept': concept,
    'example': example,
    'question': question,
    'options': options,
    'action': action,
    'disclaimer': disclaimer,
    'source': _sourceToJson(source),
    if (selectedOption != null) 'selectedOption': selectedOption,
  };
}

class FutureSeedYearPoint {
  const FutureSeedYearPoint({
    required this.year,
    required this.principalMinor,
    required this.balanceMinor,
  });

  final int year;
  final int principalMinor;
  final int balanceMinor;

  factory FutureSeedYearPoint.fromJson(Map<String, dynamic> json) =>
      FutureSeedYearPoint(
        year: json['year'] as int,
        principalMinor: json['principalMinor'] as int,
        balanceMinor: json['balanceMinor'] as int,
      );
}

class FutureSeedPreview {
  const FutureSeedPreview({
    required this.principalMinor,
    required this.growthMinor,
    required this.endingBalanceMinor,
    required this.yearlyPoints,
    required this.disclaimer,
  });

  final int principalMinor;
  final int growthMinor;
  final int endingBalanceMinor;
  final List<FutureSeedYearPoint> yearlyPoints;
  final String disclaimer;

  factory FutureSeedPreview.fromJson(Map<String, dynamic> json) =>
      FutureSeedPreview(
        principalMinor: json['principalMinor'] as int,
        growthMinor: json['growthMinor'] as int,
        endingBalanceMinor: json['endingBalanceMinor'] as int,
        yearlyPoints: (json['yearlyPoints'] as List<dynamic>)
            .map(
              (item) =>
                  FutureSeedYearPoint.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
        disclaimer: json['disclaimer'] as String,
      );
}

class MonthlyCashflowPoint {
  const MonthlyCashflowPoint({
    required this.month,
    required this.incomeMinor,
    required this.expenseMinor,
    required this.subscriptionMinor,
    required this.netMinor,
  });

  final String month;
  final int incomeMinor;
  final int expenseMinor;
  final int subscriptionMinor;
  final int netMinor;

  factory MonthlyCashflowPoint.fromJson(Map<String, dynamic> json) =>
      MonthlyCashflowPoint(
        month: json['month'] as String,
        incomeMinor: json['incomeMinor'] as int,
        expenseMinor: json['expenseMinor'] as int,
        subscriptionMinor: json['subscriptionMinor'] as int,
        netMinor: json['netMinor'] as int,
      );
}

class InsightNotice {
  const InsightNotice({
    required this.id,
    required this.kind,
    required this.level,
    required this.title,
    required this.message,
    required this.actionPath,
    this.amountMinor,
  });

  final String id;
  final InsightKind kind;
  final InsightLevel level;
  final String title;
  final String message;
  final String actionPath;
  final int? amountMinor;

  factory InsightNotice.fromJson(Map<String, dynamic> json) => InsightNotice(
    id: json['id'] as String,
    kind: _enumByName(InsightKind.values, json['kind'] as String),
    level: _enumByName(InsightLevel.values, json['level'] as String),
    title: json['title'] as String,
    message: json['message'] as String,
    actionPath: json['actionPath'] as String,
    amountMinor: json['amountMinor'] as int?,
  );
}

class FinancialInsights {
  const FinancialInsights({
    required this.generatedAt,
    required this.monthlyCashflow,
    required this.needMinor,
    required this.wantMinor,
    required this.uncertainMinor,
    required this.subscriptionMinor,
    required this.summary,
    required this.notices,
  });

  final DateTime generatedAt;
  final List<MonthlyCashflowPoint> monthlyCashflow;
  final int needMinor;
  final int wantMinor;
  final int uncertainMinor;
  final int subscriptionMinor;
  final String summary;
  final List<InsightNotice> notices;

  factory FinancialInsights.fromJson(Map<String, dynamic> json) =>
      FinancialInsights(
        generatedAt: DateTime.parse(json['generatedAt'] as String),
        monthlyCashflow: (json['monthlyCashflow'] as List<dynamic>)
            .map(
              (item) =>
                  MonthlyCashflowPoint.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
        needMinor: json['needMinor'] as int,
        wantMinor: json['wantMinor'] as int,
        uncertainMinor: json['uncertainMinor'] as int,
        subscriptionMinor: json['subscriptionMinor'] as int,
        summary: json['summary'] as String,
        notices: (json['notices'] as List<dynamic>)
            .map((item) => InsightNotice.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}

class LearningPlanModule {
  const LearningPlanModule({
    required this.id,
    required this.title,
    required this.reason,
    required this.nextAction,
    required this.status,
  });

  final String id;
  final String title;
  final String reason;
  final String nextAction;
  final String status;

  factory LearningPlanModule.fromJson(Map<String, dynamic> json) =>
      LearningPlanModule(
        id: json['id'] as String,
        title: json['title'] as String,
        reason: json['reason'] as String,
        nextAction: json['nextAction'] as String,
        status: json['status'] as String,
      );
}

class LearningPlan {
  const LearningPlan({
    required this.title,
    required this.summary,
    required this.modules,
    required this.source,
    required this.disclaimer,
  });

  final String title;
  final String summary;
  final List<LearningPlanModule> modules;
  final CaptureSource source;
  final String disclaimer;

  factory LearningPlan.fromJson(Map<String, dynamic> json) => LearningPlan(
    title: json['title'] as String,
    summary: json['summary'] as String,
    modules: (json['modules'] as List<dynamic>)
        .map(
          (item) => LearningPlanModule.fromJson(item as Map<String, dynamic>),
        )
        .toList(),
    source: _sourceFromJson(json['source'] as String),
    disclaimer: json['disclaimer'] as String,
  );
}

class InvestmentYearPoint {
  const InvestmentYearPoint({
    required this.year,
    required this.principalMinor,
    required this.balanceMinor,
    required this.annualReturnPercent,
    this.eventLabel,
  });

  final int year;
  final int principalMinor;
  final int balanceMinor;
  final double annualReturnPercent;
  final String? eventLabel;

  factory InvestmentYearPoint.fromJson(Map<String, dynamic> json) =>
      InvestmentYearPoint(
        year: json['year'] as int,
        principalMinor: json['principalMinor'] as int,
        balanceMinor: json['balanceMinor'] as int,
        annualReturnPercent: (json['annualReturnPercent'] as num).toDouble(),
        eventLabel: json['eventLabel'] as String?,
      );
}

class InvestmentScenario {
  const InvestmentScenario({
    required this.id,
    required this.title,
    required this.description,
    required this.assumedAnnualRatePercent,
    required this.riskLabel,
    required this.principalMinor,
    required this.growthMinor,
    required this.endingBalanceMinor,
    required this.maxDrawdownPercent,
    required this.yearlyPoints,
  });

  final InvestmentScenarioId id;
  final String title;
  final String description;
  final double assumedAnnualRatePercent;
  final String riskLabel;
  final int principalMinor;
  final int growthMinor;
  final int endingBalanceMinor;
  final double maxDrawdownPercent;
  final List<InvestmentYearPoint> yearlyPoints;

  factory InvestmentScenario.fromJson(Map<String, dynamic> json) =>
      InvestmentScenario(
        id: _scenarioFromJson(json['id'] as String),
        title: json['title'] as String,
        description: json['description'] as String,
        assumedAnnualRatePercent: (json['assumedAnnualRatePercent'] as num)
            .toDouble(),
        riskLabel: json['riskLabel'] as String,
        principalMinor: json['principalMinor'] as int,
        growthMinor: json['growthMinor'] as int,
        endingBalanceMinor: json['endingBalanceMinor'] as int,
        maxDrawdownPercent: (json['maxDrawdownPercent'] as num).toDouble(),
        yearlyPoints: (json['yearlyPoints'] as List<dynamic>)
            .map(
              (item) =>
                  InvestmentYearPoint.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
      );
}

class InvestmentSimulation {
  const InvestmentSimulation({
    required this.initialAmountMinor,
    required this.monthlyContributionMinor,
    required this.years,
    required this.scenarios,
    required this.assumptionVersion,
    required this.disclaimer,
  });

  final int initialAmountMinor;
  final int monthlyContributionMinor;
  final int years;
  final List<InvestmentScenario> scenarios;
  final String assumptionVersion;
  final String disclaimer;

  factory InvestmentSimulation.fromJson(Map<String, dynamic> json) =>
      InvestmentSimulation(
        initialAmountMinor: json['initialAmountMinor'] as int,
        monthlyContributionMinor: json['monthlyContributionMinor'] as int,
        years: json['years'] as int,
        scenarios: (json['scenarios'] as List<dynamic>)
            .map(
              (item) =>
                  InvestmentScenario.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
        assumptionVersion: json['assumptionVersion'] as String,
        disclaimer: json['disclaimer'] as String,
      );
}

class CoachReply {
  const CoachReply({
    required this.answer,
    required this.takeaway,
    required this.suggestions,
    required this.source,
    required this.disclaimer,
  });

  final String answer;
  final String takeaway;
  final List<String> suggestions;
  final CaptureSource source;
  final String disclaimer;

  factory CoachReply.fromJson(Map<String, dynamic> json) => CoachReply(
    answer: json['answer'] as String,
    takeaway: json['takeaway'] as String,
    suggestions: List<String>.from(json['suggestions'] as List<dynamic>),
    source: _sourceFromJson(json['source'] as String),
    disclaimer: json['disclaimer'] as String,
  );
}

class FamilyMember {
  const FamilyMember({
    required this.userId,
    required this.role,
    required this.label,
    required this.isSelf,
  });

  final String userId;
  final AccountRole role;
  final String label;
  final bool isSelf;

  factory FamilyMember.fromJson(Map<String, dynamic> json) => FamilyMember(
    userId: json['userId'] as String,
    role: _enumByName(AccountRole.values, json['role'] as String),
    label: json['label'] as String,
    isSelf: json['isSelf'] as bool? ?? false,
  );
}

class FamilyChildSummary {
  const FamilyChildSummary({
    required this.userId,
    required this.label,
    required this.monthlyBudgetMinor,
    required this.incomeMinor,
    required this.expenseMinor,
    required this.subscriptionMinor,
    required this.availableMinor,
    required this.goalProgress,
    required this.summary,
    required this.noticeCount,
  });

  final String userId;
  final String label;
  final int monthlyBudgetMinor;
  final int incomeMinor;
  final int expenseMinor;
  final int subscriptionMinor;
  final int availableMinor;
  final double goalProgress;
  final String summary;
  final int noticeCount;

  factory FamilyChildSummary.fromJson(Map<String, dynamic> json) =>
      FamilyChildSummary(
        userId: json['userId'] as String,
        label: json['label'] as String,
        monthlyBudgetMinor: json['monthlyBudgetMinor'] as int,
        incomeMinor: json['incomeMinor'] as int,
        expenseMinor: json['expenseMinor'] as int,
        subscriptionMinor: json['subscriptionMinor'] as int,
        availableMinor: json['availableMinor'] as int,
        goalProgress: (json['goalProgress'] as num).toDouble(),
        summary: json['summary'] as String,
        noticeCount: json['noticeCount'] as int,
      );
}

class FamilyOverview {
  const FamilyOverview({
    required this.familyId,
    required this.inviteCode,
    required this.members,
    required this.childSummaries,
  });

  final String familyId;
  final String? inviteCode;
  final List<FamilyMember> members;
  final List<FamilyChildSummary> childSummaries;

  factory FamilyOverview.fromJson(Map<String, dynamic> json) => FamilyOverview(
    familyId: json['familyId'] as String,
    inviteCode: json['inviteCode'] as String?,
    members: (json['members'] as List<dynamic>)
        .map((item) => FamilyMember.fromJson(item as Map<String, dynamic>))
        .toList(),
    childSummaries: (json['childSummaries'] as List<dynamic>? ?? [])
        .map(
          (item) => FamilyChildSummary.fromJson(item as Map<String, dynamic>),
        )
        .toList(),
  );
}

class MarketQuote {
  const MarketQuote({
    required this.symbol,
    required this.name,
    required this.kind,
    required this.sector,
    required this.price,
    required this.change,
    required this.changePercent,
    required this.asOf,
    required this.source,
  });

  final String symbol;
  final String name;
  final String kind;
  final String sector;
  final double price;
  final double change;
  final double changePercent;
  final DateTime asOf;
  final MarketQuoteSource source;

  factory MarketQuote.fromJson(Map<String, dynamic> json) => MarketQuote(
    symbol: json['symbol'] as String,
    name: json['name'] as String,
    kind: json['kind'] as String,
    sector: json['sector'] as String,
    price: (json['price'] as num).toDouble(),
    change: (json['change'] as num).toDouble(),
    changePercent: (json['changePercent'] as num).toDouble(),
    asOf: DateTime.parse(json['asOf'] as String),
    source: _marketSourceFromJson(json['source'] as String),
  );

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'name': name,
    'kind': kind,
    'sector': sector,
    'price': price,
    'change': change,
    'changePercent': changePercent,
    'asOf': asOf.toIso8601String().split('T').first,
    'source': marketSourceToJson(source),
  };
}

class MarketSnapshot {
  const MarketSnapshot({
    required this.quotes,
    required this.fetchedAt,
    required this.source,
    required this.sourceLabel,
    required this.sourceUrl,
    required this.isFallback,
    required this.disclaimer,
  });

  final List<MarketQuote> quotes;
  final DateTime fetchedAt;
  final MarketQuoteSource source;
  final String sourceLabel;
  final String sourceUrl;
  final bool isFallback;
  final String disclaimer;

  factory MarketSnapshot.fromJson(Map<String, dynamic> json) => MarketSnapshot(
    quotes: (json['quotes'] as List<dynamic>)
        .map((item) => MarketQuote.fromJson(item as Map<String, dynamic>))
        .toList(),
    fetchedAt: DateTime.parse(json['fetchedAt'] as String),
    source: _marketSourceFromJson(json['source'] as String),
    sourceLabel: json['sourceLabel'] as String,
    sourceUrl: json['sourceUrl'] as String,
    isFallback: json['isFallback'] as bool,
    disclaimer: json['disclaimer'] as String,
  );
}

class VirtualInvestmentOrder {
  const VirtualInvestmentOrder({
    required this.id,
    required this.symbol,
    required this.name,
    required this.side,
    required this.quantity,
    required this.unitPrice,
    required this.totalMinor,
    required this.quoteAsOf,
    required this.quoteSource,
    required this.idempotencyKey,
    required this.createdAt,
  });

  final String id;
  final String symbol;
  final String name;
  final InvestmentOrderSide side;
  final int quantity;
  final double unitPrice;
  final int totalMinor;
  final DateTime quoteAsOf;
  final MarketQuoteSource quoteSource;
  final String idempotencyKey;
  final DateTime createdAt;

  factory VirtualInvestmentOrder.fromJson(Map<String, dynamic> json) =>
      VirtualInvestmentOrder(
        id: json['id'] as String,
        symbol: json['symbol'] as String,
        name: json['name'] as String,
        side: _enumByName(InvestmentOrderSide.values, json['side'] as String),
        quantity: json['quantity'] as int,
        unitPrice: (json['unitPrice'] as num).toDouble(),
        totalMinor: json['totalMinor'] as int,
        quoteAsOf: DateTime.parse(json['quoteAsOf'] as String),
        quoteSource: _marketSourceFromJson(json['quoteSource'] as String),
        idempotencyKey: json['idempotencyKey'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class VirtualHolding {
  const VirtualHolding({
    required this.symbol,
    required this.name,
    required this.quantity,
    required this.averageCost,
    required this.currentPrice,
    required this.costMinor,
    required this.marketValueMinor,
    required this.gainLossMinor,
    required this.allocationPercent,
  });

  final String symbol;
  final String name;
  final int quantity;
  final double averageCost;
  final double currentPrice;
  final int costMinor;
  final int marketValueMinor;
  final int gainLossMinor;
  final double allocationPercent;

  factory VirtualHolding.fromJson(Map<String, dynamic> json) => VirtualHolding(
    symbol: json['symbol'] as String,
    name: json['name'] as String,
    quantity: json['quantity'] as int,
    averageCost: (json['averageCost'] as num).toDouble(),
    currentPrice: (json['currentPrice'] as num).toDouble(),
    costMinor: json['costMinor'] as int,
    marketValueMinor: json['marketValueMinor'] as int,
    gainLossMinor: json['gainLossMinor'] as int,
    allocationPercent: (json['allocationPercent'] as num).toDouble(),
  );
}

class InvestmentLab {
  const InvestmentLab({
    required this.startingCashMinor,
    required this.cashMinor,
    required this.marketValueMinor,
    required this.totalAssetMinor,
    required this.gainLossMinor,
    required this.returnPercent,
    required this.diversificationScore,
    required this.learningSummary,
    required this.holdings,
    required this.orders,
    required this.market,
    required this.disclaimer,
  });

  final int startingCashMinor;
  final int cashMinor;
  final int marketValueMinor;
  final int totalAssetMinor;
  final int gainLossMinor;
  final double returnPercent;
  final int diversificationScore;
  final String learningSummary;
  final List<VirtualHolding> holdings;
  final List<VirtualInvestmentOrder> orders;
  final MarketSnapshot market;
  final String disclaimer;

  factory InvestmentLab.fromJson(Map<String, dynamic> json) => InvestmentLab(
    startingCashMinor: json['startingCashMinor'] as int,
    cashMinor: json['cashMinor'] as int,
    marketValueMinor: json['marketValueMinor'] as int,
    totalAssetMinor: json['totalAssetMinor'] as int,
    gainLossMinor: json['gainLossMinor'] as int,
    returnPercent: (json['returnPercent'] as num).toDouble(),
    diversificationScore: json['diversificationScore'] as int,
    learningSummary: json['learningSummary'] as String,
    holdings: (json['holdings'] as List<dynamic>)
        .map((item) => VirtualHolding.fromJson(item as Map<String, dynamic>))
        .toList(),
    orders: (json['orders'] as List<dynamic>)
        .map(
          (item) =>
              VirtualInvestmentOrder.fromJson(item as Map<String, dynamic>),
        )
        .toList(),
    market: MarketSnapshot.fromJson(json['market'] as Map<String, dynamic>),
    disclaimer: json['disclaimer'] as String,
  );
}

class PracticeDiceEvent {
  const PracticeDiceEvent({
    required this.id,
    required this.rollIndex,
    required this.title,
    required this.situation,
    required this.practicePrompt,
    required this.coachQuestion,
    required this.learningFocus,
    required this.deckVersion,
    required this.disclaimer,
  });

  final String id;
  final int rollIndex;
  final String title;
  final String situation;
  final String practicePrompt;
  final String coachQuestion;
  final String learningFocus;
  final String deckVersion;
  final String disclaimer;

  factory PracticeDiceEvent.fromJson(Map<String, dynamic> json) =>
      PracticeDiceEvent(
        id: json['id'] as String,
        rollIndex: json['rollIndex'] as int,
        title: json['title'] as String,
        situation: json['situation'] as String,
        practicePrompt: json['practicePrompt'] as String,
        coachQuestion: json['coachQuestion'] as String,
        learningFocus: json['learningFocus'] as String,
        deckVersion: json['deckVersion'] as String,
        disclaimer: json['disclaimer'] as String,
      );
}
