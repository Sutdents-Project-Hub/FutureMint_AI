import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/core/models.dart';
import 'package:futuremint_app/data/guest_repository.dart';
import 'package:futuremint_app/data/api_repository.dart';
import 'package:futuremint_app/state/app_controller.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    controller = AppController(
      repository: await GuestRepository.create(),
      mode: AppMode.guest,
    );
  });

  test(
    'initialize loads profile, dashboard, events, and service mode',
    () async {
      await controller.initialize();

      expect(controller.initialized, isTrue);
      expect(controller.profile?.goalName, '校外活動基金');
      expect(controller.dashboard?.recentEvents, isNotEmpty);
      expect(controller.events, isNotEmpty);
      expect(controller.mode, AppMode.guest);
    },
  );

  test(
    'parse keeps the ledger unchanged and exposes confirmation drafts',
    () async {
      await controller.initialize();
      final eventCount = controller.events.length;

      await controller.parseCapture(
        '今天買珍奶 75',
        referenceTime: DateTime.parse('2026-07-13T12:00:00+08:00'),
      );

      expect(controller.captureResult?.drafts.single.amountMinor, 75);
      expect(controller.events, hasLength(eventCount));
      expect(controller.errorMessage, isNull);
    },
  );

  test('saving a confirmed draft refreshes dashboard and records', () async {
    await controller.initialize();
    await controller.parseCapture(
      '今天買珍奶 75',
      referenceTime: DateTime.parse('2026-07-13T12:00:00+08:00'),
    );
    final before = controller.events.length;

    await controller.saveDraft(controller.captureResult!.drafts.single);

    expect(controller.events, hasLength(before + 1));
    expect(controller.captureResult, isNull);
    expect(controller.lastSavedEvent?.amountMinor, 75);
  });

  test(
    'saving one draft keeps the remaining drafts in the same capture',
    () async {
      await controller.initialize();
      await controller.parseCapture(
        '早餐 65，飲料 40',
        referenceTime: DateTime.parse('2026-07-13T12:00:00+08:00'),
      );
      final first = controller.captureResult!.drafts.first;

      await controller.saveDraft(first);

      expect(controller.captureResult?.drafts, hasLength(1));
      expect(controller.captureResult?.drafts.single.amountMinor, 40);
    },
  );

  test(
    'saving a subscription refreshes the comparison from that event',
    () async {
      await controller.initialize();
      await controller.parseCapture(
        'Spotify 480 四人分',
        referenceTime: DateTime.parse('2026-07-13T18:00:00+08:00'),
      );

      await controller.saveDraft(controller.captureResult!.drafts.single);

      expect(controller.subscriptionComparison?.currentName, 'Spotify');
      expect(controller.subscriptionComparison?.currentMonthlyCostMinor, 120);
    },
  );

  test('profile update reports failure so the editor can stay open', () async {
    final failingController = AppController(
      repository: ApiRepository(
        baseUri: Uri.parse('https://example.test/api'),
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'code': 'network_error',
              'message': '暫時無法儲存。',
              'retryable': true,
            }),
            503,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      ),
      mode: AppMode.authenticated,
    );

    final didSave = await failingController.updateProfile(
      UserProfile(
        userId: 'account-test',
        monthlyBudgetMinor: 6000,
        goalName: '我的目標',
        goalTargetMinor: 12000,
        goalSavedMinor: 0,
        goalDate: DateTime(2026, 12, 31),
      ),
    );

    expect(didSave, isFalse);
    expect(failingController.errorMessage, '暫時無法儲存。');
  });
}
