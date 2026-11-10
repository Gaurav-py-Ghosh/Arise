/// Days are stored as yyyymmdd ints: sortable, timezone-free, cheap to index.
int dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

DateTime dayFromKey(int k) => DateTime(k ~/ 10000, (k ~/ 100) % 100, k % 100);

int addDays(int key, int n) {
  final d = dayFromKey(key);
  return dayKey(DateTime(d.year, d.month, d.day + n));
}

int daysBetween(int fromKey, int toKey) {
  final a = dayFromKey(fromKey), b = dayFromKey(toKey);
  return DateTime.utc(b.year, b.month, b.day)
      .difference(DateTime.utc(a.year, a.month, a.day))
      .inDays;
}

bool isWeekend(int key) {
  final w = dayFromKey(key).weekday;
  return w == DateTime.saturday || w == DateTime.sunday;
}

String fmtMin(int m) {
  if (m < 60) return '${m}m';
  final h = m ~/ 60, r = m % 60;
  return r == 0 ? '${h}h' : '${h}h ${r}m';
}

const _wd = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
String fmtDay(int key, {int? today}) {
  if (today != null) {
    final diff = daysBetween(today, key);
    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'TOMORROW';
    if (diff == -1) return 'YESTERDAY';
  }
  final d = dayFromKey(key);
  return '${_wd[d.weekday - 1]} ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

enum Priority { low, normal, high }

class Target {
  final int? id;
  final String title;
  final int? deadline; // day key
  final Priority priority;
  final int createdAt; // ms epoch
  final bool archived;

  const Target({
    this.id,
    required this.title,
    this.deadline,
    this.priority = Priority.normal,
    required this.createdAt,
    this.archived = false,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'deadline': deadline,
        'priority': priority.index,
        'created_at': createdAt,
        'archived': archived ? 1 : 0,
      };

  factory Target.fromMap(Map<String, Object?> m) => Target(
        id: m['id'] as int?,
        title: m['title'] as String,
        deadline: m['deadline'] as int?,
        priority: Priority.values[m['priority'] as int],
        createdAt: m['created_at'] as int,
        archived: (m['archived'] as int) == 1,
      );
}

class Quest {
  final int? id;
  final int? targetId;
  final String title;
  final int day;
  final int estimateMin;
  final int actualMin;
  final bool done;
  final bool penalty;
  final Priority priority;
  final int? deadline;

  const Quest({
    this.id,
    this.targetId,
    required this.title,
    required this.day,
    required this.estimateMin,
    this.actualMin = 0,
    this.done = false,
    this.penalty = false,
    this.priority = Priority.normal,
    this.deadline,
  });

  int get remainingMin {
    final r = estimateMin - actualMin;
    return r > 0 ? r : 0;
  }

  Quest copyWith({
    int? id,
    int? targetId,
    String? title,
    int? day,
    int? estimateMin,
    int? actualMin,
    bool? done,
    bool? penalty,
    Priority? priority,
    int? deadline,
  }) =>
      Quest(
        id: id ?? this.id,
        targetId: targetId ?? this.targetId,
        title: title ?? this.title,
        day: day ?? this.day,
        estimateMin: estimateMin ?? this.estimateMin,
        actualMin: actualMin ?? this.actualMin,
        done: done ?? this.done,
        penalty: penalty ?? this.penalty,
        priority: priority ?? this.priority,
        deadline: deadline ?? this.deadline,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'target_id': targetId,
        'title': title,
        'day': day,
        'estimate_min': estimateMin,
        'actual_min': actualMin,
        'done': done ? 1 : 0,
        'penalty': penalty ? 1 : 0,
        'priority': priority.index,
        'deadline': deadline,
      };

  factory Quest.fromMap(Map<String, Object?> m) => Quest(
        id: m['id'] as int?,
        targetId: m['target_id'] as int?,
        title: m['title'] as String,
        day: m['day'] as int,
        estimateMin: m['estimate_min'] as int,
        actualMin: m['actual_min'] as int,
        done: (m['done'] as int) == 1,
        penalty: (m['penalty'] as int) == 1,
        priority: Priority.values[m['priority'] as int],
        deadline: m['deadline'] as int?,
      );
}

enum FunKind { game, movie, book, music }

enum FunStatus { backlog, active, done }

class FunItem {
  final int? id;
  final FunKind kind;
  final String title;
  final FunStatus status;
  final int createdAt;

  const FunItem({
    this.id,
    required this.kind,
    required this.title,
    this.status = FunStatus.backlog,
    required this.createdAt,
  });

  FunItem copyWith({FunStatus? status}) => FunItem(
        id: id,
        kind: kind,
        title: title,
        status: status ?? this.status,
        createdAt: createdAt,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'kind': kind.index,
        'title': title,
        'status': status.index,
        'created_at': createdAt,
      };

  factory FunItem.fromMap(Map<String, Object?> m) => FunItem(
        id: m['id'] as int?,
        kind: FunKind.values[m['kind'] as int],
        title: m['title'] as String,
        status: FunStatus.values[m['status'] as int],
        createdAt: m['created_at'] as int,
      );
}

/// Usage of one app over a window, as reported by Android.
class AppUsage {
  final String package;
  final String label;
  final int minutes;

  /// Android's own app category (ApplicationInfo.category), or -1.
  final int systemCategory;

  const AppUsage({
    required this.package,
    required this.label,
    required this.minutes,
    this.systemCategory = -1,
  });
}

class Player {
  final int xp;
  final int streak;
  final int bestStreak;

  /// Last day that has been closed out by rollover.
  final int lastClosedDay;

  const Player({
    this.xp = 0,
    this.streak = 0,
    this.bestStreak = 0,
    this.lastClosedDay = 0,
  });

  Player copyWith({int? xp, int? streak, int? bestStreak, int? lastClosedDay}) =>
      Player(
        xp: xp ?? this.xp,
        streak: streak ?? this.streak,
        bestStreak: bestStreak ?? this.bestStreak,
        lastClosedDay: lastClosedDay ?? this.lastClosedDay,
      );
}
