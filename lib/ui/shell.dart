import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/controller.dart';
import '../system/bridge.dart';
import 'chat_screen.dart';
import 'quests_screen.dart';
import 'status_screen.dart';
import 'theme.dart';
import 'usage_screen.dart';
import 'vault_screen.dart';
import 'widgets.dart';

/// Five tabs and the System window queue.
class Shell extends StatefulWidget {
  const Shell({super.key, required this.controller});

  final AppController controller;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int _tab = 0;

  /// Alerts that came from Android rather than the controller.
  final List<SystemEvent> _alerts = [];
  bool _showing = false;

  /// Keeps scroll offsets of tabs that are not built.
  final _bucket = PageStorageBucket();

  AppController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c.addListener(_schedule);
    final b = c.bridge;
    if (b is AndroidBridge) {
      b.onAlert((text) {
        _alerts.add(_alertEvent(text));
        _schedule();
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final launch = await c.bridge.consumeLaunchAlert();
      if (launch != null) _alerts.add(_alertEvent(launch));
      _schedule();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.removeListener(_schedule);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && c.ready) c.refresh();
  }

  /// Alerts arrive as "TITLE\n\nbody".
  static SystemEvent _alertEvent(String text) {
    final i = text.indexOf('\n');
    if (i < 0) return SystemEvent('SYSTEM ALERT', text, danger: true);
    return SystemEvent(text.substring(0, i).trim(), text.substring(i).trim(),
        danger: true);
  }

  void _schedule() {
    if (_showing || (_alerts.isEmpty && c.events.isEmpty)) return;
    _showing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _drain());
  }

  /// Shows queued events one at a time.
  Future<void> _drain() async {
    while (mounted) {
      final e = _alerts.isNotEmpty ? _alerts.removeAt(0) : c.takeEvent();
      if (e == null) break;
      await showSystemWindow(context, e);
    }
    _showing = false;
  }

  void _select(int i) {
    if (i == _tab) return;
    HapticFeedback.selectionClick();
    c.sfx('tick');
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: PageStorage(
          bucket: _bucket,
          // Only the visible tab is built.
          child: switch (_tab) {
            0 => StatusScreen(onOpenTab: _select),
            1 => const QuestsScreen(),
            2 => const ChatScreen(),
            3 => const UsageScreen(),
            _ => const VaultScreen(),
          },
        ),
      ),
      bottomNavigationBar:
          keyboard ? null : _NavBar(index: _tab, onSelect: _select),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  static const _items = [
    (Icons.shield_outlined, 'STATUS'),
    (Icons.checklist_rounded, 'QUESTS'),
    (Icons.terminal_rounded, 'SYSTEM'),
    (Icons.timelapse_rounded, 'USAGE'),
    (Icons.inventory_2_outlined, 'VAULT'),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Sys.panel,
        border: Border(top: BorderSide(color: Sys.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _NavItem(
                    icon: _items[i].$1,
                    label: _items[i].$2,
                    on: i == index,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.on,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = on ? Sys.accent : Sys.dim;
    return Semantics(
      selected: on,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        splashColor: Sys.accent.withValues(alpha: 0.12),
        highlightColor: Colors.transparent,
        child: Column(
          children: [
            SizedBox(
              height: 2,
              width: double.infinity,
              child: on ? const ColoredBox(color: Sys.accent) : null,
            ),
            const Spacer(),
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: Sys.font,
                  fontSize: 10,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                  letterSpacing: 1.2,
                  color: color,
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
