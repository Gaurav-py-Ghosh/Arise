import 'package:flutter/material.dart';

import '../domain/app_catalog.dart';
import '../domain/models.dart';
import 'scope.dart';
import 'theme.dart';
import 'widgets.dart';

class UsageScreen extends StatelessWidget {
  const UsageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    const header = SliverToBoxAdapter(child: ScreenHeader('USAGE', 'sys://sensor'));
    if (!c.usageAccess) {
      return CustomScrollView(
        slivers: [
          header,
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: Sys.gutter),
            sliver: SliverToBoxAdapter(
              child: GrantAccessPanel(onGrant: c.bridge.openUsageAccess),
            ),
          ),
        ],
      );
    }

    final rep = c.report;
    final apps = c.usage.where((u) => u.minutes > 0).toList(growable: false);
    final total = apps.fold<int>(0, (s, u) => s + u.minutes);
    final cats = rep?.byCategory ?? const <String, int>{};
    final maxCat = cats.isEmpty ? 1 : cats.values.first;

    return CustomScrollView(
      key: const PageStorageKey('usage'),
      slivers: [
        header,
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: Sys.gutter),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SysPanel(
                  label: 'SCREEN TIME TODAY',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(fmtMin(total),
                          style: const TextStyle(
                              fontFamily: Sys.font,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                              color: Sys.text)),
                      if (rep != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text('DISTRACTION',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Sys.label.copyWith(fontSize: 10)),
                            ),
                            Text('${fmtMin(rep.distractionMin)} / ${fmtMin(rep.budgetMin)}',
                                style: Sys.small.copyWith(
                                    color: rep.overBudgetBy > 0 ? Sys.danger : Sys.accentHi)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SysBar(
                          value: rep.budgetMin == 0
                              ? (rep.distractionMin > 0 ? 1 : 0)
                              : rep.distractionMin / rep.budgetMin,
                          color: rep.overBudgetBy > 0 ? Sys.danger : Sys.gold,
                        ),
                      ],
                    ],
                  ),
                ),
                if (cats.isNotEmpty) ...[
                  const SizedBox(height: Sys.gap),
                  SysPanel(
                    label: 'BY CATEGORY',
                    child: Column(
                      children: [
                        for (final e in cats.entries)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 76,
                                  child: Text(e.key.toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Sys.small.copyWith(letterSpacing: 1)),
                                ),
                                Expanded(
                                  child: SysBar(
                                    value: e.value / maxCat,
                                    segments: 16,
                                    height: 5,
                                    color: _distractingCategory(e.key) ? Sys.gold : Sys.accent,
                                  ),
                                ),
                                SizedBox(
                                  width: 60,
                                  child: Text(fmtMin(e.value),
                                      textAlign: TextAlign.right,
                                      style: Sys.small.copyWith(color: Sys.text)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SectionLabel('APPS',
                    trailing: Text('distracting?', style: Sys.label.copyWith(letterSpacing: 1))),
                const SizedBox(height: 6),
                if (apps.isEmpty)
                  const SystemNote('No screen time recorded yet today.'),
              ],
            ),
          ),
        ),
        SliverList.builder(
          itemCount: apps.length,
          itemBuilder: (ctx, i) {
            final u = apps[i];
            final value = isDistracting(u.package, u.systemCategory, c.rules);
            final custom = c.rules.containsKey(u.package);
            return _AppRow(
              usage: u,
              distracting: value,
              custom: custom,
              onChanged: (v) => c.setDistracting(u.package, v),
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  static bool _distractingCategory(String cat) =>
      cat == social || cat == video || cat == games || cat == shopping;
}

class _AppRow extends StatelessWidget {
  const _AppRow({
    required this.usage,
    required this.distracting,
    required this.custom,
    required this.onChanged,
  });

  final AppUsage usage;
  final bool distracting;
  final bool custom;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final u = usage;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sys.gutter, 2, 8, 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Sys.body.copyWith(
                        fontSize: 13, color: distracting ? Sys.gold : Sys.text)),
                Text(
                  '${categoryOf(u.package, u.systemCategory)} · ${custom ? 'your rule' : 'default'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Sys.small.copyWith(
                      fontSize: 10.5, color: custom ? Sys.accent : Sys.dim),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(fmtMin(u.minutes), style: Sys.small.copyWith(color: Sys.accentHi)),
          Switch(value: distracting, onChanged: onChanged),
        ],
      ),
    );
  }
}
