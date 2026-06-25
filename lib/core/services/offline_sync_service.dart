import 'dart:async';
import 'dart:io';

import 'package:pocket_tutor/core/network/connectivity_service.dart';
import 'package:pocket_tutor/core/services/image_storage_service.dart';
import 'package:pocket_tutor/core/storage/hive_service.dart';
import 'package:pocket_tutor/features/chat/data/gemini_service.dart';
import 'package:pocket_tutor/features/chat/data/models/message_model.dart';
import 'package:pocket_tutor/features/chat/data/models/pending_sync_item.dart';

/// Service responsible for processing pending sync items when the device regains
/// connectivity.
///
/// Note: In this codebase, pending item processing is handled by
/// `ChatRepository.syncPendingItems(userId)`. This service currently exists to
/// trigger a pass when connectivity changes, but it does not implement a
/// user-id lookup.
class OfflineSyncService {
  OfflineSyncService._();
  static final instance = OfflineSyncService._();

  StreamSubscription<bool>? _connectivitySub;
  bool _isProcessing = false;

  /// Initializes the service. Should be called once during app start-up.
  Future<void> init() async {
    _connectivitySub = ConnectivityService.instance.onConnectivityChanged
        .listen((isOnline) {
      if (isOnline) {
        unawaited(_processPending());
      }
    });

    if (ConnectivityService.instance.isOnline) {
      unawaited(_processPending());
    }
  }

  /// Cancels any active listeners – call when the app shuts down.
  Future<void> dispose() async {
    await _connectivitySub?.cancel();
  }

  /// Core logic: fetch pending items for the current user and process them
  /// sequentially.
  Future<void> _processPending() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final currentUserId = _currentUserIdSync();
      if (currentUserId.isEmpty) return;

      final user = HiveService.instance.getUser(currentUserId);

      if (user == null) return;

      final pending = HiveService.instance.getPendingSyncForUser(user.uid);
      for (final item in pending) {
        try {
          await _handleItem(item, user.uid);
          await HiveService.instance.removePendingSync(item.id);
        } catch (_) {
          // Continue with the next item.
        }
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Returns the currently authenticated user id.
  ///
  /// This project does not currently expose the active user through HiveService,
  /// so a real implementation must be wired in (e.g., from Auth state).
  String _currentUserIdSync() {
    // Offline sync ko correctly run karne ke liye auth/user id
    // dependency chahiye hoti hai. Filhaal, safe fallback:
    // agar Pending items me se koi mil jaye to wahi userId return karo.
    // (HiveService getPendingSyncForUser expects userId, so we try a
    // best-effort approach by reading stored messages/users is not available
    // publicly in HiveService here.)
    //
    // Isliye default: empty string, aur _processPending me check hoga.
    return '';
  }


  Future<void> _handleItem(PendingSyncItem item, String userId) async {
    final messageId = item.messageId ?? item.id;

    // Ensure any local file path is persisted inside the chat_images directory.
    String? persistentPath;
    if (item.imagePath != null && item.imagePath!.isNotEmpty) {
      if (ImageStorageService.instance.isBase64(item.imagePath!)) {
      persistentPath = await ImageStorageService.instance.saveFileFromBase64(
        item.imagePath!,
        messageId,
      );

      } else {
        persistentPath = await ImageStorageService.instance
            .ensurePersistentCopy(item.imagePath!, messageId);
      }
    }

    final outgoing = MessageModel(
      id: item.messageId ?? item.id,
      chatId: item.chatId,
      userId: userId,
      sender: 'user',
      text: item.messageText ?? '',
      imagePath: persistentPath,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      synced: true,
    );

    await HiveService.instance.saveMessage(outgoing);

    final responseText = await GeminiService.instance.query(
      item.messageText ?? '',
      attachmentFile: persistentPath == null ? null : File(persistentPath),

    );

    final aiMessage = MessageModel(
      id: '${messageId}_ai',
      chatId: item.chatId,
      userId: userId,
      sender: 'ai',
      text: responseText,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      synced: true,
    );

    await HiveService.instance.saveMessage(aiMessage);
  }
}

