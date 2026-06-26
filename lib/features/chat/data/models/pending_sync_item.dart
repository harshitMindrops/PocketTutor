enum PendingSyncType { sendMessage, deleteChat }

class PendingSyncItem {
  final String id;
  final String userId;
  final PendingSyncType type;
  final String chatId;
  final String? messageText;
  final String? messageId;
  final int createdAt;
  final String? imagePath;
  final String? toolTag;

  const PendingSyncItem({
    required this.id,
    required this.userId,
    required this.type,
    required this.chatId,
    this.messageText,
    this.messageId,
    required this.createdAt,
    this.imagePath,
    this.toolTag,
  });
}
