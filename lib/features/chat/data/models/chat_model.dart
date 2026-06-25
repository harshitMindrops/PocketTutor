import 'package:pocket_tutor/core/utils/timestamp_parser.dart';

class ChatModel {
  final String id;
  final String userId;
  final String title;
  final int timestamp;
  final bool isLocalOnly;

  const ChatModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.timestamp,
    this.isLocalOnly = false,
  });

  factory ChatModel.fromMap(
    String userId,
    String chatId,
    Map<dynamic, dynamic> map,
  ) {
    return ChatModel(
      id: chatId,
      userId: userId,
      title: map['title']?.toString() ?? 'Chat',
      timestamp: TimestampParser.parse(map['timestamp'], fallback: 0),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'timestamp': timestamp,
      };

  ChatModel copyWith({
    String? id,
    String? userId,
    String? title,
    int? timestamp,
    bool? isLocalOnly,
  }) {
    return ChatModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      timestamp: timestamp ?? this.timestamp,
      isLocalOnly: isLocalOnly ?? this.isLocalOnly,
    );
  }
}
