import '../core/game_config.dart';
import 'leveling.dart';
import 'models.dart';

/// What happened on one past day, as input to the day-end judgement.
class DaySummary {
  final int day;
  final int totalQuests;
  final int doneQuests;
  final int distractionMin;
  final int budgetMin;

  const DaySummary({
    required this.day,
    required this.totalQuests,
    required this.doneQuests,
    this.distractionMin = 0,
    this.budgetMin = 0,
  });

  int get missed => totalQuests - doneQuests;
  bool get budgetBlown => budgetMin > 0 && distractionMin > budgetMin;
}

class RolloverResult {
  final Player player;

  /// Human-readable System log lines, oldest first.
  final List<String> log;
  final int xpLost;
  final int questsMissed;

  const RolloverResult(this.player, this.log, this.xpLost, this.questsMissed);
}

/// Closes out every day in [days] (ascending, all before today):
/// - a day with missed quests resets the streak
/// - a day with quests and none missed extends it
/// - a day without quests leaves it alone
/// - a blown distraction budget costs XP, never a level
///
/// Moving the missed quests to today as penalty quests is done by the caller.
RolloverResult computeRollover(Player player, List<DaySummary> days) {
  var p = player;
  final log = <String>[];
  var lost = 0, missed = 0;
  for (final d in days) {
    if (d.day <= p.lastClosedDay) continue;
    final label = fmtDay(d.day);
    if (d.missed > 0) {
      missed += d.missed;
      if (p.streak > 0) {
        log.add('$label: ${d.missed} quest(s) failed. Streak of ${p.streak} broken.');
      } else {
        log.add('$label: ${d.missed} quest(s) failed.');
      }
      p = p.copyWith(streak: 0);
    } else if (d.totalQuests > 0) {
      final s = p.streak + 1;
      p = p.copyWith(streak: s, bestStreak: s > p.bestStreak ? s : p.bestStreak);
      log.add('$label: all quests cleared. Streak $s.');
    }
    if (d.budgetBlown) {
      final next = applyXpLoss(p.xp, GameConfig.budgetBlownXpLoss);
      final delta = p.xp - next;
      lost += delta;
      p = p.copyWith(xp: next);
      log.add(
          '$label: distraction ${fmtMin(d.distractionMin)} over the ${fmtMin(d.budgetMin)} limit. -$delta XP.');
    }
    p = p.copyWith(lastClosedDay: d.day);
  }
  return RolloverResult(p, log, lost, missed);
}
