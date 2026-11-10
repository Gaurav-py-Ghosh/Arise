import 'dart:math';

import 'package:arise/app/controller.dart';
import 'package:arise/domain/models.dart';
import 'package:arise/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  final clock = DateTime(2026, 11, 11, 10); // Wednesday
  const today = 20261111;

  late FakeBridge bridge;

  Future<AppController> boot({
    int xp = 0,
    List<Quest> quests = const [],
    void Function(FakeBridge b)? setup,
  }) async {
    bridge = FakeBridge();
    setup?.call(bridge);
    final store = await memoryStore(isolate: false);
    await store.savePlayer(
        Player(xp: xp, streak: 3, bestStreak: 7, lastClosedDay: today - 1));
    await store.addQuests(quests);
    final c = AppController(
      store: store,
      bridge: bridge,
      now: () => clock,
      rng: Random(1),
    );
    await c.init();
    return c;
  }

  Future<void> pumpApp(WidgetTester tester, AppController c) async {
    await tester.pumpWidget(AriseApp(controller: c));
    await tester.pumpAndSettle();
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.bySemanticsLabel(label));
    await tester.pumpAndSettle();
  }

  testWidgets('status screen renders level and rank', (tester) async {
    // 700 XP is the start of level 5, the floor of rank D.
    final c = await boot(xp: 720);
    await pumpApp(tester, c);

    expect(find.text('LEVEL 5'), findsOneWidget);
    expect(find.text('D'), findsOneWidget);
    expect(find.text('RANK D'), findsOneWidget);
    expect(find.text('20 / 300'), findsOneWidget);
    expect(find.text('3d'), findsOneWidget);
    expect(find.text('7d'), findsOneWidget);
  });

  testWidgets('ticking a quest shows the QUEST COMPLETE window', (tester) async {
    final c = await boot(quests: const [
      Quest(title: 'Write report', day: today, estimateMin: 30),
      Quest(title: 'Review notes', day: today, estimateMin: 45),
    ]);
    await pumpApp(tester, c);
    await openTab(tester, 'QUESTS');

    final q = c.todayQuests.firstWhere((q) => q.title == 'Write report');
    await tester.tap(find.byKey(ValueKey('tick-${q.id}')));
    await tester.pumpAndSettle();

    expect(find.text('[ SYSTEM ]'), findsOneWidget);
    expect(find.text('QUEST COMPLETE'), findsOneWidget);
    expect(find.textContaining('+30 XP'), findsWidgets);
    expect(c.player.xp, 30);

    await tester.tap(find.text('ACKNOWLEDGE'));
    await tester.pumpAndSettle();
    expect(find.text('QUEST COMPLETE'), findsNothing);
  });

  testWidgets('a chat chip produces a System line', (tester) async {
    final c = await boot(quests: const [
      Quest(title: 'Write report', day: today, estimateMin: 30),
    ]);
    await pumpApp(tester, c);
    await openTab(tester, 'SYSTEM');

    await tester.tap(find.text('30m'));
    await tester.pumpAndSettle();

    expect(find.text('> I have 30 min. What should I tackle first?'),
        findsOneWidget);
    expect(find.textContaining('[SYSTEM] [DIRECTIVE] Begin "Write report"'),
        findsOneWidget);
    expect(find.textContaining('// offline template'), findsOneWidget);
    expect(find.text('link: offline'), findsOneWidget);
  });

  testWidgets('a new target drafts the offline plan and is accepted',
      (tester) async {
    final c = await boot();
    await pumpApp(tester, c);
    await openTab(tester, 'QUESTS');

    await tester.tap(find.byKey(const ValueKey('new-quest')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Learn Rust');
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pumpAndSettle();

    expect(find.text('// source: offline template'), findsOneWidget);
    expect(find.text('Learn Rust: fundamentals'), findsOneWidget);

    await tester.ensureVisible(find.text('ACCEPT'));
    await tester.tap(find.text('ACCEPT'));
    await tester.pumpAndSettle();

    expect(c.targets.single.title, 'Learn Rust');
    expect(find.text('NEW QUEST LINE'), findsOneWidget);
  });

  testWidgets('every screen fits a 320dp phone', (tester) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const long = 'An unusually long quest title that keeps going to test wrapping';
    final c = await boot(
      xp: 99999,
      quests: const [
        Quest(title: long, day: today, estimateMin: 240, priority: Priority.high, penalty: true),
        Quest(title: 'Short', day: today, estimateMin: 15, actualMin: 5),
        Quest(title: long, day: today + 1, estimateMin: 90, priority: Priority.low),
      ],
      setup: (b) => b.byDay[today] = const [
        AppUsage(package: 'com.instagram.android', label: 'Instagram with a long name', minutes: 95),
        AppUsage(package: 'com.termux', label: 'Termux', minutes: 30),
        AppUsage(package: 'x.y.z', label: 'Unknown', minutes: 3, systemCategory: 0),
      ],
    );
    await c.addFun(FunKind.book, long);
    await c.startFocus(c.todayQuests.first);
    await pumpApp(tester, c);

    for (final tab in ['QUESTS', 'SYSTEM', 'USAGE', 'VAULT', 'STATUS']) {
      await openTab(tester, tab);
      expect(tester.takeException(), isNull, reason: tab);
    }
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await c.stopFocus();
  });

  testWidgets('the planning sheet and chat survive the keyboard at 320dp',
      (tester) async {
    tester.view.physicalSize = const Size(320, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final c = await boot();
    await pumpApp(tester, c);
    await openTab(tester, 'QUESTS');
    await tester.tap(find.byKey(const ValueKey('new-quest')));
    await tester.pumpAndSettle();

    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.enterText(
        find.byType(TextField), 'Master distributed systems design');
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('// source: offline template'), findsOneWidget);

    await tester.tap(find.text('QUICK QUEST'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await openTab(tester, 'SYSTEM');
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    // The tab bar steps aside for the keyboard; the input stays visible.
    expect(find.bySemanticsLabel('VAULT'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
