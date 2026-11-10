import '../core/game_config.dart';
import 'app_catalog.dart';
import 'models.dart';

enum DeviationLevel { onTrack, warning, deviating }

class DeviationReport {
  final DeviationLevel level;
  final int distractionMin;
  final int budgetMin;
  final int plannedMin;
  final int doneMin;
  final int pendingQuests;

  /// Distracting apps, heaviest first.
  final List<AppUsage> offenders;

  /// Minutes per category across all apps, heaviest first.
  final Map<String, int> byCategory;
  final List<String> reasons;

  const DeviationReport({
    required this.level,
    required this.distractionMin,
    required this.budgetMin,
    required this.plannedMin,
    required this.doneMin,
    required this.pendingQuests,
    required this.offenders,
    required this.byCategory,
    required this.reasons,
  });

  int get overBudgetBy =>
      distractionMin > budgetMin ? distractionMin - budgetMin : 0;
}

/// Compares today's phone usage and quest progress against the plan.
///
/// [rules] maps package -> user override of "is distracting"; apps without an
/// override fall back to the built-in catalog.
DeviationReport evaluateDeviation({
  required List<AppUsage> usage,
  required Map<String, bool> rules,
  required int budgetMin,
  required List<Quest> todayQuests,
  required int hourOfDay,
}) {
  final offenders = <AppUsage>[];
  final cats = <String, int>{};
  var distraction = 0;
  for (final u in usage) {
    if (u.minutes <= 0) continue;
    final cat = categoryOf(u.package, u.systemCategory);
    cats[cat] = (cats[cat] ?? 0) + u.minutes;
    if (isDistracting(u.package, u.systemCategory, rules)) {
      distraction += u.minutes;
      offenders.add(u);
    }
  }
  offenders.sort((a, b) => b.minutes.compareTo(a.minutes));
  final sortedCats = Map.fromEntries(
      cats.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));

  var planned = 0, done = 0, pending = 0;
  for (final q in todayQuests) {
    planned += q.estimateMin;
    if (q.done) {
      // A ticked quest without timer data counts as its estimate.
      done += q.actualMin > 0 ? q.actualMin : q.estimateMin;
    } else {
      done += q.actualMin;
      pending++;
    }
  }

  final reasons = <String>[];
  var level = DeviationLevel.onTrack;
  if (pending > 0) {
    if (distraction > budgetMin) {
      level = DeviationLevel.deviating;
      reasons.add(
          'Distraction ${fmtMin(distraction)} exceeds the ${fmtMin(budgetMin)} limit');
    } else if (budgetMin > 0 &&
        distraction >= budgetMin * GameConfig.warnAtBudgetFraction) {
      level = DeviationLevel.warning;
      reasons.add(
          'Distraction ${fmtMin(distraction)} is close to the ${fmtMin(budgetMin)} limit');
    }
    if (hourOfDay >= GameConfig.behindCheckHour && done * 2 < planned) {
      if (level == DeviationLevel.onTrack) level = DeviationLevel.warning;
      reasons.add(
          'Only ${fmtMin(done)} of ${fmtMin(planned)} planned is done and the day is closing');
    }
  }

  return DeviationReport(
    level: level,
    distractionMin: distraction,
    budgetMin: budgetMin,
    plannedMin: planned,
    doneMin: done,
    pendingQuests: pending,
    offenders: offenders,
    byCategory: sortedCats,
    reasons: reasons,
  );
}
