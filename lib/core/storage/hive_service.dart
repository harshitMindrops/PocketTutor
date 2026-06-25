import 'package:hive_flutter/hive_flutter.dart';
import 'package:pocket_tutor/core/storage/hive_adapters.dart';
import 'package:pocket_tutor/features/auth/data/models/user_model.dart';
import 'package:pocket_tutor/features/chat/data/models/chat_model.dart';
import 'package:pocket_tutor/features/chat/data/models/message_model.dart';
import 'package:pocket_tutor/features/chat/data/models/pending_sync_item.dart';

class HiveService {
  HiveService._();

  static final instance = HiveService._();

  static const _usersBoxName = 'users';
  static const _chatsBoxName = 'chats';
  static const _messagesBoxName = 'messages';
  static const _pendingSyncBoxName = 'pending_sync';

  late Box<UserModel> _usersBox;
  late Box<ChatModel> _chatsBox;
  late Box<MessageModel> _messagesBox;
  late Box<PendingSyncItem> _pendingSyncBox;

  Future<void> init() async {
    await Hive.initFlutter();
    _registerAdapters();

    _usersBox = await Hive.openBox<UserModel>(_usersBoxName);
    _chatsBox = await Hive.openBox<ChatModel>(_chatsBoxName);
    _messagesBox = await Hive.openBox<MessageModel>(_messagesBoxName);
    _pendingSyncBox = await Hive.openBox<PendingSyncItem>(_pendingSyncBoxName);
  }

  void _registerAdapters() {
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(UserModelAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(ChatModelAdapter());
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(MessageModelAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(PendingSyncItemAdapter());
    }
  }

  String _chatKey(String userId, String chatId) => '$userId::$chatId';

  String _messageKey(String userId, String chatId, String messageId) =>
      '$userId::$chatId::$messageId';

  Future<void> saveUser(UserModel user) => _usersBox.put(user.uid, user);

  UserModel? getUser(String uid) => _usersBox.get(uid);

  Future<void> saveChat(ChatModel chat) =>
      _chatsBox.put(_chatKey(chat.userId, chat.id), chat);

  List<ChatModel> getChatsForUser(String userId) {
    final prefix = '$userId::';
    final chats = _chatsBox.keys
        .where((key) => key.toString().startsWith(prefix))
        .map((key) => _chatsBox.get(key))
        .whereType<ChatModel>()
        .toList();
    chats.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return chats;
  }

  /// Deletes a chat and all its messages from Hive.
  /// Returns the list of local image paths for all deleted messages so the
  /// caller can remove the files from disk.
  Future<List<String?>> deleteChat(String userId, String chatId) async {
    await _chatsBox.delete(_chatKey(userId, chatId));

    final prefix = '$userId::$chatId::';
    final keysToDelete = _messagesBox.keys
        .where((key) => key.toString().startsWith(prefix))
        .toList();

    final imagePaths = <String?>[];
    for (final key in keysToDelete) {
      final msg = _messagesBox.get(key);
      imagePaths.add(msg?.imagePath);
      await _messagesBox.delete(key);
    }
    return imagePaths;
  }

  Future<void> replaceChatId({
    required String userId,
    required String oldChatId,
    required String newChatId,
  }) async {
    final oldKey = _chatKey(userId, oldChatId);
    final chat = _chatsBox.get(oldKey);
    if (chat == null) return;

    await _chatsBox.delete(oldKey);
    await saveChat(chat.copyWith(id: newChatId, isLocalOnly: false));

    final prefix = '$userId::$oldChatId::';
    final messageKeys = _messagesBox.keys
        .where((key) => key.toString().startsWith(prefix))
        .toList();

    for (final key in messageKeys) {
      final message = _messagesBox.get(key);
      if (message == null) continue;
      await _messagesBox.delete(key);
      await saveMessage(message.copyWith(chatId: newChatId));
    }
  }

  Future<void> saveMessage(MessageModel message) => _messagesBox.put(
        _messageKey(message.userId, message.chatId, message.id),
        message,
      );

  MessageModel? getMessage(
    String userId,
    String chatId,
    String messageId,
  ) =>
      _messagesBox.get(_messageKey(userId, chatId, messageId));

  /// Deletes a single message from Hive and returns its local image path (if
  /// any) so the caller can decide whether to delete the file from disk.
  Future<String?> deleteMessage(
    String userId,
    String chatId,
    String messageId,
  ) async {
    final key = _messageKey(userId, chatId, messageId);
    final msg = _messagesBox.get(key);
    await _messagesBox.delete(key);
    return msg?.imagePath;
  }

  List<MessageModel> getMessagesForChat(String userId, String chatId) {
    final prefix = '$userId::$chatId::';
    final messages = _messagesBox.keys
        .where((key) => key.toString().startsWith(prefix))
        .map((key) => _messagesBox.get(key))
        .whereType<MessageModel>()
        .toList();
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return messages;
  }

  Future<void> addPendingSync(PendingSyncItem item) =>
      _pendingSyncBox.put(item.id, item);

  List<PendingSyncItem> getPendingSyncForUser(String userId) {
    final items = _pendingSyncBox.values
        .where((item) => item.userId == userId)
        .toList();
    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }

  Future<void> removePendingSync(String id) => _pendingSyncBox.delete(id);
}
