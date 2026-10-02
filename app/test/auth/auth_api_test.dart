import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/auth/auth_api.dart';
import 'package:futuremint_app/auth/service_policy.dart';
import 'package:futuremint_app/auth/session_store.dart';
import 'package:futuremint_app/data/api_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'in-app guardian consent sends only current policy and explicit declarations',
    () async {
      final api = AuthApi(
        baseUri: Uri.parse('https://api.test/api/'),
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/privacy/guardian-consent/in-app');
          expect(request.headers['authorization'], 'Bearer current-session');
          expect(jsonDecode(request.body), {
            'policyVersion': agePolicyVersion,
            'adult': true,
            'legalGuardian': true,
            'accepted': true,
          });
          return http.Response(
            jsonEncode({
              'data': {'canWrite': true},
            }),
            200,
          );
        }),
      );
      await api.confirmGuardianInApp('current-session');
    },
  );

  test(
    'verification resend and password reset use the expected request contract',
    () async {
      final paths = <String>[];
      final api = AuthApi(
        baseUri: Uri.parse('https://api.test/api/'),
        client: MockClient((request) async {
          paths.add(request.url.path);
          expect(request.method, 'POST');
          if (request.url.path.endsWith('email-verification/request')) {
            expect(request.headers['authorization'], 'Bearer current-session');
            expect(request.headers['content-type'], isNull);
            expect(request.body, isEmpty);
          } else {
            expect(jsonDecode(request.body), {'email': 'student@example.com'});
            expect(request.headers['authorization'], isNull);
          }
          return http.Response(
            jsonEncode({
              'data': {'accepted': true},
            }),
            200,
          );
        }),
      );
      await api.requestEmailVerification('current-session');
      await api.requestPasswordReset(email: 'student@example.com');
      expect(paths, [
        '/api/auth/email-verification/request',
        '/api/auth/password-reset/request',
      ]);
    },
  );

  test('register sends credentials and returns an opaque session', () async {
    final api = AuthApi(
      baseUri: Uri.parse('https://example.test/api/'),
      client: MockClient((request) async {
        expect(request.url.path, '/api/auth/register');
        expect(jsonDecode(request.body), {
          'email': 'student@example.com',
          'password': 'futuremint2026',
        });
        return http.Response(
          jsonEncode({
            'requestId': 'register-request',
            'data': {
              'token': 'a' * 43,
              'emailDeliveryPending': true,
              'account': {
                'id': 'account-1',
                'email': 'student@example.com',
                'profileComplete': false,
                'createdAt': '2026-07-14T00:00:00.000Z',
              },
            },
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final session = await api.register(
      email: 'student@example.com',
      password: 'futuremint2026',
    );

    expect(session.token, 'a' * 43);
    expect(session.emailDeliveryPending, isTrue);
    expect(session.account.email, 'student@example.com');
  });

  test('web session store persists only the token', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await SessionStore.create(useWebStorage: true);

    await store.writeToken('token-value');

    expect(await store.readToken(), 'token-value');
    expect(store.preferences.getKeys(), {SessionStore.tokenKey});
    await store.clearToken();
    expect(await store.readToken(), isNull);
  });

  test(
    'consent and deletion use the required authenticated HTTP methods',
    () async {
      final api = AuthApi(
        baseUri: Uri.parse('https://example.test/api/'),
        client: MockClient((request) async {
          expect(request.headers['authorization'], 'Bearer token-value');
          if (request.method == 'GET') {
            expect(request.url.path, '/api/privacy/ai-consent');
            return http.Response(
              jsonEncode({
                'requestId': 'consent-get',
                'data': {
                  'granted': false,
                  'policyVersion': '2026-08-30',
                  'grantedAt': null,
                  'withdrawnAt': null,
                },
              }),
              200,
            );
          }
          if (request.method == 'PUT') {
            expect(request.url.path, '/api/privacy/ai-consent');
            expect(jsonDecode(request.body), {'granted': true});
            return http.Response(
              jsonEncode({
                'requestId': 'consent-put',
                'data': {
                  'granted': true,
                  'policyVersion': '2026-08-30',
                  'grantedAt': '2026-08-30T00:00:00.000Z',
                  'withdrawnAt': null,
                },
              }),
              200,
            );
          }
          expect(request.method, 'DELETE');
          expect(request.url.path, '/api/auth/account');
          expect(jsonDecode(request.body), {'password': 'current-pass'});
          return http.Response(
            jsonEncode({'requestId': 'account-delete', 'data': {}}),
            200,
          );
        }),
      );

      final current = await api.getAiConsent('token-value');
      final updated = await api.updateAiConsent(
        token: 'token-value',
        granted: true,
      );
      await api.deleteAccount(token: 'token-value', password: 'current-pass');

      expect(current.granted, isFalse);
      expect(updated.granted, isTrue);
    },
  );

  test('invalid credentials retain their password-specific message', () async {
    final api = AuthApi(
      baseUri: Uri.parse('https://example.test/api/'),
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'requestId': 'wrong-password',
            'code': 'invalid_credentials',
            'message': '電子郵件或密碼不正確。',
            'retryable': false,
          }),
          401,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    expect(
      () => api.deleteAccount(token: 'token-value', password: 'wrong-pass'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          '電子郵件或密碼不正確。',
        ),
      ),
    );
  });
}
