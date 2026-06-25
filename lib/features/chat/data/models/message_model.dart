import 'package:pocket_tutor/core/utils/timestamp_parser.dart';

class MessageModel {
  final String id;
  final String chatId;
  final String userId;
  final String sender;
  final String text;
  final String? imagePath;
  final int timestamp;
  final bool synced;

  const MessageModel({
    required this.id,
    required this.chatId,
    required this.userId,
    required this.sender,
    required this.text,
    this.imagePath,
    required this.timestamp,
    this.synced = true,
  });

  factory MessageModel.fromMap(
    String userId,
    String chatId,
    String messageId,
    Map<dynamic, dynamic> map,
  ) {
    return MessageModel(
      id: messageId,
      chatId: chatId,
      userId: userId,
      sender: map['sender']?.toString() ?? 'user',
      text: map['text']?.toString() ?? '',
      imagePath: map['imagePath']?.toString(),
      timestamp: TimestampParser.parse(map['timestamp']),
    );
  }

  Map<String, dynamic> toMap() => {
    'sender': sender,
    'text': text,
    'imagePath': imagePath,
    'timestamp': timestamp,
  };

  MessageModel copyWith({
    String? id,
    String? chatId,
    String? userId,
    String? sender,
    String? text,
    String? imagePath,
    int? timestamp,
    bool? synced,
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
    );
  }
}
