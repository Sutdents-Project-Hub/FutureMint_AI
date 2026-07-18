import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/auth/auth_api.dart';
import 'package:futuremint_app/auth/session_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('register sends credentials and returns an opaque session', () async {
    final api = AuthApi(
      baseUri: Uri.parse('https://example.test/api/'),
      client: MockClient((request) async {
        expect(request.url.path, '/api/auth/register');
        expect(jsonDecode(request.body), {
          'email': 'student@example.com',
          'password': 'futuremint202',
        });
        return http.Response(
          jsonEncode({
            'requestId': 'register-request',
            'data': {
              'token': 'a' * 43,
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
    expect(session.account.email, 'student@example.com');
  });

  test('session store persists only the token', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await SessionStore.create();

    await store.writeToken('token-value');

    expect(await store.readToken(), 'token-value');
    expect(store.preferences.getKeys(), {SessionStore.tokenKey});
    await store.clearToken();
    expect(await store.readToken(), isNull);
  });
}
