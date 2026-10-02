import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/reminders/subscription_reminders.dart';
import 'package:futuremint_app/state/app_controller.dart';
import 'package:futuremint_app/core/models.dart';
import 'package:futuremint_app/data/guest_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('subscription-reminders-test');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('iOS and Android support local reminders; other platforms do not', () {
    for (final platform in TargetPlatform.values) {
      debugDefaultTargetPlatformOverride = platform;
      expect(
        SubscriptionReminders().supported,
        platform == TargetPlatform.iOS || platform == TargetPlatform.android,
        reason: platform.name,
      );
    }
  });

  test(
    'settings recovery reads actual state without requesting permission',
    () async {
      final calls = <MethodCall>[];
      var permission = 'denied';
      var preference = true;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'openSettings') return true;
        if (call.method == 'replace') return null;
        return {
          'enabled': preference && permission == 'authorized',
          'permission': permission,
        };
      });
      final service = SubscriptionReminders(channel: channel, supported: true);
      await service.bind('account-1');
      expect(service.enabled, isFalse);
      expect(await service.openSettings(), isTrue);
      permission = 'authorized';
      await service.refreshPermission();
      await service.synchronize([]);
      expect(service.enabled, isTrue);
      expect(service.permission, 'authorized');
      expect(calls.map((call) => call.method), [
        'bind',
        'openSettings',
        'status',
        'replace',
      ]);
      expect(calls[2].arguments, {'owner': 'account-1', 'generation': 1});
      preference = false;
      await service.refreshPermission();
      expect(service.enabled, isFalse);
    },
  );

  test('late status cannot restore reminders after logout', () async {
    final gate = Completer<Map<String, Object>>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'status') return gate.future;
      return {'enabled': false, 'permission': 'notDetermined'};
    });
    final service = SubscriptionReminders(channel: channel, supported: true);
    await service.bind('account-1');
    final refresh = service.refreshPermission();
    await Future<void>.delayed(Duration.zero);
    final logout = service.clear();
    // Logout cleanup must finish while the old status call is still pending.
    await logout.timeout(const Duration(seconds: 1));
    gate.complete({'enabled': true, 'permission': 'authorized'});
    await refresh;
    await logout;
    expect(service.enabled, isFalse);
    expect(await service.openSettings(), isFalse);
  });

  test(
    'logout reaches native without waiting for a permission dialog',
    () async {
      final gate = Completer<Map<String, Object>>();
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'setEnabled') return gate.future;
        return {'enabled': false, 'permission': 'notDetermined'};
      });
      final service = SubscriptionReminders(channel: channel, supported: true);
      await service.bind('account-1');
      final enabling = service.setEnabled(true);
      await Future<void>.delayed(Duration.zero);
      await service.clear().timeout(const Duration(seconds: 1));
      expect(calls, ['bind', 'setEnabled', 'bind']);
      gate.complete({'enabled': true, 'permission': 'authorized'});
      await enabling;
      expect(service.enabled, isFalse);
    },
  );

  test(
    'old controller cannot replace the new account reminders after permission returns',
    () async {
      final gate = Completer<Map<String, Object>>();
      final replacements = <Object?>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'setEnabled') return gate.future;
        if (call.method == 'replace') {
          replacements.add(call.arguments);
          return null;
        }
        return {
          'enabled': (call.arguments as Map)['owner'] == 'account-2',
          'permission': 'authorized',
        };
      });
      final service = SubscriptionReminders(channel: channel, supported: true);
      await service.bind('account-1');
      final old = AppController(
        repository: await GuestRepository.create(),
        mode: AppMode.authenticated,
        reminders: service,
        intentOwner: 'account-1',
      );
      final enabling = old.setRemindersEnabled(true);
      await Future<void>.delayed(Duration.zero);
      // The new account owns the service even before the old controller is
      // disposed; it must not receive the old controller's subscription list.
      await service.bind('account-2');
      gate.complete({'enabled': true, 'permission': 'authorized'});
      await enabling;
      expect(service.enabled, isTrue);
      expect(replacements, isEmpty);
      await old.refreshReminderPermission();
      expect(replacements, isEmpty);
      old.dispose();
    },
  );

  test(
    'unsupported platform never opens or requests system settings',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        fail('Unsupported platforms must not invoke a native channel');
      });
      final service = SubscriptionReminders(channel: channel, supported: false);
      await service.bind('account-1');
      await service.refreshPermission();
      expect(await service.openSettings(), isFalse);
      expect(await service.setEnabled(true), isFalse);
    },
  );
}
