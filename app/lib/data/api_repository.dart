import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/future_mint_repository.dart';
import '../core/models.dart';

class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    required this.retryable,
  });

  final String code;
  final String message;
  final bool retryable;

  @override
  String toString() => message;
}

class ApiRepository implements FutureMintRepository {
  ApiRepository({
    required this.baseUri,
    this.accessToken,
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 12),
  }) : _client = client ?? http.Client();

  final Uri baseUri;
  final String? accessToken;
  final http.Client _client;
  final Duration requestTimeout;

  String _apiDateTime(DateTime value) {
    if (value.isUtc) return value.toIso8601String();
    final minutes = value.timeZoneOffset.inMinutes;
    final sign = minutes < 0 ? '-' : '+';
    final absolute = minutes.abs();
    final hoursText = (absolute ~/ 60).toString().padLeft(2, '0');
    final minutesText = (absolute % 60).toString().padLeft(2, '0');
    return '${value.toIso8601String()}$sign$hoursText:$minutesText';
  }

  Uri _uri(String path) {
    final prefix = baseUri.path.endsWith('/')
        ? baseUri.path
        : '${baseUri.path}/';
    return baseUri.replace(
      path: '$prefix${path.startsWith('/') ? path.substring(1) : path}',
      query: null,
      fragment: null,
    );
  }

  Future<dynamic> _send(String method, String path, {Object? body}) async {
    late http.Response response;
    try {
      final headers = <String, String>{
        'content-type': 'application/json',
        if (accessToken != null) 'authorization': 'Bearer $accessToken',
      };
      final encoded = body == null ? null : jsonEncode(body);
      final request = switch (method) {
        'GET' => _client.get(_uri(path), headers: headers),
        'PUT' => _client.put(_uri(path), headers: headers, body: encoded),
        'PATCH' => _client.patch(_uri(path), headers: headers, body: encoded),
        _ => _client.post(_uri(path), headers: headers, body: encoded),
      };
      response = await request.timeout(requestTimeout);
    } on TimeoutException {
      throw const ApiException(
        code: 'request_timeout',
        message: '連線逾時，請檢查網路後再試一次。',
        retryable: true,
      );
    } on http.ClientException {
      throw const ApiException(
        code: 'network_error',
        message: '目前無法連上服務，請檢查網路後再試。',
        retryable: true,
      );
    }

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw const ApiException(
        code: 'invalid_response',
        message: '服務回覆格式異常，請稍後再試。',
        retryable: true,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        code: decoded['code'] as String? ?? 'request_failed',
        message: response.statusCode == 401
            ? '登入已過期，請重新登入。'
            : decoded['message'] as String? ?? '目前無法完成請求。',
        retryable: decoded['retryable'] as bool? ?? false,
      );
    }
    return decoded['data'];
  }

  @override
  Future<UserProfile> getProfile() async => UserProfile.fromJson(
    await _send('GET', 'profile') as Map<String, dynamic>,
  );

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async =>
      UserProfile.fromJson(
        await _send('PUT', 'profile', body: profile.toJson())
            as Map<String, dynamic>,
      );

  @override
  Future<List<MoneyEvent>> listMoneyEvents() async =>
      (await _send('GET', 'money-events') as List<dynamic>)
          .map((item) => MoneyEvent.fromJson(item as Map<String, dynamic>))
          .toList();

  @override
  Future<DashboardSummary> getDashboard() async => DashboardSummary.fromJson(
    await _send('GET', 'dashboard') as Map<String, dynamic>,
  );

  @override
  Future<FinancialInsights> getInsights() async => FinancialInsights.fromJson(
    await _send('GET', 'insights') as Map<String, dynamic>,
  );

  @override
  Future<CaptureResult> parseCapture(
    String text, {
    required DateTime referenceTime,
  }) async {
    final json =
        await _send(
              'POST',
              'captures/parse',
              body: {
                'text': text,
                'locale': 'zh-TW',
                'referenceTime': _apiDateTime(referenceTime),
              },
            )
            as Map<String, dynamic>;
    return CaptureResult(
      drafts: (json['drafts'] as List<dynamic>)
          .map((item) => CaptureDraft.fromJson(item as Map<String, dynamic>))
          .toList(),
      clarificationQuestion: json['clarificationQuestion'] as String?,
      rejectedReason: json['rejectedReason'] as String?,
    );
  }

  @override
  Future<MoneyEvent> saveDraft(
    CaptureDraft draft, {
    required String idempotencyKey,
  }) async {
    final amount = draft.amountMinor;
    if (amount == null || amount <= 0) {
      throw const FormatException('請先補上正確金額。');
    }
    return MoneyEvent.fromJson(
      await _send(
            'POST',
            'money-events',
            body: {
              'type': draft.type.name,
              'amountMinor': amount,
              'currency': 'TWD',
              'category': draft.category.name,
              if (draft.merchant != null) 'merchant': draft.merchant,
              'occurredAt': _apiDateTime(draft.occurredAt),
              if (draft.recurrence != null)
                'recurrence': {
                  'billingCycle': draft.recurrence!.billingCycle.name,
                  if (draft.recurrence!.nextBillingAt != null)
                    'nextBillingAt': _apiDateTime(
                      draft.recurrence!.nextBillingAt!,
                    ),
                },
              if (draft.split != null) 'split': draft.split!.toJson(),
              if (draft.spendingIntent != null)
                'spendingIntent': draft.spendingIntent!.name,
              if (draft.intentReason != null)
                'intentReason': draft.intentReason,
              'confirmed': true,
              'idempotencyKey': idempotencyKey,
            },
          )
          as Map<String, dynamic>,
    );
  }

  @override
  Future<SubscriptionComparison?> compareSubscriptions() async {
    final events = await listMoneyEvents();
    final subscriptions = events
        .where((event) => event.type == MoneyEventType.subscription)
        .toList();
    subscriptions.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final current = subscriptions.isEmpty ? null : subscriptions.first;
    if (current == null) return null;
    final json =
        await _send(
              'POST',
              'subscriptions/compare',
              body: {
                'currentName': current.merchant ?? '未命名訂閱',
                'currentPriceMinor': current.effectiveAmountMinor,
                'currentBillingCycle':
                    current.recurrence?.billingCycle.name ?? 'monthly',
                'members': current.split?.participants ?? 1,
                'isStudent': true,
              },
            )
            as Map<String, dynamic>;
    return SubscriptionComparison(
      currentName: json['currentName'] as String,
      currentMonthlyCostMinor: json['currentMonthlyCostMinor'] as int,
      options: (json['options'] as List<dynamic>).map((item) {
        final option = item as Map<String, dynamic>;
        return SubscriptionOption(
          id: option['id'] as String,
          name: option['name'] as String,
          monthlyCostMinor: option['monthlyCostMinor'] as int,
          userMonthlyCostMinor: option['userMonthlyCostMinor'] as int,
          monthlySavingsMinor: option['monthlySavingsMinor'] as int?,
          eligible: option['eligible'] as bool,
          eligibilityMessage: option['eligibilityMessage'] as String,
          sourceType: option['sourceType'] as String,
        );
      }).toList(),
      disclaimer: json['disclaimer'] as String,
    );
  }

  @override
  Future<Lesson> generateLesson() async {
    try {
      return Lesson.fromJson(
        await _send('GET', 'lessons/current') as Map<String, dynamic>,
      );
    } on ApiException catch (error) {
      if (error.code != 'lesson_not_found') rethrow;
      return Lesson.fromJson(
        await _send('POST', 'lessons/generate', body: const {})
            as Map<String, dynamic>,
      );
    }
  }

  @override
  Future<Lesson> completeLesson(Lesson lesson, String selectedOption) async =>
      Lesson.fromJson(
        await _send(
              'PATCH',
              'lessons/${lesson.id}',
              body: {'selectedOption': selectedOption},
            )
            as Map<String, dynamic>,
      );

  @override
  Future<LearningPlan> getLearningPlan() async => LearningPlan.fromJson(
    await _send('GET', 'learning-plan') as Map<String, dynamic>,
  );

  @override
  Future<FutureSeedPreview> previewFutureSeed({
    required int monthlyContributionMinor,
    required int years,
    required double annualRatePercent,
  }) async => FutureSeedPreview.fromJson(
    await _send(
          'POST',
          'future-seed/preview',
          body: {
            'monthlyContributionMinor': monthlyContributionMinor,
            'years': years,
            'annualRatePercent': annualRatePercent,
          },
        )
        as Map<String, dynamic>,
  );

  @override
  Future<InvestmentSimulation> simulateInvestments({
    required int initialAmountMinor,
    required int monthlyContributionMinor,
    required int years,
  }) async => InvestmentSimulation.fromJson(
    await _send(
          'POST',
          'future-seed/simulate',
          body: {
            'initialAmountMinor': initialAmountMinor,
            'monthlyContributionMinor': monthlyContributionMinor,
            'years': years,
          },
        )
        as Map<String, dynamic>,
  );

  @override
  Future<CoachReply> askCoach({
    required String topic,
    required String question,
    InvestmentScenarioId? scenarioId,
    int? selectedYear,
  }) async => CoachReply.fromJson(
    await _send(
          'POST',
          'coach/chat',
          body: {
            'topic': topic,
            'question': question,
            if (scenarioId != null) 'scenarioId': scenarioToJson(scenarioId),
            'selectedYear': ?selectedYear,
          },
        )
        as Map<String, dynamic>,
  );

  @override
  Future<MarketSnapshot> getMarketSnapshot() async => MarketSnapshot.fromJson(
    await _send('GET', 'market/quotes') as Map<String, dynamic>,
  );

  @override
  Future<InvestmentLab> getInvestmentLab() async => InvestmentLab.fromJson(
    await _send('GET', 'investment-lab') as Map<String, dynamic>,
  );

  @override
  Future<InvestmentLab> placeInvestmentOrder({
    required String symbol,
    required InvestmentOrderSide side,
    required int quantity,
    required String idempotencyKey,
  }) async => InvestmentLab.fromJson(
    await _send(
          'POST',
          'investment-lab/orders',
          body: {
            'symbol': symbol,
            'side': side.name,
            'quantity': quantity,
            'idempotencyKey': idempotencyKey,
          },
        )
        as Map<String, dynamic>,
  );

  @override
  Future<PracticeDiceEvent> rollInvestmentDice({
    required int rollIndex,
  }) async => PracticeDiceEvent.fromJson(
    await _send('POST', 'investment-lab/dice', body: {'rollIndex': rollIndex})
        as Map<String, dynamic>,
  );

  @override
  Future<void> resetDemo() async {
    await _send('POST', 'demo/reset', body: const {});
  }
}
