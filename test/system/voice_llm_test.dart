import 'dart:convert';

import 'package:arise/domain/deviation.dart';
import 'package:arise/domain/models.dart';
import 'package:arise/system/llm.dart';
import 'package:arise/system/voice.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('parseMinutes', () {
    expect(parseMinutes('I have 40 min left'), 40);
    expect(parseMinutes('1h 30m free'), 90);
    expect(parseMinutes('1.5 hours'), 90);
    expect(parseMinutes('got 2 hours'), 120);
    expect(parseMinutes('half an hour'), 30);
    expect(parseMinutes('an hour to kill'), 60);
    expect(parseMinutes('what should I do in 5 months'), isNull);
    expect(parseMinutes('am I on track?'), isNull);
  });

  test('compactContext stays small however long the quest list is', () {
    const today = 20261111;
    final quests = [
      for (var i = 0; i < 40; i++)
        Quest(title: 'Quest number $i with a long name', day: today, estimateMin: 45)
    ];
    final usage = [
      for (var i = 0; i < 30; i++)
        AppUsage(package: 'game.$i', label: 'Game $i', minutes: 30 - i, systemCategory: 0)
    ];
    final report = evaluateDeviation(
        usage: usage, rules: const {}, budgetMin: 45, todayQuests: quests, hourOfDay: 14);
    final ctx = compactContext(
        today: today, hour: 14, player: const Player(xp: 500, streak: 2),
        todayQuests: quests, report: report);
    expect(ctx.length < 500, true, reason: '${ctx.length} chars');
    expect(ctx, contains('Game 0 30'));
    expect(ctx, isNot(contains('Game 5')));
  });

  group('GeminiLlm', () {
    GeminiLlm llm(MockClient c) =>
        GeminiLlm(apiKey: 'k', model: 'm-1', client: c);

    test('sends key in a header, maps roles, reads text and tokens', () async {
      late http.Request seen;
      final client = MockClient((req) async {
        seen = req;
        return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'Arise, '},
                      {'text': 'Player.'}
                    ]
                  }
                }
              ],
              'usageMetadata': {'totalTokenCount': 57}
            }),
            200,
            headers: {'content-type': 'application/json'});
      });
      final r = await llm(client).generate(
          system: 'sys',
          turns: const [ChatTurn(true, 'a'), ChatTurn(false, 'b'), ChatTurn(true, 'c')],
          maxTokens: 100,
          json: true);
      expect(r.text, 'Arise, Player.');
      expect(r.tokens, 57);
      expect(seen.url.path, '/v1beta/models/m-1:generateContent');
      expect(seen.url.query, isEmpty);
      expect(seen.headers['x-goog-api-key'], 'k');
      final body = jsonDecode(seen.body) as Map;
      expect((body['contents'] as List).map((c) => c['role']), ['user', 'model', 'user']);
      expect(body['generationConfig']['maxOutputTokens'], 100);
      expect(body['generationConfig']['responseMimeType'], 'application/json');
      expect(body['systemInstruction']['parts'][0]['text'], 'sys');
    });

    Future<String> failWith(int code, String body) async {
      try {
        await llm(MockClient((_) async => http.Response(body, code)))
            .generate(system: 's', turns: const [ChatTurn(true, 'a')], maxTokens: 10);
        return 'no error';
      } on LlmException catch (e) {
        return e.message;
      }
    }

    test('maps failures to readable messages', () async {
      expect(await failWith(429, '{"error":{"message":"quota"}}'), contains('quota'));
      expect(await failWith(404, '{"error":{"message":"nope"}}'), contains('m-1'));
      expect(await failWith(403, '{"error":{"message":"bad key"}}'), contains('bad key'));
      expect(await failWith(500, '<html>'), contains('500'));
      expect(await failWith(200, '{"candidates":[]}'), contains('nothing'));
    });

    test('network errors become LlmException', () async {
      final c = MockClient((_) async => throw http.ClientException('offline'));
      expect(
          () => llm(c).generate(system: 's', turns: const [ChatTurn(true, 'a')], maxTokens: 10),
          throwsA(isA<LlmException>()));
    });
  });
}
