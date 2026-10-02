import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../core/launch_models.dart';
import '../core/models.dart';

/// Date-only billing dates are interpreted in Asia/Taipei, independent of the
/// device timezone. Preserve the original day/month after short months.
List<Map<String, Object>> reminderOccurrences(
  List<ActiveSubscription> items,
  DateTime now,
) {
  final out = <Map<String, Object>>[];
  for (final s in items.where((s) => s.active)) {
    var year = s.nextBillingDate.year, month = s.nextBillingDate.month;
    for (var i = 0; i < 60; i++) {
      final last = DateTime.utc(year, month + 1, 0).day;
      final day = s.originalBillingDay.clamp(1, last);
      final billing = DateTime.utc(year, month, day);
      // 09:00 Taipei on the preceding calendar day is 01:00 UTC.
      final at = billing
          .subtract(const Duration(days: 1))
          .add(const Duration(hours: 1));
      if (at.isAfter(now.toUtc())) {
        out.add({
          'id': 'futuremint.subscription.${s.id}.${dateOnly(billing)}',
          'at': at.toIso8601String(),
        });
      }
      if (s.billingCycle == BillingCycle.yearly) {
        year++;
        month = s.originalBillingMonth;
      } else {
        month++;
        if (month > 12) {
          month = 1;
          year++;
        }
      }
    }
  }
  out.sort((a, b) => (a['at'] as String).compareTo(b['at'] as String));
  return out.take(60).toList();
}

class SubscriptionReminders {
  SubscriptionReminders({MethodChannel? channel, bool? supported})
    : _channel =
          channel ?? const MethodChannel('futuremint/subscription-reminders'),
      supported =
          supported ??
          (!kIsWeb &&
              (defaultTargetPlatform == TargetPlatform.iOS ||
                  defaultTargetPlatform == TargetPlatform.android));
  final MethodChannel _channel;
  final bool supported;
  int get bindingGeneration => _generation;
  bool isBoundTo(String owner) => _owner == owner;
  String? _owner;
  int _generation = 0;
  bool enabled = false;
  String permission = 'notDetermined';
  Future<void> _queue = Future<void>.value();
  Future<void> _binding = Future<void>.value();
  void Function(String owner)? onOpen;
  Future<void> bind(String? owner) async {
    _owner = owner;
    final generation = ++_generation;
    enabled = false;
    if (!supported) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'open' &&
          call.arguments is String &&
          call.arguments == _owner) {
        onOpen?.call(call.arguments as String);
      }
    });
    // Binding invalidates pending permission callbacks immediately, even while
    // a system prompt is open. Other mutations still wait for binding cleanup.
    final nextBinding = () async {
      final state = await _channel.invokeMapMethod<String, dynamic>('bind', {
        'owner': owner,
        'generation': generation,
      });
      if (generation != _generation) return;
      enabled = state?['enabled'] == true;
      permission = state?['permission'] as String? ?? 'notDetermined';
    }();
    _binding = nextBinding;
    await nextBinding;
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _queue.then((_) async {
      await _binding;
      await action();
    });
    _queue = next.catchError((Object _) {});
    return next;
  }

  Future<bool> setEnabled(bool value) async {
    final owner = _owner, generation = _generation;
    if (!supported || owner == null) return false;
    await _enqueue(() async {
      if (generation != _generation) return;
      final state = await _channel.invokeMapMethod<String, dynamic>(
        'setEnabled',
        {'owner': owner, 'generation': generation, 'enabled': value},
      );
      if (generation != _generation) return;
      enabled = state?['enabled'] == true;
      permission = state?['permission'] as String? ?? 'denied';
    });
    return enabled;
  }

  /// Read system settings without prompting or clearing the account binding.
  Future<void> refreshPermission() async {
    final owner = _owner, generation = _generation;
    if (!supported || owner == null) return;
    await _enqueue(() async {
      if (generation != _generation) return;
      final state = await _channel.invokeMapMethod<String, dynamic>('status', {
        'owner': owner,
        'generation': generation,
      });
      if (generation != _generation) return;
      enabled = state?['enabled'] == true;
      permission = state?['permission'] as String? ?? 'notDetermined';
    });
  }

  Future<bool> openSettings() async {
    final owner = _owner, generation = _generation;
    if (!supported || owner == null) return false;
    var opened = false;
    await _enqueue(() async {
      if (generation != _generation) return;
      opened =
          await _channel.invokeMethod<bool>('openSettings', {
            'owner': owner,
            'generation': generation,
          }) ==
          true;
    });
    return opened;
  }

  Future<void> synchronize(
    List<ActiveSubscription> items, {
    DateTime? now,
  }) async {
    final owner = _owner, generation = _generation;
    if (!supported || owner == null) return;
    await _enqueue(() async {
      if (generation != _generation) return;
      await _channel.invokeMethod<void>('replace', {
        'owner': owner,
        'generation': generation,
        'occurrences': enabled
            ? reminderOccurrences(items, now ?? DateTime.now())
            : <Object>[],
      });
    });
  }

  Future<void> clear() => bind(null);
}
