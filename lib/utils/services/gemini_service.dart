import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:pocket_tutor/utils/constants/app_strings.dart';

class GeminiService {
  // Use flash-lite as primary - lighter model with more availability
  final GenerativeModel _model = GenerativeModel(
    model: 'gemini-1.5-flash',
    apiKey: AppStrings.geminiApiKey,
  );

  // Fallback model if primary is unavailable
  final GenerativeModel _fallbackModel = GenerativeModel(
    model: 'gemini-1.5-flash-8b',
    apiKey: AppStrings.geminiApiKey,
  );

  /// Sends [prompt] to Gemini and returns the raw response text.
  Future<String> askGemini(String prompt, {bool useFallback = false}) async {
    final model = useFallback ? _fallbackModel : _model;
    final response = await model.generateContent([Content.text(prompt)]);
    return response.text ?? 'No response from Gemini.';
  }

  /// Simple filter – remove extra whitespace.
  String filterResponse(String raw) {
    return raw.trim();
  }

  /// Full pipeline with retry logic: ask Gemini → filter → return.
  Future<String> query(String prompt) async {
    // Try primary model up to 2 times
    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        final raw = await askGemini(prompt);
        return filterResponse(raw);
      } catch (e) {
        final msg = e.toString().toLowerCase();
        // If server busy (503) and not last attempt, wait and retry
        if ((msg.contains('503') || msg.contains('unavailable')) &&
            attempt < 2) {
          await Future.delayed(const Duration(seconds: 3));
          continue;
        }
        // Try fallback model on final primary failure
        try {
          final raw = await askGemini(prompt, useFallback: true);
          return filterResponse(raw);
        } catch (fallbackError) {
          final ferr = fallbackError.toString().toLowerCase();
          if (ferr.contains('quota') ||
              ferr.contains('rate') ||
              ferr.contains('limit')) {
            throw 'API quota khatam ho gayi hai. Nai Gemini API key banao:\nhttps://aistudio.google.com/app/apikey';
          } else if (ferr.contains('503') || ferr.contains('unavailable')) {
            throw 'Gemini server abhi busy hai. Kuch seconds baad dobara try karo.';
          } else {
            throw 'ERROR: ${fallbackError.toString()}';
          }
        }
      }
    }
    throw 'Kuch unexpected hua. Dobara try karo.';
  }
}
