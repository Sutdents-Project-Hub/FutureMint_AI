import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/api_repository.dart';
import 'auth_models.dart';

abstract interface class AuthGateway {
  Future<AuthSession> register({
    required String email,
    required String password,
  });
  Future<AuthSession> login({required String email, required String password});
  Future<PublicAccount> me(String token);
  Future<void> logout(String token);
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
        'content-type': 'application/json',
        if (token != null) 'authorization': 'Bearer $token',
      };
      final encoded = body == null ? null : jsonEncode(body);
      final request = switch (method) {
        'GET' => _client.get(_uri(path), headers: headers),
        _ => _client.post(_uri(path), headers: headers, body: encoded),
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
}
