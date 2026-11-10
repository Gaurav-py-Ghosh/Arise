import 'package:arise/data/store.dart';
import 'package:arise/domain/models.dart';
import 'package:arise/system/bridge.dart';
import 'package:arise/system/llm.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// [isolate] false runs SQLite on the calling isolate, which widget tests
/// need: their fake clock never delivers messages from a background isolate.
Future<Store> memoryStore({bool isolate = true}) async {
  sqfliteFfiInit();
  final factory = isolate ? databaseFactoryFfi : databaseFactoryFfiNoIsolate;
  final db = await factory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: Store.schemaVersion,
      singleInstance: false,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: Store.createSchema,
    ),
  );
  return Store(db);
}

class FakeBridge implements SystemBridge {
  bool access = true;

  /// Usage returned for a window, keyed by the day key of its start.
  final Map<int, List<AppUsage>> byDay = {};
  Map<String, Object?>? watch;
  String? focusTitle;

  @override
  Future<bool> hasUsageAccess() async => access;
  @override
  Future<List<AppUsage>> usage(int startMs, int endMs) async =>
      List.of(byDay[dayKey(DateTime.fromMillisecondsSinceEpoch(startMs))] ??
          const []);
  @override
  Future<void> saveWatchConfig(Map<String, Object?> config) async =>
      watch = config;
  @override
  Future<void> focusNotification(String? title, int startedMs) async =>
      focusTitle = title;
  @override
  Future<void> openUsageAccess() async {}
  @override
  Future<bool> requestNotifications() async => true;
  @override
  Future<bool> notificationsAllowed() async => true;
  @override
  Future<bool> canOverlay() async => false;
  @override
  Future<void> openOverlaySettings() async {}
  @override
  Future<bool> ignoresBattery() async => false;
  @override
  Future<void> requestIgnoreBattery() async {}
  @override
  Future<void> testAlert() async {}
  @override
  Future<String?> consumeLaunchAlert() async => null;
}

class FakeLlm implements Llm {
  String reply;
  bool fail = false;
  final List<List<ChatTurn>> calls = [];
  FakeLlm(this.reply);

  @override
  Future<LlmReply> generate({
    required String system,
    required List<ChatTurn> turns,
    required int maxTokens,
    bool json = false,
  }) async {
    calls.add(turns);
    if (fail) throw const LlmException('down');
    return LlmReply(reply, 42);
  }
}
