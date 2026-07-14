import 'package:flutter/material.dart';

import '../auth/auth_api.dart';
import '../auth/auth_models.dart';
import '../auth/session_store.dart';
import '../core/future_mint_repository.dart';
import '../core/models.dart';
import '../data/api_repository.dart';
import 'app_controller.dart';

enum SessionStatus { loading, signedOut, onboarding, authenticated, guest }

typedef AuthenticatedRepositoryFactory =
    FutureMintRepository Function(String token);
typedef GuestRepositoryFactory = Future<FutureMintRepository> Function();

class SessionController extends ChangeNotifier {
  SessionController({
    required AuthGateway auth,
    required SessionPersistence store,
    required AuthenticatedRepositoryFactory authenticatedRepository,
    required GuestRepositoryFactory guestRepository,
  }) : _auth = auth,
       _store = store,
       _authenticatedRepository = authenticatedRepository,
       _guestRepository = guestRepository;

  final AuthGateway _auth;
  final SessionPersistence _store;
  final AuthenticatedRepositoryFactory _authenticatedRepository;
  final GuestRepositoryFactory _guestRepository;

  SessionStatus status = SessionStatus.loading;
  PublicAccount? account;
  AppController? app;
  String? message;
  String? _token;
  bool busy = false;

  bool get isGuest => status == SessionStatus.guest;

  String _messageFor(Object error) =>
      error is ApiException ? error.message : '目前無法完成操作，請稍後再試。';

  Future<void> start() async {
    _token = await _store.readToken();
    if (_token == null) {
      status = SessionStatus.signedOut;
      notifyListeners();
      return;
    }
    busy = true;
    notifyListeners();
    try {
      final restored = await _auth.me(_token!);
      await _activateAuthenticated(restored, _token!);
    } catch (error) {
      await _store.clearToken();
      _token = null;
      status = SessionStatus.signedOut;
      message = _messageFor(error);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> register({required String email, required String password}) =>
      _beginAuth(() => _auth.register(email: email, password: password));

  Future<bool> login({required String email, required String password}) =>
      _beginAuth(() => _auth.login(email: email, password: password));

  Future<bool> _beginAuth(Future<AuthSession> Function() action) async {
    busy = true;
    message = null;
    notifyListeners();
    try {
      final session = await action();
      _token = session.token;
      await _store.writeToken(session.token);
      await _activateAuthenticated(session.account, session.token);
      return true;
    } catch (error) {
      message = _messageFor(error);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _activateAuthenticated(
    PublicAccount nextAccount,
    String token,
  ) async {
    account = nextAccount;
    if (!nextAccount.profileComplete) {
      app = null;
      status = SessionStatus.onboarding;
      return;
    }
    final nextApp = AppController(
      repository: _authenticatedRepository(token),
      mode: AppMode.authenticated,
      accountEmail: nextAccount.email,
      onExit: logout,
    );
    await nextApp.initialize();
    if (!nextApp.initialized) {
      status = SessionStatus.signedOut;
      message = nextApp.errorMessage ?? '無法載入你的資料，請稍後再試。';
      return;
    }
    app = nextApp;
    status = SessionStatus.authenticated;
  }

  Future<bool> completeOnboarding(UserProfile profile) async {
    final token = _token;
    if (token == null || account == null) return false;
    busy = true;
    message = null;
    notifyListeners();
    final nextApp = AppController(
      repository: _authenticatedRepository(token),
      mode: AppMode.authenticated,
      accountEmail: account!.email,
      onExit: logout,
    );
    final saved = await nextApp.updateProfile(profile);
    busy = false;
    if (!saved) {
      message = nextApp.errorMessage ?? '預算與目標尚未保存。';
      notifyListeners();
      return false;
    }
    app = nextApp;
    account = account!.copyWith(profileComplete: true);
    status = SessionStatus.authenticated;
    notifyListeners();
    return true;
  }

  Future<void> continueAsGuest() async {
    busy = true;
    message = null;
    await _store.clearToken();
    _token = null;
    notifyListeners();
    try {
      final nextApp = AppController(
        repository: await _guestRepository(),
        mode: AppMode.guest,
        onExit: logout,
      );
      await nextApp.initialize();
      app = nextApp;
      account = null;
      status = SessionStatus.guest;
    } catch (error) {
      status = SessionStatus.signedOut;
      message = _messageFor(error);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final token = _token;
    busy = true;
    notifyListeners();
    try {
      if (token != null) await _auth.logout(token);
    } catch (_) {
      message = '已離開帳號；目前無法通知伺服器撤銷這次登入。';
    } finally {
      await _store.clearToken();
      _token = null;
      account = null;
      app = null;
      busy = false;
      status = SessionStatus.signedOut;
      notifyListeners();
    }
  }
}
