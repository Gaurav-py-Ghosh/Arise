import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/game_config.dart';
import '../data/store.dart';
import '../domain/app_catalog.dart';
import '../domain/deviation.dart';
import '../domain/leveling.dart';
import '../domain/models.dart';
import '../domain/picker.dart';
import '../domain/planner.dart';
import '../domain/rollover.dart';
import '../system/bridge.dart';
import '../system/llm.dart';
import '../system/voice.dart';

/// FNV-1a. String.hashCode is not guaranteed stable across runs, and cache
/// keys must be.
int stableHash(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xffffffff;
  }
  return h;
}

class ChatLine {
  final bool fromUser;
  final String text;

  /// True when the line came from the offline templates, not the LLM.
  final bool offline;
  const ChatLine(this.fromUser, this.text, {this.offline = false});
}

/// One-shot things the UI should show as a System window.
class SystemEvent {
  final String title;
  final String body;
  final bool danger;
  const SystemEvent(this.title, this.body, {this.danger = false});
}

class Settings {
  int weekdayCap = GameConfig.defaultWeekdayCapacityMin;
  int weekendCap = GameConfig.defaultWeekendCapacityMin;
  int budgetMin = GameConfig.defaultDistractionBudgetMin;
  bool overlay = false;
  String model = GameConfig.defaultModel;

  int capacityFor(int day) => isWeekend(day) ? weekendCap : weekdayCap;
}

class AppController extends ChangeNotifier {
  final Store store;
  final SystemBridge bridge;
  final DateTime Function() now;
  final Random _rng;

  /// Null means offline mode: templates only.
  Llm? llm;

  AppController({
    required this.store,
    required this.bridge,
    this.llm,
    DateTime Function()? now,
    Random? rng,
  })  : now = now ?? DateTime.now,
        _rng = rng ?? Random();

  // --- state the UI reads ---
  bool ready = false;
  Player player = const Player();
  final settings = Settings();
  List<Quest> todayQuests = const [];
  List<Quest> upcoming = const [];
  List<Target> targets = const [];
  Map<int, (int, int)> targetProgress = const {};
  List<FunItem> fun = const [];
  List<AppUsage> usage = const [];
  Map<String, bool> rules = const {};
  bool usageAccess = false;
  DeviationReport? report;
  int tokensToday = 0;
  int? focusQuestId;
  int focusStartedMs = 0;
  final List<ChatLine> chat = [];
  bool thinking = false;
  final List<SystemEvent> events = [];

  int get today => dayKey(now());
  LevelInfo get level => levelFor(player.xp);

  SystemEvent? takeEvent() => events.isEmpty ? null : events.removeAt(0);

  Future<void> init() async {
    settings
      ..weekdayCap = await store.getInt('cap_weekday', settings.weekdayCap)
      ..weekendCap = await store.getInt('cap_weekend', settings.weekendCap)
      ..budgetMin = await store.getInt('budget_min', settings.budgetMin)
      ..overlay = await store.getInt('overlay', 0) == 1
      ..model = await store.get('model') ?? settings.model;
    focusQuestId = int.tryParse(await store.get('focus_quest') ?? '');
    focusStartedMs = await store.getInt('focus_started', 0);
    player = await store.player();
    rules = await store.appRules();
    await _closePastDays();
    await refresh();
    ready = true;
    notifyListeners();
  }

  /// Reloads everything from disk and Android. Cheap enough to call on
  /// resume: a handful of indexed queries and one usage query.
  Future<void> refresh() async {
    final t = today;
    if (player.lastClosedDay != 0 && player.lastClosedDay < addDays(t, -1)) {
      await _closePastDays();
    }
    final all = await store.questsBetween(t, addDays(t, 13));
    todayQuests = all.where((q) => q.day == t).toList();
    upcoming = all.where((q) => q.day > t).toList();
    targets = await store.targets();
    targetProgress = {
      for (final tg in targets) tg.id!: await store.targetProgress(tg.id!)
    };
    fun = await store.funItems();
    tokensToday = await store.getInt('tokens_$t', 0);
    usageAccess = await bridge.hasUsageAccess();
    if (usageAccess) {
      final n = now();
      final start = DateTime(n.year, n.month, n.day).millisecondsSinceEpoch;
      usage = (await bridge.usage(start, n.millisecondsSinceEpoch))
        ..sort((a, b) => b.minutes.compareTo(a.minutes));
    }
    _evaluate();
    await _syncWatch();
    notifyListeners();
  }

  void _evaluate() {
    report = evaluateDeviation(
      usage: usage,
      rules: rules,
      budgetMin: settings.budgetMin,
      todayQuests: todayQuests,
      hourOfDay: now().hour,
    );
  }

  Future<void> _syncWatch() async {
    final pending = todayQuests.where((q) => !q.done).toList();
    final distracting = <String>{
      for (final e in knownApps.keys)
        if (isDistracting(e, -1, rules)) e,
      for (final u in usage)
        if (isDistracting(u.package, u.systemCategory, rules)) u.package,
      for (final e in rules.entries)
        if (e.value) e.key,
    }..removeWhere((p) => rules[p] == false);
    await bridge.saveWatchConfig({
      'day': today,
      'budgetMin': settings.budgetMin,
      'pending': pending.length,
      'pendingTitles': pending.take(3).map((q) => q.title).toList(),
      'plannedMin': report?.plannedMin ?? 0,
      'doneMin': report?.doneMin ?? 0,
      'distracting': distracting.toList(),
      'overlay': settings.overlay,
      'xpLoss': GameConfig.budgetBlownXpLoss,
    });
  }

  // --- day end ---
  Future<void> _closePastDays() async {
    final t = today;
    final yesterday = addDays(t, -1);
    if (player.lastClosedDay == 0) {
      // First launch: nothing to judge.
      player = player.copyWith(lastClosedDay: yesterday);
      await store.savePlayer(player);
      return;
    }
    if (player.lastClosedDay >= yesterday) return;
    // Judge at most the last 7 days; older gaps collapse into them.
    var from = addDays(player.lastClosedDay, 1);
    if (daysBetween(from, yesterday) > 6) from = addDays(yesterday, -6);
    final totals = await store.dayTotals(from, yesterday);
    final access = await bridge.hasUsageAccess();
    final days = <DaySummary>[];
    for (var d = from; d <= yesterday; d = addDays(d, 1)) {
      var distraction = 0;
      if (access) {
        final s = dayFromKey(d);
        final e = dayFromKey(addDays(d, 1));
        final u = await bridge.usage(
            s.millisecondsSinceEpoch, e.millisecondsSinceEpoch);
        for (final a in u) {
          if (isDistracting(a.package, a.systemCategory, rules)) {
            distraction += a.minutes;
          }
        }
      }
      final (total, done) = totals[d] ?? (0, 0);
      days.add(DaySummary(
        day: d,
        totalQuests: total,
        doneQuests: done,
        distractionMin: distraction,
        // Distraction only costs XP on days that had a plan.
        budgetMin: total > 0 ? settings.budgetMin : 0,
      ));
    }
    final r = computeRollover(player, days);
    player = r.player;
    await store.savePlayer(player);
    final moved = await store.rollOverMissed(t);
    if (r.log.isNotEmpty || moved > 0) {
      final body = [
        ...r.log,
        if (moved > 0)
          '$moved quest(s) returned as PENALTY QUESTS at half XP. Clear them today.',
      ].join('\n');
      events.add(SystemEvent('DAY JUDGEMENT', body,
          danger: r.questsMissed > 0 || r.xpLost > 0));
    }
  }

  // --- targets and quests ---
  /// Asks the LLM for a plan; falls back to the template. Cached per goal.
  Future<(List<PlanStep>, bool fromLlm)> suggestPlan(String goal,
      {int? deadline}) async {
    final g = goal.trim();
    final key = 'plan:${g.toLowerCase()}:${deadline ?? 0}';
    final hit = await store.cached(key);
    if (hit != null) {
      final steps = parsePlanSteps(hit);
      if (steps.isNotEmpty) return (steps, true);
    }
    final client = llm;
    if (client != null) {
      try {
        final reply = await client.generate(
          system: planPersona,
          turns: [
            ChatTurn(
                true,
                planPrompt(g,
                    daysToDeadline:
                        deadline == null ? null : daysBetween(today, deadline),
                    dailyMin: settings.weekdayCap))
          ],
          maxTokens: GameConfig.maxPlanTokens,
          json: true,
        );
        await _countTokens(reply.tokens);
        final steps = parsePlanSteps(reply.text);
        if (steps.isNotEmpty) {
          await store.cache(key, reply.text, now().millisecondsSinceEpoch);
          return (steps, true);
        }
      } on LlmException {
        // fall through to the template
      }
    }
    return (templatePlan(g), false);
  }

  Future<void> createTarget({
    required String title,
    required List<PlanStep> steps,
    Priority priority = Priority.normal,
    int? deadline,
  }) async {
    final id = await store.addTarget(Target(
      title: title.trim(),
      deadline: deadline,
      priority: priority,
      createdAt: now().millisecondsSinceEpoch,
    ));
    final quests = schedulePlan(
      steps: steps,
      startDay: today,
      capacityFor: settings.capacityFor,
      alreadyPlanned: await store.plannedMinutes(today),
      targetId: id,
      priority: priority,
      deadline: deadline,
    );
    await store.addQuests(quests);
    events.add(SystemEvent('NEW QUEST LINE',
        '"${title.trim()}" accepted. ${quests.length} quests issued across ${quests.map((q) => q.day).toSet().length} day(s).'));
    await refresh();
  }

  Future<void> deleteTarget(int id) async {
    await store.deleteTarget(id);
    await refresh();
  }

  Future<void> addQuest(String title, int minutes,
      {int? day, Priority priority = Priority.normal}) async {
    await store.addQuest(Quest(
      title: title.trim(),
      day: day ?? today,
      estimateMin: minutes,
      priority: priority,
    ));
    await refresh();
  }

  Future<void> moveQuest(Quest q, int day) async {
    await store.updateQuest(q.copyWith(day: day));
    await refresh();
  }

  Future<void> deleteQuest(Quest q) async {
    if (focusQuestId == q.id) await _clearFocus();
    await store.deleteQuest(q.id!);
    await refresh();
  }

  Future<void> completeQuest(Quest q) async {
    if (q.done) return;
    var quest = q;
    if (focusQuestId == q.id) quest = await _stopFocusInternal() ?? q;
    await store.updateQuest(quest.copyWith(done: true));
    final before = level.level;
    var gained = questXp(quest);
    final others = todayQuests.where((x) => x.id != quest.id);
    final dayCleared = quest.day == today && others.every((x) => x.done);
    if (dayCleared) gained += GameConfig.dailyClearBonusXp;
    player = player.copyWith(xp: player.xp + gained);
    await store.savePlayer(player);
    final after = level.level;

    if (dayCleared) {
      final backlog =
          fun.where((f) => f.status != FunStatus.done).toList(growable: false);
      final reward =
          backlog.isEmpty ? null : backlog[_rng.nextInt(backlog.length)];
      events.add(SystemEvent(
          'DAILY QUESTS CLEARED',
          '+$gained XP (includes +${GameConfig.dailyClearBonusXp} clear bonus).\n'
              '${reward == null ? 'Reward slot empty: add something to the Vault.' : 'REWARD UNLOCKED: ${reward.kind.name.toUpperCase()} "${reward.title}". You earned it.'}'));
    } else {
      events.add(SystemEvent('QUEST COMPLETE', '"${quest.title}"  +$gained XP'));
    }
    if (after > before) {
      final rankUp = rankFor(after) != rankFor(before);
      events.add(SystemEvent(
          'LEVEL UP',
          'Level $before -> $after.'
              '${rankUp ? '\nRANK UP: ${rankFor(before)} -> ${rankFor(after)}.' : ''}'));
    }
    await refresh();
  }

  /// Un-ticks a quest and takes back exactly what it paid.
  Future<void> reopenQuest(Quest q) async {
    if (!q.done) return;
    final wasCleared = q.day == today && todayQuests.every((x) => x.done);
    var loss = questXp(q);
    if (wasCleared) loss += GameConfig.dailyClearBonusXp;
    await store.updateQuest(q.copyWith(done: false));
    player = player.copyWith(xp: max(0, player.xp - loss));
    await store.savePlayer(player);
    await refresh();
  }

  // --- focus timer ---
  Future<void> startFocus(Quest q) async {
    if (focusQuestId != null) await stopFocus();
    focusQuestId = q.id;
    focusStartedMs = now().millisecondsSinceEpoch;
    await store.set('focus_quest', q.id!);
    await store.set('focus_started', focusStartedMs);
    await bridge.focusNotification(q.title, focusStartedMs);
    notifyListeners();
  }

  Future<void> stopFocus() async {
    await _stopFocusInternal();
    await refresh();
  }

  Future<Quest?> _stopFocusInternal() async {
    final id = focusQuestId;
    if (id == null) return null;
    final q = await store.quest(id);
    final elapsed =
        ((now().millisecondsSinceEpoch - focusStartedMs) / 60000).round();
    await _clearFocus();
    if (q == null) return null;
    // A forgotten timer is capped at 4 hours.
    final updated = q.copyWith(actualMin: q.actualMin + elapsed.clamp(0, 240));
    await store.updateQuest(updated);
    return updated;
  }

  Future<void> _clearFocus() async {
    focusQuestId = null;
    focusStartedMs = 0;
    await store.unset('focus_quest');
    await store.unset('focus_started');
    await bridge.focusNotification(null, 0);
  }

  // --- vault ---
  Future<void> addFun(FunKind kind, String title) async {
    await store.addFun(FunItem(
        kind: kind,
        title: title.trim(),
        createdAt: now().millisecondsSinceEpoch));
    fun = await store.funItems();
    notifyListeners();
  }

  Future<void> setFunStatus(FunItem f, FunStatus s) async {
    await store.updateFun(f.copyWith(status: s));
    fun = await store.funItems();
    notifyListeners();
  }

  Future<void> deleteFun(FunItem f) async {
    await store.deleteFun(f.id!);
    fun = await store.funItems();
    notifyListeners();
  }

  // --- usage rules and settings ---
  Future<void> setDistracting(String package, bool value) async {
    await store.setAppRule(package, value);
    rules = {...rules, package: value};
    _evaluate();
    await _syncWatch();
    notifyListeners();
  }

  Future<void> saveSettings() async {
    await store.set('cap_weekday', settings.weekdayCap);
    await store.set('cap_weekend', settings.weekendCap);
    await store.set('budget_min', settings.budgetMin);
    await store.set('overlay', settings.overlay ? 1 : 0);
    await store.set('model', settings.model);
    _evaluate();
    await _syncWatch();
    notifyListeners();
  }

  Future<void> _countTokens(int n) async {
    if (n <= 0) return;
    tokensToday += n;
    await store.set('tokens_$today', tokensToday);
  }

  // --- chat ---
  /// Answers the Player. Decisions are computed locally; the LLM only words
  /// them, and only free-form questions cost a full context.
  Future<void> ask(String text) async {
    final q = text.trim();
    if (q.isEmpty || thinking) return;
    chat.add(ChatLine(true, q));
    thinking = true;
    notifyListeners();

    final rep = report!;
    final minutes = parseMinutes(q);
    String facts;
    String offline;
    var cacheable = true;
    if (minutes != null && minutes > 0) {
      final pick = pickNext(todayQuests, minutes, today);
      facts = pickFacts(pick, minutes);
      offline = pickOffline(pick, minutes);
    } else if (asksForReport(q)) {
      facts = '${_context(rep)}\n${reportFacts(rep)}';
      offline = reportOffline(rep);
    } else {
      cacheable = false;
      facts = '${_context(rep)}\nPlayer says: $q';
      offline = llm == null
          ? 'The System link is offline. Add a Gemini key in Settings for free-form answers. '
              '${reportOffline(rep)}'
          : reportOffline(rep);
    }

    var answer = offline;
    var usedOffline = true;
    final client = llm;
    if (client != null) {
      final key = 'say:${stableHash(facts)}';
      final hit = cacheable ? await store.cached(key) : null;
      if (hit != null) {
        answer = hit;
        usedOffline = false;
      } else {
        try {
          final history = cacheable
              ? const <ChatTurn>[]
              : _history(GameConfig.chatHistoryTurns);
          final reply = await client.generate(
            system: persona,
            turns: [...history, ChatTurn(true, facts)],
            maxTokens: GameConfig.maxReplyTokens,
          );
          await _countTokens(reply.tokens);
          answer = reply.text;
          usedOffline = false;
          if (cacheable) {
            await store.cache(key, answer, now().millisecondsSinceEpoch);
          }
        } on LlmException catch (e) {
          answer = '$offline\n\n// ${e.message}';
        }
      }
    }
    chat.add(ChatLine(false, answer, offline: usedOffline));
    thinking = false;
    notifyListeners();
  }

  String _context(DeviationReport rep) => compactContext(
        today: today,
        hour: now().hour,
        player: player,
        todayQuests: todayQuests,
        report: rep,
      );

  /// Previous exchanges, excluding the question just added.
  List<ChatTurn> _history(int turns) {
    final prior = chat.sublist(0, chat.length - 1);
    final tail =
        prior.length > turns * 2 ? prior.sublist(prior.length - turns * 2) : prior;
    final out = [for (final l in tail) ChatTurn(l.fromUser, l.text)];
    // Gemini requires the first turn to be from the user.
    while (out.isNotEmpty && !out.first.fromUser) {
      out.removeAt(0);
    }
    return out;
  }
}
