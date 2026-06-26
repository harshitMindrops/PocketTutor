import 'dart:convert';

import 'package:pocket_tutor/core/utils/timestamp_parser.dart';
import 'package:pocket_tutor/features/chat/presentation/widgets/quiz.dart';

class MessageModel {
  final String id;
  final String chatId;
  final String userId;
  final String sender;
  final String text;
  final String? imagePath;
  final int timestamp;
  final bool synced;
  final String? toolTag;
  final String? flashcardQuestion;
  final String? flashcardAnswer;
  final List<QuizQuestion>? quizQuestions; // ✅ already tha, sirf serialization fix kiya

  const MessageModel({
    required this.id,
    required this.chatId,
    required this.userId,
    required this.sender,
    required this.text,
    this.imagePath,
    required this.timestamp,
    this.synced = true,
    this.toolTag,
    this.flashcardQuestion,
    this.flashcardAnswer,
    this.quizQuestions,
  });

  factory MessageModel.fromMap(
    String userId,
    String chatId,
    String messageId,
    Map<dynamic, dynamic> map,
  ) {
    final parsed = _parseFlashcardFields(map);

    // ✅ Firebase se quizQuestions parse karo
    List<QuizQuestion>? quizQuestions;
    final rawQuiz = map['quizQuestions'];
    if (rawQuiz != null) {
      try {
        List<dynamic> quizList;
        if (rawQuiz is String) {
          quizList = jsonDecode(rawQuiz) as List<dynamic>;
        } else if (rawQuiz is List) {
          quizList = rawQuiz;
        } else {
          quizList = [];
        }
        quizQuestions = quizList.map((item) {
          final m = Map<String, dynamic>.from(item as Map);
          final opts = (m['options'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          while (opts.length < 4) opts.add('Option ${opts.length + 1}');
          return QuizQuestion(
            question: m['question']?.toString() ?? '',
            options: opts.take(4).toList(),
            correctIndex: int.tryParse(
                    m['correctIndex']?.toString() ?? '0') ??
                0,
          );
        }).toList();
      } catch (_) {
        quizQuestions = null;
      }
    }

    return MessageModel(
      id: messageId,
      chatId: chatId,
      userId: userId,
      sender: map['sender']?.toString() ?? 'user',
      text: map['text']?.toString() ?? '',
      imagePath: map['imagePath']?.toString(),
      timestamp: TimestampParser.parse(map['timestamp']),
      toolTag: map['toolTag']?.toString(),
      flashcardQuestion: parsed.$1,
      flashcardAnswer: parsed.$2,
      quizQuestions: quizQuestions, // ✅
    );
  }

  static (String?, String?) _parseFlashcardFields(Map<dynamic, dynamic> map) {
    var question = _cleanField(map['flashcardQuestion']?.toString());
    var answer = _cleanField(map['flashcardAnswer']?.toString());

    if ((question == null || answer == null) &&
        map['toolTag']?.toString() == 'generate_flashcard') {
      final fromText = _tryParseFlashcardJson(map['text']?.toString());
      question ??= fromText.$1;
      answer ??= fromText.$2;
    }

    return (question, answer);
  }

  static String? _cleanField(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.length > 4000 ? trimmed.substring(0, 4000) : trimmed;
  }

  static (String?, String?) _tryParseFlashcardJson(String? raw) {
    if (raw == null || raw.isEmpty) return (null, null);
    var cleaned = raw.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
      cleaned = cleaned.replaceFirst(RegExp(r'\s*```$'), '');
    }
    if (!cleaned.startsWith('{')) return (null, null);
    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is! Map) return (null, null);
      final q = _cleanField(decoded['question']?.toString());
      final a = _cleanField(decoded['answer']?.toString());
      return (q, a);
    } catch (_) {
      return (null, null);
    }
  }

  // ✅ toMap mein quizQuestions ko JSON string ke roop mein save karo Firebase ke liye
  Map<String, dynamic> toMap() => {
    'sender': sender,
    'text': text,
    'imagePath': imagePath,
    'timestamp': timestamp,
    if (toolTag != null) 'toolTag': toolTag,
    if (flashcardQuestion != null) 'flashcardQuestion': flashcardQuestion,
    if (flashcardAnswer != null) 'flashcardAnswer': flashcardAnswer,
    if (quizQuestions != null && quizQuestions!.isNotEmpty)
      'quizQuestions': jsonEncode(
        quizQuestions!.map((q) => {
          'question': q.question,
          'options': q.options,
          'correctIndex': q.correctIndex,
        }).toList(),
      ),
  };

  // ✅ copyWith mein quizQuestions add kiya
  MessageModel copyWith({
    String? id,
    String? chatId,
    String? userId,
    String? sender,
    String? text,
    String? imagePath,
    int? timestamp,
    bool? synced,
    String? toolTag,
    String? flashcardQuestion,
    String? flashcardAnswer,
    List<QuizQuestion>? quizQuestions,
  }) {
    return MessageModel(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      userId: userId ?? this.userId,
      sender: sender ?? this.sender,
      text: text ?? this.text,
      imagePath: imagePath ?? this.imagePath,
      timestamp: timestamp ?? this.timestamp,
      synced: synced ?? this.synced,
      toolTag: toolTag ?? this.toolTag,
      flashcardQuestion: flashcardQuestion ?? this.flashcardQuestion,
      flashcardAnswer: flashcardAnswer ?? this.flashcardAnswer,
      quizQuestions: quizQuestions ?? this.quizQuestions,
    );
  }

  bool get hasFlashcard =>
      flashcardQuestion != null &&
      flashcardQuestion!.isNotEmpty &&
      flashcardAnswer != null &&
      flashcardAnswer!.isNotEmpty;

  // ✅ helper getter
  bool get hasQuiz =>
      quizQuestions != null && quizQuestions!.isNotEmpty;
}