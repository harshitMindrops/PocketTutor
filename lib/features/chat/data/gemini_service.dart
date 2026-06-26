import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:pocket_tutor/core/constants/app_strings.dart';
import 'package:pocket_tutor/features/chat/data/models/chat_tool_type.dart';
import 'package:pocket_tutor/features/chat/presentation/widgets/quiz.dart'
    show QuizQuestion;
import 'package:path/path.dart' as p;
import 'package:docx_to_text/docx_to_text.dart';

class FlashcardResult {
  const FlashcardResult({required this.question, required this.answer});

  final String question;
  final String answer;
}

// ✅ Renamed to GeminiQuizQuestion — quiz.dart ke QuizQuestion se clash nahi hoga
class GeminiQuizQuestion {
  final String question;
  final List<String> options;
  final int correctAnswerIndex;

  const GeminiQuizQuestion({
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
  });

  factory GeminiQuizQuestion.fromJson(Map<String, dynamic> json) {
    final questionText =
        json['question']?.toString().trim() ?? 'Quiz Question';

    final rawOptions = json['options'];
    List<String> optionsList = [];
    if (rawOptions is List) {
      optionsList = rawOptions.map((e) => e.toString().trim()).toList();
    }

    while (optionsList.length < 4) {
      optionsList.add('Option ${optionsList.length + 1}');
    }
    if (optionsList.length > 4) {
      optionsList = optionsList.sublist(0, 4);
    }

    var correctIdx = 0;
    if (json['correctAnswerIndex'] != null) {
      final parsedIdx =
          int.tryParse(json['correctAnswerIndex'].toString());
      if (parsedIdx != null && parsedIdx >= 0 && parsedIdx < 4) {
        correctIdx = parsedIdx;
      }
    }

    return GeminiQuizQuestion(
      question: questionText,
      options: optionsList,
      correctAnswerIndex: correctIdx,
    );
  }

  // ✅ quiz.dart ke QuizQuestion mein convert karta hai
  QuizQuestion toUiQuestion() => QuizQuestion(
        question: question,
        options: options,
        correctIndex: correctAnswerIndex,
      );
}

class GeminiService {
  GeminiService._();

  static final instance = GeminiService._();

  static final _systemInstruction = Content.system(
    "You are PocketTutor, a helpful, highly efficient, and concise AI study assistant. "
    "Your goal is to help students learn effectively. "
    "Keep explanations clear, accurate, and direct. "
    "Avoid unnecessary conversational filler, preambles, or postambles (e.g., do NOT say 'Sure, let me help you with that' or 'Here is your answer'). "
    "Get straight to the point. Use markdown formatting like bullet points, bold text, and tables where appropriate to keep responses fast to read and clean. "
    "Limit your response length; be brief and concise while remaining highly educational.",
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
        return (await _generate(prompt, attachmentFile: attachmentFile))
            .trim();
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
          ))
              .trim();
        } catch (fallbackError) {
          throw _mapError(fallbackError);
        }
      }
    }
    throw 'Kuch unexpected hua. Dobara try karo.';
  }

  Future<FlashcardResult> generateFlashcard(
    String topic, {
    File? attachmentFile,
  }) async {
    final prompt =
        'Generate exactly one educational flashcard based on the user topic below. '
        'Respond ONLY with valid JSON (no markdown fences, no extra text) in this exact format:\n'
        '{"question":"...","answer":"..."}\n'
        'The answer should be a concise explanation. Wrap important terms in **double asterisks** for bold.\n'
        'User topic: ${topic.trim()}';

    final raw = await query(prompt, attachmentFile: attachmentFile);
    return _parseFlashcardResponse(raw);
  }

  // ✅ Ab List<QuizQuestion> return karta hai — quiz.dart ka QuizQuestion
  Future<List<QuizQuestion>> generateQuiz(
    String topic, {
    File? attachmentFile,
  }) async {
    final prompt = buildToolPrompt(topic, ChatToolType.generateQuiz);
    final raw = await query(prompt, attachmentFile: attachmentFile);

    var cleaned = raw.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
      cleaned = cleaned.replaceFirst(RegExp(r'\s*```$'), '');
      cleaned = cleaned.trim();
    }

    try {
      final decoded = jsonDecode(cleaned);

      List<GeminiQuizQuestion> geminiQuestions = [];

      if (decoded is List) {
        geminiQuestions = decoded.map((item) {
          if (item is Map<String, dynamic>) {
            return GeminiQuizQuestion.fromJson(item);
          }
          throw 'Invalid item structure inside JSON array';
        }).toList();
      } else if (decoded is Map && decoded.containsKey('quiz')) {
        final quizList = decoded['quiz'];
        if (quizList is List) {
          geminiQuestions = quizList
              .map((item) =>
                  GeminiQuizQuestion.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      } else {
        throw 'Decoded JSON is not a List';
      }

      // ✅ GeminiQuizQuestion → QuizQuestion (quiz.dart wala)
      return geminiQuestions.map((q) => q.toUiQuestion()).toList();
    } catch (e) {
      throw 'Quiz data structure load nahi ho paya. Kripya dhang se dobara try karein.';
    }
  }

  String buildToolPrompt(String text, ChatToolType tool) {
    final topic = text.trim();
    return switch (tool) {
      ChatToolType.generateQuiz =>
        'Generate a short quiz with exactly 10 multiple choice questions about the following topic. '
            'Respond ONLY with a valid JSON array (no markdown fences like ```json, no extra conversational text). '
            'Each object in the array must have "question" (string), "options" (array of 4 strings), and "correctAnswerIndex" (int, 0 to 3).\n\n'
            'Topic: $topic',
      ChatToolType.generateFlashcard => topic,
    };
  }

  FlashcardResult _parseFlashcardResponse(String raw) {
    var cleaned = raw.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
      cleaned = cleaned.replaceFirst(RegExp(r'\s*```$'), '');
    }

    try {
      final map = jsonDecode(cleaned) as Map<String, dynamic>;
      final question = map['question']?.toString().trim() ?? '';
      final answer = map['answer']?.toString().trim() ?? '';
      if (question.isNotEmpty && answer.isNotEmpty) {
        return FlashcardResult(
          question: question.length > 500
              ? question.substring(0, 500)
              : question,
          answer:
              answer.length > 4000 ? answer.substring(0, 4000) : answer,
        );
      }
    } catch (_) {}

    return FlashcardResult(
      question: 'What did you learn about this topic?',
      answer: cleaned.isNotEmpty
          ? (cleaned.length > 4000
              ? cleaned.substring(0, 4000)
              : cleaned)
          : 'No answer generated.',
    );
  }

  Future<String> _generate(
    String prompt, {
    File? attachmentFile,
    bool useFallback = false,
  }) async {
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
              docText =
                  "${docText.substring(0, 15000)}\n\n[... Content truncated to save tokens ...]";
            }
            final promptText = prompt.trim().isEmpty
                ? "Analyze this document and summarize its key details."
                : prompt.trim();
            final fullPrompt =
                "[Document Content from ${p.basename(attachmentFile.path)}]:\n\n$docText\n\nUser Question:\n$promptText";
            contents = [Content.text(fullPrompt)];
          } else if (ext == '.doc') {
            String docText = '';
            try {
              docText = docxToText(bytes);
            } catch (_) {
              docText = String.fromCharCodes(bytes);
            }
            if (docText.length > 15000) {
              docText =
                  "${docText.substring(0, 15000)}\n\n[... Content truncated to save tokens ...]";
            }
            final promptText = prompt.trim().isEmpty
                ? "Analyze this document and summarize its key details."
                : prompt.trim();
            final fullPrompt =
                "[Document Content from ${p.basename(attachmentFile.path)}]:\n\n$docText\n\nUser Question:\n$promptText";
            contents = [Content.text(fullPrompt)];
          } else {
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
                  prompt.trim().isEmpty
                      ? "Analyze this image"
                      : prompt.trim(),
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