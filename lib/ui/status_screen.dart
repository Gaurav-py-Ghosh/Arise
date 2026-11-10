import 'package:flutter/material.dart';

import '../app/controller.dart';
import '../domain/deviation.dart';
import '../domain/leveling.dart';
import '../domain/models.dart';
import '../domain/picker.dart';
import 'scope.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'widgets.dart';

class StatusScreen extends StatelessWidget {
  const StatusScreen({super.key, this.onOpenTab});

  /// Switches the shell to another tab (1 = QUESTS, 3 = USAGE).
  final ValueChanged<int>? onOpenTab;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final rep = c.report;
    return ListView(
      key: const PageStorageKey('status'),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        ScreenHeader(
          'ARISE',
          'sys://player',
          trailing: IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.tune_rounded, color: Sys.dim),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const SettingsScreen())),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sys.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PlayerPanel(player: c.player, level: c.level),
              if (!c.usageAccess) ...[
                const SizedBox(height: Sys.gap),
                GrantAccessPanel(onGrant: c.bridge.openUsageAccess),
              ],
              const SizedBox(height: Sys.gap),
              _DirectivePanel(controller: c, onOpenQuests: () => onOpenTab?.call(1)),
              if (rep != null) ...[
                const SizedBox(height: Sys.gap),
                _TodayPanel(report: rep),
                if (c.usageAccess) ...[
                  const SizedBox(height: Sys.gap),
                  _DistractionPanel(
                      report: rep, onOpenUsage: () => onOpenTab?.call(3)),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PlayerPanel extends StatelessWidget {
  const _PlayerPanel({required this.player, required this.level});

  final Player player;
  final LevelInfo level;

  @override
  Widget build(BuildContext context) {
    final rank = rankFor(level.level);
    return SysPanel(
      label: 'STATUS',
      glow: true,
      trailing: Text('${player.xp} XP TOTAL',
          style: Sys.label.copyWith(color: Sys.dim, letterSpacing: 1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _RankBox(rank: rank),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('RANK $rank', style: Sys.label.copyWith(color: Sys.accent)),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'LEVEL ${level.level}',
                        style: const TextStyle(
                          fontFamily: Sys.font,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                          color: Sys.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SysBar(value: level.progress, height: 7, segments: 30),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('XP', style: Sys.small.copyWith(letterSpacing: 2)),
              const Spacer(),
              Text('${level.into} / ${level.needed}',
                  style: Sys.small.copyWith(color: Sys.accentHi)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'STREAK',
                  value: '${player.streak}d',
                  color: player.streak > 0 ? Sys.gold : Sys.text,
                ),
              ),
              Expanded(
                child: _Stat(label: 'BEST', value: '${player.bestStreak}d'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RankBox extends StatelessWidget {
  const _RankBox({required this.rank});

  final String rank;

  @override
  Widget build(BuildContext context) {
    final color = rank == 'S' ? Sys.gold : Sys.accentHi;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: Sys.panelHi,
        shape: Sys.shape(color.withValues(alpha: 0.8), width: 1.5, radius: Sys.cut),
      ),
      child: SizedBox(
        width: 72,
        height: 72,
        child: Center(
          child: Text(
            rank,
            style: TextStyle(
              fontFamily: Sys.font,
              fontSize: 40,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color = Sys.text});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Sys.label.copyWith(fontSize: 10)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontFamily: Sys.font,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color)),
      ],
    );
  }
}

class _DirectivePanel extends StatelessWidget {
  const _DirectivePanel({required this.controller, required this.onOpenQuests});

  final AppController controller;
  final VoidCallback onOpenQuests;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final running = c.focusQuestId == null
        ? null
        : c.todayQuests.where((q) => q.id == c.focusQuestId).firstOrNull ??
            c.upcoming.where((q) => q.id == c.focusQuestId).firstOrNull;

    if (running != null) {
      return SysPanel(
        label: 'QUEST IN PROGRESS',
        accent: Sys.accent,
        trailing: FocusClock(startedMs: c.focusStartedMs, now: c.now),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(running.title,
                style: Sys.body.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('${running.actualMin}/${running.estimateMin}m logged before this run',
                style: Sys.small),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SysButton('STOP',
                      icon: Icons.stop_rounded, onPressed: c.stopFocus),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SysButton('COMPLETE',
                      icon: Icons.check_rounded,
                      filled: true,
                      color: Sys.ok,
                      onPressed: () => c.completeQuest(running)),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final done = c.report?.doneMin ?? 0;
    var left = c.settings.capacityFor(c.today) - done;
    // Past capacity, still name something: the clock is not the excuse.
    if (left < 15) left = 15;
    final pick = pickNext(c.todayQuests, left, c.today).first;

    if (pick == null) {
      final anyToday = c.todayQuests.isNotEmpty;
      return SysPanel(
        label: 'NEXT DIRECTIVE',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SystemNote(anyToday
                ? 'All directives for today are cleared. Rest is permitted.'
                : 'No directives issued. Set a target and the System will plan the path.'),
            if (!anyToday) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: SysButton('OPEN QUESTS',
                    icon: Icons.add, onPressed: onOpenQuests),
              ),
            ],
          ],
        ),
      );
    }

    final q = pick.quest;
    return SysPanel(
      label: 'NEXT DIRECTIVE',
      trailing: Text('${fmtMin(left)} LEFT',
          style: Sys.label.copyWith(letterSpacing: 1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(q.title,
              style: Sys.body.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(pick.fits ? fmtMin(pick.minutes) : '${fmtMin(pick.minutes)} of ${fmtMin(q.remainingMin)}',
                  style: Sys.small.copyWith(color: Sys.text)),
              if (q.priority == Priority.high) const SysTag('HIGH', color: Sys.gold),
              if (q.penalty) const SysTag('PENALTY', color: Sys.danger),
              Text('+${questXp(q)} XP', style: Sys.small.copyWith(color: Sys.gold)),
            ],
          ),
          if (pick.reasons.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('// ${pick.reasons.join(' · ')}', style: Sys.small),
          ],
          const SizedBox(height: 12),
          SysButton('BEGIN',
              icon: Icons.play_arrow_rounded,
              filled: true,
              onPressed: () => c.startFocus(q)),
        ],
      ),
    );
  }
}

class _TodayPanel extends StatelessWidget {
  const _TodayPanel({required this.report});

  final DeviationReport report;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (report.level) {
      DeviationLevel.onTrack => ('ON TRACK', Sys.ok),
      DeviationLevel.warning => ('WARNING', Sys.gold),
      DeviationLevel.deviating => ('DEVIATION', Sys.danger),
    };
    final planned = report.plannedMin;
    return SysPanel(
      label: 'TODAY',
      accent: report.level == DeviationLevel.deviating ? Sys.danger : null,
      trailing: SysTag(label, color: color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Figure(
            value: fmtMin(report.doneMin),
            of: '/ ${fmtMin(planned)} planned',
            side: '${report.pendingQuests} pending',
            sideColor: report.pendingQuests > 0 ? Sys.accentHi : Sys.dim,
          ),
          const SizedBox(height: 8),
          SysBar(
            value: planned == 0 ? 0 : report.doneMin / planned,
            color: Sys.ok,
          ),
          if (report.reasons.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final r in report.reasons)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('> $r', style: Sys.small.copyWith(color: color, height: 1.4)),
              ),
          ] else if (planned == 0) ...[
            const SizedBox(height: 10),
            const SystemNote('Nothing planned today. An empty day does not extend the streak.'),
          ],
        ],
      ),
    );
  }
}

class _DistractionPanel extends StatelessWidget {
  const _DistractionPanel({required this.report, required this.onOpenUsage});

  final DeviationReport report;
  final VoidCallback onOpenUsage;

  @override
  Widget build(BuildContext context) {
    final over = report.distractionMin > report.budgetMin;
    final color = over
        ? Sys.danger
        : report.budgetMin > 0 && report.distractionMin >= report.budgetMin * 0.8
            ? Sys.gold
            : Sys.accent;
    return SysPanel(
      label: 'DISTRACTION',
      trailing: InkWell(
        onTap: onOpenUsage,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text('DETAILS >', style: Sys.label.copyWith(color: Sys.accent, letterSpacing: 1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Figure(
            value: fmtMin(report.distractionMin),
            valueColor: over ? Sys.danger : Sys.text,
            of: '/ ${fmtMin(report.budgetMin)} budget',
            side: over ? '+${fmtMin(report.overBudgetBy)} OVER' : null,
            sideColor: Sys.danger,
          ),
          const SizedBox(height: 8),
          SysBar(
            value: report.budgetMin == 0
                ? (report.distractionMin > 0 ? 1 : 0)
                : report.distractionMin / report.budgetMin,
            color: color,
          ),
          const SizedBox(height: 10),
          if (report.offenders.isEmpty)
            const SystemNote('No distracting apps used today. Maintain this.')
          else
            for (final a in report.offenders.take(3))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(a.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Sys.body.copyWith(fontSize: 13)),
                    ),
                    Text(fmtMin(a.minutes),
                        style: Sys.small.copyWith(color: Sys.accentHi)),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// `1h 20m / 2h planned        3 pending`, safe at any width.
class _Figure extends StatelessWidget {
  const _Figure({
    required this.value,
    required this.of,
    this.side,
    this.valueColor = Sys.text,
    this.sideColor = Sys.dim,
  });

  final String value;
  final String of;
  final String? side;
  final Color valueColor;
  final Color sideColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(value,
            style: TextStyle(
                fontFamily: Sys.font,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: valueColor)),
        const SizedBox(width: 6),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(of,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: Sys.small),
          ),
        ),
        if (side != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 2, left: 8),
              child: Text(side!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Sys.small
                      .copyWith(color: sideColor, fontWeight: FontWeight.w700)),
            ),
          ),
      ],
    );
  }
}
