import 'package:arise/domain/models.dart';
import 'package:arise/domain/planner.dart';
import 'package:flutter_test/flutter_test.dart';

int cap(int day) => isWeekend(day) ? 240 : 120;

void main() {
  // 2026-11-11 is a Wednesday.
  const wed = 20261111;

  test('fills days up to capacity then moves on', () {
    final qs = schedulePlan(
      steps: const [PlanStep('a', 60), PlanStep('b', 60), PlanStep('c', 45)],
      startDay: wed,
      capacityFor: cap,
    );
    expect(qs.map((q) => q.day), [wed, wed, 20261112]);
  });

  test('never exceeds capacity on any day', () {
    final qs = schedulePlan(
      steps: templatePlan('flutter prep'),
      startDay: wed,
      capacityFor: cap,
      alreadyPlanned: const {wed: 90},
    );
    final perDay = <int, int>{wed: 90};
    for (final q in qs) {
      perDay[q.day] = (perDay[q.day] ?? 0) + q.estimateMin;
    }
    perDay.forEach((d, m) => expect(m <= cap(d), true, reason: '$d has $m'));
    expect(qs.fold<int>(0, (s, q) => s + q.estimateMin), 300);
  });

  test('a step that does not fit the rest of today moves whole', () {
    final qs = schedulePlan(
      steps: const [PlanStep('big', 100)],
      startDay: wed,
      capacityFor: cap,
      alreadyPlanned: const {wed: 60},
    );
    expect(qs.single.day, 20261112);
    expect(qs.single.title, 'big');
  });

  test('a step larger than a full day is split into parts', () {
    final qs = schedulePlan(
      steps: const [PlanStep('epic', 300)],
      startDay: wed,
      capacityFor: cap,
    );
    expect(qs.map((q) => q.estimateMin), [120, 120, 60]);
    expect(qs.map((q) => q.day), [wed, 20261112, 20261113]);
    expect(qs.first.title, 'epic (part 1)');
  });

  test('skips zero-capacity days and carries target fields', () {
    final qs = schedulePlan(
      steps: const [PlanStep('a', 30)],
      startDay: wed,
      capacityFor: (d) => d == wed ? 0 : 60,
      targetId: 7,
      priority: Priority.high,
      deadline: 20261120,
    );
    final q = qs.single;
    expect([q.day, q.targetId, q.priority, q.deadline],
        [20261112, 7, Priority.high, 20261120]);
  });

  test('no capacity anywhere still terminates', () {
    final qs = schedulePlan(
      steps: const [PlanStep('a', 30)],
      startDay: wed,
      capacityFor: (_) => 0,
    );
    expect(qs.single.estimateMin, 30);
  });

  group('parsePlanSteps', () {
    test('reads compact JSON', () {
      expect(parsePlanSteps('[{"t":"Widgets","m":45},{"t":"State","m":60}]'),
          const [PlanStep('Widgets', 45), PlanStep('State', 60)]);
    });
    test('tolerates fences, prose and long keys', () {
      const raw = 'Here:\n```json\n[{"title":"A","minutes":"30"}]\n```';
      expect(parsePlanSteps(raw), const [PlanStep('A', 30)]);
    });
    test('clamps silly durations and drops broken entries', () {
      expect(parsePlanSteps('[{"t":"x","m":9999},{"t":"","m":5},{"m":5},3]'),
          const [PlanStep('x', 240)]);
    });
    test('returns empty on garbage', () {
      expect(parsePlanSteps('no idea'), isEmpty);
      expect(parsePlanSteps('[{"t":'), isEmpty);
    });
  });
}
