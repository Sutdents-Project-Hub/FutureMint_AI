import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/core/future_mint_repository.dart';
import 'package:futuremint_app/core/models.dart';
import 'package:futuremint_app/features/settings/settings_sheet.dart';
import 'package:futuremint_app/state/app_controller.dart';
import 'package:provider/provider.dart';

import '../widget_test.dart';

class _FamilyRepository extends Fake implements FutureMintRepository {
  FamilyOverview? family;
  String? joinedCode;
  int rotations = 0;
  int revocations = 0;
  int leaves = 0;
  bool failLoad = false;
  static const code = 'aBcDeF0123456789_-AbCdEf';
  FamilyOverview overview({bool active = true, String? code}) => FamilyOverview(
    familyId: 'family-1',
    inviteCode: code,
    members: const [],
    childSummaries: const [],
    inviteActive: active,
    inviteCodeExpiresAt: DateTime.utc(2030),
  );
  @override
  Future<FamilyOverview?> getFamilyOverview() async {
    if (failLoad) throw const FormatException('家庭資料暫時無法取得。');
    return family;
  }

  @override
  Future<FamilyOverview> rotateFamilyInvite() async {
    rotations++;
    return family = overview(code: code);
  }

  @override
  Future<FamilyOverview> revokeFamilyInvite() async {
    revocations++;
    return family = overview(active: false);
  }

  @override
  Future<FamilyOverview> joinFamily(String inviteCode) async {
    joinedCode = inviteCode;
    return family = overview(active: false);
  }

  @override
  Future<void> leaveFamily() async {
    leaves++;
    family = null;
  }
}

Future<void> openSettings(
  WidgetTester tester,
  AppController controller, {
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: controller,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showSettingsSheet(context),
              child: const Text('設定'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('設定'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('read-only child can stop family sharing', (tester) async {
    final controller = await createController(
      mode: AppMode.authenticated,
      canWrite: false,
    );
    final repository = _FamilyRepository();
    repository.family = repository.overview(active: false);
    controller.repository = repository;
    await openSettings(tester, controller);
    final leave = find.byKey(const Key('leave-family'));
    await tester.ensureVisible(leave);
    await tester.tap(leave);
    await tester.pumpAndSettle();
    expect(repository.leaves, 0);
    await tester.tap(find.byKey(const Key('confirm-leave-family')));
    await tester.pumpAndSettle();
    expect(repository.leaves, 1);
    expect(controller.familyOverview, isNull);
    expect(controller.errorMessage, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('read-only parent can revoke but cannot rotate an invite', (
    tester,
  ) async {
    final controller = await createController(
      mode: AppMode.authenticated,
      canWrite: false,
    );
    controller.profile = UserProfile.fromJson({
      ...controller.profile!.toJson(),
      'accountRole': 'parent',
    });
    final repository = _FamilyRepository();
    repository.family = repository.overview();
    controller.repository = repository;
    await controller.rotateFamilyInvite();
    expect(repository.rotations, 0);
    await openSettings(tester, controller);
    final revoke = find.byKey(const Key('revoke-family-invite'));
    await tester.ensureVisible(revoke);
    await tester.tap(revoke);
    await tester.pumpAndSettle();
    expect(repository.revocations, 1);
    expect(controller.errorMessage, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('parent can rotate and revoke an expiring invite', (
    tester,
  ) async {
    final controller = await createController(mode: AppMode.authenticated);
    controller.profile = UserProfile.fromJson({
      ...controller.profile!.toJson(),
      'accountRole': 'parent',
    });
    final repository = _FamilyRepository();
    repository.family = repository.overview();
    controller.repository = repository;
    await openSettings(tester, controller);
    final rotate = find.byKey(const Key('rotate-family-invite'));
    await tester.ensureVisible(rotate);
    await tester.tap(rotate);
    await tester.pumpAndSettle();
    expect(repository.rotations, 1);
    expect(find.text(_FamilyRepository.code), findsOneWidget);
    final revoke = find.byKey(const Key('revoke-family-invite'));
    await tester.ensureVisible(revoke);
    await tester.tap(revoke);
    await tester.pumpAndSettle();
    expect(repository.revocations, 1);
    expect(find.text(_FamilyRepository.code), findsNothing);
    expect(find.text('目前沒有有效邀請碼。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('joining preserves the full case-sensitive invite', (
    tester,
  ) async {
    final controller = await createController(mode: AppMode.authenticated);
    final repository = _FamilyRepository();
    controller.repository = repository;
    await openSettings(tester, controller);
    final input = find.byKey(const Key('family-invite-code'));
    await tester.ensureVisible(input);
    await tester.enterText(input, _FamilyRepository.code);
    final join = find.byKey(const Key('join-family'));
    await tester.ensureVisible(join);
    await tester.tap(join);
    await tester.pumpAndSettle();
    expect(repository.joinedCode, isNull);
    await tester.tap(find.byKey(const Key('confirm-join-family')));
    await tester.pumpAndSettle();
    expect(repository.joinedCode, _FamilyRepository.code);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling sharing sends no join request', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await createController(mode: AppMode.authenticated);
    final repository = _FamilyRepository();
    controller.repository = repository;
    await openSettings(tester, controller, textScale: 2);
    final input = find.byKey(const Key('family-invite-code'));
    await tester.ensureVisible(input);
    await tester.enterText(input, _FamilyRepository.code);
    final join = find.byKey(const Key('join-family'));
    await tester.ensureVisible(join);
    await tester.tap(join);
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(repository.joinedCode, isNull);
    expect(controller.familyOverview, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed family lookup offers retry instead of join', (
    tester,
  ) async {
    final controller = await createController(mode: AppMode.authenticated);
    final repository = _FamilyRepository()..failLoad = true;
    controller.repository = repository;
    await openSettings(tester, controller);
    expect(find.text('家庭資料暫時無法取得。'), findsOneWidget);
    expect(find.byKey(const Key('join-family')), findsNothing);
    repository.failLoad = false;
    final retry = find.byKey(const Key('retry-family'));
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('join-family')), findsOneWidget);
    expect(find.text('家庭資料暫時無法取得。'), findsNothing);
  });

  testWidgets('parent with a child must keep the family owned', (tester) async {
    final controller = await createController(mode: AppMode.authenticated);
    controller.profile = UserProfile.fromJson({
      ...controller.profile!.toJson(),
      'accountRole': 'parent',
    });
    final repository = _FamilyRepository();
    repository.family = const FamilyOverview(
      familyId: 'family-1',
      inviteCode: null,
      members: [
        FamilyMember(
          userId: 'child',
          role: AccountRole.child,
          label: '孩子帳號 1',
          isSelf: false,
        ),
      ],
      childSummaries: [],
    );
    controller.repository = repository;
    await openSettings(tester, controller);
    final leave = tester.widget<OutlinedButton>(
      find.byKey(const Key('leave-family')),
    );
    expect(leave.onPressed, isNull);
    expect(find.text('孩子仍在此家庭；請先由孩子帳號離開，家長才能關閉家庭。'), findsOneWidget);
    expect(repository.leaves, 0);
  });
}
