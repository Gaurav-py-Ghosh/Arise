import 'package:flutter/material.dart';

import '../core/game_config.dart';
import '../domain/models.dart';
import '../system/llm.dart';
import '../system/secrets.dart';
import 'scope.dart';
import 'theme.dart';
import 'widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  final _key = TextEditingController();
  final _model = TextEditingController();
  bool _obscure = true;
  bool _hasKey = false;

  bool? _notifications;
  bool? _battery;
  bool? _overlayAllowed;

  /// Overlay was switched on before permission existed; finish on return.
  bool _wantOverlay = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final c = AppScope.read(context);
    _model.text = c.settings.model;
    Secrets.geminiKey().then((k) {
      if (!mounted) return;
      setState(() {
        _hasKey = k != null;
        _key.text = k ?? '';
      });
    });
    _probe();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _probe();
  }

  Future<void> _probe() async {
    final b = AppScope.read(context).bridge;
    final n = await b.notificationsAllowed();
    final bat = await b.ignoresBattery();
    final o = await b.canOverlay();
    if (!mounted) return;
    setState(() {
      _notifications = n;
      _battery = bat;
      _overlayAllowed = o;
    });
    if (_wantOverlay && o) {
      _wantOverlay = false;
      final c = AppScope.read(context);
      c.settings.overlay = true;
      await c.saveSettings();
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _update(void Function() change) async {
    final c = AppScope.read(context);
    change();
    await c.saveSettings();
  }

  Future<void> _saveKey() async {
    final c = AppScope.read(context);
    final k = _key.text.trim();
    FocusScope.of(context).unfocus();
    try {
      await Secrets.setGeminiKey(k);
    } catch (_) {
      _toast('Secure storage refused the key.');
      return;
    }
    c.llm = k.isEmpty ? null : GeminiLlm(apiKey: k, model: c.settings.model);
    await c.saveSettings();
    if (!mounted) return;
    setState(() => _hasKey = k.isNotEmpty);
    _toast(k.isEmpty ? 'Key removed. The System is offline.' : 'Key stored. The System link is online.');
  }

  Future<void> _saveModel() async {
    final c = AppScope.read(context);
    final m = _model.text.trim().isEmpty ? GameConfig.defaultModel : _model.text.trim();
    _model.text = m;
    FocusScope.of(context).unfocus();
    c.settings.model = m;
    final current = c.llm;
    if (current is GeminiLlm) c.llm = GeminiLlm(apiKey: current.apiKey, model: m);
    await c.saveSettings();
    _toast('Model set to $m.');
  }

  Future<void> _toggleOverlay(bool on) async {
    final c = AppScope.read(context);
    if (on && _overlayAllowed != true) {
      _wantOverlay = true;
      await c.bridge.openOverlaySettings();
      return;
    }
    await _update(() => c.settings.overlay = on);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final s = c.settings;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, Sys.gutter, 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: Sys.accent),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SETTINGS', style: Sys.title),
                        SizedBox(height: 2),
                        Text('sys://config', style: Sys.small),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sys.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  SysPanel(
                    label: 'CAPACITY',
                    child: Column(
                      children: [
                        SysStepper(
                          label: 'Weekday',
                          value: s.weekdayCap,
                          min: 15,
                          max: 960,
                          onChanged: (v) => _update(() => s.weekdayCap = v),
                        ),
                        const SizedBox(height: 10),
                        SysStepper(
                          label: 'Weekend',
                          value: s.weekendCap,
                          min: 15,
                          max: 960,
                          onChanged: (v) => _update(() => s.weekendCap = v),
                        ),
                        const SizedBox(height: 10),
                        SysStepper(
                          label: 'Distraction budget',
                          value: s.budgetMin,
                          min: 0,
                          max: 480,
                          onChanged: (v) => _update(() => s.budgetMin = v),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Capacity is how much quest time the planner may book per day. '
                          'Past the budget, distracting apps cost XP at day end.',
                          style: Sys.small.copyWith(height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Sys.gap),
                  SysPanel(
                    label: 'SYSTEM LINK',
                    trailing: SysTag(c.llm != null ? 'ONLINE' : 'OFFLINE',
                        color: c.llm != null ? Sys.ok : Sys.dim),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'A free Gemini key from Google AI Studio lets the System word '
                          'plans and answers. Decisions never depend on it.',
                          style: Sys.small.copyWith(height: 1.4),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _key,
                          obscureText: _obscure,
                          autocorrect: false,
                          enableSuggestions: false,
                          style: Sys.body,
                          decoration: InputDecoration(
                            hintText: 'Gemini API key',
                            suffixIcon: IconButton(
                              tooltip: _obscure ? 'Show key' : 'Hide key',
                              onPressed: () => setState(() => _obscure = !_obscure),
                              icon: Icon(_obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                            ),
                          ),
                          onSubmitted: (_) => _saveKey(),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(_hasKey ? 'key stored securely' : 'no key stored',
                                  style: Sys.small.copyWith(
                                      color: _hasKey ? Sys.ok : Sys.dim)),
                            ),
                            SysButton('SAVE KEY', dense: true, onPressed: _saveKey),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _model,
                          autocorrect: false,
                          enableSuggestions: false,
                          style: Sys.body,
                          decoration: const InputDecoration(
                            labelText: 'Model',
                            hintText: GameConfig.defaultModel,
                          ),
                          onSubmitted: (_) => _saveModel(),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text('tokens today: ${c.tokensToday}',
                                  style: Sys.small),
                            ),
                            SysButton('SAVE MODEL', dense: true, onPressed: _saveModel),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Sys.gap),
                  SysPanel(
                    label: 'ALERTS',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Permission(
                          title: 'Notifications',
                          why: 'Deviation alerts and the focus timer.',
                          granted: _notifications,
                          action: 'ALLOW',
                          onAction: () async {
                            await c.bridge.requestNotifications();
                            _probe();
                          },
                        ),
                        _Permission(
                          title: 'Usage access',
                          why: 'Screen time per app, to detect deviation.',
                          granted: c.usageAccess,
                          action: 'GRANT',
                          onAction: c.bridge.openUsageAccess,
                        ),
                        _Permission(
                          title: 'Battery exemption',
                          why: 'Keeps the 15-minute watcher on schedule.',
                          granted: _battery,
                          action: 'EXEMPT',
                          onAction: c.bridge.requestIgnoreBattery,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Sound effects', style: Sys.body),
                                  Text('Clicks, quest chimes and the alert tone.',
                                      style: Sys.small.copyWith(fontSize: 11)),
                                ],
                              ),
                            ),
                            Switch(
                              value: s.sound,
                              onChanged: (v) async {
                                await _update(() => c.settings.sound = v);
                                if (v) c.sfx('complete');
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Overlay pop-up', style: Sys.body),
                                  Text(
                                    _overlayAllowed == false
                                        ? 'Draw-over permission needed.'
                                        : 'System window over other apps when you deviate.',
                                    style: Sys.small.copyWith(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: s.overlay && _overlayAllowed == true,
                              onChanged: _toggleOverlay,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SysButton(
                          'TEST ALERT',
                          icon: Icons.notifications_active_outlined,
                          onPressed: () async {
                            await c.bridge.testAlert();
                            _toast('Test alert sent. It needs notification permission '
                                'and usage access to appear.');
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Sys.gap),
                  SysPanel(
                    label: 'DATA',
                    child: Text(
                      'Everything is stored on this device. With a key set, only the '
                      'short facts behind a chat answer or a plan request are sent to '
                      'Gemini. Day: ${fmtDay(c.today)}.',
                      style: Sys.small.copyWith(height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Permission extends StatelessWidget {
  const _Permission({
    required this.title,
    required this.why,
    required this.granted,
    required this.action,
    required this.onAction,
  });

  final String title;
  final String why;

  /// Null while unknown.
  final bool? granted;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final g = granted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(title, style: Sys.body)),
                    const SizedBox(width: 8),
                    if (g != null)
                      SysTag(g ? 'GRANTED' : 'MISSING', color: g ? Sys.ok : Sys.gold),
                  ],
                ),
                Text(why, style: Sys.small.copyWith(fontSize: 11)),
              ],
            ),
          ),
          if (g == false) ...[
            const SizedBox(width: 8),
            SysButton(action, dense: true, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}
