import 'package:flutter/material.dart';

import '../app/controller.dart';
import 'theme.dart';
import 'widgets.dart';

/// The cold-start screen: the logo fades in, then the System reports in line
/// by line. It stays at least [minDuration] so it reads as a moment rather
/// than a flash, and a tap skips the rest once the app is ready.
class BootScreen extends StatefulWidget {
  const BootScreen({
    super.key,
    required this.controller,
    required this.onDone,
    this.minDuration = const Duration(milliseconds: 1500),
  });

  final AppController controller;
  final VoidCallback onDone;
  final Duration minDuration;

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.minDuration);
  bool _sound = false;
  bool _done = false;

  AppController get ctl => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_maybeFinish);
    ctl.addListener(_onController);
    _c.forward();
    _onController();
  }

  @override
  void dispose() {
    ctl.removeListener(_onController);
    _c.dispose();
    super.dispose();
  }

  void _onController() {
    // The sound waits for the settings to load so a muted app stays muted.
    if (ctl.ready && !_sound) {
      _sound = true;
      ctl.sfx('boot');
    }
    _maybeFinish();
  }

  void _maybeFinish() {
    if (_done || !ctl.ready || !_c.isCompleted) return;
    _done = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onDone();
    });
  }

  void _skip() {
    if (ctl.ready) _c.value = 1;
  }

  @override
  Widget build(BuildContext context) {
    final lines = <(String, String)>[
      ('mounting storage', 'OK'),
      ('reading player data', 'OK'),
      ('sensors', ctl.ready && ctl.usageAccess ? 'ONLINE' : 'OFFLINE'),
      ('system link', ctl.llm == null ? 'OFFLINE' : 'ONLINE'),
    ];
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _skip,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.value;
              final logo = Curves.easeOutCubic.transform((t / 0.3).clamp(0.0, 1.0));
              // Lines appear one after another between 30% and 90%.
              final shown = (((t - 0.3) / 0.6).clamp(0.0, 1.0) * (lines.length + 1)).floor();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(flex: 3),
                    Center(
                      child: Opacity(
                        opacity: logo,
                        child: Transform.scale(
                          scale: 0.85 + 0.15 * logo,
                          child: Image.asset('assets/brand/logo.png',
                              width: 150, height: 150, filterQuality: FilterQuality.medium),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Opacity(
                      opacity: logo,
                      child: const Center(child: Text('ARISE', style: Sys.title)),
                    ),
                    const SizedBox(height: 4),
                    Opacity(
                      opacity: logo,
                      child: Center(
                        child: Text('sys://boot', style: Sys.small.copyWith(letterSpacing: 2)),
                      ),
                    ),
                    const Spacer(flex: 2),
                    for (var i = 0; i < lines.length; i++)
                      _BootLine(
                        name: lines[i].$1,
                        result: lines[i].$2,
                        visible: i < shown,
                      ),
                    const SizedBox(height: 6),
                    Text(
                      '> SYSTEM ONLINE',
                      style: Sys.body.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: shown > lines.length ? Sys.ok : Colors.transparent,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SysBar(value: t, segments: 36, height: 4),
                    const Spacer(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BootLine extends StatelessWidget {
  const _BootLine({required this.name, required this.result, required this.visible});

  final String name;
  final String result;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final bad = result == 'OFFLINE';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('> $name ', style: Sys.small.copyWith(color: visible ? Sys.dim : Colors.transparent)),
          Expanded(
            child: Text(
              '.' * 40,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: Sys.small.copyWith(color: visible ? Sys.line : Colors.transparent),
            ),
          ),
          Text(
            ' $result',
            style: Sys.small.copyWith(
              fontWeight: FontWeight.w700,
              color: visible ? (bad ? Sys.gold : Sys.accent) : Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}
