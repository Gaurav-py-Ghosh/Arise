import 'dart:math';

import 'package:arise/app/controller.dart';
import 'package:arise/core/game_config.dart';
import 'package:arise/domain/models.dart';
import 'package:arise/domain/planner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  late DateTime clock;
  late FakeBridge bridge;
  late AppController c;

  Future<AppController> boot({FakeLlm? llm}) async {
    final ctl = AppController(
      store: await memoryStore(),
      bridge: bridge,
      llm: llm,
      now: () => clock,
      rng: Random(1),
    );
    await ctl.init();
    return ctl;
  }

  setUp(() async {
    clock = DateTime(2026, 11, 11, 10); // Wednesday
    bridge = FakeBridge();
    c = await boot();
  });

  test('sound effects respect the setting', () async {
    c.sfx('tick');
    expect(bridge.sounds, ['tick']);
    c.settings.sound = false;
    await c.saveSettings();
    c.sfx('tick');
    expect(bridge.sounds, ['tick']);
    // The choice survives a restart.
    final again = AppController(
        store: c.store, bridge: bridge, now: () => clock, rng: Random(1));
    await again.init();
    expect(again.settings.sound, false);
    again.sfx('open');
    expect(bridge.sounds, ['tick']);
  });

  test('starting the focus timer plays its sound', () async {
    await c.addQuest('a', 30);
    await c.startFocus(c.todayQuests.single);
    expect(bridge.sounds, ['start']);
  });

  test('first launch judges nothing', () {
    expect(c.player.lastClosedDay, 20261110);
    expect(c.events, isEmpty);
  });

  test('creating a target schedules quests within capacity', () async {
    await c.createTarget(
        title: 'Flutter prep', steps: templatePlan('Flutter prep'));
    expect(c.targets.single.title, 'Flutter prep');
    expect(c.todayQuests.fold<int>(0, (s, q) => s + q.estimateMin) <= 120, true);
    expect(c.todayQuests.length + c.upcoming.length, 6);
    expect(c.targetProgress[c.targets.single.id], (0, 6));
  });

  test('completing quests pays XP, then the clear bonus and a reward', () async {
    await c.addFun(FunKind.game, 'Hollow Knight');
    await c.addQuest('a', 30);
    await c.addQuest('b', 60, priority: Priority.high);
    c.events.clear();

    await c.completeQuest(c.todayQuests.firstWhere((q) => q.title == 'a'));
    expect(c.player.xp, 30);
    expect(c.events.single.title, 'QUEST COMPLETE');
    c.events.clear();

    await c.completeQuest(c.todayQuests.firstWhere((q) => q.title == 'b'));
    expect(c.player.xp, 30 + 75 + GameConfig.dailyClearBonusXp);
    expect(c.events.first.title, 'DAILY QUESTS CLEARED');
    expect(c.events.first.body, contains('Hollow Knight'));
    expect(c.events.last.title, 'LEVEL UP');
    expect(c.report!.pendingQuests, 0);
  });

  test('reopening a quest takes back what it paid', () async {
    await c.addQuest('a', 30);
    await c.completeQuest(c.todayQuests.single);
    expect(c.player.xp, 80);
    await c.reopenQuest(c.todayQuests.single);
    expect(c.player.xp, 0);
    expect(c.todayQuests.single.done, false);
  });

  test('focus timer records real minutes and survives completion', () async {
    await c.addQuest('a', 60);
    await c.startFocus(c.todayQuests.single);
    expect(bridge.focusTitle, 'a');
    clock = clock.add(const Duration(minutes: 25));
    await c.stopFocus();
    expect(c.todayQuests.single.actualMin, 25);
    expect(bridge.focusTitle, isNull);

    await c.startFocus(c.todayQuests.single);
    clock = clock.add(const Duration(minutes: 10));
    await c.completeQuest(c.todayQuests.single);
    expect(c.todayQuests.single.actualMin, 35);
    expect(c.focusQuestId, isNull);
  });

  test('missed quests come back as penalty quests and break the streak',
      () async {
    await c.addQuest('a', 30);
    await c.addQuest('b', 30);
    await c.completeQuest(c.todayQuests.first);
    final xp = c.player.xp;
    c.events.clear();

    clock = DateTime(2026, 11, 12, 9);
    await c.refresh();
    expect(c.player.lastClosedDay, 20261111);
    expect(c.player.streak, 0);
    expect(c.player.xp, xp);
    expect(c.todayQuests.single.penalty, true);
    expect(c.todayQuests.single.day, 20261112);
    expect(c.events.map((e) => e.title), ['DAY JUDGEMENT', 'DAILY BRIEFING']);
    expect(c.events.first.danger, true);
    expect(c.events.last.body, contains('penalty'));
    expect(c.history[20261111], (1, 1));

    // The briefing is not repeated on the same day.
    c.events.clear();
    await c.refresh();
    expect(c.events, isEmpty);
  });

  test('a cleared day builds the streak; blown budget costs XP', () async {
    await c.addQuest('a', 120);
    await c.completeQuest(c.todayQuests.single);
    expect(c.player.xp, 170); // level 2, floor 100
    bridge.byDay[20261111] = const [
      AppUsage(package: 'com.instagram.android', label: 'Instagram', minutes: 90)
    ];
    clock = DateTime(2026, 11, 12, 9);
    await c.refresh();
    expect(c.player.streak, 1);
    expect(c.player.xp, 120);
  });

  test('watch config carries budget, pending quests and distracting apps',
      () async {
    await c.addQuest('a', 30);
    await c.setDistracting('com.github.android', true);
    await c.setDistracting('com.instagram.android', false);
    final w = bridge.watch!;
    expect(w['pending'], 1);
    expect(w['budgetMin'], 45);
    expect(w['pendingTitles'], ['a']);
    final d = w['distracting'] as List;
    expect(d, contains('com.github.android'));
    expect(d, isNot(contains('com.instagram.android')));
    expect(d, contains('com.google.android.youtube'));
  });

  group('suggestPlan', () {
    test('uses the template offline', () async {
      final (steps, fromLlm) = await c.suggestPlan('flutter prep');
      expect(fromLlm, false);
      expect(steps.length, 6);
    });

    test('uses the LLM once, then the cache', () async {
      final llm = FakeLlm('[{"t":"Widgets","m":45},{"t":"State","m":60}]');
      c = await boot(llm: llm);
      final (steps, fromLlm) = await c.suggestPlan('Flutter Prep');
      expect(fromLlm, true);
      expect(steps.first, const PlanStep('Widgets', 45));
      await c.suggestPlan('flutter prep ');
      expect(llm.calls.length, 1);
      expect(c.tokensToday, 42);
    });

    test('falls back to the template when the LLM fails or rambles', () async {
      final llm = FakeLlm('sorry')..fail = true;
      c = await boot(llm: llm);
      expect((await c.suggestPlan('x')).$2, false);
      llm.fail = false;
      expect((await c.suggestPlan('y')).$2, false);
    });
  });

  group('ask', () {
    test('time-left question is answered offline from the picker', () async {
      await c.addQuest('short', 30);
      await c.addQuest('long', 90, priority: Priority.high);
      await c.ask('I have 40 min, what first?');
      expect(c.chat.last.offline, true);
      expect(c.chat.last.text, contains('"short"'));
    });

    test('LLM words the decision, sees only the chosen facts, and is cached',
        () async {
      final llm = FakeLlm('Begin "short", Player.');
      c = await boot(llm: llm);
      await c.addQuest('short', 30);
      await c.ask('40 min left');
      expect(c.chat.last.text, 'Begin "short", Player.');
      expect(c.chat.last.offline, false);
      expect(llm.calls.single.single.text, contains('Chosen quest: "short"'));
      await c.ask('40 min left');
      expect(llm.calls.length, 1);
    });

    test('free-form chat sends compact context and bounded history', () async {
      final llm = FakeLlm('Noted.');
      c = await boot(llm: llm);
      await c.addQuest('short', 30);
      for (var i = 0; i < 8; i++) {
        await c.ask('question $i');
      }
      final last = llm.calls.last;
      expect(last.length, GameConfig.chatHistoryTurns * 2 + 1);
      expect(last.first.fromUser, true);
      expect(last.last.text, contains('Player says: question 7'));
      expect(last.last.text.length < 400, true);
    });

    test('LLM failure degrades to the offline answer with the reason',
        () async {
      final llm = FakeLlm('x')..fail = true;
      c = await boot(llm: llm);
      await c.ask('status report');
      expect(c.chat.last.offline, true);
      expect(c.chat.last.text, contains('[STATUS: ON TRACK]'));
      expect(c.chat.last.text, contains('down'));
      expect(c.thinking, false);
    });
  });
}
