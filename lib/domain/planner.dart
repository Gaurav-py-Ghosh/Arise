import 'dart:convert';

import '../core/game_config.dart';
import 'models.dart';

/// One step of a plan before it is placed on a day.
class PlanStep {
  final String title;
  final int minutes;
  const PlanStep(this.title, this.minutes);

  @override
  bool operator ==(Object other) =>
      other is PlanStep && other.title == title && other.minutes == minutes;

  @override
  int get hashCode => Object.hash(title, minutes);

  @override
  String toString() => 'PlanStep($title, $minutes)';
}

/// Offline plan used until (or instead of) the LLM answering.
List<PlanStep> templatePlan(String goal) {
  final g = goal.trim();
  return [
    PlanStep('Recon: scope $g and list topics', 30),
    PlanStep('$g: fundamentals', 60),
    PlanStep('$g: hands-on practice', 60),
    PlanStep('$g: deep work session', 60),
    PlanStep('$g: attack weak spots', 45),
    PlanStep('$g: review and self-test', 45),
  ];
}

/// Parses the LLM's plan reply. Accepts `[{"t": "...", "m": 45}, ...]`,
/// tolerating code fences, prose around the array and long key names.
List<PlanStep> parsePlanSteps(String raw) {
  final start = raw.indexOf('[');
  final end = raw.lastIndexOf(']');
  if (start < 0 || end <= start) return const [];
  Object? decoded;
  try {
    decoded = jsonDecode(raw.substring(start, end + 1));
  } on FormatException {
    return const [];
  }
  if (decoded is! List) return const [];
  final out = <PlanStep>[];
  for (final e in decoded) {
    if (e is! Map) continue;
    final title = (e['t'] ?? e['title'] ?? '').toString().trim();
    final rawMin = e['m'] ?? e['minutes'] ?? e['min'];
    final minutes = rawMin is num ? rawMin.round() : int.tryParse('$rawMin');
    if (title.isEmpty || minutes == null) continue;
    out.add(PlanStep(title, minutes.clamp(5, 240)));
  }
  return out;
}

/// Places [steps] on days starting at [startDay], never exceeding the day's
/// free capacity. A step bigger than what is left of a day moves to the next
/// day; a step bigger than a whole day's capacity is split into parts.
///
/// [capacityFor] is the user's total capacity for a day; [alreadyPlanned]
/// is minutes already booked per day by other quests.
List<Quest> schedulePlan({
  required List<PlanStep> steps,
  required int startDay,
  required int Function(int day) capacityFor,
  Map<int, int> alreadyPlanned = const {},
  int? targetId,
  Priority priority = Priority.normal,
  int? deadline,
}) {
  final quests = <Quest>[];
  final booked = Map<int, int>.from(alreadyPlanned);
  final lastDay = addDays(startDay, GameConfig.maxPlanHorizonDays - 1);
  var day = startDay;

  int free(int d) {
    final f = capacityFor(d) - (booked[d] ?? 0);
    return f > 0 ? f : 0;
  }

  void place(String title, int minutes) {
    quests.add(Quest(
      targetId: targetId,
      title: title,
      day: day,
      estimateMin: minutes,
      priority: priority,
      deadline: deadline,
    ));
    booked[day] = (booked[day] ?? 0) + minutes;
  }

  for (final step in steps) {
    var left = step.minutes;
    if (left <= 0) continue;
    final parts = <int>[];
    while (left > 0) {
      // Find the next day that can hold the whole remainder, or, when no
      // single day ever could, the next day with any room at all.
      while (day < lastDay && free(day) < left && free(day) < capacityFor(day)) {
        day = addDays(day, 1);
      }
      while (day < lastDay && free(day) == 0) {
        day = addDays(day, 1);
      }
      final room = free(day);
      // Past the horizon everything left lands on the last day.
      final chunk = (day >= lastDay || room >= left) ? left : room;
      parts.add(chunk);
      final partNo = parts.length;
      final split = chunk < step.minutes;
      place(split ? '${step.title} (part $partNo)' : step.title, chunk);
      left -= chunk;
    }
  }
  return quests;
}
