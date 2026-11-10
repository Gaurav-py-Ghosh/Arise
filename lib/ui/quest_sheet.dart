import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../domain/planner.dart';
import 'scope.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> showQuestSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const QuestSheet(),
    );

/// Issue a new target (planned by the System) or a single quick quest.
class QuestSheet extends StatefulWidget {
  const QuestSheet({super.key});

  @override
  State<QuestSheet> createState() => _QuestSheetState();
}

const _priorities = [
  ('LOW', Priority.low),
  ('NORMAL', Priority.normal),
  ('HIGH', Priority.high),
];

class _QuestSheetState extends State<QuestSheet> {
  bool _quick = false;

  // NEW TARGET
  final _title = TextEditingController();
  Priority _priority = Priority.normal;
  int? _deadline;
  List<PlanStep> _steps = const [];
  bool? _fromLlm;
  bool _loading = false;

  /// The title changed since the steps were drafted.
  bool _stale = false;
  Timer? _debounce;
  int _req = 0;
  Map<int, int> _booked = const {};

  // QUICK QUEST
  final _quickTitle = TextEditingController();
  int _minutes = 30;
  bool _tomorrow = false;
  Priority _quickPriority = Priority.normal;

  @override
  void initState() {
    super.initState();
    final c = AppScope.read(context);
    c.store.plannedMinutes(c.today).then((m) {
      if (mounted) setState(() => _booked = m);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _title.dispose();
    _quickTitle.dispose();
    super.dispose();
  }

  void _onTitle(String text) {
    _debounce?.cancel();
    if (text.trim().length < 4) {
      _req++;
      if (_steps.isNotEmpty || _loading || _stale) {
        setState(() {
          _steps = const [];
          _fromLlm = null;
          _loading = false;
          _stale = false;
        });
      }
      return;
    }
    if (_steps.isNotEmpty && !_stale) setState(() => _stale = true);
    _debounce = Timer(const Duration(milliseconds: 900), _draft);
  }

  Future<void> _draft() async {
    final goal = _title.text.trim();
    if (goal.length < 4) return;
    final c = AppScope.read(context);
    final id = ++_req;
    // The template shows at once; the System's plan replaces it if it comes.
    setState(() {
      _steps = templatePlan(goal);
      _fromLlm = false;
      _loading = c.llm != null;
      _stale = false;
    });
    final (steps, fromLlm) = await c.suggestPlan(goal, deadline: _deadline);
    if (!mounted || id != _req) return;
    setState(() {
      _steps = steps;
      _fromLlm = fromLlm;
      _loading = false;
    });
  }

  Future<void> _pickDeadline() async {
    final c = AppScope.read(context);
    final now = dayFromKey(c.today);
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 2, now.month, now.day),
      initialDate: _deadline == null
          ? DateTime(now.year, now.month, now.day + 14)
          : dayFromKey(_deadline!),
      helpText: 'DEADLINE',
    );
    if (picked == null || !mounted) return;
    setState(() => _deadline = dayKey(picked));
    if (_title.text.trim().length >= 4) _draft();
  }

  void _accept() {
    final c = AppScope.read(context);
    final title = _title.text.trim();
    final steps = _steps;
    Navigator.of(context).pop();
    c.createTarget(
        title: title, steps: steps, priority: _priority, deadline: _deadline);
  }

  void _addQuick() {
    final title = _quickTitle.text.trim();
    if (title.isEmpty) return;
    final c = AppScope.read(context);
    Navigator.of(context).pop();
    c.addQuest(title, _minutes,
        day: _tomorrow ? addDays(c.today, 1) : c.today,
        priority: _quickPriority);
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Sys.gutter, 14, Sys.gutter, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(child: Text('// ISSUE', style: Sys.label)),
                IconButton(
                  tooltip: 'Close',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            ChoiceChips<bool>(
              options: const [('NEW TARGET', false), ('QUICK QUEST', true)],
              selected: _quick,
              onSelected: (v) => setState(() => _quick = v),
            ),
            const SizedBox(height: 16),
            if (_quick) ..._quickForm() else ..._targetForm(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _targetForm(BuildContext context) {
    final c = AppScope.read(context);
    final today = c.today;
    return [
      TextField(
        controller: _title,
        autofocus: true,
        maxLength: 80,
        textCapitalization: TextCapitalization.sentences,
        style: Sys.body,
        decoration: const InputDecoration(
          hintText: 'Target, e.g. Pass the Flutter interview',
          counterText: '',
        ),
        onChanged: _onTitle,
      ),
      const SizedBox(height: 14),
      const Text('// PRIORITY', style: Sys.label),
      const SizedBox(height: 8),
      ChoiceChips<Priority>(
        options: _priorities,
        selected: _priority,
        onSelected: (p) => setState(() => _priority = p),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: Text(
              _deadline == null
                  ? 'DEADLINE: none'
                  : 'DEADLINE: ${fmtDay(_deadline!, today: today)} '
                      '(${daysBetween(today, _deadline!)}d)',
              style: Sys.small.copyWith(
                  color: _deadline == null ? Sys.dim : Sys.accentHi),
            ),
          ),
          if (_deadline != null)
            IconButton(
              tooltip: 'Clear deadline',
              visualDensity: VisualDensity.compact,
              onPressed: () {
                setState(() => _deadline = null);
                if (_title.text.trim().length >= 4) _draft();
              },
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          SysButton('SET',
              icon: Icons.event_rounded, dense: true, onPressed: _pickDeadline),
        ],
      ),
      const SizedBox(height: 16),
      ..._preview(today),
      const SizedBox(height: 16),
      SysButton(
        'ACCEPT',
        icon: Icons.check_rounded,
        filled: true,
        onPressed: _steps.isEmpty || _stale ? null : _accept,
      ),
    ];
  }

  List<Widget> _preview(int today) {
    if (_steps.isEmpty) {
      return [
        SystemNote(_title.text.trim().length < 4
            ? 'Name the target. At four characters the System drafts a plan.'
            : 'Every step was removed. Retype the target to draft again.'),
      ];
    }
    final c = AppScope.read(context);
    final quests = schedulePlan(
      steps: _steps,
      startDay: today,
      capacityFor: c.settings.capacityFor,
      alreadyPlanned: _booked,
      priority: _priority,
      deadline: _deadline,
    );

    // schedulePlan emits each step's parts in order; walk minutes to map
    // every scheduled quest back to the step it came from.
    final stepOf = <int>[];
    var s = 0, used = 0;
    for (final q in quests) {
      while (s < _steps.length && _steps[s].minutes <= 0) {
        s++;
      }
      stepOf.add(s);
      used += q.estimateMin;
      if (s < _steps.length && used >= _steps[s].minutes) {
        s++;
        used = 0;
      }
    }

    final total = _steps.fold<int>(0, (a, b) => a + b.minutes);
    final days = quests.map((q) => q.day).toSet().length;
    final out = <Widget>[
      SectionLabel('PLAN',
          trailing: Text('${_steps.length} steps · ${fmtMin(total)} · ${days}d',
              style: Sys.label.copyWith(letterSpacing: 1))),
      const SizedBox(height: 4),
      Text(
        _loading
            ? '// offline template · querying the System...'
            : _fromLlm == true
                ? '// source: the System'
                : '// source: offline template',
        style: Sys.small.copyWith(
            color: _fromLlm == true && !_loading ? Sys.accent : Sys.dim),
      ),
      const SizedBox(height: 10),
    ];
    int? lastDay;
    for (var i = 0; i < quests.length; i++) {
      final q = quests[i];
      if (q.day != lastDay) {
        lastDay = q.day;
        out.add(Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          child: Text(fmtDay(q.day, today: today),
              style: Sys.small.copyWith(
                  color: Sys.accentHi,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700)),
        ));
      }
      final step = stepOf[i];
      out.add(Row(
        children: [
          const Text('· ', style: Sys.small),
          Expanded(
            child: Text(q.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Sys.body.copyWith(fontSize: 12.5)),
          ),
          const SizedBox(width: 8),
          Text(fmtMin(q.estimateMin), style: Sys.small),
          IconButton(
            tooltip: 'Remove step',
            visualDensity: VisualDensity.compact,
            onPressed: step < _steps.length
                ? () => setState(() {
                      _steps = [..._steps]..removeAt(step);
                    })
                : null,
            icon: const Icon(Icons.close_rounded, size: 16),
          ),
        ],
      ));
    }
    return out;
  }

  List<Widget> _quickForm() {
    return [
      TextField(
        controller: _quickTitle,
        autofocus: true,
        maxLength: 80,
        textCapitalization: TextCapitalization.sentences,
        style: Sys.body,
        decoration: const InputDecoration(
          hintText: 'Quest, e.g. Read chapter 4',
          counterText: '',
        ),
        onSubmitted: (_) => _addQuick(),
      ),
      const SizedBox(height: 14),
      SysStepper(
        label: 'ESTIMATE',
        value: _minutes,
        min: 15,
        max: 240,
        onChanged: (v) => setState(() => _minutes = v),
      ),
      const SizedBox(height: 14),
      const Text('// WHEN', style: Sys.label),
      const SizedBox(height: 8),
      ChoiceChips<bool>(
        options: const [('TODAY', false), ('TOMORROW', true)],
        selected: _tomorrow,
        onSelected: (v) => setState(() => _tomorrow = v),
      ),
      const SizedBox(height: 14),
      const Text('// PRIORITY', style: Sys.label),
      const SizedBox(height: 8),
      ChoiceChips<Priority>(
        options: _priorities,
        selected: _quickPriority,
        onSelected: (p) => setState(() => _quickPriority = p),
      ),
      const SizedBox(height: 20),
      // Only the button listens to typing.
      ListenableBuilder(
        listenable: _quickTitle,
        builder: (_, _) => SysButton(
          'ADD QUEST',
          icon: Icons.add,
          filled: true,
          onPressed: _quickTitle.text.trim().isEmpty ? null : _addQuick,
        ),
      ),
    ];
  }
}
