import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Reads secrets from `--dart-define` first, then optional `.env` asset.
abstract final class EnvConfig {
  static String get geminiApiKey {
    const fromDefine = String.fromEnvironment('GEMINI_API_KEY');
    if (fromDefine.isNotEmpty) return fromDefine;
    return dotenv.env['GEMINI_API_KEY']?.trim() ?? '';
  }

  static bool get hasGeminiApiKey => geminiApiKey.isNotEmpty;
}
