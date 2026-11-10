import 'package:flutter/material.dart';

import '../app/controller.dart';
import '../domain/leveling.dart';
import '../domain/models.dart';
import 'quest_sheet.dart';
import 'scope.dart';
import 'theme.dart';
import 'widgets.dart';

class QuestsScreen extends StatelessWidget {
  const QuestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final today = c.today;
    final todays = c.todayQuests;
    final done = todays.where((q) => q.done).length;
    final planned = todays.fold<int>(0, (s, q) => s + q.estimateMin);

    // Upcoming as a flat list: an int is a day header, a Quest is a row.
    final rows = <Object>[];
    int? lastDay;
    for (final q in c.upcoming) {
      if (q.day != lastDay) {
        rows.add(q.day);
        lastDay = q.day;
      }
      rows.add(q);
    }

    return CustomScrollView(
      key: const PageStorageKey('quests'),
      slivers: [
        SliverToBoxAdapter(
          child: ScreenHeader(
            'QUESTS',
            'sys://quests',
            trailing: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SysButton('NEW',
                  key: const ValueKey('new-quest'),
                  icon: Icons.add,
                  dense: true,
                  onPressed: () => showQuestSheet(context)),
            ),
          ),
        ),
        _Section('TODAY',
            trailing: todays.isEmpty ? null : '$done/${todays.length} · ${fmtMin(planned)}'),
        if (todays.isEmpty)
          const _Empty('No quests issued for today. Accept a quest line or add a quick quest.')
        else
          SliverList.builder(
            itemCount: todays.length,
            itemBuilder: (ctx, i) => _tile(ctx, c, todays[i]),
          ),
        const _Section('UPCOMING'),
        if (rows.isEmpty)
          const _Empty('Nothing scheduled ahead. The road is unwritten.')
        else
          SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (ctx, i) {
              final r = rows[i];
              if (r is int) return _DayHeader(day: r, today: today, quests: c.upcoming);
              return _tile(ctx, c, r as Quest);
            },
          ),
        const _Section('QUEST LINES'),
        if (c.targets.isEmpty)
          const _Empty('No quest lines. Set a target and the System will break it into daily quests.')
        else
          SliverList.builder(
            itemCount: c.targets.length,
            itemBuilder: (ctx, i) {
              final t = c.targets[i];
              return _TargetTile(
                target: t,
                progress: c.targetProgress[t.id] ?? (0, 0),
                today: today,
              );
            },
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
      ],
    );
  }

  Widget _tile(BuildContext context, AppController c, Quest q) {
    final running = c.focusQuestId == q.id;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sys.gutter, 0, Sys.gutter, 8),
      child: QuestTile(
        quest: q,
        running: running,
        startedMs: running ? c.focusStartedMs : 0,
        now: c.now,
        onToggle: () => q.done ? c.reopenQuest(q) : c.completeQuest(q),
        onFocus: q.done ? null : () => running ? c.stopFocus() : c.startFocus(q),
        onLongPress: () => _questActions(context, c, q),
      ),
    );
  }

  Future<void> _questActions(BuildContext context, AppController c, Quest q) async {
    final today = c.today;
    final tomorrow = addDays(today, 1);
    final pick = await showActionSheet<int>(
      context,
      title: q.title,
      actions: [
        if (!q.done && q.day <= today)
          (Icons.redo_rounded, 'MOVE TO TOMORROW', tomorrow, false),
        if (!q.done && q.day > today) ...[
          (Icons.today_rounded, 'MOVE TO TODAY', today, false),
          (Icons.redo_rounded, 'PUSH ONE DAY', addDays(q.day, 1), false),
        ],
        (Icons.delete_outline_rounded, 'DELETE', -1, true),
      ],
    );
    if (pick == null) return;
    if (pick == -1) {
      await c.deleteQuest(q);
    } else {
      await c.moveQuest(q, pick);
    }
  }
}

class _Section extends StatelessWidget {
  const _Section(this.label, {this.trailing});

  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sys.gutter, 14, Sys.gutter, 10),
        child: SectionLabel(
          label,
          trailing: trailing == null
              ? null
              : Text(trailing!, style: Sys.label.copyWith(letterSpacing: 1)),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sys.gutter, 0, Sys.gutter, 6),
        child: SystemNote(text),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.today, required this.quests});

  final int day;
  final int today;
  final List<Quest> quests;

  @override
  Widget build(BuildContext context) {
    var total = 0;
    for (final q in quests) {
      if (q.day == day) total += q.estimateMin;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sys.gutter + 2, 4, Sys.gutter, 8),
      child: Row(
        children: [
          Text(fmtDay(day, today: today),
              style: Sys.small.copyWith(
                  color: Sys.accentHi, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          const Expanded(child: SizedBox(height: 1, child: ColoredBox(color: Sys.line))),
          const SizedBox(width: 8),
          Text(fmtMin(total), style: Sys.small),
        ],
      ),
    );
  }
}

/// One quest: tick box, title, minutes, tags, XP and the focus timer button.
class QuestTile extends StatelessWidget {
  const QuestTile({
    super.key,
    required this.quest,
    required this.running,
    required this.startedMs,
    required this.now,
    required this.onToggle,
    required this.onFocus,
    required this.onLongPress,
  });

  final Quest quest;
  final bool running;
  final int startedMs;
  final DateTime Function() now;
  final VoidCallback onToggle;
  final VoidCallback? onFocus;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final q = quest;
    final shape = Sys.shape(
      running ? Sys.accent : (q.penalty && !q.done ? Sys.danger.withValues(alpha: 0.5) : Sys.line),
      radius: Sys.cutSmall,
    );
    final titleColor = q.done ? Sys.dim : Sys.text;
    return Material(
      color: running ? Sys.panelHi : Sys.panel,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 6, 4, 6),
          child: Row(
            children: [
              _TickBox(
                key: ValueKey('tick-${q.id}'),
                done: q.done,
                color: q.penalty ? Sys.danger : Sys.accent,
                onTap: onToggle,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: Sys.font,
                        fontSize: 13.5,
                        height: 1.3,
                        color: titleColor,
                        decoration: q.done ? TextDecoration.lineThrough : null,
                        decorationColor: Sys.dim,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('${q.actualMin}/${q.estimateMin}m',
                            style: Sys.small.copyWith(
                                color: q.actualMin > 0 ? Sys.accentHi : Sys.dim)),
                        if (q.priority == Priority.high)
                          const SysTag('HIGH', color: Sys.gold),
                        if (q.priority == Priority.low) const SysTag('LOW'),
                        if (q.penalty) const SysTag('PENALTY', color: Sys.danger),
                        Text('+${questXp(q)} XP',
                            style: Sys.small.copyWith(
                                color: q.done ? Sys.dim : Sys.gold)),
                      ],
                    ),
                  ],
                ),
              ),
              if (running)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: FocusClock(startedMs: startedMs, now: now),
                ),
              if (onFocus != null)
                IconButton(
                  tooltip: running ? 'Stop timer' : 'Start timer',
                  onPressed: onFocus,
                  icon: Icon(
                    running ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    color: running ? Sys.accent : Sys.dim,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TickBox extends StatelessWidget {
  const _TickBox({super.key, required this.done, required this.color, required this.onTap});

  final bool done;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: done,
      button: true,
      label: done ? 'Reopen quest' : 'Complete quest',
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: done ? color.withValues(alpha: 0.18) : Colors.transparent,
                border: Border.all(color: done ? color : Sys.dim, width: 1.5),
              ),
              child: SizedBox(
                width: 20,
                height: 20,
                child: done ? Icon(Icons.check_rounded, size: 16, color: color) : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TargetTile extends StatelessWidget {
  const _TargetTile({required this.target, required this.progress, required this.today});

  final Target target;
  final (int, int) progress;
  final int today;

  @override
  Widget build(BuildContext context) {
    final (done, total) = progress;
    final t = target;
    final complete = total > 0 && done == total;
    final shape = Sys.shape(complete ? Sys.ok.withValues(alpha: 0.6) : Sys.line,
        radius: Sys.cutSmall);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sys.gutter, 0, Sys.gutter, 8),
      child: Material(
        color: Sys.panel,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onLongPress: () => _delete(context, total),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(t.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Sys.body.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    if (t.priority == Priority.high) ...[
                      const SizedBox(width: 8),
                      const SysTag('HIGH', color: Sys.gold),
                    ],
                    if (complete) ...[
                      const SizedBox(width: 8),
                      const SysTag('CLEARED', color: Sys.ok),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                SysBar(value: total == 0 ? 0 : done / total, color: complete ? Sys.ok : Sys.accent),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text('$done/$total quests', style: Sys.small),
                    const Spacer(),
                    if (t.deadline != null)
                      Text(_deadline(t.deadline!),
                          style: Sys.small.copyWith(
                              color: daysBetween(today, t.deadline!) <= 3 && !complete
                                  ? Sys.gold
                                  : Sys.dim)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _deadline(int dl) {
    final left = daysBetween(today, dl);
    if (left < 0) return 'DEADLINE PASSED';
    if (left == 0) return 'DUE TODAY';
    return 'DUE ${fmtDay(dl, today: today)} · ${left}d';
  }

  Future<void> _delete(BuildContext context, int total) async {
    final c = AppScope.read(context);
    final ok = await confirmSystem(
      context,
      title: 'ABANDON QUEST LINE',
      body: '"${target.title}" and its $total quest(s) will be erased. '
          'XP already earned is kept.',
      confirm: 'ABANDON',
    );
    if (ok) await c.deleteTarget(target.id!);
  }
}
