import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/models.dart';

/// All persistence. Local SQLite only; a sync layer can wrap this later.
class Store {
  final Database db;
  Store(this.db);

  static const schemaVersion = 1;

  static Future<void> createSchema(Database db, int version) async {
    final b = db.batch();
    b.execute('''CREATE TABLE targets(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      deadline INTEGER,
      priority INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL,
      archived INTEGER NOT NULL DEFAULT 0)''');
    b.execute('''CREATE TABLE quests(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      target_id INTEGER REFERENCES targets(id) ON DELETE CASCADE,
      title TEXT NOT NULL,
      day INTEGER NOT NULL,
      estimate_min INTEGER NOT NULL,
      actual_min INTEGER NOT NULL DEFAULT 0,
      done INTEGER NOT NULL DEFAULT 0,
      penalty INTEGER NOT NULL DEFAULT 0,
      priority INTEGER NOT NULL DEFAULT 1,
      deadline INTEGER)''');
    b.execute('CREATE INDEX quests_day ON quests(day, done)');
    b.execute('''CREATE TABLE fun_items(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      kind INTEGER NOT NULL,
      title TEXT NOT NULL,
      status INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL)''');
    b.execute('''CREATE TABLE app_rules(
      package TEXT PRIMARY KEY,
      distracting INTEGER NOT NULL)''');
    b.execute('CREATE TABLE kv(key TEXT PRIMARY KEY, value TEXT NOT NULL)');
    b.execute('''CREATE TABLE llm_cache(
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL,
      ts INTEGER NOT NULL)''');
    await b.commit(noResult: true);
  }

  static Future<Store> open() async {
    final path = p.join(await getDatabasesPath(), 'arise.db');
    final db = await openDatabase(
      path,
      version: schemaVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: createSchema,
    );
    return Store(db);
  }

  // --- kv ---
  Future<String?> get(String key) async {
    final r = await db.query('kv', where: 'key = ?', whereArgs: [key]);
    return r.isEmpty ? null : r.first['value'] as String;
  }

  Future<int> getInt(String key, int fallback) async =>
      int.tryParse(await get(key) ?? '') ?? fallback;

  Future<void> set(String key, Object value) => db.insert(
      'kv', {'key': key, 'value': '$value'},
      conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> unset(String key) =>
      db.delete('kv', where: 'key = ?', whereArgs: [key]);

  // --- player ---
  Future<Player> player() async => Player(
        xp: await getInt('xp', 0),
        streak: await getInt('streak', 0),
        bestStreak: await getInt('best_streak', 0),
        lastClosedDay: await getInt('last_closed_day', 0),
      );

  Future<void> savePlayer(Player pl) async {
    final b = db.batch();
    void put(String k, int v) => b.insert('kv', {'key': k, 'value': '$v'},
        conflictAlgorithm: ConflictAlgorithm.replace);
    put('xp', pl.xp);
    put('streak', pl.streak);
    put('best_streak', pl.bestStreak);
    put('last_closed_day', pl.lastClosedDay);
    await b.commit(noResult: true);
  }

  // --- targets ---
  Future<int> addTarget(Target t) => db.insert('targets', t.toMap());

  Future<List<Target>> targets() async => (await db.query('targets',
          where: 'archived = 0', orderBy: 'created_at DESC'))
      .map(Target.fromMap)
      .toList();

  Future<void> deleteTarget(int id) =>
      db.delete('targets', where: 'id = ?', whereArgs: [id]);

  // --- quests ---
  Future<int> addQuest(Quest q) => db.insert('quests', q.toMap());

  Future<void> addQuests(List<Quest> qs) async {
    final b = db.batch();
    for (final q in qs) {
      b.insert('quests', q.toMap());
    }
    await b.commit(noResult: true);
  }

  Future<void> updateQuest(Quest q) =>
      db.update('quests', q.toMap(), where: 'id = ?', whereArgs: [q.id]);

  Future<void> deleteQuest(int id) =>
      db.delete('quests', where: 'id = ?', whereArgs: [id]);

  Future<Quest?> quest(int id) async {
    final r = await db.query('quests', where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : Quest.fromMap(r.first);
  }

  Future<List<Quest>> questsBetween(int fromDay, int toDay) async =>
      (await db.query('quests',
              where: 'day BETWEEN ? AND ?',
              whereArgs: [fromDay, toDay],
              orderBy: 'day, done, priority DESC, id'))
          .map(Quest.fromMap)
          .toList();

  /// Planned minutes per day for unfinished quests from [fromDay] on.
  Future<Map<int, int>> plannedMinutes(int fromDay) async {
    final r = await db.rawQuery(
        'SELECT day, SUM(estimate_min) m FROM quests WHERE day >= ? GROUP BY day',
        [fromDay]);
    return {for (final row in r) row['day'] as int: (row['m'] as num).toInt()};
  }

  /// Quest totals per day in a closed range, for day-end judgement.
  Future<Map<int, (int total, int done)>> dayTotals(int fromDay, int toDay) async {
    final r = await db.rawQuery(
        'SELECT day, COUNT(*) t, SUM(done) d FROM quests WHERE day BETWEEN ? AND ? GROUP BY day',
        [fromDay, toDay]);
    return {
      for (final row in r)
        row['day'] as int: ((row['t'] as int), (row['d'] as num).toInt())
    };
  }

  /// Moves every unfinished quest from before [today] onto [today] as a
  /// penalty quest. Returns how many moved.
  Future<int> rollOverMissed(int today) => db.rawUpdate(
      'UPDATE quests SET day = ?, penalty = 1 WHERE done = 0 AND day < ?',
      [today, today]);

  Future<(int done, int total)> targetProgress(int targetId) async {
    final r = await db.rawQuery(
        'SELECT COUNT(*) t, COALESCE(SUM(done), 0) d FROM quests WHERE target_id = ?',
        [targetId]);
    return ((r.first['d'] as num).toInt(), r.first['t'] as int);
  }

  // --- fun ---
  Future<int> addFun(FunItem f) => db.insert('fun_items', f.toMap());

  Future<List<FunItem>> funItems() async =>
      (await db.query('fun_items', orderBy: 'status, created_at DESC'))
          .map(FunItem.fromMap)
          .toList();

  Future<void> updateFun(FunItem f) =>
      db.update('fun_items', f.toMap(), where: 'id = ?', whereArgs: [f.id]);

  Future<void> deleteFun(int id) =>
      db.delete('fun_items', where: 'id = ?', whereArgs: [id]);

  // --- app rules ---
  Future<Map<String, bool>> appRules() async => {
        for (final r in await db.query('app_rules'))
          r['package'] as String: (r['distracting'] as int) == 1
      };

  Future<void> setAppRule(String package, bool distracting) => db.insert(
      'app_rules', {'package': package, 'distracting': distracting ? 1 : 0},
      conflictAlgorithm: ConflictAlgorithm.replace);

  // --- llm cache ---
  Future<String?> cached(String key) async {
    final r = await db.query('llm_cache', where: 'key = ?', whereArgs: [key]);
    return r.isEmpty ? null : r.first['value'] as String;
  }

  Future<void> cache(String key, String value, int nowMs) async {
    await db.insert('llm_cache', {'key': key, 'value': value, 'ts': nowMs},
        conflictAlgorithm: ConflictAlgorithm.replace);
    // Keep the cache small: drop entries older than 14 days.
    await db.delete('llm_cache',
        where: 'ts < ?', whereArgs: [nowMs - 14 * 24 * 3600 * 1000]);
  }
}
