import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:futuremint_app/auth/auth_api.dart';
import 'package:futuremint_app/auth/auth_models.dart';
import 'package:futuremint_app/auth/session_store.dart';
import 'package:futuremint_app/data/guest_repository.dart';
import 'package:futuremint_app/design/theme.dart';
import 'package:futuremint_app/features/auth/onboarding_screen.dart';
import 'package:futuremint_app/state/session_controller.dart';

class _Store implements SessionPersistence {
  @override
  Future<void> clearToken() async {}

  @override
  Future<String?> readToken() async => null;

  @override
  Future<void> writeToken(String token) async {}
}

class _Auth extends AuthGateway {
  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<PublicAccount> me(String token) => throw UnimplementedError();

  @override
  Future<void> logout(String token) async {}

  @override
  Future<void> deleteAccount({
    required String token,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AiConsentStatus> getAiConsent(String token) async =>
      const AiConsentStatus.notGranted();

  @override
  Future<AiConsentStatus> updateAiConsent({
    required String token,
    required bool granted,
  }) async => AiConsentStatus(granted: granted, policyVersion: 'test');

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
  }) => throw UnimplementedError();
}

Future<void> _pumpOnboarding(
  WidgetTester tester, {
  required Brightness brightness,
  double textScale = 2,
}) async {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final session =
      SessionController(
          auth: _Auth(),
          store: _Store(),
          authenticatedRepository: (_) => throw UnimplementedError(),
          guestRepository: GuestRepository.create,
        )
        ..account = PublicAccount(
          id: 'test-account',
          email: 'student@example.invalid',
          profileComplete: false,
          createdAt: DateTime(2026),
        );
  addTearDown(session.dispose);

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: session,
      child: MaterialApp(
        theme: FutureMintTheme.light(),
        darkTheme: FutureMintTheme.dark(),
        themeMode: brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        locale: const Locale('zh', 'TW'),
        supportedLocales: const [Locale('zh', 'TW')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(375, 812),
            devicePixelRatio: 1,
            textScaler: TextScaler.linear(textScale),
          ),
          child: const OnboardingScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectRequiredEntrances() {
  for (final label in [
    '使用角色',
    '預算與目標',
    '每月可安排的預算（元）',
    '想累積的目標',
    '目標金額（元）',
    '希望完成的日期',
    '儲存並開始使用',
    '隱私權政策',
    '聯絡支援',
    '使用說明與協助',
    '登出',
    '刪除這個帳號',
  ]) {
    expect(find.text(label), findsOneWidget, reason: '入口「$label」仍須可見');
  }
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'keeps required onboarding entrances reachable at 375dp and 200% text ($brightness)',
      (tester) async {
        await _pumpOnboarding(tester, brightness: brightness);
        _expectRequiredEntrances();
        expect(find.byType(InputDecorator), findsNWidgets(4));

        final saveButton = find.text('儲存並開始使用');
        await tester.ensureVisible(saveButton);
        await tester.pumpAndSettle();
        final saveRect = tester.getRect(saveButton);
        expect(saveRect.top, greaterThanOrEqualTo(0));
        expect(saveRect.bottom, lessThanOrEqualTo(812));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('tapping the date field calendar icon opens the date picker', (
    tester,
  ) async {
    await _pumpOnboarding(tester, brightness: Brightness.light, textScale: 1);

    final calendarIcon = find.byIcon(Icons.calendar_month_outlined);
    await tester.ensureVisible(calendarIcon);
    await tester.pumpAndSettle();
    await tester.tap(calendarIcon);
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
