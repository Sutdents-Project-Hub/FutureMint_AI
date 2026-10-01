import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/api_repository.dart';
import 'auth_models.dart';
import 'service_policy.dart';

abstract class AuthGateway {
  Future<AuthSession> registerWithAge({
    required String email,
    required String password,
    required String ageBand,
  }) => register(email: email, password: password);
  Future<ServicePolicy?> getServicePolicy() async => null;
  Future<EligibilityStatus?> getEligibility(String token) async => null;
  Future<void> declareAge(String token, String ageBand) async =>
      throw UnimplementedError();
  Future<void> requestGuardian(String token, String email) async =>
      throw UnimplementedError();
  Future<void> withdrawGuardian(String token) async =>
      throw UnimplementedError();
  Future<AiConsentStatus> updateVersionedAiConsent({
    required String token,
    required bool granted,
    String? policyVersion,
  }) => updateAiConsent(token: token, granted: granted);

  Future<AuthSession> register({
    required String email,
    required String password,
  });
  Future<AuthSession> login({required String email, required String password});
  Future<PublicAccount> me(String token);
  Future<void> logout(String token);
  Future<AiConsentStatus> getAiConsent(String token);
  Future<AiConsentStatus> updateAiConsent({
    required String token,
    required bool granted,
  });
  Future<void> deleteAccount({required String token, required String password});

  Future<void> requestEmailVerification(String token) async =>
      throw UnimplementedError();

  Future<void> requestPasswordReset({required String email}) async =>
      throw UnimplementedError();
}

class AuthApi implements AuthGateway {
  AuthApi({
    required this.baseUri,
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 12),
  }) : _client = client ?? http.Client();

  final Uri baseUri;
  final http.Client _client;
  final Duration requestTimeout;

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

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    String? token,
  }) async {
    late http.Response response;
    try {
      final headers = <String, String>{
        if (body != null) 'content-type': 'application/json',
        if (token != null) 'authorization': 'Bearer $token',
      };
      final encoded = body == null ? null : jsonEncode(body);
      final request = switch (method) {
        'GET' => _client.get(_uri(path), headers: headers),
        'POST' => _client.post(_uri(path), headers: headers, body: encoded),
        'PUT' => _client.put(_uri(path), headers: headers, body: encoded),
        'DELETE' => _client.delete(_uri(path), headers: headers, body: encoded),
        _ => throw ArgumentError.value(
          method,
          'method',
          'Unsupported HTTP method',
        ),
      };
      response = await request.timeout(requestTimeout);
    } on TimeoutException {
      throw const ApiException(
        code: 'request_timeout',
        message: '連不上服務，請檢查網路後再試一次。',
        retryable: true,
      );
    } on http.ClientException {
      throw const ApiException(
        code: 'network_error',
        message: '連不上服務，請檢查網路後再試一次。',
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
      final code = decoded['code'] as String? ?? 'request_failed';
      throw ApiException(
        code: code,
        message: code == 'invalid_credentials'
            ? decoded['message'] as String? ?? '電子郵件或密碼不正確。'
            : response.statusCode == 401
            ? '登入已過期，請重新登入。'
            : decoded['message'] as String? ?? '目前無法完成請求。',
        retryable: decoded['retryable'] as bool? ?? false,
      );
    }
    return decoded['data'];
  }

  @override
  Future<AuthSession> registerWithAge({
    required String email,
    required String password,
    required String ageBand,
  }) async => AuthSession.fromJson(
    await _send(
          'POST',
          'auth/register',
          body: {
            'email': email,
            'password': password,
            'ageDeclaration': {
              'ageBand': ageBand,
              'policyVersion': agePolicyVersion,
              'accepted': true,
            },
          },
        )
        as Map<String, dynamic>,
  );
  @override
  Future<ServicePolicy?> getServicePolicy() async => ServicePolicy.fromJson(
    await _send('GET', 'service-policy') as Map<String, dynamic>,
  );
  @override
  Future<EligibilityStatus?> getEligibility(String token) async =>
      EligibilityStatus.fromJson(
        await _send('GET', 'privacy/eligibility', token: token)
            as Map<String, dynamic>,
      );
  @override
  Future<void> declareAge(String token, String ageBand) async {
    await _send(
      'PUT',
      'privacy/age-declaration',
      token: token,
      body: {
        'ageBand': ageBand,
        'policyVersion': agePolicyVersion,
        'accepted': true,
      },
    );
  }

  @override
  Future<void> requestGuardian(String token, String email) async {
    await _send(
      'POST',
      'privacy/guardian-consent/request',
      token: token,
      body: {'email': email},
    );
  }

  @override
  Future<void> withdrawGuardian(String token) async {
    await _send('DELETE', 'privacy/guardian-consent', token: token);
  }

  @override
  Future<AiConsentStatus> updateVersionedAiConsent({
    required String token,
    required bool granted,
    String? policyVersion,
  }) async => AiConsentStatus.fromJson(
    await _send(
          'PUT',
          'privacy/ai-consent',
          token: token,
          body: {
            'granted': granted,
            if (granted) 'policyVersion': policyVersion,
          },
        )
        as Map<String, dynamic>,
  );

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
  }) async => AuthSession.fromJson(
    await _send(
          'POST',
          'auth/register',
          body: {'email': email, 'password': password},
        )
        as Map<String, dynamic>,
  );

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async => AuthSession.fromJson(
    await _send(
          'POST',
          'auth/login',
          body: {'email': email, 'password': password},
        )
        as Map<String, dynamic>,
  );

  @override
  Future<PublicAccount> me(String token) async => PublicAccount.fromJson(
    await _send('GET', 'auth/me', token: token) as Map<String, dynamic>,
  );

  @override
  Future<void> logout(String token) async {
    await _send('POST', 'auth/logout', body: const {}, token: token);
  }

  @override
  Future<AiConsentStatus> getAiConsent(String token) async =>
      AiConsentStatus.fromJson(
        await _send('GET', 'privacy/ai-consent', token: token)
            as Map<String, dynamic>,
      );

  @override
  Future<AiConsentStatus> updateAiConsent({
    required String token,
    required bool granted,
  }) async => AiConsentStatus.fromJson(
    await _send(
          'PUT',
          'privacy/ai-consent',
          token: token,
          body: {'granted': granted},
        )
        as Map<String, dynamic>,
  );

  @override
  Future<void> deleteAccount({
    required String token,
    required String password,
  }) async {
    await _send(
      'DELETE',
      'auth/account',
      token: token,
      body: {'password': password},
    );
  }

  @override
  Future<void> requestEmailVerification(String token) async {
    await _send('POST', 'auth/email-verification/request', token: token);
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    await _send('POST', 'auth/password-reset/request', body: {'email': email});
  }
}
