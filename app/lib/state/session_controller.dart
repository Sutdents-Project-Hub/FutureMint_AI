import 'package:flutter/material.dart';

import '../auth/auth_api.dart';
import '../auth/auth_models.dart';
import '../auth/session_store.dart';
import '../core/future_mint_repository.dart';
import '../core/models.dart';
import '../data/api_repository.dart';
import 'app_controller.dart';
import '../auth/service_policy.dart';
import '../reminders/subscription_reminders.dart';

enum SessionStatus {
  loading,
  signedOut,
  restorationFailed,
  verificationRequired,
  onboarding,
  eligibilityRequired,
  authenticated,
  guest,
}

typedef AuthenticatedRepositoryFactory =
    FutureMintRepository Function(String token);
typedef GuestRepositoryFactory = Future<FutureMintRepository> Function();

class SessionController extends ChangeNotifier {
  SessionController({
    required AuthGateway auth,
    required SessionPersistence store,
    required AuthenticatedRepositoryFactory authenticatedRepository,
    required GuestRepositoryFactory guestRepository,
    SubscriptionReminders? reminders,
  }) : _auth = auth,
       _store = store,
       _authenticatedRepository = authenticatedRepository,
       _guestRepository = guestRepository,
       reminders = reminders ?? SubscriptionReminders();

  final AuthGateway _auth;
  final SessionPersistence _store;
  final AuthenticatedRepositoryFactory _authenticatedRepository;
  final GuestRepositoryFactory _guestRepository;

  final SubscriptionReminders reminders;
  ServicePolicy? servicePolicy;
  EligibilityStatus? eligibility;
  SessionStatus status = SessionStatus.loading;
  PublicAccount? account;
  AppController? app;
  String? message;
  String? notice;
  String? _token;
  bool busy = false;
  int _epoch = 0;
  bool _disposed = false;
  Future<void> _persistenceQueue = Future<void>.value();

  // Serialize platform writes and check ownership when an operation starts.
  Future<void> _persist(int epoch, Future<void> Function() action) {
    final pending = _persistenceQueue.then((_) async {
      if (_isCurrent(epoch)) await action();
    });
    _persistenceQueue = pending.then<void>((_) {}, onError: (Object _) {});
    return pending;
  }

  bool get isGuest => status == SessionStatus.guest;
  bool get hasActiveToken => _token != null;
  bool get needsEmailVerification =>
      account?.verificationRequired == true && account?.emailVerified != true;

  bool _isCurrent(int epoch, [String? token]) =>
      !_disposed && epoch == _epoch && (token == null || token == _token);

  int _beginTransition() => ++_epoch;

  void _notifyListeners() {
    if (!_disposed) notifyListeners();
  }

  void _disposeApp() {
    final previous = app;
    app = null;
    previous?.dispose();
  }

  @override
  void dispose() {
    _disposed = true;
    _beginTransition();
    _disposeApp();
    super.dispose();
  }

  String _messageFor(Object error) =>
      error is ApiException ? error.message : '目前無法完成操作，請稍後再試。';

  bool _isExpiredSession(Object error) =>
      error is ApiException && error.code == 'unauthorized';

  Future<void> start() async {
    final epoch = _beginTransition();
    busy = true;
    message = null;
    _notifyListeners();
    String? storedToken;
    try {
      await _persist(epoch, () async {
        storedToken = await _store.readToken();
      });
    } catch (error) {
      if (!_isCurrent(epoch)) return;
      status = SessionStatus.restorationFailed;
      busy = false;
      message = '無法讀取裝置上的登入資訊，請重試。';
      _notifyListeners();
      return;
    }
    if (!_isCurrent(epoch)) return;
    final token = storedToken;
    _token = token;
    if (token == null) {
      busy = false;
      status = SessionStatus.signedOut;
      _notifyListeners();
      await _loadSignedOutPolicy(epoch);
      return;
    }
    busy = true;
    _notifyListeners();
    try {
      final restored = await _auth.me(token);
      if (!_isCurrent(epoch, token)) return;
      await _activateAuthenticated(restored, token, epoch);
    } catch (error) {
      if (!_isCurrent(epoch, token)) return;
      if (_isExpiredSession(error)) {
        await _expireSessionFor(token, epoch);
      } else {
        status = SessionStatus.restorationFailed;
        message = _messageFor(error);
      }
    } finally {
      if (_isCurrent(epoch, token)) {
        busy = false;
        _notifyListeners();
      }
    }
  }

  Future<void> _loadSignedOutPolicy(int epoch) async {
    try {
      final policy = await _auth.getServicePolicy();
      if (!_isCurrent(epoch) || status != SessionStatus.signedOut) return;
      servicePolicy = policy;
      _notifyListeners();
    } catch (_) {
      // Public capability lookup does not prevent sign-in or guest access.
      // The API remains authoritative if this request fails.
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    String? ageBand,
  }) => _beginAuth(
    () => ageBand == null
        ? _auth.register(email: email, password: password)
        : _auth.registerWithAge(
            email: email,
            password: password,
            ageBand: ageBand,
          ),
  );

  Future<bool> login({required String email, required String password}) =>
      _beginAuth(() => _auth.login(email: email, password: password));

  Future<bool> _beginAuth(Future<AuthSession> Function() action) async {
    final epoch = _beginTransition();
    busy = true;
    message = null;
    notice = null;
    _notifyListeners();
    try {
      final session = await action();
      if (!_isCurrent(epoch)) return false;
      _token = session.token;
      await _persist(epoch, () => _store.writeToken(session.token));
      if (!_isCurrent(epoch, session.token)) return false;
      await _activateAuthenticated(session.account, session.token, epoch);
      if (_isCurrent(epoch, session.token) &&
          status == SessionStatus.verificationRequired &&
          session.emailDeliveryPending) {
        message = '帳號已建立，但驗證信暫時無法寄出。請點「重新寄驗證信」再試一次。';
      }
      return _isCurrent(epoch, session.token) &&
          (status == SessionStatus.eligibilityRequired ||
              status == SessionStatus.verificationRequired ||
              status == SessionStatus.onboarding ||
              status == SessionStatus.authenticated);
    } catch (error) {
      if (!_isCurrent(epoch)) return false;
      if (_isExpiredSession(error)) {
        await _expireSessionFor(_token, epoch);
      } else {
        message = _messageFor(error);
      }
      return false;
    } finally {
      if (_isCurrent(epoch)) {
        busy = false;
        _notifyListeners();
      }
    }
  }

  Future<void> _activateAuthenticated(
    PublicAccount nextAccount,
    String token,
    int epoch, {
    bool readOnly = false,
  }) async {
    if (!_isCurrent(epoch, token)) return;
    account = nextAccount;
    if (nextAccount.verificationRequired && !nextAccount.emailVerified) {
      _disposeApp();
      status = SessionStatus.verificationRequired;
      return;
    }
    servicePolicy = await _auth.getServicePolicy();
    if (!_isCurrent(epoch, token)) return;
    eligibility = await _auth.getEligibility(token);
    if (!_isCurrent(epoch, token)) return;
    if (!readOnly &&
        servicePolicy?.eligibilityRequired != false &&
        eligibility != null &&
        !eligibility!.canWrite) {
      await _clearReminders();
      _disposeApp();
      status = SessionStatus.eligibilityRequired;
      return;
    }
    if (!nextAccount.profileComplete) {
      _disposeApp();
      status = SessionStatus.onboarding;
      return;
    }
    final aiConsent = await _loadAiConsent(token);
    if (!_isCurrent(epoch, token)) return;
    final nextApp = AppController(
      repository: _authenticatedRepository(token),
      mode: AppMode.authenticated,
      accountEmail: nextAccount.email,
      intentOwner: nextAccount.id,
      intentStore: _store is PendingIntentPersistence
          ? _store as PendingIntentPersistence
          : null,
      onExit: () => _logoutFor(token, epoch),
      onUnauthorized: () => _expireSessionFor(token, epoch),
      aiConsent: readOnly ? const AiConsentStatus.notGranted() : aiConsent,
      canWrite: !readOnly,
      onViewEligibility: showEligibility,
      servicePolicy: servicePolicy,
      reminders: reminders,
      onGuardianWithdrawn:
          eligibility?.ageBand == '15-17' &&
              eligibility?.guardianStatus == 'approved'
          ? withdrawGuardian
          : null,
      onEligibilityChanged: () async {
        await refreshEligibility();
      },
      onAiConsentChanged: (granted) => _auth.updateVersionedAiConsent(
        token: token,
        granted: granted,
        policyVersion: servicePolicy?.aiPolicyVersion,
      ),
      onDeleteAccount: (password) => _deleteAccountFor(token, epoch, password),
    );
    if (readOnly) {
      await _clearReminders();
    } else {
      await reminders.bind(nextAccount.id);
    }
    if (!_isCurrent(epoch, token)) {
      nextApp.dispose();
      return;
    }
    try {
      await nextApp.restorePendingIntents();
      await nextApp.initialize();
    } catch (_) {
      nextApp.dispose();
      rethrow;
    }
    if (!_isCurrent(epoch, token)) {
      nextApp.dispose();
      return;
    }
    if (!nextApp.initialized) {
      nextApp.dispose();
      status = SessionStatus.restorationFailed;
      message = nextApp.errorMessage ?? '無法載入你的資料，請稍後再試。';
      return;
    }
    _disposeApp();
    app = nextApp;
    status = SessionStatus.authenticated;
  }

  Future<bool> completeOnboarding(UserProfile profile) async {
    final token = _token;
    if (token == null || account == null) return false;
    final epoch = _epoch;
    final nextAccount = account!;
    busy = true;
    message = null;
    _notifyListeners();
    AppController? nextApp;
    try {
      final aiConsent = await _loadAiConsent(token);
      if (!_isCurrent(epoch, token)) return false;
      nextApp = AppController(
        repository: _authenticatedRepository(token),
        mode: AppMode.authenticated,
        accountEmail: nextAccount.email,
        intentOwner: nextAccount.id,
        intentStore: _store is PendingIntentPersistence
            ? _store as PendingIntentPersistence
            : null,
        onExit: () => _logoutFor(token, epoch),
        onUnauthorized: () => _expireSessionFor(token, epoch),
        aiConsent: aiConsent,
        servicePolicy: servicePolicy,
        reminders: reminders,
        onGuardianWithdrawn:
            eligibility?.ageBand == '15-17' &&
                eligibility?.guardianStatus == 'approved'
            ? withdrawGuardian
            : null,
        onEligibilityChanged: () async {
          await refreshEligibility();
        },
        onAiConsentChanged: (granted) => _auth.updateVersionedAiConsent(
          token: token,
          granted: granted,
          policyVersion: servicePolicy?.aiPolicyVersion,
        ),
        onDeleteAccount: (password) =>
            _deleteAccountFor(token, epoch, password),
      );
      await nextApp.restorePendingIntents();
      final saved = await nextApp.updateProfile(profile);
      if (!_isCurrent(epoch, token)) return false;
      if (!saved) {
        message = nextApp.errorMessage ?? '預算與目標尚未保存。';
        return false;
      }
      account = nextAccount.copyWith(profileComplete: true);
      if (!nextApp.summariesLoaded) {
        status = SessionStatus.restorationFailed;
        message = '設定已儲存，但摘要暫時無法載入。請重新連線，不需要重新設定。';
        return false;
      }
      await reminders.bind(nextAccount.id);
      await reminders.synchronize(nextApp.subscriptions.items);
      if (!_isCurrent(epoch, token)) return false;
      _disposeApp();
      app = nextApp;
      nextApp = null;
      status = SessionStatus.authenticated;
      return true;
    } catch (error) {
      if (!_isCurrent(epoch, token)) return false;
      if (_isExpiredSession(error)) {
        await _expireSessionFor(token, epoch);
      } else {
        message = _messageFor(error);
      }
      return false;
    } finally {
      nextApp?.dispose();
      if (_isCurrent(epoch, token)) {
        busy = false;
        _notifyListeners();
      }
    }
  }

  Future<void> continueAsGuest() async {
    final epoch = _beginTransition();
    await _clearReminders();
    busy = true;
    message = null;
    _notifyListeners();
    try {
      await _persist(epoch, _store.clearToken);
      if (!_isCurrent(epoch)) return;
      _token = null;
      final nextApp = AppController(
        repository: await _guestRepository(),
        mode: AppMode.guest,
        onExit: () => _logoutFor(null, epoch),
        onUnauthorized: () => _expireSessionFor(null, epoch),
      );
      await nextApp.initialize();
      if (!_isCurrent(epoch)) {
        nextApp.dispose();
        return;
      }
      if (!nextApp.initialized) {
        nextApp.dispose();
        status = SessionStatus.signedOut;
        message = nextApp.errorMessage ?? '目前無法載入訪客模式。';
        return;
      }
      _disposeApp();
      app = nextApp;
      account = null;
      status = SessionStatus.guest;
    } catch (error) {
      if (!_isCurrent(epoch)) return;
      status = SessionStatus.signedOut;
      message = _messageFor(error);
    } finally {
      if (_isCurrent(epoch)) {
        busy = false;
        _notifyListeners();
      }
    }
  }

  void showEligibility() {
    _disposeApp();
    status = SessionStatus.eligibilityRequired;
    _notifyListeners();
  }

  Future<void> enterReadOnly() async {
    final token = _token, epoch = _epoch, current = account;
    if (token == null || current == null || !current.profileComplete || busy) {
      return;
    }
    busy = true;
    message = null;
    _notifyListeners();
    try {
      await _activateAuthenticated(current, token, epoch, readOnly: true);
    } catch (e) {
      if (_isCurrent(epoch, token)) message = _messageFor(e);
    } finally {
      if (_isCurrent(epoch, token)) {
        busy = false;
        _notifyListeners();
      }
    }
  }

  Future<bool> _eligibilityAction(
    Future<void> Function(String token) action,
  ) async {
    final token = _token, epoch = _epoch;
    if (token == null || busy) return false;
    busy = true;
    message = null;
    notice = null;
    _notifyListeners();
    try {
      await action(token);
      if (!_isCurrent(epoch, token)) return false;
      final current = await _auth.me(token);
      if (!_isCurrent(epoch, token)) return false;
      await _activateAuthenticated(current, token, epoch);
      return _isCurrent(epoch, token);
    } catch (e) {
      if (_isCurrent(epoch, token)) {
        if (_isExpiredSession(e)) {
          await _expireSessionFor(token, epoch);
        } else {
          message = _messageFor(e);
        }
      }
      return false;
    } finally {
      if (_isCurrent(epoch, token)) {
        busy = false;
        _notifyListeners();
      }
    }
  }

  Future<bool> declareAge(String ageBand) =>
      _eligibilityAction((token) => _auth.declareAge(token, ageBand));
  Future<bool> requestGuardian(String email) =>
      _eligibilityAction((token) => _auth.requestGuardian(token, email.trim()));
  Future<bool> confirmGuardianInApp() =>
      _eligibilityAction((token) => _auth.confirmGuardianInApp(token));
  Future<bool> refreshEligibility() => _eligibilityAction((_) async {});
  Future<void> withdrawGuardian() async {
    await _eligibilityAction((token) async {
      await _auth.withdrawGuardian(token);
      await _clearReminders();
    });
  }

  Future<void> resume() async {
    final token = _token, epoch = _epoch, current = app;
    if (busy || current?.busy == true || token == null) return;
    busy = true;
    _notifyListeners();
    try {
      final refreshed = await _auth.me(token);
      if (!_isCurrent(epoch, token)) return;
      final metadata = await _auth.getServicePolicy();
      if (!_isCurrent(epoch, token)) return;
      final nextEligibility = await _auth.getEligibility(token);
      if (!_isCurrent(epoch, token)) return;
      final writable =
          metadata?.eligibilityRequired == false ||
          nextEligibility == null ||
          nextEligibility.canWrite;
      final needsVerification =
          refreshed.verificationRequired && !refreshed.emailVerified;
      if (current != null &&
          refreshed.id == account?.id &&
          refreshed.profileComplete &&
          !needsVerification &&
          current.canWrite == writable &&
          servicePolicy?.signature == metadata?.signature) {
        account = refreshed;
        eligibility = nextEligibility;
        servicePolicy = metadata;
        final consent = await _loadAiConsent(token);
        if (!_isCurrent(epoch, token)) return;
        current.applyAiConsent(
          current.canWrite ? consent : const AiConsentStatus.notGranted(),
        );
        await current.refreshWithFeedback();
      } else {
        await _activateAuthenticated(refreshed, token, epoch);
      }
    } catch (e) {
      if (_isCurrent(epoch, token)) {
        if (_isExpiredSession(e)) {
          await _expireSessionFor(token, epoch);
        } else {
          message = _messageFor(e);
        }
      }
    } finally {
      if (_isCurrent(epoch, token)) {
        busy = false;
        _notifyListeners();
      }
    }
  }

  Future<bool> requestEmailVerification() async {
    final token = _token;
    final epoch = _epoch;
    if (token == null || !needsEmailVerification) return false;
    busy = true;
    message = null;
    notice = null;
    _notifyListeners();
    try {
      await _auth.requestEmailVerification(token);
      if (!_isCurrent(epoch, token)) return false;
      notice = '驗證信已寄出，請完成信件中的步驟後回到 App。';
      return true;
    } catch (error) {
      if (!_isCurrent(epoch, token)) return false;
      if (_isExpiredSession(error)) {
        await _expireSessionFor(token, epoch);
      } else {
        message = _messageFor(error);
      }
      return false;
    } finally {
      if (_isCurrent(epoch, token)) {
        busy = false;
        _notifyListeners();
      }
    }
  }

  Future<bool> refreshEmailVerification() async {
    final token = _token;
    final epoch = _epoch;
    if (token == null || !needsEmailVerification) return false;
    busy = true;
    message = null;
    notice = null;
    _notifyListeners();
    try {
      final refreshed = await _auth.me(token);
      if (!_isCurrent(epoch, token)) return false;
      if (refreshed.verificationRequired && !refreshed.emailVerified) {
        account = refreshed;
        notice = '尚未完成驗證，請先開啟驗證信中的連結。';
        return false;
      }
      await _activateAuthenticated(refreshed, token, epoch);
      return _isCurrent(epoch, token) &&
          (status == SessionStatus.onboarding ||
              status == SessionStatus.authenticated);
    } catch (error) {
      if (!_isCurrent(epoch, token)) return false;
      if (_isExpiredSession(error)) {
        await _expireSessionFor(token, epoch);
      } else {
        message = _messageFor(error);
      }
      return false;
    } finally {
      if (_isCurrent(epoch, token)) {
        busy = false;
        _notifyListeners();
      }
    }
  }

  Future<bool> requestPasswordReset(String email) async {
    final normalizedEmail = email.trim();
    if (busy) return false;
    if (servicePolicy?.mailEnabled == false) {
      message = '目前未提供寄信重設密碼，請妥善保存密碼；需要協助可開啟聯絡支援。';
      notice = null;
      _notifyListeners();
      return false;
    }
    if (!normalizedEmail.contains('@') || !normalizedEmail.contains('.')) {
      message = '請先輸入有效的電子郵件，再寄送重設說明。';
      notice = null;
      _notifyListeners();
      return false;
    }
    final epoch = _epoch;
    busy = true;
    message = null;
    notice = null;
    _notifyListeners();
    try {
      await _auth.requestPasswordReset(email: normalizedEmail);
      if (!_isCurrent(epoch)) return false;
      notice = '若此電子郵件可用，我們已寄出重設密碼的說明。';
      return true;
    } catch (error) {
      if (!_isCurrent(epoch)) return false;
      message = _messageFor(error);
      return false;
    } finally {
      if (_isCurrent(epoch)) {
        busy = false;
        _notifyListeners();
      }
    }
  }

  Future<void> _clearReminders() async {
    try {
      await reminders.clear();
    } catch (_) {
      notice = '本機提醒暫時無法清除，請到系統設定關閉 FutureMint AI 通知。';
    }
  }

  Future<void> logout() => _logoutFor(_token, _epoch);

  Future<void> _logoutFor(String? token, int expectedEpoch) async {
    if (!_isCurrent(expectedEpoch, token)) return;
    await _clearReminders();
    if (!_isCurrent(expectedEpoch, token)) return;
    final epoch = _beginTransition();
    busy = true;
    _notifyListeners();
    try {
      if (token != null) await _auth.logout(token);
    } catch (_) {
      if (_isCurrent(epoch)) {
        message = '已離開帳號；目前無法通知伺服器撤銷這次登入。';
      }
    } finally {
      if (_isCurrent(epoch)) {
        try {
          await _persist(epoch, _store.clearToken);
        } catch (_) {
          if (_isCurrent(epoch)) message = '已離開帳號，但裝置無法清除登入資訊，請重試。';
        }
        if (_isCurrent(epoch)) {
          _token = null;
          account = null;
          _disposeApp();
          busy = false;
          status = SessionStatus.signedOut;
          _notifyListeners();
        }
      }
    }
  }

  Future<AiConsentStatus> _loadAiConsent(String token) async {
    try {
      final consent = await _auth.getAiConsent(token);
      if (servicePolicy != null &&
          (!servicePolicy!.reviewed ||
              consent.policyVersion != servicePolicy!.aiPolicyVersion)) {
        return const AiConsentStatus.notGranted();
      }
      return consent;
    } catch (error) {
      if (_isExpiredSession(error)) rethrow;
      // Consent is security-sensitive: network or server failures must not
      // activate AI features locally.
      return const AiConsentStatus.notGranted();
    }
  }

  Future<void> deleteAccount(String password) =>
      _deleteAccountFor(_token, _epoch, password);

  Future<void> _deleteAccountFor(
    String? token,
    int expectedEpoch,
    String password,
  ) async {
    if (token == null || !_isCurrent(expectedEpoch, token)) {
      throw const ApiException(
        code: 'unauthorized',
        message: '登入已過期，請重新登入。',
        retryable: false,
      );
    }
    final epoch = expectedEpoch;
    busy = true;
    message = null;
    _notifyListeners();
    try {
      final deletedAccountId = account?.id;
      await _auth.deleteAccount(token: token, password: password);
      String? pendingWarning;
      if (deletedAccountId != null && _store is PendingIntentPersistence) {
        try {
          await (_store as PendingIntentPersistence).clearPending(
            deletedAccountId,
          );
        } catch (_) {
          pendingWarning = '帳號已刪除，但裝置仍有舊待確認資訊；請清除 App 本機資料。';
        }
      }
      if (_isCurrent(epoch, token)) await _clearReminders();
      if (!_isCurrent(epoch)) return;
      String? storageWarning = pendingWarning;
      try {
        await _persist(epoch, _store.clearToken);
      } catch (_) {
        storageWarning = '帳號已刪除，但裝置無法清除舊登入資訊，請重試。';
      }
      if (!_isCurrent(epoch)) return;
      _token = null;
      account = null;
      _disposeApp();
      status = SessionStatus.signedOut;
      message = storageWarning ?? '帳號已刪除。';
    } catch (error) {
      if (_isCurrent(epoch)) message = _messageFor(error);
      rethrow;
    } finally {
      if (_isCurrent(epoch)) {
        busy = false;
        _notifyListeners();
      }
    }
  }

  Future<void> expireSession() => _expireSessionFor(_token, _epoch);

  Future<void> _expireSessionFor(String? token, int expectedEpoch) async {
    if (!_isCurrent(expectedEpoch, token)) return;
    await _clearReminders();
    if (!_isCurrent(expectedEpoch, token)) return;
    final epoch = _beginTransition();
    String? storageWarning;
    try {
      await _persist(epoch, _store.clearToken);
    } catch (_) {
      storageWarning = '裝置無法清除登入資訊，請重試。';
    }
    if (!_isCurrent(epoch)) return;
    _token = null;
    account = null;
    _disposeApp();
    busy = false;
    status = SessionStatus.signedOut;
    message = storageWarning ?? '登入已過期，請重新登入。';
    _notifyListeners();
  }

  Future<void> discardStoredSession() async {
    final epoch = _beginTransition();
    await _clearReminders();
    String? storageWarning;
    try {
      await _persist(epoch, _store.clearToken);
    } catch (_) {
      storageWarning = '裝置無法清除登入資訊，請重試。';
    }
    if (!_isCurrent(epoch)) return;
    _token = null;
    account = null;
    _disposeApp();
    message = storageWarning;
    busy = false;
    status = SessionStatus.signedOut;
    _notifyListeners();
  }
}
