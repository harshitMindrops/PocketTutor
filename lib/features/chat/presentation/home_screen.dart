import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:pocket_tutor/app/theme/app_colors.dart';
import 'package:pocket_tutor/app/theme/app_decorations.dart';
import 'package:pocket_tutor/core/constants/app_strings.dart';
import 'package:pocket_tutor/core/navigation/app_routes.dart';
import 'package:pocket_tutor/core/network/connectivity_service.dart';
import 'package:pocket_tutor/core/services/tts_service.dart';
import 'package:pocket_tutor/features/auth/data/auth_repository.dart';
import 'package:pocket_tutor/features/chat/data/chat_repository.dart';
import 'package:pocket_tutor/features/chat/data/models/chat_model.dart';
import 'package:pocket_tutor/features/chat/data/models/message_model.dart';
import 'package:pocket_tutor/features/chat/presentation/widgets/chat_drawer.dart';
import 'package:pocket_tutor/features/chat/presentation/widgets/chat_empty_state.dart';
import 'package:pocket_tutor/features/chat/presentation/widgets/chat_input_bar.dart';
import 'package:pocket_tutor/features/chat/presentation/widgets/message_bubble.dart';
import 'package:pocket_tutor/features/chat/presentation/widgets/offline_banner.dart';
import 'package:pocket_tutor/features/chat/presentation/widgets/typing_indicator.dart';
import 'package:pocket_tutor/features/reminders/presentation/reminder_sheet.dart';
import 'package:pocket_tutor/shared/widgets/connection_status_badge.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _chatRepo = ChatRepository.instance;
  final _connectivity = ConnectivityService.instance;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  String? _currentChatId;
  String _userName = 'User';
  String _userEmail = '';
  List<ChatModel> _chats = [];
  List<MessageModel> _messages = [];
  bool _isLoadingChats = true;
  bool _isSending = false;
  bool _isOnline = true;

  File? _selectedFile;
  final SpeechToText _speechToText = SpeechToText();
  String? _currentlySpeakingMessageId;
  bool _shouldSpeakNextResponse = false;
  String? _lastSpokenMessageId;

  StreamSubscription<List<ChatModel>>? _chatsSub;
  StreamSubscription<List<MessageModel>>? _messagesSub;
  StreamSubscription<bool>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _isOnline = _connectivity.isOnline;

    _connectivitySub = _connectivity.onConnectivityChanged.listen((online) {
      if (mounted) setState(() => _isOnline = online);
    });

    _loadUser();
    _loadChats();

    TtsService.instance.onSpeakStateChanged = (msgId) {
      if (mounted) {
        setState(() {
          _currentlySpeakingMessageId = msgId;
        });
      }
    };

    // If the widget already had an active chat before backgrounding,
    // reattach messages stream so offline Hive messages show.
    if (_currentChatId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _selectChat(_currentChatId!);
      });
    }
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    _messageController.dispose();
    _scrollController.dispose();
    _chatsSub?.cancel();
    _messagesSub?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = AuthRepository.instance.currentUser;
    if (user == null) return;

    setState(() {
      _userName = user.displayName ?? 'Student';
      _userEmail = user.email ?? '';
    });

    final profile = await AuthRepository.instance.getUserProfile(user.uid);
    if (profile != null && mounted) {
      setState(() {
        _userName = profile.name.isNotEmpty ? profile.name : _userName;
        _userEmail = profile.email.isNotEmpty ? profile.email : _userEmail;
      });
    }
  }

  void _loadChats() {
    final user = AuthRepository.instance.currentUser;
    if (user == null) return;

    _chatsSub?.cancel();
    _chatsSub = _chatRepo
        .watchChats(user.uid)
        .listen(
          (chats) {
            if (!mounted) return;
            setState(() {
              _chats = chats;
              _isLoadingChats = false;
            });
          },
          onError: (_) {
            if (mounted) setState(() => _isLoadingChats = false);
          },
        );
  }

  void _selectChat(String chatId) {
    final user = AuthRepository.instance.currentUser;
    if (user == null) return;

    setState(() {
      _currentChatId = chatId;
      _messages = [];
    });

    _messagesSub?.cancel();
    _messagesSub = _chatRepo.watchMessages(user.uid, chatId).listen((messages) {
      if (!mounted) return;

      final lastMsg = messages.isNotEmpty ? messages.last : null;
      if (lastMsg != null &&
          lastMsg.sender == 'ai' &&
          _shouldSpeakNextResponse &&
          lastMsg.id != _lastSpokenMessageId) {
        _lastSpokenMessageId = lastMsg.id;
        _shouldSpeakNextResponse = false;
        TtsService.instance.currentlySpeakingId = lastMsg.id;
        TtsService.instance.onSpeakStateChanged?.call(lastMsg.id);
        TtsService.instance.speak(lastMsg.text);
      }

      setState(() => _messages = messages);
      _scrollToBottom();
    });
  }

  void _startNewChat() {
    _messagesSub?.cancel();
    setState(() {
      _currentChatId = null;
      _messages = [];
    });
  }

  Future<void> _deleteChat(String chatId) async {
    final user = AuthRepository.instance.currentUser;
    if (user == null) return;
    if (_currentChatId == chatId) _startNewChat();
    await _chatRepo.deleteChat(user.uid, chatId);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty && _selectedFile == null) return;
    final user = AuthRepository.instance.currentUser;
    if (user == null) return;

    setState(() => _isSending = true);
    _messageController.clear();
    final String? imagePath = _selectedFile?.path;
    setState(() {
      _selectedFile = null;
    });

    try {
      var chatId = _currentChatId;
      if (chatId == null) {
        final ext = imagePath != null ? imagePath.split('.').last.toLowerCase() : '';
        final isDoc = ext == 'pdf' || ext == 'docx' || ext == 'doc';
        final title = text.trim().isNotEmpty
            ? (text.length > 28 ? '${text.substring(0, 28)}...' : text.trim())
            : (isDoc ? "Document query" : "Image query");
        chatId = await _chatRepo.createChat(userId: user.uid, title: title);
        _selectChat(chatId);
      }

      await _chatRepo.sendMessage(
        userId: user.uid,
        chatId: chatId,
        text: text.trim(),
        imagePath: imagePath,
      );

      if (!_isOnline && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.offlineMessageSaved),
            backgroundColor: AppColors.offline,
          ),
        );
      }
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAttachment() async {
    final picker = ImagePicker();
    final result = await showModalBottomSheet<dynamic>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.camera_alt_outlined,
                color: AppColors.primaryAccent,
              ),
              title: const Text(
                'Take a Photo',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                final img = await picker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 800,
                  maxHeight: 800,
                  imageQuality: 70,
                );
                if (context.mounted) Navigator.pop(context, img);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.primaryAccent,
              ),
              title: const Text(
                'Choose from Gallery',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                final img = await picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 800,
                  maxHeight: 800,
                  imageQuality: 70,
                );
                if (context.mounted) Navigator.pop(context, img);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.insert_drive_file_outlined,
                color: AppColors.primaryAccent,
              ),
              title: const Text(
                'Choose Document (PDF, Word)',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                try {
                  final pickerResult = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['pdf', 'docx', 'doc'],
                  );
                  if (context.mounted) Navigator.pop(context, pickerResult);
                } catch (e) {
                  debugPrint('Error picking file: $e');
                  if (context.mounted) Navigator.pop(context, null);
                }
              },
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    if (result is XFile) {
      setState(() {
        _selectedFile = File(result.path);
      });
    } else if (result is FilePickerResult) {
      if (result.files.single.path != null) {
        final pickedFile = File(result.files.single.path!);
        try {
          final size = await pickedFile.length();
          if (size > 5 * 1024 * 1024) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('File size stands more than 5MB. Please choose a smaller file to save tokens.'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
            return;
          }
        } catch (e) {
          debugPrint('Error checking file size: $e');
        }
        setState(() {
          _selectedFile = pickedFile;
        });
      }
    }
  }

  void _startVoiceInput() async {
    final speechAvailable = await _speechToText.initialize(
      onError: (val) => debugPrint('Error: $val'),
      onStatus: (val) => debugPrint('Status: $val'),
    );

    if (!speechAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Speech recognition not available on this device.'),
          ),
        );
      }
      return;
    }

    String recognizedText = '';
    bool isListening = true;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void startListening() async {
              setModalState(() {
                isListening = true;
                recognizedText = '';
              });
              await _speechToText.listen(
                onResult: (result) {
                  setModalState(() {
                    recognizedText = result.recognizedWords;
                  });
                },
              );
            }

            void stopListening() async {
              await _speechToText.stop();
              setModalState(() {
                isListening = false;
              });
            }

            if (!_speechToText.isListening && isListening) {
              startListening();
            }

            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isListening ? "Listening..." : "Listening Stopped",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isListening
                          ? AppColors.primaryAccent
                          : AppColors.onSurfaceHint,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 100,
                    alignment: Alignment.center,
                    child: SingleChildScrollView(
                      child: Text(
                        recognizedText.isEmpty
                            ? (isListening
                                  ? "Say something..."
                                  : "No words recognized")
                            : recognizedText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () {
                      if (isListening) {
                        stopListening();
                      } else {
                        startListening();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isListening
                            ? AppColors.primary.withAlpha(51)
                            : AppColors.border,
                      ),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isListening
                              ? AppColors.primary
                              : AppColors.onSurfaceMuted,
                        ),
                        child: Icon(
                          isListening
                              ? Icons.mic_rounded
                              : Icons.mic_none_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () {
                          _speechToText.stop();
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: recognizedText.isEmpty
                            ? null
                            : () {
                                _speechToText.stop();
                                Navigator.pop(context, recognizedText);
                              },
                        child: const Text(
                          'Send Message',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((resultText) {
      if (resultText != null && resultText.isNotEmpty) {
        _shouldSpeakNextResponse = true;
        _sendMessage(resultText);
      }
    });
  }

  Future<void> _logout() async {
    await AuthRepository.instance.signOut();
    if (!mounted) return;
    AppRoutes.goToLogin(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_open_rounded, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              AppStrings.appName,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            ConnectionStatusBadge(isOnline: _isOnline),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Study Reminders',
            icon: const Icon(
              Icons.notifications_outlined,
              color: AppColors.onSurface,
            ),
            onPressed: () => showReminderSheet(context),
          ),
          IconButton(
            icon: const Icon(
              Icons.settings_outlined,
              color: AppColors.onSurface,
            ),
            onPressed: () => AppRoutes.openSettings(context),
          ),
        ],
      ),
      drawer: ChatDrawer(
        userName: _userName,
        userEmail: _userEmail,
        chats: _chats,
        isLoading: _isLoadingChats,
        currentChatId: _currentChatId,
        onNewChat: _startNewChat,
        onSelectChat: _selectChat,
        onDeleteChat: _deleteChat,
        onLogout: _logout,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppDecorations.backgroundGradient,
        ),
        child: Column(
          children: [
            if (!_isOnline) const OfflineBanner(),
            Expanded(
              child: _messages.isEmpty
                  ? ChatEmptyState(onPromptSelected: _sendMessage)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length + (_isSending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length && _isSending) {
                          return const TypingIndicator();
                        }
                        final message = _messages[index];
                        final isSpeaking =
                            _currentlySpeakingMessageId == message.id;
                        return MessageBubble(
                          text: message.text,
                          isUser: message.sender == 'user',
                          imagePath: message.imagePath,
                          messageId: message.id,
                          currentlySpeakingId: _currentlySpeakingMessageId,
                          onSpeakToggled: message.sender == 'ai'
                              ? () {
                                  if (isSpeaking) {
                                    TtsService.instance.stop();
                                  } else {
                                    TtsService.instance.currentlySpeakingId =
                                        message.id;
                                    TtsService.instance.onSpeakStateChanged
                                        ?.call(message.id);
                                    TtsService.instance.speak(message.text);
                                  }
                                }
                              : null,
                        );
                      },
                    ),
            ),
            if (_selectedFile != null)
              Container(
                margin: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildSelectedFilePreview(_selectedFile!.path),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedFile!.path.split(Platform.isWindows ? '\\' : '/').last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.error,
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedFile = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ChatInputBar(
              controller: _messageController,
              onSend: _sendMessage,
              onAttachPick: _pickAttachment,
              onVoiceRecord: _startVoiceInput,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedFilePreview(String path) {
    final ext = path.split('.').last.toLowerCase();
    if (ext == 'jpg' || ext == 'jpeg' || ext == 'png' || ext == 'webp' || ext == 'gif') {
      return Image.file(
        File(path),
        width: 50,
        height: 50,
        fit: BoxFit.cover,
      );
    }

    IconData iconData = Icons.insert_drive_file;
    Color iconColor = Colors.grey;
    if (ext == 'pdf') {
      iconData = Icons.picture_as_pdf;
      iconColor = Colors.redAccent;
    } else if (ext == 'docx' || ext == 'doc') {
      iconData = Icons.description;
      iconColor = Colors.blue;
    }

    return Container(
      width: 50,
      height: 50,
      color: AppColors.background,
      child: Icon(iconData, color: iconColor, size: 28),
    );
  }
}
