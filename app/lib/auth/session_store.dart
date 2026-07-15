import 'package:shared_preferences/shared_preferences.dart';

abstract interface class SessionPersistence {
  Future<String?> readToken();
  Future<void> writeToken(String token);
  Future<void> clearToken();
}

class SessionStore implements SessionPersistence {
  SessionStore._(this.preferences);

  static const tokenKey = 'futuremint.session-token.v1';

  final SharedPreferences preferences;

  static Future<SessionStore> create() async =>
      SessionStore._(await SharedPreferences.getInstance());

  @override
  Future<String?> readToken() async => preferences.getString(tokenKey);

  @override
  Future<void> writeToken(String token) =>
      preferences.setString(tokenKey, token);

  @override
  Future<void> clearToken() => preferences.remove(tokenKey);
}
