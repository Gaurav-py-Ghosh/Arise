import 'package:flutter/services.dart';

import '../domain/models.dart';

/// Everything that needs Android. Faked in tests.
abstract class SystemBridge {
  Future<bool> hasUsageAccess();
  Future<void> openUsageAccess();
  Future<List<AppUsage>> usage(int startMs, int endMs);

  /// Hands the background watcher what it needs to judge deviation without
  /// starting Flutter.
  Future<void> saveWatchConfig(Map<String, Object?> config);
  Future<bool> requestNotifications();

  /// Whether notifications may be posted, without asking.
  Future<bool> notificationsAllowed();
  Future<bool> canOverlay();
  Future<void> openOverlaySettings();
  Future<bool> ignoresBattery();
  Future<void> requestIgnoreBattery();
  Future<void> testAlert();

  /// Shows the ongoing focus timer notification; null title removes it.
  Future<void> focusNotification(String? title, int startedMs);

  /// Plays a bundled effect: tick, open, start, complete, clear, levelup,
  /// warn or boot. Unknown names are ignored.
  Future<void> playSound(String name);

  /// Text of the alert the app was opened from, if any. Read once.
  Future<String?> consumeLaunchAlert();
}

class AndroidBridge implements SystemBridge {
  static const _ch = MethodChannel('arise/system');

  /// Called when an alert notification is tapped while the app is running.
  void onAlert(void Function(String text) handler) {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'alert') handler(call.arguments as String);
    });
  }

  Future<T?> _call<T>(String m, [Object? args]) async {
    try {
      return await _ch.invokeMethod<T>(m, args);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<bool> hasUsageAccess() async =>
      await _call<bool>('hasUsageAccess') ?? false;

  @override
  Future<void> openUsageAccess() => _call('openUsageAccess');

  @override
  Future<List<AppUsage>> usage(int startMs, int endMs) async {
    final raw = await _call<List<Object?>>(
        'usage', {'start': startMs, 'end': endMs});
    if (raw == null) return const [];
    return [
      for (final e in raw.cast<Map<Object?, Object?>>())
        AppUsage(
          package: e['pkg'] as String,
          label: e['label'] as String,
          minutes: ((e['ms'] as num) / 60000).round(),
          systemCategory: (e['cat'] as num?)?.toInt() ?? -1,
        )
    ];
  }

  @override
  Future<void> saveWatchConfig(Map<String, Object?> config) =>
      _call('saveWatchConfig', config);

  @override
  Future<bool> requestNotifications() async =>
      await _call<bool>('requestNotifications') ?? false;

  @override
  Future<bool> notificationsAllowed() async =>
      await _call<bool>('notificationsAllowed') ?? false;

  @override
  Future<bool> canOverlay() async => await _call<bool>('canOverlay') ?? false;

  @override
  Future<void> openOverlaySettings() => _call('openOverlaySettings');

  @override
  Future<bool> ignoresBattery() async =>
      await _call<bool>('ignoresBattery') ?? false;

  @override
  Future<void> requestIgnoreBattery() => _call('requestIgnoreBattery');

  @override
  Future<void> testAlert() => _call('testAlert');

  @override
  Future<void> focusNotification(String? title, int startedMs) =>
      _call('focusNotification', {'title': title, 'started': startedMs});

  @override
  Future<void> playSound(String name) => _call('playSound', {'name': name});

  @override
  Future<String?> consumeLaunchAlert() => _call<String>('consumeLaunchAlert');
}
