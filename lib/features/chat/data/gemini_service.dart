import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:pocket_tutor/core/constants/app_strings.dart';
import 'package:path/path.dart' as p;
import 'package:docx_to_text/docx_to_text.dart';

class GeminiService {
  GeminiService._();

  static final instance = GeminiService._();

  static final _systemInstruction = Content.system(
    "You are PocketTutor, a helpful, highly efficient, and concise AI study assistant. "
    "Your goal is to help students learn effectively. "
    "Keep explanations clear, accurate, and direct. "
    "Avoid unnecessary conversational filler, preambles, or postambles (e.g., do NOT say 'Sure, let me help you with that' or 'Here is your answer'). "
    "Get straight to the point. Use markdown formatting like bullet points, bold text, and tables where appropriate to keep responses fast to read and clean. "
    "Limit your response length; be brief and concise while remaining highly educational."
  );

  static final _generationConfig = GenerationConfig(
    maxOutputTokens: 800,
    temperature: 0.3,
  );

  final List<GenerativeModel> _candidateModels = [
    GenerativeModel(
      model: 'gemini-2.5-flash-lite',
      apiKey: AppStrings.geminiApiKey,
      systemInstruction: _systemInstruction,
      generationConfig: _generationConfig,
    ),
    GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: AppStrings.geminiApiKey,
      systemInstruction: _systemInstruction,
      generationConfig: _generationConfig,
    ),
  ];

  Future<String> query(String prompt, {File? attachmentFile}) async {
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        return (await _generate(prompt, attachmentFile: attachmentFile)).trim();
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
            attachmentFile: attachmentFile,
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
    File? attachmentFile,
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
        if (attachmentFile != null && await attachmentFile.exists()) {
          final ext = p.extension(attachmentFile.path).toLowerCase();
          final bytes = await attachmentFile.readAsBytes();

          if (ext == '.pdf') {
            contents = [
              Content.multi([
                TextPart(
                  prompt.trim().isEmpty
                      ? "Analyze this PDF document"
                      : prompt.trim(),
                ),
                DataPart('application/pdf', bytes),
              ]),
            ];
          } else if (ext == '.docx') {
            String docText = docxToText(bytes);
            if (docText.length > 15000) {
              docText = "${docText.substring(0, 15000)}\n\n[... Content truncated to save tokens ...]";
            }
            final promptText = prompt.trim().isEmpty
                ? "Analyze this document and summarize its key details."
                : prompt.trim();
            final fullPrompt =
                "[Document Content from ${p.basename(attachmentFile.path)}]:\n\n$docText\n\nUser Question:\n$promptText";
            contents = [Content.text(fullPrompt)];
          } else if (ext == '.doc') {
            // Fallback for doc: try docxToText or treat as text if possible
            String docText = '';
            try {
              docText = docxToText(bytes);
            } catch (_) {
              // Try reading as plain string as a last resort
              docText = String.fromCharCodes(bytes);
            }
            if (docText.length > 15000) {
              docText = "${docText.substring(0, 15000)}\n\n[... Content truncated to save tokens ...]";
            }
            final promptText = prompt.trim().isEmpty
                ? "Analyze this document and summarize its key details."
                : prompt.trim();
            final fullPrompt =
                "[Document Content from ${p.basename(attachmentFile.path)}]:\n\n$docText\n\nUser Question:\n$promptText";
            contents = [Content.text(fullPrompt)];
          } else {
            // Default to image handling
            final mimeType = ext == '.png'
                ? 'image/png'
                : ext == '.webp'
                ? 'image/webp'
                : ext == '.gif'
                ? 'image/gif'
                : 'image/jpeg';
            contents = [
              Content.multi([
                TextPart(
                  prompt.trim().isEmpty ? "Analyze this image" : prompt.trim(),
                ),
                DataPart(mimeType, bytes),
              ]),
            ];
          }
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
