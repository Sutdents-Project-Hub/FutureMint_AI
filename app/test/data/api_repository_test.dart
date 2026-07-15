import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/data/api_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('sends a Bearer token for every account data request', () async {
    final repository = ApiRepository(
      baseUri: Uri.parse('https://example.test/api/'),
      accessToken: 'session-token',
      client: MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer session-token');
        return http.Response(
          jsonEncode({
            'requestId': 'request-token',
            'data': {
              'userId': 'account-1',
              'monthlyBudgetMinor': 6000,
              'goalName': '校外活動基金',
              'goalTargetMinor': 12000,
              'goalSavedMinor': 4200,
              'goalDate': '2026-10-31',
              'preferredTone': 'supportive',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    expect((await repository.getProfile()).userId, 'account-1');
  });

  test('unwraps the API data envelope into a profile', () async {
    final repository = ApiRepository(
      baseUri: Uri.parse('https://example.test/api/'),
      client: MockClient((request) async {
        expect(request.url.path, '/api/profile');
        return http.Response(
          jsonEncode({
            'requestId': 'request-1',
            'data': {
              'userId': 'demo-user',
              'monthlyBudgetMinor': 6000,
              'goalName': '校外活動基金',
              'goalTargetMinor': 12000,
              'goalSavedMinor': 4200,
              'goalDate': '2026-10-31',
              'preferredTone': 'supportive',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final profile = await repository.getProfile();
    expect(profile.monthlyBudgetMinor, 6000);
  });

  test(
    'keeps the API path when the configured base URL has no trailing slash',
    () async {
      final repository = ApiRepository(
        baseUri: Uri.parse('https://example.test/api'),
        client: MockClient((request) async {
          expect(request.url.path, '/api/profile');
          return http.Response(
            jsonEncode({
              'requestId': 'request-path',
              'data': {
                'userId': 'demo-user',
                'monthlyBudgetMinor': 6000,
                'goalName': '校外活動基金',
                'goalTargetMinor': 12000,
                'goalSavedMinor': 4200,
                'goalDate': '2026-10-31',
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      expect((await repository.getProfile()).userId, 'demo-user');
    },
  );

  test('maps a retryable problem without exposing the raw body', () async {
    final repository = ApiRepository(
      baseUri: Uri.parse('https://example.test/api/'),
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'code': 'ai_unavailable',
            'message': 'AI 服務暫時無法使用，請稍後再試。',
            'requestId': 'request-2',
            'retryable': true,
          }),
          503,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    await expectLater(
      repository.parseCapture(
        '早餐 65',
        referenceTime: DateTime.parse('2026-07-13T12:00:00+08:00'),
      ),
      throwsA(
        isA<ApiException>()
            .having((error) => error.code, 'code', 'ai_unavailable')
            .having((error) => error.retryable, 'retryable', isTrue)
            .having(
              (error) => error.toString(),
              'safe output',
              isNot(contains('request-2')),
            ),
      ),
    );
  });

  test('turns a stalled request into a retryable timeout', () async {
    final repository = ApiRepository(
      baseUri: Uri.parse('https://example.test/api/'),
      requestTimeout: const Duration(milliseconds: 5),
      client: MockClient((_) => Completer<http.Response>().future),
    );

    await expectLater(
      repository.getDashboard(),
      throwsA(
        isA<ApiException>()
            .having((error) => error.code, 'code', 'request_timeout')
            .having((error) => error.retryable, 'retryable', isTrue),
      ),
    );
  });

  test(
    'sends capture reference time with an explicit timezone offset',
    () async {
      final repository = ApiRepository(
        baseUri: Uri.parse('https://example.test/api'),
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(
            body['referenceTime'],
            matches(RegExp(r'(Z|[+-]\d{2}:\d{2})$')),
          );
          return http.Response(
            jsonEncode({
              'requestId': 'request-time',
              'data': {
                'drafts': [
                  {
                    'draftId': 'draft-time',
                    'type': 'expense',
                    'amountMinor': 65,
                    'currency': 'TWD',
                    'category': 'food',
                    'occurredAt': '2026-07-13T12:00:00+08:00',
                    'confidence': 0.9,
                    'missingFields': [],
                    'needsConfirmation': true,
                    'source': 'deterministic-demo',
                  },
                ],
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final result = await repository.parseCapture(
        '早餐 65',
        referenceTime: DateTime(2026, 7, 13, 12),
      );
      expect(result.drafts.single.amountMinor, 65);
    },
  );

  test(
    'builds subscription comparison from the recorded subscription',
    () async {
      final repository = ApiRepository(
        baseUri: Uri.parse('https://example.test/api'),
        client: MockClient((request) async {
          if (request.url.path.endsWith('/money-events')) {
            return http.Response(
              jsonEncode({
                'requestId': 'request-events',
                'data': [
                  {
                    'id': 'subscription-1',
                    'userId': 'demo-user',
                    'type': 'subscription',
                    'amountMinor': 480,
                    'currency': 'TWD',
                    'category': 'subscription',
                    'merchant': '合成音樂',
                    'occurredAt': '2026-07-13T12:00:00+08:00',
                    'recurrence': {'billingCycle': 'monthly'},
                    'split': {'participants': 4, 'userShareMinor': 120},
                    'createdAt': '2026-07-13T12:00:00+08:00',
                    'updatedAt': '2026-07-13T12:00:00+08:00',
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body, {
            'currentName': '合成音樂',
            'currentPriceMinor': 120,
            'currentBillingCycle': 'monthly',
            'members': 4,
            'isStudent': true,
          });
          return http.Response(
            jsonEncode({
              'requestId': 'request-comparison',
              'data': {
                'currentName': '合成音樂',
                'currentMonthlyCostMinor': 120,
                'options': <Object>[],
                'disclaimer': '合成資料',
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final comparison = await repository.compareSubscriptions();
      expect(comparison?.currentMonthlyCostMinor, 120);
    },
  );

  test('does not invent a current subscription for an empty ledger', () async {
    final repository = ApiRepository(
      baseUri: Uri.parse('https://example.test/api'),
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'requestId': 'empty-events', 'data': <Object>[]}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    expect(await repository.compareSubscriptions(), isNull);
  });

  test(
    'reuses the current completed lesson without generating another',
    () async {
      var postCalls = 0;
      final repository = ApiRepository(
        baseUri: Uri.parse('https://example.test/api'),
        client: MockClient((request) async {
          if (request.method == 'POST') postCalls += 1;
          return http.Response(
            jsonEncode({
              'requestId': 'request-current-lesson',
              'data': {
                'id': 'lesson-1',
                'title': '固定支出',
                'concept': '先看懂成本',
                'example': '每月比較',
                'question': '要先做什麼？',
                'options': ['先檢查訂閱', '繼續記錄'],
                'action': '七天後複盤',
                'disclaimer': '教育用途',
                'source': 'liangjie-ai',
                'selectedOption': '先檢查訂閱',
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final lesson = await repository.generateLesson();

      expect(lesson.selectedOption, '先檢查訂閱');
      expect(postCalls, 0);
    },
  );

  test('generates a lesson when no current lesson exists', () async {
    var postCalls = 0;
    final repository = ApiRepository(
      baseUri: Uri.parse('https://example.test/api'),
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'code': 'lesson_not_found',
              'message': '目前還沒有微課。',
              'retryable': false,
            }),
            404,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        postCalls += 1;
        return http.Response(
          jsonEncode({
            'requestId': 'request-new-lesson',
            'data': {
              'id': 'lesson-new',
              'title': '金錢選擇',
              'concept': '先看懂取捨',
              'example': '把需要與想要分開',
              'question': '要先檢查什麼？',
              'options': ['檢查固定支出', '繼續記錄'],
              'action': '完成可行選擇',
              'disclaimer': '教育用途',
              'source': 'liangjie-ai',
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final lesson = await repository.generateLesson();

    expect(lesson.id, 'lesson-new');
    expect(postCalls, 1);
  });
}
