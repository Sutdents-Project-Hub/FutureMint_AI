enum AppMode { connected, offlineDemo }

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

enum CaptureSource { azureAi, deterministicDemo }

enum BillingCycle { monthly, yearly }

T _enumByName<T extends Enum>(Iterable<T> values, String name) =>
    values.firstWhere((value) => value.name == name);

String _sourceToJson(CaptureSource source) => switch (source) {
  CaptureSource.azureAi => 'azure-ai',
  CaptureSource.deterministicDemo => 'deterministic-demo',
};

CaptureSource _sourceFromJson(String value) => switch (value) {
  'azure-ai' => CaptureSource.azureAi,
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
  });

  final String userId;
  final int monthlyBudgetMinor;
  final int? weeklyBudgetMinor;
  final String goalName;
  final int goalTargetMinor;
  final int goalSavedMinor;
  final DateTime goalDate;
  final String preferredTone;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    userId: json['userId'] as String,
    monthlyBudgetMinor: json['monthlyBudgetMinor'] as int,
    weeklyBudgetMinor: json['weeklyBudgetMinor'] as int?,
    goalName: json['goalName'] as String,
    goalTargetMinor: json['goalTargetMinor'] as int,
    goalSavedMinor: json['goalSavedMinor'] as int,
    goalDate: DateTime.parse(json['goalDate'] as String),
    preferredTone: json['preferredTone'] as String? ?? 'supportive',
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
