import 'models.dart';

class Pick {
  final Quest quest;

  /// Minutes of this quest to do in the available window.
  final int minutes;

  /// True when the whole remainder of the quest fits.
  final bool fits;
  final int score;
  final List<String> reasons;

  const Pick(this.quest, this.minutes, this.fits, this.score, this.reasons);
}

class PickResult {
  /// What to start right now, or null when nothing is pending.
  final Pick? first;

  /// Quests that fit back-to-back in the window, in order, starting with
  /// [first] when it fits.
  final List<Pick> queue;

  const PickResult(this.first, this.queue);
}

int _score(Quest q, int today, List<String> why) {
  var s = switch (q.priority) {
    Priority.high => 30,
    Priority.normal => 20,
    Priority.low => 10,
  };
  if (q.priority == Priority.high) why.add('high priority');
  final dl = q.deadline;
  if (dl != null) {
    final left = daysBetween(today, dl);
    if (left <= 1) {
      s += 30;
      why.add(left < 0 ? 'deadline passed' : 'deadline within a day');
    } else if (left <= 3) {
      s += 20;
      why.add('deadline in $left days');
    } else if (left <= 7) {
      s += 10;
      why.add('deadline this week');
    }
  }
  if (q.penalty) {
    s += 15;
    why.add('penalty quest');
  }
  if (q.actualMin > 0) {
    s += 5;
    why.add('already started');
  }
  return s;
}

/// Decides what to tackle with [minutesLeft] available. Pure and
/// deterministic: the LLM only words the result.
PickResult pickNext(List<Quest> quests, int minutesLeft, int today) {
  final pending = quests.where((q) => !q.done && q.day <= today).toList();
  if (pending.isEmpty || minutesLeft <= 0) return const PickResult(null, []);

  final picks = <Pick>[];
  for (final q in pending) {
    final why = <String>[];
    var s = _score(q, today, why);
    final rem = q.remainingMin == 0 ? 5 : q.remainingMin;
    final fits = rem <= minutesLeft;
    if (fits) {
      s += 20;
      why.add('fits in ${fmtMin(minutesLeft)}');
    }
    picks.add(Pick(q, fits ? rem : minutesLeft, fits, s, why));
  }
  // Highest score first; ties go to the shorter quest, then the older one.
  picks.sort((a, b) {
    final c = b.score.compareTo(a.score);
    if (c != 0) return c;
    final m = a.quest.remainingMin.compareTo(b.quest.remainingMin);
    if (m != 0) return m;
    return (a.quest.id ?? 0).compareTo(b.quest.id ?? 0);
  });

  final queue = <Pick>[];
  var room = minutesLeft;
  for (final p in picks) {
    if (p.fits && p.minutes <= room) {
      queue.add(p);
      room -= p.minutes;
    }
  }
  return PickResult(picks.first, queue);
}
