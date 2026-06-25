import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:pocket_tutor/app/theme/app_colors.dart';

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
        final ext = imagePath != null
            ? imagePath.split('.').last.toLowerCase()
            : '';
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
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Add Attachment',
                style: TextStyle(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              _AttachOption(
                emoji: '📷',
                label: 'Take a Photo',
                color: AppColors.primary,
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
              _AttachOption(
                emoji: '🖼️',
                label: 'Choose from Gallery',
                color: AppColors.secondary,
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
              _AttachOption(
                emoji: '📄',
                label: 'Choose Document (PDF / Word)',
                color: AppColors.offline,
                onTap: () async {
                  try {
                    final pickerResult = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf', 'docx', 'doc'],
                    );
                    if (context.mounted) Navigator.pop(context, pickerResult);
                  } catch (e) {
                    debugPrint('Error picking file: \$e');
                    if (context.mounted) Navigator.pop(context, null);
                  }
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
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
                  content: Text(
                    'File size stands more than 5MB. Please choose a smaller file to save tokens.',
                  ),
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border(
              bottom: BorderSide(
                color: AppColors.glassBorder.withValues(alpha: 0.4),
              ),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Builder(
                    builder: (ctx) => IconButton(
                      icon: const Icon(
                        Icons.menu_rounded,
                        color: AppColors.onSurface,
                        size: 26,
                      ),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Gradient title
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        AppColors.heroGradient.createShader(bounds),
                    child: const Text(
                      'PocketTutor',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Online dot
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isOnline ? AppColors.online : AppColors.offline,
                      boxShadow: [
                        BoxShadow(
                          color:
                              (_isOnline ? AppColors.online : AppColors.offline)
                                  .withValues(alpha: 0.6),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Reminder bell
                  _AppBarBtn(
                    icon: Icons.notifications_outlined,
                    onTap: () => showReminderSheet(context),
                  ),
                  _AppBarBtn(
                    icon: Icons.settings_outlined,
                    onTap: () => AppRoutes.openSettings(context),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),
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
        decoration: const BoxDecoration(gradient: AppColors.meshGradient),
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
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primaryLight.withValues(alpha: 0.3),
                  ),
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
                        _selectedFile!.path
                            .split(Platform.isWindows ? '\\' : '/')
                            .last,
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
    if (ext == 'jpg' ||
        ext == 'jpeg' ||
        ext == 'png' ||
        ext == 'webp' ||
        ext == 'gif') {
      return Image.file(File(path), width: 50, height: 50, fit: BoxFit.cover);
    }

    IconData iconData = Icons.insert_drive_file_rounded;
    Color iconColor = AppColors.onSurfaceMuted;
    if (ext == 'pdf') {
      iconData = Icons.picture_as_pdf_rounded;
      iconColor = const Color(0xFFFF4757);
    } else if (ext == 'docx' || ext == 'doc') {
      iconData = Icons.description_rounded;
      iconColor = AppColors.secondary;
    }

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(iconData, color: iconColor, size: 26),
    );
  }
}

// ── Helper: AppBar icon button ────────────────────────────────────────────────
class _AppBarBtn extends StatefulWidget {
  const _AppBarBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_AppBarBtn> createState() => _AppBarBtnState();
}

class _AppBarBtnState extends State<_AppBarBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: _pressed
              ? AppColors.primaryLight.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          widget.icon,
          color: _pressed ? AppColors.primaryLight : AppColors.onSurface,
          size: 22,
        ),
      ),
    );
  }
}

// ── Helper: Attachment option tile ───────────────────────────────────────────
class _AttachOption extends StatelessWidget {
  const _AttachOption({
    required this.emoji,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
      ),
      title: Text(
        label,
        style: const TextStyle(
          color: AppColors.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        size: 14,
        color: AppColors.onSurfaceMuted,
      ),
    );
  }
}
