import 'package:arise/domain/app_catalog.dart';
import 'package:arise/domain/deviation.dart';
import 'package:arise/domain/models.dart';
import 'package:arise/domain/rollover.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const today = 20261111;
  const insta = AppUsage(
      package: 'com.instagram.android', label: 'Instagram', minutes: 40);
  const yt = AppUsage(
      package: 'com.google.android.youtube', label: 'YouTube', minutes: 30);
  const gh =
      AppUsage(package: 'com.github.android', label: 'GitHub', minutes: 50);
  const pending = Quest(title: 'a', day: today, estimateMin: 60);

  group('app catalog', () {
    test('defaults', () {
      expect(defaultDistracting('com.instagram.android', -1), true);
      expect(defaultDistracting('com.github.android', -1), false);
      expect(defaultDistracting('some.unknown.game', 0), true);
      expect(defaultDistracting('some.unknown.app', -1), false);
    });
    test('user override wins both ways', () {
      expect(isDistracting('com.instagram.android', -1, {'com.instagram.android': false}), false);
      expect(isDistracting('com.github.android', -1, {'com.github.android': true}), true);
    });
  });

  group('evaluateDeviation', () {
    DeviationReport run(List<AppUsage> u,
            {int budget = 45,
            List<Quest> quests = const [pending],
            int hour = 12,
            Map<String, bool> rules = const {}}) =>
        evaluateDeviation(
            usage: u,
            rules: rules,
            budgetMin: budget,
            todayQuests: quests,
            hourOfDay: hour);

    test('over budget with quests pending is deviating', () {
      final r = run([insta, yt, gh]);
      expect(r.level, DeviationLevel.deviating);
      expect(r.distractionMin, 70);
      expect(r.overBudgetBy, 25);
      expect(r.offenders.first.label, 'Instagram');
      expect(r.byCategory.keys.first, 'dev');
    });

    test('over budget with nothing pending is fine', () {
      final r = run([insta, yt], quests: [pending.copyWith(done: true)]);
      expect(r.level, DeviationLevel.onTrack);
      expect(r.doneMin, 60);
    });

    test('near the budget is a warning', () {
      expect(run([insta]).level, DeviationLevel.warning);
      expect(run([yt]).level, DeviationLevel.onTrack);
    });

    test('behind plan late in the day is a warning', () {
      expect(run([], hour: 19).level, DeviationLevel.warning);
      expect(run([], hour: 19, quests: [pending.copyWith(actualMin: 40)]).level,
          DeviationLevel.onTrack);
    });

    test('override removes an app from the distraction total', () {
      final r = run([insta, yt], rules: {'com.instagram.android': false});
      expect(r.distractionMin, 30);
    });
  });

  group('computeRollover', () {
    const p = Player(xp: 180, streak: 3, bestStreak: 3, lastClosedDay: 20261108);

    test('cleared day extends the streak', () {
      final r = computeRollover(
          p, const [DaySummary(day: 20261109, totalQuests: 2, doneQuests: 2)]);
      expect(r.player.streak, 4);
      expect(r.player.bestStreak, 4);
      expect(r.player.lastClosedDay, 20261109);
    });

    test('missed quests reset the streak but keep the best', () {
      final r = computeRollover(
          p, const [DaySummary(day: 20261109, totalQuests: 3, doneQuests: 1)]);
      expect(r.player.streak, 0);
      expect(r.player.bestStreak, 3);
      expect(r.questsMissed, 2);
    });

    test('empty day leaves the streak alone', () {
      final r = computeRollover(
          p, const [DaySummary(day: 20261109, totalQuests: 0, doneQuests: 0)]);
      expect(r.player.streak, 3);
    });

    test('blown budget costs XP but never a level', () {
      final r = computeRollover(p.copyWith(xp: 120), const [
        DaySummary(
            day: 20261109,
            totalQuests: 1,
            doneQuests: 1,
            distractionMin: 90,
            budgetMin: 45)
      ]);
      expect(r.player.xp, 100);
      expect(r.xpLost, 20);
    });

    test('already closed days are skipped, several days chain', () {
      final r = computeRollover(p, const [
        DaySummary(day: 20261108, totalQuests: 1, doneQuests: 0),
        DaySummary(day: 20261109, totalQuests: 1, doneQuests: 1),
        DaySummary(day: 20261110, totalQuests: 1, doneQuests: 1),
      ]);
      expect(r.player.streak, 5);
      expect(r.player.lastClosedDay, 20261110);
      expect(r.log.length, 2);
    });
  });
}
