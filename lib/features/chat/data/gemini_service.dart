import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:pocket_tutor/core/constants/app_strings.dart';

class GeminiService {
  GeminiService._();

  static final instance = GeminiService._();

  /// Candidate models (latest stable-ish first). We pick the most reliable
  /// by trying in order and using the first one that succeeds.
  final List<GenerativeModel> _candidateModels = [
    // Backwards-compatible option
    GenerativeModel(
      model: 'gemini-2.5-flash-lite',
      apiKey: AppStrings.geminiApiKey,
    ),

    GenerativeModel(model: 'gemini-3.5-flash', apiKey: AppStrings.geminiApiKey),
  ];

  Future<String> query(String prompt, {File? imageFile}) async {
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        return (await _generate(prompt, imageFile: imageFile)).trim();
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if ((msg.contains('503') || msg.contains('unavailable')) &&
            attempt < 2) {
          await Future.delayed(const Duration(seconds: 3));
          continue;
        }

        try {
          return (await _generate(
            prompt,
            imageFile: imageFile,
            useFallback: true,
          )).trim();
        } catch (fallbackError) {
          throw _mapError(fallbackError);
        }
      }
    }
    throw 'Kuch unexpected hua. Dobara try karo.';
  }

  Future<String> _generate(
    String prompt, {
    File? imageFile,
    bool useFallback = false,
  }) async {
    // When useFallback is false, we try the full candidate list.
    // When true, we try only a smaller subset (still ordered).
    final modelsToTry = useFallback
        ? _candidateModels.take(2).toList(growable: false)
        : _candidateModels;

    Object? lastError;
    for (final m in modelsToTry) {
      try {
        final List<Content> contents;
        if (imageFile != null) {
          final bytes = await imageFile.readAsBytes();
          final mimeType = imageFile.path.endsWith('.png')
              ? 'image/png'
              : 'image/jpeg';
          contents = [
            Content.multi([
              TextPart(prompt.trim().isEmpty ? "Analyze this image" : prompt),
              DataPart(mimeType, bytes),
            ]),
          ];
        } else {
          contents = [Content.text(prompt)];
        }
        final response = await m.generateContent(contents);
        final text = response.text;
        if (text != null && text.trim().isNotEmpty) {
          return text.trim();
        }
      } catch (e) {
        lastError = e;
      }
    }

    throw lastError ?? 'Gemini response failed.';
  }

  String _mapError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('quota') ||
        message.contains('rate') ||
        message.contains('limit')) {
      return message;
    }
    if (message.contains('503') || message.contains('unavailable')) {
      return 'Gemini server abhi busy hai. Kuch seconds baad dobara try karo.';
    }
    return 'ERROR: $error';
  }
}
