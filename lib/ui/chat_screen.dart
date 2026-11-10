import 'package:flutter/material.dart';

import '../app/controller.dart';
import 'scope.dart';
import 'theme.dart';
import 'widgets.dart';

/// Terminal-style conversation with the System.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

const _chips = [
  ('15m', 'I have 15 min. What should I tackle first?'),
  ('30m', 'I have 30 min. What should I tackle first?'),
  ('1h', 'I have 1 hour. What should I tackle first?'),
  ('2h', 'I have 2 hours. What should I tackle first?'),
  ('STATUS REPORT', 'Status report.'),
];

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send(AppController c, String text) {
    if (text.trim().isEmpty || c.thinking) return;
    c.ask(text);
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final lines = c.chat;
    final online = c.llm != null;
    // Newest at the bottom: a reversed list keeps the view pinned there
    // without scroll animations.
    final count = lines.length + (c.thinking ? 1 : 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHeader(
          'SYSTEM',
          'sys://link',
          trailing: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SysTag(online ? 'ONLINE' : 'OFFLINE',
                color: online ? Sys.ok : Sys.dim),
          ),
        ),
        const SizedBox(height: 1, child: ColoredBox(color: Sys.line)),
        Expanded(
          child: count == 0
              ? _Intro(online: online)
              : ListView.builder(
                  key: const PageStorageKey('chat'),
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(Sys.gutter, 12, Sys.gutter, 12),
                  itemCount: count,
                  itemBuilder: (_, i) {
                    if (c.thinking && i == 0) return const _Processing();
                    final line = lines[lines.length - 1 - (i - (c.thinking ? 1 : 0))];
                    return _Line(line: line);
                  },
                ),
        ),
        const SizedBox(height: 1, child: ColoredBox(color: Sys.line)),
        SizedBox(
          height: 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Sys.gutter, vertical: 7),
            itemCount: _chips.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => SysButton(
              _chips[i].$1,
              dense: true,
              uppercase: false,
              onPressed: c.thinking ? null : () => _send(c, _chips[i].$2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Sys.gutter, 2, 8, 0),
          child: Row(
            children: [
              const Text('>', style: TextStyle(fontFamily: Sys.font, color: Sys.accent, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _input,
                  style: Sys.body,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Speak to the System'),
                  onSubmitted: (t) => _send(c, t),
                ),
              ),
              IconButton(
                tooltip: 'Send',
                onPressed: c.thinking ? null : () => _send(c, _input.text),
                icon: Icon(Icons.subdirectory_arrow_left_rounded,
                    color: c.thinking ? Sys.line : Sys.accent),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Sys.gutter, 6, Sys.gutter, 8),
          child: Row(
            children: [
              Expanded(
                child: Text('tokens today: ${c.tokensToday}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Sys.small.copyWith(fontSize: 10.5)),
              ),
              const SizedBox(width: 8),
              Text('link: ${online ? 'online' : 'offline'}',
                  style: Sys.small.copyWith(
                      fontSize: 10.5, color: online ? Sys.ok : Sys.dim)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Sys.gutter),
      children: [
        const SystemNote('Link established. State the time you have and the System will '
            'name the quest to begin. Or request a status report.', color: Sys.accent),
        if (!online) ...[
          const SizedBox(height: 10),
          const SystemNote('Operating offline: directives come from local templates. '
              'Add a Gemini key in Settings for free-form answers.'),
        ],
      ],
    );
  }
}

class _Processing extends StatelessWidget {
  const _Processing();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text('[SYSTEM] ...processing',
          style: Sys.body.copyWith(color: Sys.dim, fontSize: 13)),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.line});

  final ChatLine line;

  @override
  Widget build(BuildContext context) {
    if (line.fromUser) {
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Text('> ${line.text}',
            style: Sys.body.copyWith(color: Sys.accent)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text.rich(
        TextSpan(children: [
          const TextSpan(
            text: '[SYSTEM] ',
            style: TextStyle(color: Sys.accentHi, fontWeight: FontWeight.w700),
          ),
          TextSpan(text: line.text),
          if (line.offline)
            const TextSpan(
              text: '  // offline template',
              style: TextStyle(color: Sys.dim, fontSize: 11.5),
            ),
        ]),
        style: Sys.body,
      ),
    );
  }
}
