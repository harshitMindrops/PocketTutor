import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:pocket_tutor/screens/login_screen.dart';
import 'package:pocket_tutor/screens/settings_screen.dart';
import 'package:pocket_tutor/utils/services/auth_service.dart';
import 'package:pocket_tutor/utils/services/gemini_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GeminiService _gemini = GeminiService();

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  String? _currentChatId;
  String _userName = 'User';
  String _userEmail = '';

  List<Map<String, dynamic>> _previousChats = [];
  List<Map<String, dynamic>> _messages = [];

  bool _isLoadingChats = true;
  bool _isSending = false;

  StreamSubscription<DatabaseEvent>? _chatsSubscription;
  StreamSubscription<DatabaseEvent>? _messagesSubscription;

  @override
  void initState() {
    super.initState();
    _initializeUser();
    _loadPreviousChats();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _chatsSubscription?.cancel();
    _messagesSubscription?.cancel();
    super.dispose();
  }

  void _initializeUser() {
    final user = AuthService.instance.currentUser;
    if (user != null) {
      setState(() {
        _userName = user.displayName ?? 'Student';
        _userEmail = user.email ?? '';
      });

      // Fetch name from database as fallback/update
      FirebaseDatabase.instance.ref('users/${user.uid}').get().then((snapshot) {
        if (snapshot.exists) {
          final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
          if (mounted && data.containsKey('name')) {
            setState(() {
              _userName = data['name'] ?? _userName;
            });
          }
        }
      });
    }
  }

  void _loadPreviousChats() {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    _chatsSubscription?.cancel();
    _chatsSubscription = FirebaseDatabase.instance
        .ref('users/${user.uid}/chats')
        .orderByChild('timestamp')
        .onValue
        .listen(
          (event) {
            if (!mounted) return;

            final List<Map<String, dynamic>> loadedChats = [];
            if (event.snapshot.exists) {
              final data = Map<dynamic, dynamic>.from(
                event.snapshot.value as Map,
              );
              data.forEach((key, value) {
                final chatData = Map<dynamic, dynamic>.from(value as Map);
                loadedChats.add({
                  'id': key,
                  'title': chatData['title'] ?? 'Chat',
                  'timestamp': chatData['timestamp'] ?? 0,
                });
              });

              // Sort by timestamp descending
              loadedChats.sort(
                (a, b) => b['timestamp'].compareTo(a['timestamp']),
              );
            }

            setState(() {
              _previousChats = loadedChats;
              _isLoadingChats = false;
            });
          },
          onError: (err) {
            if (mounted) {
              setState(() {
                _isLoadingChats = false;
              });
            }
          },
        );
  }

  void _selectChat(String chatId) {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    setState(() {
      _currentChatId = chatId;
      _messages = [];
    });

    _messagesSubscription?.cancel();
    _messagesSubscription = FirebaseDatabase.instance
        .ref('users/${user.uid}/chats/$chatId/messages')
        .orderByChild('timestamp')
        .onValue
        .listen((event) {
          if (!mounted) return;

          final List<Map<String, dynamic>> loadedMessages = [];
          if (event.snapshot.exists) {
            final data = Map<dynamic, dynamic>.from(
              event.snapshot.value as Map,
            );
            data.forEach((key, value) {
              final msgData = Map<dynamic, dynamic>.from(value as Map);
              loadedMessages.add({
                'id': key,
                'sender': msgData['sender'] ?? 'user',
                'text': msgData['text'] ?? '',
                'timestamp': msgData['timestamp'] ?? 0,
              });
            });

            // Sort by timestamp ascending
            loadedMessages.sort(
              (a, b) => a['timestamp'].compareTo(b['timestamp']),
            );
          }

          setState(() {
            _messages = loadedMessages;
          });
          _scrollToBottom();
        });
  }

  void _startNewChat() {
    _messagesSubscription?.cancel();
    setState(() {
      _currentChatId = null;
      _messages = [];
    });
  }

  Future<void> _deleteChat(String chatId) async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    // If deleting currently active chat, reset view
    if (_currentChatId == chatId) {
      _startNewChat();
    }

    await FirebaseDatabase.instance
        .ref('users/${user.uid}/chats/$chatId')
        .remove();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final user = AuthService.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isSending = true;
    });

    _messageController.clear();

    try {
      // 1. Create a new chat session if none is active
      String chatId = _currentChatId ?? '';
      if (_currentChatId == null) {
        final chatsRef = FirebaseDatabase.instance.ref(
          'users/${user.uid}/chats',
        );
        final newChatRef = chatsRef.push();
        chatId = newChatRef.key!;

        await newChatRef.set({
          'id': chatId,
          'title': text.length > 28 ? '${text.substring(0, 28)}...' : text,
          'timestamp': ServerValue.timestamp,
        });

        _selectChat(chatId);
      }

      // 2. Push User Message to Firebase
      final msgRef = FirebaseDatabase.instance
          .ref('users/${user.uid}/chats/$chatId/messages')
          .push();
      await msgRef.set({
        'sender': 'user',
        'text': text.trim(),
        'timestamp': ServerValue.timestamp,
      });

      _scrollToBottom();

      // 3. Generate AI Response via Gemini
      final aiResponse = await _gemini.query(text.trim());

      // 4. Push AI Message to Firebase
      final aiMsgRef = FirebaseDatabase.instance
          .ref('users/${user.uid}/chats/$chatId/messages')
          .push();
      await aiMsgRef.set({
        'sender': 'ai',
        'text': aiResponse,
        'timestamp': ServerValue.timestamp,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to send: ${e.toString()}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    await AuthService.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(
                Icons.menu_open_rounded,
                color: Colors.white,
                size: 28,
              ),
              onPressed: () => Scaffold.of(context).openDrawer(),
            );
          },
        ),
        title: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'PocketTutor',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '● OFFLINE MODE',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white54,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.history_rounded, color: Colors.white70),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF0F172A),
        child: Column(
          children: [
            // Drawer Header
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF312E81), Color(0xFF1E1B4B)],
                ),
              ),
              currentAccountPicture: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white10,
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Colors.indigoAccent,
                  size: 40,
                ),
              ),
              accountName: Text(
                _userName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              accountEmail: Text(
                _userEmail,
                style: const TextStyle(color: Colors.white70),
              ),
            ),

            // New Chat Trigger
            ListTile(
              leading: const Icon(
                Icons.add_circle_outline_rounded,
                color: Colors.indigoAccent,
              ),
              title: const Text(
                'New Chat',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(context); // Close drawer
                _startNewChat();
              },
            ),
            const Divider(color: Colors.white10),

            // Previous Chats Title
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'PREVIOUS CHATS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white30,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),

            // Chats History List
            Expanded(
              child: _isLoadingChats
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.indigoAccent,
                        ),
                      ),
                    )
                  : _previousChats.isEmpty
                  ? const Center(
                      child: Text(
                        'No previous chats',
                        style: TextStyle(color: Colors.white24, fontSize: 14),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _previousChats.length,
                      itemBuilder: (context, index) {
                        final chat = _previousChats[index];
                        final isCurrent = _currentChatId == chat['id'];
                        return ListTile(
                          leading: Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: isCurrent
                                ? Colors.indigoAccent
                                : Colors.white38,
                          ),
                          title: Text(
                            chat['title'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isCurrent ? Colors.white : Colors.white70,
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            onPressed: () => _deleteChat(chat['id']),
                          ),
                          onTap: () {
                            Navigator.pop(context); // Close drawer
                            _selectChat(chat['id']);
                          },
                        );
                      },
                    ),
            ),
            const Divider(color: Colors.white10),

            // Logout Option
            ListTile(
              leading: const Icon(
                Icons.logout_rounded,
                color: Colors.redAccent,
              ),
              title: const Text(
                'Logout',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(context); // Close drawer
                _logout();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF070B19)],
          ),
        ),
        child: Column(
          children: [
            // Chat Message List or Empty State
            Expanded(
              child: _messages.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16.0),
                      itemCount: _messages.length + (_isSending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length && _isSending) {
                          return _buildTypingIndicator();
                        }
                        final message = _messages[index];
                        final isUser = message['sender'] == 'user';
                        return _buildChatBubble(message['text'], isUser);
                      },
                    ),
            ),

            // Bottom Input Bar
            _buildBottomInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            // Robot Icon logo
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.indigoAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                size: 50,
                color: Colors.indigoAccent,
              ),
            ),
            const SizedBox(height: 30),

            // Welcome Header
            const Text(
              'How can I help you today?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),

            // Quick Prompt Suggestion Cards
            _buildPromptCard(
              'Explain Quantum Entanglement like I\'m five.',
              onTap: () =>
                  _sendMessage('Explain Quantum Entanglement like I\'m five.'),
            ),
            const SizedBox(height: 16),
            _buildPromptCard(
              'Summarize my last lecture on Microeconomics.',
              onTap: () =>
                  _sendMessage('Summarize my last lecture on Microeconomics.'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptCard(String text, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18.0),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10, width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white30,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF4F46E5) // Indigo purple for User
              : const Color(0xFF1E293B), // Slate/Grey for AI
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: isUser ? const Radius.circular(18) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(18),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.zero,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
              ),
            ),
            SizedBox(width: 10),
            Text(
              "PocketTutor is thinking...",
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(top: BorderSide(color: Colors.white10, width: 1)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Attachment Icon
            IconButton(
              icon: const Icon(
                Icons.attach_file_rounded,
                color: Colors.white54,
              ),
              onPressed: () {},
            ),

            // Input TextField
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        maxLines: null,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Ask PocketTutor...',
                          hintStyle: TextStyle(color: Colors.white30),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12.0),
                        ),
                        onSubmitted: (value) => _sendMessage(value),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.mic_none_rounded,
                        color: Colors.white54,
                      ),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Send Button
            GestureDetector(
              onTap: () => _sendMessage(_messageController.text),
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF4F46E5),
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
