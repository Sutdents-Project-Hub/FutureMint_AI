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
  Future<FamilyOverview?> getFamilyOverview() async => family;
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
}

Future<void> openSettings(WidgetTester tester, AppController controller) async {
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: controller,
      child: MaterialApp(
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
    expect(repository.joinedCode, _FamilyRepository.code);
    expect(tester.takeException(), isNull);
  });
}
