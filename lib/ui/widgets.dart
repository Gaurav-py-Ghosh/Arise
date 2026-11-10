import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/controller.dart';
import '../domain/models.dart';
import 'theme.dart';

/// Cut-corner panel with an optional `// LABEL` header.
class SysPanel extends StatelessWidget {
  const SysPanel({
    super.key,
    this.label,
    this.trailing,
    required this.child,
    this.glow = false,
    this.accent,
    this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 14),
  });

  final String? label;
  final Widget? trailing;
  final Widget child;

  /// A single soft BoxShadow. Use on a few header panels only.
  final bool glow;

  /// Border and label colour; defaults to the plain line colour.
  final Color? accent;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final edge = accent ?? Sys.line;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: Sys.panel,
        shape: Sys.shape(glow ? (accent ?? Sys.accent).withValues(alpha: 0.6) : edge),
        shadows: glow
            ? [
                BoxShadow(
                  color: (accent ?? Sys.accent).withValues(alpha: 0.18),
                  blurRadius: 18,
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: padding,
        child: label == null
            ? child
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionLabel(label!, trailing: trailing, color: accent),
                  const SizedBox(height: 10),
                  child,
                ],
              ),
      ),
    );
  }
}

/// `// LABEL` with an optional widget on the right.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing, this.color});

  final String text;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '// $text',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: color == null ? Sys.label : Sys.label.copyWith(color: color),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

/// Screen title block: `ARISE` over `sys://path`.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader(this.title, this.path, {super.key, this.trailing});

  final String title;
  final String path;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sys.gutter, 10, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Sys.title, maxLines: 1),
                const SizedBox(height: 2),
                Text(path, style: Sys.small.copyWith(letterSpacing: 1)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Outlined, uppercase, cut-corner button.
class SysButton extends StatelessWidget {
  const SysButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.danger = false,
    this.icon,
    this.filled = false,
    this.dense = false,
    this.color,
    this.uppercase = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool uppercase;
  final bool danger;
  final IconData? icon;
  final bool filled;
  final bool dense;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? (danger ? Sys.danger : Sys.accent);
    final enabled = onPressed != null;
    final fg = enabled ? c : Sys.dim;
    final shape = Sys.shape(
      enabled ? c.withValues(alpha: 0.75) : Sys.line,
      radius: Sys.cutSmall,
    );
    return Material(
      color: filled && enabled ? c.withValues(alpha: 0.14) : Colors.transparent,
      shape: shape,
      child: InkWell(
        onTap: onPressed,
        customBorder: shape,
        splashColor: c.withValues(alpha: 0.18),
        highlightColor: c.withValues(alpha: 0.08),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: dense ? 34 : 44),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: dense ? 14 : 16, color: fg),
                  if (label.isNotEmpty) const SizedBox(width: 6),
                ],
                if (label.isNotEmpty)
                  Flexible(
                    child: Text(
                      uppercase ? label.toUpperCase() : label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: Sys.font,
                        fontSize: dense ? 11 : 12.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                        color: fg,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Thin segmented progress bar. Animates between values, never on its own.
class SysBar extends StatelessWidget {
  const SysBar({
    super.key,
    required this.value,
    this.color = Sys.accent,
    this.segments = 24,
    this.height = 6,
  });

  /// 0..1; values outside are clamped.
  final double value;
  final Color color;
  final int segments;
  final double height;

  @override
  Widget build(BuildContext context) {
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return RepaintBoundary(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: v),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          builder: (_, t, _) =>
              CustomPaint(painter: _BarPainter(t, color, segments)),
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.value, this.color, this.segments);

  final double value;
  final Color color;
  final int segments;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 2.0;
    final w = (size.width - gap * (segments - 1)) / segments;
    if (w <= 0) return;
    final on = Paint()..color = color;
    final off = Paint()..color = Sys.well;
    final filled = value * segments;
    for (var i = 0; i < segments; i++) {
      final x = i * (w + gap);
      canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), off);
      final f = (filled - i).clamp(0.0, 1.0);
      if (f > 0) canvas.drawRect(Rect.fromLTWH(x, 0, w * f, size.height), on);
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.value != value || old.color != color || old.segments != segments;
}

/// Tiny bordered chip: `HIGH`, `PENALTY`.
class SysTag extends StatelessWidget {
  const SysTag(this.text, {super.key, this.color = Sys.dim});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: Sys.font,
            fontSize: 9.5,
            height: 1.2,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// A row of selectable cut-corner chips. Wraps on narrow screens.
class ChoiceChips<T> extends StatelessWidget {
  const ChoiceChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<(String, T)> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (label, value) in options)
          _Chip(
            label: label,
            on: value == selected,
            onTap: () => onSelected(value),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = Sys.shape(on ? Sys.accent : Sys.line, radius: Sys.cutSmall);
    return Semantics(
      selected: on,
      button: true,
      child: Material(
        color: on ? Sys.accent.withValues(alpha: 0.14) : Colors.transparent,
        shape: shape,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: Sys.font,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: on ? Sys.accent : Sys.dim,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `- 45m +` with fixed steps.
class SysStepper extends StatelessWidget {
  const SysStepper({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.step = 15,
    this.min = 0,
    this.max = 720,
    this.format = fmtMin,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int step;
  final int min;
  final int max;
  final String Function(int) format;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: Sys.body, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
        _StepButton(
          icon: Icons.remove,
          tooltip: 'Decrease $label',
          onTap: value - step >= min ? () => onChanged(value - step) : null,
        ),
        SizedBox(
          width: 72,
          child: Text(
            format(value),
            textAlign: TextAlign.center,
            style: Sys.body.copyWith(
                color: Sys.accentHi, fontWeight: FontWeight.w700),
          ),
        ),
        _StepButton(
          icon: Icons.add,
          tooltip: 'Increase $label',
          onTap: value + step <= max ? () => onChanged(value + step) : null,
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.tooltip, this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = Sys.shape(onTap == null ? Sys.line : Sys.accent.withValues(alpha: 0.7),
        radius: Sys.cutSmall);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: shape,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: SizedBox(
            width: 40,
            height: 36,
            child: Icon(icon,
                size: 16, color: onTap == null ? Sys.line : Sys.accent),
          ),
        ),
      ),
    );
  }
}

/// A line in the System's voice for empty states.
class SystemNote extends StatelessWidget {
  const SystemNote(this.text, {super.key, this.color = Sys.dim});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: [
        TextSpan(
          text: '[SYSTEM] ',
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
        TextSpan(text: text),
      ]),
      style: Sys.body.copyWith(color: color, fontSize: 12.5),
    );
  }
}

/// Explains why Usage Access is needed, with a button to grant it.
class GrantAccessPanel extends StatelessWidget {
  const GrantAccessPanel({super.key, required this.onGrant});

  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    return SysPanel(
      label: 'SENSOR OFFLINE',
      accent: Sys.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'The System cannot see your screen time. Without Usage Access it '
            'cannot detect deviation, warn you before the budget breaks, or '
            'judge distraction at day end.',
            style: Sys.body,
          ),
          const SizedBox(height: 6),
          Text(
            'Arise reads only which apps were in the foreground and for how '
            'long. Nothing leaves the device.',
            style: Sys.small.copyWith(height: 1.4),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: SysButton('GRANT ACCESS',
                icon: Icons.sensors, color: Sys.gold, onPressed: onGrant),
          ),
        ],
      ),
    );
  }
}

/// Live `mm:ss` for the running quest. Only this text rebuilds each second.
class FocusClock extends StatefulWidget {
  const FocusClock({
    super.key,
    required this.startedMs,
    required this.now,
    this.style,
  });

  final int startedMs;
  final DateTime Function() now;
  final TextStyle? style;

  @override
  State<FocusClock> createState() => _FocusClockState();
}

class _FocusClockState extends State<FocusClock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ms = widget.now().millisecondsSinceEpoch - widget.startedMs;
    final s = ms < 0 ? 0 : ms ~/ 1000;
    final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    final text = h > 0 ? '$h:${two(m)}:${two(sec)}' : '${two(m)}:${two(sec)}';
    return Text(
      text,
      style: widget.style ??
          const TextStyle(
            fontFamily: Sys.font,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Sys.accent,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
    );
  }
}

/// Text that types itself out once, then stays. The full text is laid out
/// from the first frame, so nothing around it moves. Tap to finish early.
class TypeText extends StatefulWidget {
  const TypeText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  State<TypeText> createState() => _TypeTextState();
}

class _TypeTextState extends State<TypeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(
        milliseconds: (widget.text.length * 12).clamp(180, 900).toInt()),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.text;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _c.value = 1,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final n = (t.length * _c.value).floor().clamp(0, t.length);
          return Text.rich(
            TextSpan(children: [
              TextSpan(text: t.substring(0, n)),
              TextSpan(
                  text: t.substring(n),
                  style: const TextStyle(color: Colors.transparent)),
            ]),
            style: widget.style,
          );
        },
      ),
    );
  }
}

/// A number that counts to its new value instead of jumping.
class CountText extends StatelessWidget {
  const CountText(this.value, {super.key, this.style, this.format});

  final int value;
  final TextStyle? style;
  final String Function(int)? format;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value.toDouble()),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) {
        final n = v.round();
        return Text(format == null ? '$n' : format!(n), style: style);
      },
    );
  }
}

// --- System windows ---

/// Shows a System event as a centred window with one ACKNOWLEDGE button.
Future<void> showSystemWindow(BuildContext context, SystemEvent e) {
  final win = _celebrations.contains(e.title);
  if (e.danger || e.title == 'LEVEL UP') {
    HapticFeedback.heavyImpact();
  } else {
    HapticFeedback.mediumImpact();
  }
  return _showWindow<void>(
    context,
    title: e.title,
    body: e.body,
    danger: e.danger,
    tint: win ? Sys.gold : null,
    typed: true,
    actions: [(win ? 'CLAIM' : 'ACKNOWLEDGE', null, false)],
  );
}

/// Events that are a win: shown in gold.
const _celebrations = {'LEVEL UP', 'DAILY QUESTS CLEARED'};

/// Asks for confirmation in a System window. True when confirmed.
Future<bool> confirmSystem(
  BuildContext context, {
  required String title,
  required String body,
  required String confirm,
  bool danger = true,
}) async =>
    await _showWindow<bool>(
      context,
      title: title,
      body: body,
      danger: danger,
      actions: [('CANCEL', false, false), (confirm, true, danger)],
    ) ??
    false;

Future<T?> _showWindow<T>(
  BuildContext context, {
  required String title,
  required String body,
  required bool danger,
  required List<(String, T?, bool)> actions,
  Color? tint,
  bool typed = false,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'SYSTEM',
    barrierColor: const Color(0xC8000000),
    transitionDuration: const Duration(milliseconds: 180),
    // The boundary keeps the window from re-recording while it scales in.
    pageBuilder: (ctx, _, _) => RepaintBoundary(
      child: _SystemWindow<T>(
        title: title,
        body: body,
        danger: danger,
        actions: actions,
        tint: tint,
        typed: typed,
      ),
    ),
    transitionBuilder: (ctx, anim, _, child) {
      final c = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: c,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(c),
          child: child,
        ),
      );
    },
  );
}

class _SystemWindow<T> extends StatelessWidget {
  const _SystemWindow({
    required this.title,
    required this.body,
    required this.danger,
    required this.actions,
    this.tint,
    this.typed = false,
  });

  final String title;
  final String body;
  final bool danger;
  final List<(String, T?, bool)> actions;
  final Color? tint;
  final bool typed;

  @override
  Widget build(BuildContext context) {
    final accent = tint ?? (danger ? Sys.danger : Sys.accent);
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              type: MaterialType.transparency,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: Sys.panel,
                  shape: Sys.shape(accent, width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(
                            danger ? '[ SYSTEM // WARNING ]' : '[ SYSTEM ]',
                            style: TextStyle(
                              fontFamily: Sys.font,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 3,
                              color: accent,
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: 6,
                            height: 6,
                            child: ColoredBox(color: accent),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 1,
                        child: ColoredBox(color: accent.withValues(alpha: 0.35)),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: Sys.font,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.5,
                          color: Sys.text,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Flexible(
                        child: SingleChildScrollView(
                          child: typed
                              ? TypeText(body, style: Sys.body)
                              : Text(body, style: Sys.body),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          for (var i = 0; i < actions.length; i++) ...[
                            if (i > 0) const SizedBox(width: 10),
                            Expanded(
                              child: SysButton(
                                actions[i].$1,
                                filled: i == actions.length - 1,
                                danger: actions[i].$3,
                                color: actions.length == 1 ? accent : null,
                                onPressed: () =>
                                    Navigator.of(context).pop(actions[i].$2),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet of actions for a long-pressed item.
Future<T?> showActionSheet<T>(
  BuildContext context, {
  required String title,
  required List<(IconData, String, T, bool)> actions,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sys.gutter, 16, Sys.gutter, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('// ACTIONS', style: Sys.label),
            const SizedBox(height: 6),
            Text(title,
                style: Sys.body.copyWith(fontWeight: FontWeight.w700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            for (final (icon, label, value, danger) in actions)
              InkWell(
                onTap: () => Navigator.of(ctx).pop(value),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    children: [
                      Icon(icon,
                          size: 18, color: danger ? Sys.danger : Sys.accent),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontFamily: Sys.font,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: danger ? Sys.danger : Sys.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
