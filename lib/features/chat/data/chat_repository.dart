import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_database/firebase_database.dart';
import 'package:pocket_tutor/core/network/connectivity_service.dart';
import 'package:pocket_tutor/core/services/image_storage_service.dart';
import 'package:pocket_tutor/core/storage/hive_service.dart';
import 'package:pocket_tutor/features/chat/data/gemini_service.dart';
import 'package:pocket_tutor/features/chat/data/models/chat_model.dart';
import 'package:pocket_tutor/features/chat/data/models/chat_tool_type.dart';
import 'package:pocket_tutor/features/chat/data/models/message_model.dart';
import 'package:pocket_tutor/features/chat/data/models/pending_sync_item.dart';
import 'package:pocket_tutor/features/chat/presentation/widgets/quiz.dart'
    show QuizQuestion;

class ChatRepository {
  ChatRepository._();

  static final instance = ChatRepository._();

  final HiveService _hive = HiveService.instance;
  final ConnectivityService _connectivity = ConnectivityService.instance;
  final GeminiService _gemini = GeminiService.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final ImageStorageService _imageStorage = ImageStorageService.instance;

  final StreamController<List<ChatModel>> _chatsController =
      StreamController<List<ChatModel>>.broadcast();
  final Map<String, StreamController<List<MessageModel>>> _messageControllers =
      {};

  StreamSubscription<DatabaseEvent>? _chatsSubscription;
  final Map<String, StreamSubscription<DatabaseEvent>> _messagesSubscriptions =
      {};

  StreamSubscription<bool>? _connectivitySubscription;

  String? _activeUserId;
  String? _activeChatId;

  Stream<List<ChatModel>> watchChats(String userId) {
    _activeUserId = userId;
    _syncPendingIfOnline(userId);
    _startChatsSync(userId);
    return _chatsController.stream;
  }

  Stream<List<MessageModel>> watchMessages(String userId, String chatId) {
    _activeUserId = userId;
    _activeChatId = chatId;
    _messageControllers.putIfAbsent(
      chatId,
      () => StreamController<List<MessageModel>>.broadcast(),
    );
    _startMessagesSync(userId, chatId);
    // Ensure any pending offline messages are processed now that we have a context.
    _syncPendingIfOnline(userId);
    return _messageControllers[chatId]!.stream;
  }

  void init() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      isOnline,
    ) {
      if (isOnline && _activeUserId != null) {
        _syncPendingIfOnline(_activeUserId!);
        _startChatsSync(_activeUserId!);
        if (_activeChatId != null) {
          _startMessagesSync(_activeUserId!, _activeChatId!);
        }
      }
    });
  }

  void _syncPendingIfOnline(String userId) {
    if (_connectivity.isOnline) {
      unawaited(syncPendingItems(userId));
    }
  }

  void _emitChats(String userId) {
    if (_chatsController.isClosed) return;
    _chatsController.add(_hive.getChatsForUser(userId));
  }

  void _emitMessages(String userId, String chatId) {
    final controller = _messageControllers[chatId];
    if (controller == null || controller.isClosed) return;
    controller.add(_hive.getMessagesForChat(userId, chatId));
  }

  void _startChatsSync(String userId) {
    // Use a microtask so the caller's .listen() is attached before we emit.
    // Without this, offline chats are lost because the broadcast event fires
    // before the subscriber has a chance to register.
    Future.microtask(() => _emitChats(userId));
    if (!_connectivity.isOnline) return;

    _chatsSubscription?.cancel();
    _chatsSubscription = _database
        .ref('users/$userId/chats')
        .orderByChild('timestamp')
        .onValue
        .listen((event) async {
          if (event.snapshot.exists) {
            final data = Map<dynamic, dynamic>.from(
              event.snapshot.value as Map,
            );
            for (final entry in data.entries) {
              await _hive.saveChat(
                ChatModel.fromMap(
                  userId,
                  entry.key.toString(),
                  Map<dynamic, dynamic>.from(entry.value as Map),
                ),
              );
            }
          }
          _emitChats(userId);
        }, onError: (_) => _emitChats(userId));
  }

  void _startMessagesSync(String userId, String chatId) {
    // Same microtask fix: ensure the listener is subscribed before emitting
    // cached messages from Hive, otherwise offline messages are never shown.
    Future.microtask(() => _emitMessages(userId, chatId));
    if (!_connectivity.isOnline) return;

    _messagesSubscriptions[chatId]?.cancel();
    _messagesSubscriptions[chatId] = _database
        .ref('users/$userId/chats/$chatId/messages')
        .orderByChild('timestamp')
        .onValue
        .listen((event) async {
          if (event.snapshot.exists) {
            final data = Map<dynamic, dynamic>.from(
              event.snapshot.value as Map,
            );
            for (final entry in data.entries) {
              final messageId = entry.key.toString();
              final rawMsg = MessageModel.fromMap(
                userId,
                chatId,
                messageId,
                Map<dynamic, dynamic>.from(entry.value as Map),
              );

              // --- Offline image persistence ---
              // Check if Hive already has this message with a valid local file.
              final existing = _hive.getMessage(userId, chatId, messageId);

              String? resolvedImagePath = rawMsg.imagePath;

              if (existing != null &&
                  _imageStorage.isValidLocalFile(existing.imagePath)) {
                // Already have a good local copy — don't overwrite with base64.
                resolvedImagePath = existing.imagePath;
              } else if (rawMsg.imagePath != null &&
                  _imageStorage.isBase64(rawMsg.imagePath!)) {
                // Firebase returned a base64 image — decode & save to disk.
                final localPath = await _imageStorage.saveImageFromBase64(
                  rawMsg.imagePath!,
                  messageId,
                );
                resolvedImagePath = localPath ?? rawMsg.imagePath;
              }

              await _hive.saveMessage(
                rawMsg.copyWith(
                  imagePath: resolvedImagePath,
                  toolTag: rawMsg.toolTag ?? existing?.toolTag,
                  flashcardQuestion:
                      rawMsg.flashcardQuestion ?? existing?.flashcardQuestion,
                  flashcardAnswer:
                      rawMsg.flashcardAnswer ?? existing?.flashcardAnswer,
                  quizQuestions:
                      rawMsg.quizQuestions ?? existing?.quizQuestions,
                ),
              );
            }
          }
          _emitMessages(userId, chatId);
        }, onError: (_) => _emitMessages(userId, chatId));
  }

  Future<String> createChat({
    required String userId,
    required String title,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    if (_connectivity.isOnline) {
      final newChatRef = _database.ref('users/$userId/chats').push();
      final chatId = newChatRef.key!;
      final chat = ChatModel(
        id: chatId,
        userId: userId,
        title: title,
        timestamp: timestamp,
      );

      await newChatRef.set({
        ...chat.toMap(),
        'timestamp': ServerValue.timestamp,
      });
      await _hive.saveChat(chat);
      _emitChats(userId);
      return chatId;
    }

    final localChatId = 'local_$timestamp';
    await _hive.saveChat(
      ChatModel(
        id: localChatId,
        userId: userId,
        title: title,
        timestamp: timestamp,
        isLocalOnly: true,
      ),
    );
    _emitChats(userId);
    return localChatId;
  }

  Future<void> sendMessage({
    required String userId,
    required String chatId,
    required String text,
    String? imagePath,
    ChatToolType? tool,
  }) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty && imagePath == null) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final localMessageId = 'local_msg_$timestamp';
    final toolTag = tool?.storageKey;

    String? persistentImagePath;
    if (imagePath != null) {
      try {
        // Use a stable filename based on the local message id so we can track
        // and clean it up later.
        persistentImagePath = await _imageStorage.ensurePersistentCopy(
          imagePath,
          localMessageId,
        );
      } catch (e) {
        persistentImagePath = imagePath;
      }
    }

    String displayMsgText = trimmedText;
    if (trimmedText.isEmpty && persistentImagePath != null) {
      final ext = persistentImagePath.split('.').last.toLowerCase();
      if (ext == 'pdf' || ext == 'docx' || ext == 'doc') {
        displayMsgText = "Document query";
      } else {
        displayMsgText = "Image query";
      }
    }

    await _hive.saveMessage(
      MessageModel(
        id: localMessageId,
        chatId: chatId,
        userId: userId,
        sender: 'user',
        text: displayMsgText,
        imagePath: persistentImagePath,
        timestamp: timestamp,
        synced: false,
        toolTag: toolTag,
      ),
    );
    _emitMessages(userId, chatId);

    if (!_connectivity.isOnline) {
      await _hive.addPendingSync(
        PendingSyncItem(
          id: 'sync_$timestamp',
          userId: userId,
          type: PendingSyncType.sendMessage,
          chatId: chatId,
          messageText: displayMsgText,
          messageId: localMessageId,
          createdAt: timestamp,
          imagePath: persistentImagePath,
          toolTag: toolTag,
        ),
      );
      return;
    }

    await _sendMessageOnline(
      userId: userId,
      chatId: chatId,
      text: trimmedText,
      imagePath: persistentImagePath,
      localMessageId: localMessageId,
      tool: tool,
    );
  }

  Future<void> _sendMessageOnline({
    required String userId,
    required String chatId,
    required String text,
    String? imagePath,
    required String localMessageId,
    ChatToolType? tool,
  }) async {
    var resolvedChatId = chatId;
    String initialText = text;
    if (text.isEmpty && imagePath != null) {
      final ext = imagePath.split('.').last.toLowerCase();
      if (ext == 'pdf' || ext == 'docx' || ext == 'doc') {
        initialText = "Document query";
      } else {
        initialText = "Image query";
      }
    }

    if (chatId.startsWith('local_')) {
      resolvedChatId = await _uploadLocalChat(userId, chatId, initialText);
    }

    await _hive.deleteMessage(userId, resolvedChatId, localMessageId);
    if (resolvedChatId != chatId) {
      await _hive.deleteMessage(userId, chatId, localMessageId);
    }

    String? base64File;
    if (imagePath != null) {
      try {
        final file = File(imagePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final ext = imagePath.split('.').last.toLowerCase();
          String mimeType = 'image/jpeg';
          if (ext == 'png') {
            mimeType = 'image/png';
          } else if (ext == 'webp') {
            mimeType = 'image/webp';
          } else if (ext == 'gif') {
            mimeType = 'image/gif';
          } else if (ext == 'pdf') {
            mimeType = 'application/pdf';
          } else if (ext == 'docx') {
            mimeType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
          } else if (ext == 'doc') {
            mimeType = 'application/msword';
          }
          base64File = 'data:$mimeType;base64,${base64.encode(bytes)}';
        }
      } catch (_) {}
    }

    final toolTag = tool?.storageKey;

    final msgRef = _database
        .ref('users/$userId/chats/$resolvedChatId/messages')
        .push();
    await msgRef.set({
      'sender': 'user',
      'text': initialText,
      'imagePath': base64File,
      'timestamp': ServerValue.timestamp,
      if (toolTag != null) 'toolTag': toolTag,
    });

    // When the message is confirmed by Firebase, update Hive with the real
    // message id but keep the same local image file path.
    await _hive.saveMessage(
      MessageModel(
        id: msgRef.key!,
        chatId: resolvedChatId,
        userId: userId,
        sender: 'user',
        text: initialText,
        imagePath: imagePath, // local file path — not base64
        timestamp: DateTime.now().millisecondsSinceEpoch,
        synced: true,
        toolTag: toolTag,
      ),
    );
    // Remove the old local-id entry.
    await _hive.deleteMessage(userId, resolvedChatId, localMessageId);
    if (resolvedChatId != chatId) {
      await _hive.deleteMessage(userId, chatId, localMessageId);
    }

    final File? fileToQuery = imagePath != null ? File(imagePath) : null;

    String aiResponseText;
    String? flashcardQuestion;
    String? flashcardAnswer;
    List<QuizQuestion>? quizQuestions;

    if (tool == ChatToolType.generateFlashcard) {
      final flashcard = await _gemini.generateFlashcard(
        initialText,
        attachmentFile: fileToQuery,
      );
      flashcardQuestion = flashcard.question;
      flashcardAnswer = flashcard.answer;
      aiResponseText = 'Flashcard ready';
    } else if (tool == ChatToolType.generateQuiz) {
      // ✅ generateQuiz() use karo (raw query() nahi) — ye Gemini ke JSON
      // response ko parse karke List<QuizQuestion> deta hai, jise neeche
      // Firebase + Hive dono mein save karna zaroori hai. Pehle yahan
      // sirf raw unparsed JSON text aiResponseText mein store ho raha tha
      // aur quizQuestions kabhi set nahi hota tha — isi wajah se UI quiz
      // widget null quizQuestions ke saath crash karta tha.
      quizQuestions = await _gemini.generateQuiz(
        initialText,
        attachmentFile: fileToQuery,
      );
      aiResponseText = 'Quiz ready';
    } else {
      aiResponseText = await _gemini.query(
        initialText,
        attachmentFile: fileToQuery,
      );
    }

    final aiMsgRef = _database
        .ref('users/$userId/chats/$resolvedChatId/messages')
        .push();

    await aiMsgRef.set({
      'sender': 'ai',
      'text': aiResponseText,
      'timestamp': ServerValue.timestamp,
      if (toolTag != null) 'toolTag': toolTag,
      if (flashcardQuestion != null) 'flashcardQuestion': flashcardQuestion,
      if (flashcardAnswer != null) 'flashcardAnswer': flashcardAnswer,
      if (quizQuestions != null && quizQuestions.isNotEmpty)
        'quizQuestions': jsonEncode(
          quizQuestions
              .map(
                (q) => {
                  'question': q.question,
                  'options': q.options,
                  'correctIndex': q.correctIndex,
                },
              )
              .toList(),
        ),
    });

    await _hive.saveMessage(
      MessageModel(
        id: aiMsgRef.key!,
        chatId: resolvedChatId,
        userId: userId,
        sender: 'ai',
        text: aiResponseText,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        toolTag: toolTag,
        flashcardQuestion: flashcardQuestion,
        flashcardAnswer: flashcardAnswer,
        quizQuestions: quizQuestions,
      ),
    );

    _emitMessages(userId, resolvedChatId);
    _emitChats(userId);
  }

  Future<String> _uploadLocalChat(
    String userId,
    String localChatId,
    String firstMessage,
  ) async {
    final localChat = _hive
        .getChatsForUser(userId)
        .firstWhere(
          (chat) => chat.id == localChatId,
          orElse: () => ChatModel(
            id: localChatId,
            userId: userId,
            title: firstMessage.length > 28
                ? '${firstMessage.substring(0, 28)}...'
                : firstMessage,
            timestamp: DateTime.now().millisecondsSinceEpoch,
            isLocalOnly: true,
          ),
        );

    final newChatRef = _database.ref('users/$userId/chats').push();
    final remoteChatId = newChatRef.key!;

    await newChatRef.set({
      'id': remoteChatId,
      'title': localChat.title,
      'timestamp': ServerValue.timestamp,
    });

    await _hive.replaceChatId(
      userId: userId,
      oldChatId: localChatId,
      newChatId: remoteChatId,
    );

    if (_activeChatId == localChatId) {
      _activeChatId = remoteChatId;
    }

    _emitChats(userId);
    return remoteChatId;
  }

  Future<void> deleteChat(String userId, String chatId) async {
    // Collect image paths before deleting from Hive so we can clean up disk.
    final imagePaths = await _hive.deleteChat(userId, chatId);
    unawaited(_imageStorage.deleteImages(imagePaths));
    _emitChats(userId);

    if (_connectivity.isOnline && !chatId.startsWith('local_')) {
      await _database.ref('users/$userId/chats/$chatId').remove();
      return;
    }

    if (!_connectivity.isOnline && !chatId.startsWith('local_')) {
      await _hive.addPendingSync(
        PendingSyncItem(
          id: 'delete_${DateTime.now().millisecondsSinceEpoch}',
          userId: userId,
          type: PendingSyncType.deleteChat,
          chatId: chatId,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
  }

  Future<void> syncPendingItems(String userId) async {
    if (!_connectivity.isOnline) return;

    for (final item in _hive.getPendingSyncForUser(userId)) {
      try {
        if (item.type == PendingSyncType.deleteChat) {
          await _database.ref('users/$userId/chats/${item.chatId}').remove();
          await _hive.removePendingSync(item.id);
        } else if (item.type == PendingSyncType.sendMessage &&
            item.messageText != null &&
            item.messageId != null) {
          await _sendMessageOnline(
            userId: userId,
            chatId: item.chatId,
            text: item.messageText!,
            imagePath: item.imagePath,
            localMessageId: item.messageId!,
            tool: ChatToolTypeX.fromStorageKey(item.toolTag),
          );
          await _hive.removePendingSync(item.id);
        }
      } catch (_) {
        // Retry on next connectivity change.
      }
    }
  }

  void dispose() {
    _chatsSubscription?.cancel();
    for (final s in _messagesSubscriptions.values) {
      s.cancel();
    }

    _connectivitySubscription?.cancel();
    _chatsController.close();
    for (final controller in _messageControllers.values) {
      controller.close();
    }
    _messageControllers.clear();
  }
}