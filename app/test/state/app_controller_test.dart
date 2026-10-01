import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/auth/auth_models.dart';
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
    'authenticated users without consent never call AI repository methods',
    () async {
      var requests = 0;
      final protected = AppController(
        repository: ApiRepository(
          baseUri: Uri.parse('https://example.test/api/'),
          client: MockClient((request) async {
            requests += 1;
            expect(request.method, 'GET');
            expect(request.url.path, '/api/education/catalog');
            return http.Response('{}', 500);
          }),
        ),
        mode: AppMode.authenticated,
      );

      await protected.parseCapture('今天買珍奶 75');
      await protected.loadLesson();
      await protected.loadLearningPlan();
      await protected.askCoach(topic: 'saving', question: '怎麼開始？');
      await protected.askLearningCoach(topic: 'budget', question: '如何分配？');

      expect(requests, 1);
      expect(protected.errorMessage, contains('尚未啟用 AI'));
    },
  );

  test(
    'revoking AI consent clears AI-only state and restores local block',
    () async {
      final consentController = AppController(
        repository: await GuestRepository.create(),
        mode: AppMode.authenticated,
        aiConsent: AiConsentStatus(granted: true, policyVersion: '2026-08-30'),
        onAiConsentChanged: (granted) async =>
            AiConsentStatus(granted: granted, policyVersion: '2026-08-30'),
      );
      await consentController.initialize();
      await consentController.loadLesson();
      expect(consentController.lesson, isNotNull);

      final revoked = await consentController.revokeAiConsent();

      expect(revoked, isTrue);
      expect(consentController.aiConsent.granted, isFalse);
      expect(consentController.lesson, isNull);
      await consentController.loadLesson();
      expect(consentController.lesson?.source, CaptureSource.manual);
      expect(consentController.lesson?.id, startsWith('catalog-'));
      expect(consentController.errorMessage, isNull);
    },
  );

  test('server policy changes invalidate the local AI consent state', () async {
    final protected = AppController(
      repository: ApiRepository(
        baseUri: Uri.parse('https://example.test/api/'),
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'code': 'ai_consent_required',
              'message': '使用第三方 AI 前，請先同意資料處理說明。',
              'retryable': false,
            }),
            403,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      ),
      mode: AppMode.authenticated,
      aiConsent: const AiConsentStatus(
        granted: true,
        policyVersion: 'outdated-policy',
      ),
    );

    await protected.parseCapture('今天買珍奶 75');

    expect(protected.aiConsent.granted, isFalse);
    expect(protected.errorMessage, contains('請先同意'));
  });

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

  test('starting another parse clears a previous saved confirmation', () async {
    await controller.initialize();
    await controller.parseCapture(
      '今天買珍奶 75',
      referenceTime: DateTime.parse('2026-07-13T12:00:00+08:00'),
    );
    await controller.saveDraft(controller.captureResult!.drafts.single);

    await controller.parseCapture(
      '剛剛買飲料',
      referenceTime: DateTime.parse('2026-07-13T12:10:00+08:00'),
    );

    expect(controller.lastSavedEvent, isNull);
    expect(controller.captureResult?.clarificationQuestion, isNotNull);
  });

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
    'records a repeated identical expense as a new confirmed event',
    () async {
      await controller.initialize();
      final initialEventCount = controller.events.length;
      final initialExpense = controller.dashboard!.expenseMinor;
      final initialAvailable = controller.dashboard!.availableMinor;

      for (var index = 1; index <= 2; index += 1) {
        await controller.parseCapture(
          '今天買珍奶 75',
          referenceTime: DateTime.now(),
        );
        await controller.saveDraft(controller.captureResult!.drafts.single);

        expect(controller.events, hasLength(initialEventCount + index));
        expect(
          controller.dashboard?.expenseMinor,
          initialExpense + (75 * index),
        );
        expect(
          controller.dashboard?.availableMinor,
          initialAvailable - (75 * index),
        );
      }

      expect(
        controller.events.where((event) => event.idempotencyKey != null),
        hasLength(2),
      );
      expect(controller.lastSavedEvent?.amountMinor, 75);
    },
  );

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
        referenceTime: DateTime.now(),
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

  test(
    'keeps learning coach replies separate from FutureSeed coach replies',
    () async {
      await controller.initialize();

      await controller.askLearningCoach(
        topic: 'spending',
        question: '我月底常常不夠用，該先看哪裡？',
        style: 'steps',
      );

      expect(controller.learningCoachReply?.answer, contains('先比較'));
      expect(controller.coachReply, isNull);
      expect(controller.errorMessage, isNull);
    },
  );
}
