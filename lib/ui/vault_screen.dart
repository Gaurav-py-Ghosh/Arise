import 'package:flutter/material.dart';

import '../domain/models.dart';
import 'scope.dart';
import 'theme.dart';
import 'widgets.dart';

/// Games, movies, books and music, doubling as rewards for a cleared day.
class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

String _kindLabel(FunKind k) => switch (k) {
      FunKind.game => 'GAME',
      FunKind.movie => 'MOVIE',
      FunKind.book => 'BOOK',
      FunKind.music => 'MUSIC',
    };

IconData _kindIcon(FunKind k) => switch (k) {
      FunKind.game => Icons.sports_esports_outlined,
      FunKind.movie => Icons.movie_outlined,
      FunKind.book => Icons.menu_book_outlined,
      FunKind.music => Icons.music_note_outlined,
    };

class _VaultScreenState extends State<VaultScreen> {
  FunKind? _filter;
  FunKind _kind = FunKind.game;
  final _title = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _add() {
    final t = _title.text.trim();
    if (t.isEmpty) return;
    AppScope.read(context).addFun(_kind, t);
    _title.clear();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final items = _filter == null
        ? c.fun
        : c.fun.where((f) => f.kind == _filter).toList(growable: false);
    final waiting = c.fun.where((f) => f.status != FunStatus.done).length;

    return CustomScrollView(
      key: const PageStorageKey('vault'),
      slivers: [
        SliverToBoxAdapter(
          child: ScreenHeader(
            'VAULT',
            'sys://rewards',
            trailing: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text('$waiting IN RESERVE',
                  style: Sys.label.copyWith(letterSpacing: 1)),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: Sys.gutter),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Clearing every quest of a day unlocks one unfinished item at random.',
                    style: Sys.small.copyWith(height: 1.4)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    PopupMenuButton<FunKind>(
                      tooltip: 'Kind',
                      initialValue: _kind,
                      onSelected: (k) => setState(() => _kind = k),
                      itemBuilder: (_) => [
                        for (final k in FunKind.values)
                          PopupMenuItem(
                            value: k,
                            child: Row(
                              children: [
                                Icon(_kindIcon(k), size: 18, color: Sys.accent),
                                const SizedBox(width: 10),
                                Text(_kindLabel(k)),
                              ],
                            ),
                          ),
                      ],
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          border: Border.fromBorderSide(BorderSide(color: Sys.line)),
                        ),
                        child: SizedBox(
                          height: 44,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_kindIcon(_kind), size: 18, color: Sys.accent),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_drop_down, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _title,
                        style: Sys.body,
                        maxLength: 80,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          hintText: 'Add ${_kindLabel(_kind).toLowerCase()}',
                          counterText: '',
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 13),
                        ),
                        onSubmitted: (_) => _add(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Add to Vault',
                      child: SysButton('', icon: Icons.add, onPressed: _add),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ChoiceChips<FunKind?>(
                  options: const [
                    ('ALL', null),
                    ('GAMES', FunKind.game),
                    ('MOVIES', FunKind.movie),
                    ('BOOKS', FunKind.book),
                    ('MUSIC', FunKind.music),
                  ],
                  selected: _filter,
                  onSelected: (k) => setState(() => _filter = k),
                ),
                const SizedBox(height: 14),
                if (items.isEmpty)
                  SystemNote(c.fun.isEmpty
                      ? 'The Vault is empty. Store what you enjoy here; the System hands it out as rewards.'
                      : 'Nothing of this kind in the Vault.'),
              ],
            ),
          ),
        ),
        SliverList.builder(
          itemCount: items.length,
          itemBuilder: (ctx, i) => _FunRow(item: items[i]),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _FunRow extends StatelessWidget {
  const _FunRow({required this.item});

  final FunItem item;

  @override
  Widget build(BuildContext context) {
    final f = item;
    final done = f.status == FunStatus.done;
    final (label, color) = switch (f.status) {
      FunStatus.backlog => ('BACKLOG', Sys.dim),
      FunStatus.active => ('ACTIVE', Sys.accent),
      FunStatus.done => ('DONE', Sys.ok),
    };
    final next = FunStatus.values[(f.status.index + 1) % FunStatus.values.length];
    return InkWell(
      onLongPress: () async {
        final c = AppScope.read(context);
        final ok = await confirmSystem(context,
            title: 'REMOVE FROM VAULT',
            body: '"${f.title}" will be removed.',
            confirm: 'REMOVE');
        if (ok) await c.deleteFun(f);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sys.gutter, 6, Sys.gutter, 6),
        child: Row(
          children: [
            Icon(_kindIcon(f.kind), size: 18, color: done ? Sys.line : Sys.dim),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                f.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Sys.body.copyWith(
                  fontSize: 13,
                  color: done ? Sys.dim : Sys.text,
                  decoration: done ? TextDecoration.lineThrough : null,
                  decorationColor: Sys.dim,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 96,
              child: SysButton(
                label,
                dense: true,
                color: color,
                onPressed: () => AppScope.read(context).setFunStatus(f, next),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
