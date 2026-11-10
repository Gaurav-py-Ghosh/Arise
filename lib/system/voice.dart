/// Everything the System says: prompt building for the LLM, and the offline
/// templates used when there is no key, no network or no quota.
library;

import '../domain/deviation.dart';
import '../domain/leveling.dart';
import '../domain/models.dart';
import '../domain/picker.dart';

const persona =
    'You are SYSTEM, the game interface of the Arise app. Address the user as '
    '"Player" in second person. Cold, precise, dramatic, never chatty. Plain '
    'text only, no markdown, max 60 words. Use only the facts given; never '
    'invent quests, numbers or apps.';

const planPersona =
    'You plan study and work goals. Reply with ONLY a JSON array of 5 to 8 '
    'steps in order: [{"t":"short action title","m":minutes}]. Titles under '
    '8 words, concrete and specific to the goal. Minutes between 20 and 90.';

String planPrompt(String goal, {int? daysToDeadline, int dailyMin = 120}) {
  final dl = daysToDeadline == null ? '' : ' Deadline in $daysToDeadline days.';
  return 'Goal: ${goal.trim()}. About $dailyMin min/day available.$dl';
}

String _p(Priority p) => switch (p) {
      Priority.high => 'H',
      Priority.normal => 'N',
      Priority.low => 'L',
    };

/// The user's state squeezed into as few tokens as possible. Capped so a
/// long quest list can never blow up the prompt.
String compactContext({
  required int today,
  required int hour,
  required Player player,
  required List<Quest> todayQuests,
  required DeviationReport report,
  int maxQuests = 6,
  int maxApps = 3,
}) {
  final lv = levelFor(player.xp);
  final b = StringBuffer()
    ..write('${fmtDay(today)} ${hour}h | L${lv.level} rank ${rankFor(lv.level)} '
        'streak ${player.streak}\n')
    ..write('Plan ${report.doneMin}/${report.plannedMin}m, '
        '${report.pendingQuests} pending\n');
  final pending = todayQuests.where((q) => !q.done).take(maxQuests);
  for (final q in pending) {
    b.write('- ${q.title} ${q.remainingMin}m ${_p(q.priority)}');
    if (q.deadline != null) b.write(' dl${daysBetween(today, q.deadline!)}d');
    if (q.penalty) b.write(' PENALTY');
    b.write('\n');
  }
  b.write('Distraction ${report.distractionMin}/${report.budgetMin}m');
  if (report.offenders.isNotEmpty) {
    b.write(' (');
    b.write(report.offenders
        .take(maxApps)
        .map((a) => '${a.label} ${a.minutes}')
        .join(', '));
    b.write(')');
  }
  return b.toString();
}

/// Reads a duration out of free text: "40 min", "1.5 hours", "1h 30m",
/// "half an hour", "an hour". Null when there is none.
int? parseMinutes(String text) {
  final t = text.toLowerCase();
  var total = 0.0;
  var found = false;
  final h = RegExp(r'(\d+(?:\.\d+)?)\s*(?:h|hr|hrs|hour|hours)\b').firstMatch(t);
  if (h != null) {
    total += double.parse(h.group(1)!) * 60;
    found = true;
  }
  final m = RegExp(r'(\d+)\s*(?:m|min|mins|minute|minutes)\b').firstMatch(t);
  if (m != null) {
    total += int.parse(m.group(1)!);
    found = true;
  }
  if (!found) {
    if (t.contains('half an hour') || t.contains('half hour')) return 30;
    if (RegExp(r'\ban hour\b').hasMatch(t)) return 60;
    return null;
  }
  return total.round();
}

bool asksForReport(String text) {
  final t = text.toLowerCase();
  return t.contains('report') ||
      t.contains('on track') ||
      t.contains('status') ||
      t.contains('deviat') ||
      t.contains('how am i doing');
}

// --- facts handed to the LLM (short) and offline wording (complete) ---

String pickFacts(PickResult r, int minutes) {
  final f = r.first;
  if (f == null) return 'Player has ${fmtMin(minutes)} free. No pending quests.';
  final b = StringBuffer('Player has ${fmtMin(minutes)} free. Chosen quest: '
      '"${f.quest.title}" for ${fmtMin(f.minutes)}');
  if (!f.fits) b.write(' (partial, ${fmtMin(f.quest.remainingMin)} total left)');
  if (f.reasons.isNotEmpty) b.write('. Why: ${f.reasons.join(', ')}');
  final rest = r.queue.where((p) => p.quest.id != f.quest.id).toList();
  if (rest.isNotEmpty) {
    b.write('. Then: ${rest.map((p) => '"${p.quest.title}" ${fmtMin(p.minutes)}').join(', ')}');
  }
  b.write('. Tell the Player what to do first and why.');
  return b.toString();
}

String pickOffline(PickResult r, int minutes) {
  final f = r.first;
  if (f == null) {
    return 'No pending quests, Player. The ${fmtMin(minutes)} is yours.';
  }
  final b = StringBuffer('[DIRECTIVE] Begin "${f.quest.title}" now');
  b.write(f.fits
      ? ' (${fmtMin(f.minutes)}).'
      : '. It will not fit: spend the full ${fmtMin(f.minutes)} on it, '
          '${fmtMin(f.quest.remainingMin - f.minutes)} will remain.');
  if (f.reasons.isNotEmpty) b.write(' Reason: ${f.reasons.join(', ')}.');
  final rest = r.queue.where((p) => p.quest.id != f.quest.id).toList();
  if (rest.isNotEmpty) {
    b.write(' Then: ${rest.map((p) => '"${p.quest.title}" (${fmtMin(p.minutes)})').join(', ')}.');
  }
  return b.toString();
}

String reportFacts(DeviationReport r) =>
    'Status: ${r.level.name}. ${r.reasons.join('. ')} '
    'Give the Player a verdict on today and one order.';

String reportOffline(DeviationReport r) {
  final head = switch (r.level) {
    DeviationLevel.onTrack => '[STATUS: ON TRACK]',
    DeviationLevel.warning => '[STATUS: WARNING]',
    DeviationLevel.deviating => '[STATUS: DEVIATION DETECTED]',
  };
  final b = StringBuffer('$head Completed ${fmtMin(r.doneMin)} of '
      '${fmtMin(r.plannedMin)} planned. ${r.pendingQuests} quest(s) pending. '
      'Distraction ${fmtMin(r.distractionMin)} of ${fmtMin(r.budgetMin)} allowed.');
  if (r.offenders.isNotEmpty) {
    b.write(' Top: ${r.offenders.take(3).map((a) => '${a.label} ${fmtMin(a.minutes)}').join(', ')}.');
  }
  if (r.level == DeviationLevel.deviating) {
    b.write(' Return to your quests or pay the penalty at day end.');
  }
  return b.toString();
}
