import '../core/game_config.dart';
import 'models.dart';

class LevelInfo {
  final int level;

  /// XP earned inside the current level.
  final int into;

  /// XP needed to finish the current level.
  final int needed;

  /// Total XP at which the current level starts.
  final int floorXp;

  const LevelInfo(this.level, this.into, this.needed, this.floorXp);

  double get progress => needed == 0 ? 0 : into / needed;
}

int xpToNext(int level) =>
    GameConfig.levelBaseXp + GameConfig.levelStepXp * (level - 1);

LevelInfo levelFor(int totalXp) {
  var level = 1;
  var floor = 0;
  var rest = totalXp < 0 ? 0 : totalXp;
  while (rest >= xpToNext(level)) {
    rest -= xpToNext(level);
    floor += xpToNext(level);
    level++;
  }
  return LevelInfo(level, rest, xpToNext(level), floor);
}

String rankFor(int level) {
  var rank = 'E';
  for (final e in GameConfig.rankFloors.entries) {
    if (level >= e.value) rank = e.key;
  }
  return rank;
}

int questXp(Quest q) {
  final mult = switch (q.priority) {
    Priority.low => GameConfig.lowPriorityMult,
    Priority.normal => GameConfig.normalPriorityMult,
    Priority.high => GameConfig.highPriorityMult,
  };
  var xp = (q.estimateMin * GameConfig.xpPerMinute * mult).round();
  if (xp < GameConfig.minQuestXp) xp = GameConfig.minQuestXp;
  if (q.penalty) xp = (xp * GameConfig.penaltyQuestMult).round();
  return xp;
}

/// Removes [loss] XP but never below the start of the current level.
int applyXpLoss(int totalXp, int loss) {
  final floor = levelFor(totalXp).floorXp;
  final next = totalXp - loss;
  return next < floor ? floor : next;
}

/// The rank after the current one and the level it starts at; null at the top.
(String rank, int level)? nextRank(int level) {
  for (final e in GameConfig.rankFloors.entries) {
    if (e.value > level) return (e.key, e.value);
  }
  return null;
}

/// A title earned by consistency first, then by level.
String titleFor(Player p, int level) {
  if (p.streak >= 30) return 'UNBROKEN';
  if (p.streak >= 14) return 'RELENTLESS';
  if (p.streak >= 7) return 'DISCIPLINED';
  if (p.streak >= 3) return 'CONSISTENT';
  if (level >= 20) return 'VETERAN';
  if (level >= 10) return 'ADEPT';
  if (level >= 5) return 'CLIMBER';
  return 'INITIATE';
}
