import 'package:arise/domain/models.dart';
import 'package:arise/domain/picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const today = 20261111;
  Quest q(int id, int est,
          {Priority p = Priority.normal,
          int? dl,
          bool penalty = false,
          bool done = false,
          int day = today,
          int actual = 0}) =>
      Quest(
          id: id,
          title: 'q$id',
          day: day,
          estimateMin: est,
          priority: p,
          deadline: dl,
          penalty: penalty,
          done: done,
          actualMin: actual);

  test('nothing pending gives no pick', () {
    expect(pickNext([q(1, 30, done: true)], 60, today).first, isNull);
    expect(pickNext([q(1, 30)], 0, today).first, isNull);
  });

  test('ignores future quests', () {
    expect(pickNext([q(1, 30, day: 20261112)], 60, today).first, isNull);
  });

  test('a fitting quest beats a higher priority one that does not fit', () {
    final r = pickNext([q(1, 120, p: Priority.high), q(2, 30)], 40, today);
    expect(r.first!.quest.id, 2);
    expect(r.first!.fits, true);
  });

  test('urgent deadline wins among quests that fit', () {
    final r = pickNext(
        [q(1, 30, p: Priority.high), q(2, 30, dl: today)], 40, today);
    expect(r.first!.quest.id, 2);
    expect(r.first!.reasons, contains('deadline within a day'));
  });

  test('penalty quests are pushed forward', () {
    final r = pickNext([q(1, 30), q(2, 30, penalty: true)], 40, today);
    expect(r.first!.quest.id, 2);
  });

  test('when nothing fits, picks the best and caps minutes to the window', () {
    final r = pickNext([q(1, 90), q(2, 120, p: Priority.high)], 25, today);
    expect(r.first!.quest.id, 2);
    expect(r.first!.fits, false);
    expect(r.first!.minutes, 25);
    expect(r.queue, isEmpty);
  });

  test('queue packs the window without overflowing it', () {
    final r = pickNext([q(1, 30), q(2, 20), q(3, 25), q(4, 50)], 60, today);
    final total = r.queue.fold<int>(0, (s, p) => s + p.minutes);
    expect(total <= 60, true);
    expect(r.queue.length, 2);
  });

  test('uses remaining minutes for a started quest', () {
    final r = pickNext([q(1, 90, actual: 70)], 30, today);
    expect(r.first!.fits, true);
    expect(r.first!.minutes, 20);
  });
}
