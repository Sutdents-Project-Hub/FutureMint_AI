import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/auth/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SecureStore implements SecureTokenPersistence {
  String? value;
  bool failWrite = false;
  @override
  Future<String?> read(String key) async => value;
  @override
  Future<void> write(String key, String value) async {
    if (failWrite) throw StateError('keychain unavailable');
    this.value = value;
  }

  @override
  Future<void> delete(String key) async => value = null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'native token migration removes preferences only after secure write',
    () async {
      SharedPreferences.setMockInitialValues({SessionStore.tokenKey: 'legacy'});
      final preferences = await SharedPreferences.getInstance();
      final secure = _SecureStore()..failWrite = true;
      final store = await SessionStore.create(
        preferences: preferences,
        secureStore: secure,
        useWebStorage: false,
      );
      await expectLater(store.readToken(), throwsStateError);
      expect(preferences.getString(SessionStore.tokenKey), 'legacy');
      secure.failWrite = false;
      expect(await store.readToken(), 'legacy');
      expect(secure.value, 'legacy');
      expect(preferences.getString(SessionStore.tokenKey), isNull);
      await store.clearToken();
      expect(secure.value, isNull);
    },
  );
  test(
    'native writes use secure storage while web retains browser persistence',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final secure = _SecureStore();
      final native = await SessionStore.create(
        preferences: preferences,
        secureStore: secure,
        useWebStorage: false,
      );
      await native.writeToken('native');
      expect(secure.value, 'native');
      expect(preferences.containsKey(SessionStore.tokenKey), isFalse);
      final web = await SessionStore.create(
        preferences: preferences,
        secureStore: secure,
        useWebStorage: true,
      );
      await web.writeToken('browser');
      expect(await web.readToken(), 'browser');
      expect(secure.value, 'native');
    },
  );
}
