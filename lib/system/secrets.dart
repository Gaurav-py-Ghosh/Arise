import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The Gemini key lives in the Android keystore, never in SQLite or git.
class Secrets {
  const Secrets._();

  static const _storage = FlutterSecureStorage();
  static const _gemini = 'gemini_key';

  static Future<String?> geminiKey() async {
    try {
      final v = await _storage.read(key: _gemini);
      return (v == null || v.trim().isEmpty) ? null : v.trim();
    } catch (_) {
      return null;
    }
  }

  /// Saves the key; null or blank removes it.
  static Future<void> setGeminiKey(String? key) async {
    final k = key?.trim() ?? '';
    if (k.isEmpty) {
      await _storage.delete(key: _gemini);
    } else {
      await _storage.write(key: _gemini, value: k);
    }
  }
}
