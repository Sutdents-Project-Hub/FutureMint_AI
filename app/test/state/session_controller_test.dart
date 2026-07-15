import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/auth/auth_api.dart';
import 'package:futuremint_app/auth/auth_models.dart';
import 'package:futuremint_app/auth/session_store.dart';
import 'package:futuremint_app/data/api_repository.dart';
import 'package:futuremint_app/data/guest_repository.dart';
import 'package:futuremint_app/state/session_controller.dart';

class FakeStore implements SessionPersistence {
  String? token;

  @override
  Future<void> clearToken() async => token = null;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> writeToken(String value) async => token = value;
}

class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway(this.result);

  AuthSession result;
  Object? meError;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async => result;

  @override
  Future<PublicAccount> me(String token) async {
    if (meError != null) throw meError!;
    return result.account;
  }

  @override
  Future<void> logout(String token) async {}

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
  }) async => result;
}

AuthSession session({bool profileComplete = false}) => AuthSession(
  token: 'a' * 43,
  account: PublicAccount(
    id: 'account-1',
    email: 'student@example.com',
    profileComplete: profileComplete,
    createdAt: DateTime.parse('2026-07-14T00:00:00Z'),
  ),
);

void main() {
  late FakeStore store;
  late FakeAuthGateway auth;
  late SessionController controller;

  setUp(() {
    store = FakeStore();
    auth = FakeAuthGateway(session());
    controller = SessionController(
      auth: auth,
      store: store,
      authenticatedRepository: (_) => throw UnimplementedError(),
      guestRepository: GuestRepository.create,
    );
  });

  test('registering an account without a profile enters onboarding', () async {
    final succeeded = await controller.register(
      email: 'student@example.com',
      password: 'futuremint2026',
    );

    expect(succeeded, isTrue);
    expect(controller.status, SessionStatus.onboarding);
    expect(await store.readToken(), 'a' * 43);
  });

  test('guest mode never writes a session token', () async {
    await controller.continueAsGuest();

    expect(controller.status, SessionStatus.guest);
    expect(await store.readToken(), isNull);
  });

  test('keeps a saved session after a retryable restoration failure', () async {
    store.token = 'a' * 43;
    auth.meError = const ApiException(
      code: 'network_error',
      message: '連不上服務，請檢查網路後再試一次。',
      retryable: true,
    );

    await controller.start();

    expect(controller.status, SessionStatus.restorationFailed);
    expect(await store.readToken(), 'a' * 43);
  });

  test(
    'clears a saved session only after the server rejects its token',
    () async {
      store.token = 'a' * 43;
      auth.meError = const ApiException(
        code: 'unauthorized',
        message: '登入已過期，請重新登入。',
        retryable: false,
      );

      await controller.start();

      expect(controller.status, SessionStatus.signedOut);
      expect(await store.readToken(), isNull);
    },
  );
}
