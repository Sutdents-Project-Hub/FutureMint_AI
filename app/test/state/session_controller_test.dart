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
  Object? consentError;
  Object? deleteError;
  String? deletedPassword;
  AiConsentStatus consent = const AiConsentStatus.notGranted();

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
  Future<void> deleteAccount({
    required String token,
    required String password,
  }) async {
    if (deleteError != null) throw deleteError!;
    deletedPassword = password;
  }

  @override
  Future<AiConsentStatus> getAiConsent(String token) async {
    if (consentError != null) throw consentError!;
    return consent;
  }

  @override
  Future<AiConsentStatus> updateAiConsent({
    required String token,
    required bool granted,
  }) async {
    consent = AiConsentStatus(granted: granted, policyVersion: 'test');
    return consent;
  }

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

  test(
    'deleting an account clears local session without logging out again',
    () async {
      final repository = await GuestRepository.create();
      final signedInAuth = FakeAuthGateway(session(profileComplete: true));
      final signedIn = SessionController(
        auth: signedInAuth,
        store: store,
        authenticatedRepository: (_) => repository,
        guestRepository: GuestRepository.create,
      );

      await signedIn.login(
        email: 'student@example.com',
        password: 'current-pass',
      );
      expect(signedIn.status, SessionStatus.authenticated);

      final deleted = await signedIn.app!.deleteAccount('current-pass');

      expect(deleted, isTrue);
      expect(signedInAuth.deletedPassword, 'current-pass');
      expect(signedIn.status, SessionStatus.signedOut);
      expect(await store.readToken(), isNull);
      expect(signedIn.app, isNull);
    },
  );

  test(
    'loads the server consent before exposing an authenticated app',
    () async {
      final repository = await GuestRepository.create();
      final signedInAuth = FakeAuthGateway(session(profileComplete: true))
        ..consent = AiConsentStatus(granted: true, policyVersion: '2026-08-30');
      final signedIn = SessionController(
        auth: signedInAuth,
        store: store,
        authenticatedRepository: (_) => repository,
        guestRepository: GuestRepository.create,
      );

      await signedIn.login(
        email: 'student@example.com',
        password: 'current-pass',
      );

      expect(signedIn.status, SessionStatus.authenticated);
      expect(signedIn.app!.aiConsent.granted, isTrue);
    },
  );

  test(
    'expires a restored session when consent lookup is unauthorized',
    () async {
      store.token = 'a' * 43;
      auth = FakeAuthGateway(session(profileComplete: true))
        ..consentError = const ApiException(
          code: 'unauthorized',
          message: '登入已過期，請重新登入。',
          retryable: false,
        );
      controller = SessionController(
        auth: auth,
        store: store,
        authenticatedRepository: (_) => throw UnimplementedError(),
        guestRepository: GuestRepository.create,
      );

      await controller.start();

      expect(controller.status, SessionStatus.signedOut);
      expect(await store.readToken(), isNull);
    },
  );

  test('a wrong delete password keeps the local session', () async {
    final repository = await GuestRepository.create();
    final signedInAuth = FakeAuthGateway(session(profileComplete: true))
      ..deleteError = const ApiException(
        code: 'invalid_credentials',
        message: '電子郵件或密碼不正確。',
        retryable: false,
      );
    final signedIn = SessionController(
      auth: signedInAuth,
      store: store,
      authenticatedRepository: (_) => repository,
      guestRepository: GuestRepository.create,
    );

    await signedIn.login(
      email: 'student@example.com',
      password: 'current-pass',
    );
    final deleted = await signedIn.app!.deleteAccount('wrong-pass');

    expect(deleted, isFalse);
    expect(signedIn.status, SessionStatus.authenticated);
    expect(await store.readToken(), 'a' * 43);
    expect(signedIn.app!.errorMessage, '電子郵件或密碼不正確。');
  });
}
