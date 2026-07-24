import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/app/future_mint_app.dart';
import 'package:futuremint_app/auth/auth_api.dart';
import 'package:futuremint_app/auth/auth_models.dart';
import 'package:futuremint_app/auth/session_store.dart';
import 'package:futuremint_app/data/guest_repository.dart';
import 'package:futuremint_app/design/tokens.dart';
import 'package:futuremint_app/state/session_controller.dart';

class _Store implements SessionPersistence {
  @override
  Future<void> clearToken() async {}

  @override
  Future<String?> readToken() async => null;

  @override
  Future<void> writeToken(String token) async {}
}

class _Auth implements AuthGateway {
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
  Future<AuthSession> register({
    required String email,
    required String password,
  }) => throw UnimplementedError();
}

void main() {
  testWidgets('offers clear sign-in and temporary guest access', (
    tester,
  ) async {
    final session = SessionController(
      auth: _Auth(),
      store: _Store(),
      authenticatedRepository: (_) => throw UnimplementedError(),
      guestRepository: GuestRepository.create,
    );
    await session.start();

    await tester.pumpWidget(FutureMintApp(session: session));
    await tester.pumpAndSettle();

    expect(find.text('登入 FutureMint'), findsOneWidget);
    expect(find.text('建立帳號'), findsOneWidget);
    expect(find.text('以訪客模式繼續'), findsOneWidget);
    expect(
      tester.getRect(find.text('以訪客模式繼續')).bottom,
      lessThanOrEqualTo(tester.view.physicalSize.height),
    );

    await tester.tap(find.text('以訪客模式繼續'));
    await tester.pumpAndSettle();

    expect(find.text('訪客資料不會儲存'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps desktop artwork close to the sign-in form', (
    tester,
  ) async {
    final session = SessionController(
      auth: _Auth(),
      store: _Store(),
      authenticatedRepository: (_) => throw UnimplementedError(),
      guestRepository: GuestRepository.create,
    );
    await session.start();
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(FutureMintApp(session: session));
    await tester.pumpAndSettle();

    final artwork = tester.getRect(find.byKey(const Key('auth-artwork-slot')));
    final form = tester.getRect(find.byKey(const Key('auth-form-content')));
    final gap = form.top - artwork.bottom;

    expect(gap, greaterThanOrEqualTo(FutureMintTokens.space2));
    expect(gap, lessThanOrEqualTo(FutureMintTokens.space6));
    expect(tester.takeException(), isNull);
  });
}
