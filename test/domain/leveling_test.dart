import 'package:arise/core/game_config.dart';
import 'package:arise/domain/leveling.dart';
import 'package:arise/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('level curve grows by a fixed step', () {
    expect(xpToNext(1), 100);
    expect(xpToNext(2), 150);
    final l1 = levelFor(0);
    expect([l1.level, l1.into, l1.needed], [1, 0, 100]);
    final l2 = levelFor(100);
    expect([l2.level, l2.into, l2.floorXp], [2, 0, 100]);
    final l3 = levelFor(260);
    expect([l3.level, l3.into, l3.floorXp], [3, 10, 250]);
  });

  test('ranks follow level floors', () {
    expect(rankFor(1), 'E');
    expect(rankFor(4), 'E');
    expect(rankFor(5), 'D');
    expect(rankFor(49), 'A');
    expect(rankFor(80), 'S');
  });

  test('next rank and titles', () {
    expect(nextRank(1), ('D', 5));
    expect(nextRank(5), ('C', 10));
    expect(nextRank(50), isNull);
    expect(titleFor(const Player(), 1), 'INITIATE');
    expect(titleFor(const Player(), 12), 'ADEPT');
    expect(titleFor(const Player(streak: 7), 12), 'DISCIPLINED');
  });

  test('quest XP scales with estimate and priority, halves for penalty', () {
    const q = Quest(title: 'a', day: 20261111, estimateMin: 60);
    expect(questXp(q), 60);
    expect(questXp(q.copyWith(priority: Priority.high)), 75);
    expect(questXp(q.copyWith(priority: Priority.low)), 48);
    expect(questXp(q.copyWith(penalty: true)), 30);
    expect(questXp(q.copyWith(estimateMin: 2)), GameConfig.minQuestXp);
  });

  test('XP loss never drops a level', () {
    expect(applyXpLoss(180, 50), 130);
    expect(applyXpLoss(120, 50), 100);
    expect(levelFor(applyXpLoss(120, 50)).level, 2);
    expect(applyXpLoss(20, 50), 0);
  });

  test('day keys round-trip and cross month ends', () {
    expect(dayKey(DateTime(2026, 11, 11)), 20261111);
    expect(addDays(20261130, 1), 20261201);
    expect(addDays(20270101, -1), 20261231);
    expect(daysBetween(20261128, 20261202), 4);
    expect(isWeekend(20261114), true);
    expect(isWeekend(20261111), false);
    expect(fmtMin(95), '1h 35m');
    expect(fmtDay(20261112, today: 20261111), 'TOMORROW');
  });
}
