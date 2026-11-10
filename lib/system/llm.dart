import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ChatTurn {
  final bool fromUser;
  final String text;
  const ChatTurn(this.fromUser, this.text);
}

class LlmReply {
  final String text;

  /// Total tokens billed for the call (prompt + output), 0 if unknown.
  final int tokens;
  const LlmReply(this.text, this.tokens);
}

class LlmException implements Exception {
  final String message;
  const LlmException(this.message);
  @override
  String toString() => message;
}

/// The only seam the app knows about. Swap the implementation to move to an
/// on-device model or another provider.
abstract class Llm {
  Future<LlmReply> generate({
    required String system,
    required List<ChatTurn> turns,
    required int maxTokens,
    bool json = false,
  });
}

class GeminiLlm implements Llm {
  final String apiKey;
  final String model;
  final http.Client _http;
  final Duration timeout;

  GeminiLlm({
    required this.apiKey,
    required this.model,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : _http = client ?? http.Client();

  @override
  Future<LlmReply> generate({
    required String system,
    required List<ChatTurn> turns,
    required int maxTokens,
    bool json = false,
  }) async {
    final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent');
    final body = jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': system}
        ]
      },
      'contents': [
        for (final t in turns)
          {
            'role': t.fromUser ? 'user' : 'model',
            'parts': [
              {'text': t.text}
            ]
          }
      ],
      'generationConfig': {
        'maxOutputTokens': maxTokens,
        'temperature': 0.6,
        if (json) 'responseMimeType': 'application/json',
      },
    });

    final http.Response res;
    try {
      res = await _http
          .post(uri,
              headers: {
                'content-type': 'application/json',
                'x-goog-api-key': apiKey,
              },
              body: body)
          .timeout(timeout);
    } on TimeoutException {
      throw const LlmException('The System link timed out.');
    } catch (_) {
      throw const LlmException('No connection to the System.');
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw LlmException('Unreadable reply (HTTP ${res.statusCode}).');
    }
    if (res.statusCode != 200) {
      final msg = (data['error'] as Map?)?['message'] ?? 'unknown error';
      throw LlmException(switch (res.statusCode) {
        429 => 'Free quota reached. Try again in a minute.',
        400 || 403 => 'API key or model rejected: $msg',
        404 => 'Model "$model" not found. Change it in Settings.',
        _ => 'HTTP ${res.statusCode}: $msg',
      });
    }

    final candidates = data['candidates'] as List?;
    final parts =
        ((candidates?.firstOrNull as Map?)?['content'] as Map?)?['parts'] as List?;
    final text = (parts ?? const [])
        .map((p) => (p as Map)['text'])
        .whereType<String>()
        .join()
        .trim();
    final tokens =
        ((data['usageMetadata'] as Map?)?['totalTokenCount'] as num?)?.toInt() ?? 0;
    if (text.isEmpty) throw const LlmException('The System returned nothing.');
    return LlmReply(text, tokens);
  }
}
