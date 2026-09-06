import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class SessionPersistence {
  Future<String?> readToken();
  Future<void> writeToken(String token);
  Future<void> clearToken();
}

abstract interface class SecureTokenPersistence {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class _SecureTokenStore implements SecureTokenPersistence {
  const _SecureTokenStore(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

class SessionStore implements SessionPersistence {
  SessionStore._({
    required this.preferences,
    required SecureTokenPersistence secureStore,
    required bool useWebStorage,
  }) : _secureStore = secureStore,
       _useWebStorage = useWebStorage;

  static const tokenKey = 'futuremint.session-token.v1';

  final SharedPreferences preferences;
  final SecureTokenPersistence _secureStore;
  final bool _useWebStorage;

  static Future<SessionStore> create({
    SharedPreferences? preferences,
    SecureTokenPersistence? secureStore,
    bool? useWebStorage,
  }) async => SessionStore._(
    preferences: preferences ?? await SharedPreferences.getInstance(),
    secureStore:
        secureStore ??
        const _SecureTokenStore(
          FlutterSecureStorage(
            aOptions: AndroidOptions(),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          ),
        ),
    useWebStorage: useWebStorage ?? kIsWeb,
  );

  @override
  Future<String?> readToken() async {
    if (_useWebStorage) return preferences.getString(tokenKey);

    final secured = await _secureStore.read(tokenKey);
    if (secured != null) {
      await preferences.remove(tokenKey);
      return secured;
    }

    // One-time migration for pre-Keychain native installs: remove the legacy
    // value only after Keychain has confirmed its write.
    final legacy = preferences.getString(tokenKey);
    if (legacy == null) return null;
    await _secureStore.write(tokenKey, legacy);
    await preferences.remove(tokenKey);
    return legacy;
  }

  @override
  Future<void> writeToken(String token) async {
    if (_useWebStorage) {
      await preferences.setString(tokenKey, token);
      return;
    }
    await _secureStore.write(tokenKey, token);
    await preferences.remove(tokenKey);
  }

  @override
  Future<void> clearToken() async {
    if (_useWebStorage) {
      await preferences.remove(tokenKey);
      return;
    }

    Object? secureError;
    try {
      await _secureStore.delete(tokenKey);
    } catch (error) {
      secureError = error;
    } finally {
      await preferences.remove(tokenKey);
    }
    if (secureError != null) throw secureError;
  }
}
