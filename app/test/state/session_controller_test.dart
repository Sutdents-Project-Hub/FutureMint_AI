import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/auth/auth_api.dart';
import 'package:futuremint_app/auth/auth_models.dart';
import 'package:futuremint_app/auth/session_store.dart';
import 'package:futuremint_app/data/api_repository.dart';
import 'package:futuremint_app/data/guest_repository.dart';
import 'package:futuremint_app/state/session_controller.dart';
import 'package:futuremint_app/reminders/subscription_reminders.dart';

class FakeStore implements SessionPersistence {
  String? token;
  Completer<void>? writeGate;
  Completer<void>? writeStarted;
  Object? readError;

  @override
  Future<void> clearToken() async => token = null;

  @override
  Future<String?> readToken() async {
    if (readError != null) throw readError!;
    return token;
  }

  @override
  Future<void> writeToken(String value) async {
    final gate = writeGate;
    writeGate = null;
    writeStarted?.complete();
    writeStarted = null;
    if (gate != null) await gate.future;
    token = value;
  }
}

class FakeAuthGateway extends AuthGateway {
  FakeAuthGateway(this.result);

  AuthSession result;
  Object? meError;
  Object? consentError;
  Object? deleteError;
  String? deletedPassword;
  Completer<void>? logoutGate;
  int verificationRequests = 0;
  String? resetEmail;

  @override
  Future<void> requestEmailVerification(String token) async {
    verificationRequests++;
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    resetEmail = email;
  }

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
  Future<void> logout(String token) async {
    await logoutGate?.future;
  }

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
      reminders: SubscriptionReminders(supported: false),
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
        reminders: SubscriptionReminders(supported: false),
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
        reminders: SubscriptionReminders(supported: false),
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
        reminders: SubscriptionReminders(supported: false),
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
      reminders: SubscriptionReminders(supported: false),
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
  test(
    'onboarding consent rejection always clears busy and returns to sign-in',
    () async {
      await controller.login(
        email: 'student@example.com',
        password: 'current-pass',
      );
      auth.consentError = const ApiException(
        code: 'unauthorized',
        message: 'expired',
        retryable: false,
      );
      final repository = await GuestRepository.create();
      final result = await controller.completeOnboarding(
        await repository.getProfile(),
      );
      expect(result, isFalse);
      expect(controller.status, SessionStatus.signedOut);
      expect(controller.busy, isFalse);
      expect(store.token, isNull);
    },
  );

  test(
    'a stale account unauthorized callback cannot clear a newer login',
    () async {
      final repository = await GuestRepository.create();
      auth.result = session(profileComplete: true);
      final signedIn = SessionController(
        auth: auth,
        store: store,
        authenticatedRepository: (_) => repository,
        guestRepository: GuestRepository.create,
        reminders: SubscriptionReminders(supported: false),
      );
      await signedIn.login(
        email: 'student@example.com',
        password: 'current-pass',
      );
      final oldUnauthorized = signedIn.app!.onUnauthorized!;
      auth.result = AuthSession(token: 'b' * 43, account: session().account);
      await signedIn.login(
        email: 'other@example.com',
        password: 'current-pass',
      );
      await oldUnauthorized();
      expect(store.token, 'b' * 43);
      expect(signedIn.status, SessionStatus.onboarding);
      expect(signedIn.busy, isFalse);
    },
  );

  test(
    'delayed logout response cannot remove a newer session from storage',
    () async {
      await controller.login(
        email: 'student@example.com',
        password: 'current-pass',
      );
      auth.logoutGate = Completer<void>();
      final loggingOut = controller.logout();
      auth.result = AuthSession(token: 'b' * 43, account: session().account);
      await controller.login(
        email: 'other@example.com',
        password: 'current-pass',
      );
      auth.logoutGate!.complete();
      await loggingOut;
      expect(store.token, 'b' * 43);
      expect(controller.status, SessionStatus.onboarding);
    },
  );

  test(
    'overlapping slow native writes finish with the newest login persisted',
    () async {
      final gate = Completer<void>();
      final started = Completer<void>();
      store.writeGate = gate;
      store.writeStarted = started;
      final first = controller.login(
        email: 'student@example.com',
        password: 'current-pass',
      );
      await started.future;
      auth.result = AuthSession(token: 'b' * 43, account: session().account);
      final second = controller.login(
        email: 'other@example.com',
        password: 'current-pass',
      );
      gate.complete();
      expect(await first, isFalse);
      expect(await second, isTrue);
      expect(store.token, 'b' * 43);
    },
  );

  test(
    'failed deletion preserves the current app session-expiry callback',
    () async {
      final repository = await GuestRepository.create();
      auth.result = session(profileComplete: true);
      auth.deleteError = const ApiException(
        code: 'invalid_credentials',
        message: 'wrong',
        retryable: false,
      );
      final signedIn = SessionController(
        auth: auth,
        store: store,
        authenticatedRepository: (_) => repository,
        guestRepository: GuestRepository.create,
        reminders: SubscriptionReminders(supported: false),
      );
      await signedIn.login(
        email: 'student@example.com',
        password: 'current-pass',
      );
      final app = signedIn.app!;
      expect(await app.deleteAccount('wrong'), isFalse);
      await app.onUnauthorized!();
      expect(signedIn.status, SessionStatus.signedOut);
      expect(store.token, isNull);
    },
  );

  test(
    'verification gate blocks profile loading and supports resend and refresh',
    () async {
      auth.result = AuthSession(
        token: 'a' * 43,
        account: session().account.copyWith(verificationRequired: true),
      );
      expect(
        await controller.register(
          email: 'student@example.com',
          password: 'current-pass',
        ),
        isTrue,
      );
      expect(controller.status, SessionStatus.verificationRequired);
      expect(controller.app, isNull);
      expect(await controller.requestEmailVerification(), isTrue);
      expect(auth.verificationRequests, 1);
      expect(await controller.refreshEmailVerification(), isFalse);
      auth.result = AuthSession(
        token: auth.result.token,
        account: auth.result.account.copyWith(emailVerified: true),
      );
      expect(await controller.refreshEmailVerification(), isTrue);
      expect(controller.status, SessionStatus.onboarding);
      expect(controller.busy, isFalse);
    },
  );

  test(
    'password reset displays generic acceptance and normalizes whitespace',
    () async {
      await controller.start();
      expect(
        await controller.requestPasswordReset(' student@example.com '),
        isTrue,
      );
      expect(auth.resetEmail, 'student@example.com');
      expect(controller.notice, contains('若此電子郵件可用'));
      expect(controller.busy, isFalse);
    },
  );

  test(
    'storage read errors leave loading with a retryable recovery screen',
    () async {
      store.readError = StateError('secure storage unavailable');
      await controller.start();
      expect(controller.status, SessionStatus.restorationFailed);
      expect(controller.busy, isFalse);
      expect(controller.message, contains('重試'));
    },
  );
  test(
    'registration delivery failure preserves the account and explains how to resend',
    () async {
      auth.result = AuthSession(
        token: 'a' * 43,
        account: session().account.copyWith(verificationRequired: true),
        emailDeliveryPending: true,
      );
      expect(
        await controller.register(
          email: 'student@example.com',
          password: 'current-pass',
        ),
        isTrue,
      );
      expect(controller.status, SessionStatus.verificationRequired);
      expect(controller.message, contains('驗證信暫時無法寄出'));
      expect(controller.message, contains('重新寄驗證信'));
      expect(store.token, 'a' * 43);
      expect(controller.busy, isFalse);
      expect(await controller.requestEmailVerification(), isTrue);
      expect(controller.message, isNull);
      expect(controller.notice, contains('驗證信已寄出'));
    },
  );
}
