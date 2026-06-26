// import 'dart:async';
// import 'dart:io';
// import 'dart:ui';

// import 'package:flutter/material.dart';
// import 'package:pocket_tutor/core/constants/app_strings.dart';
// import 'package:pocket_tutor/core/navigation/app_routes.dart';
// import 'package:pocket_tutor/core/navigation/chat_launch_action.dart';
// import 'package:pocket_tutor/core/network/connectivity_service.dart';
// import 'package:pocket_tutor/core/storage/hive_service.dart';
// import 'package:pocket_tutor/features/auth/data/auth_repository.dart';
// import 'package:pocket_tutor/features/chat/data/chat_repository.dart';
// import 'package:pocket_tutor/features/chat/data/models/chat_model.dart';
// import 'package:pocket_tutor/features/chat/presentation/widgets/offline_banner.dart';

// class DashboardScreen extends StatefulWidget {
//   const DashboardScreen({super.key});

//   @override
//   State<DashboardScreen> createState() => _DashboardScreenState();
// }

// class _DashboardScreenState extends State<DashboardScreen>
//     with TickerProviderStateMixin {
//   late AnimationController _fadeController;
//   late AnimationController _slideController;
//   late AnimationController _pulseController;
//   late Animation<double> _fadeAnim;
//   late Animation<Offset> _slideAnim;
//   late Animation<double> _pulseAnim;

//   String _userName = 'Student';
//   List<ChatModel> _chats = [];
//   int _messageCount = 0;
//   int _aiMessageCount = 0;
//   bool _isOnline = true;

//   StreamSubscription<List<ChatModel>>? _chatsSub;
//   StreamSubscription<bool>? _connectivitySub;

//   @override
//   void initState() {
//     super.initState();

//     _fadeController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 800),
//     );
//     _slideController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 700),
//     );
//     _pulseController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1500),
//     )..repeat(reverse: true);

//     _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
//     _slideAnim = Tween<Offset>(
//       begin: const Offset(0, 0.12),
//       end: Offset.zero,
//     ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
//     _pulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
//       CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
//     );

//     _fadeController.forward();
//     _slideController.forward();

//     _isOnline = ConnectivityService.instance.isOnline;
//     _connectivitySub =
//         ConnectivityService.instance.onConnectivityChanged.listen((online) {
//       if (mounted) setState(() => _isOnline = online);
//     });

//     _loadUser();
//     _loadChats();
//     _loadStats();
//   }

//   @override
//   void dispose() {
//     _chatsSub?.cancel();
//     _connectivitySub?.cancel();
//     _fadeController.dispose();
//     _slideController.dispose();
//     _pulseController.dispose();
//     super.dispose();
//   }

//   Future<void> _loadUser() async {
//     final user = AuthRepository.instance.currentUser;
//     if (user == null) return;

//     setState(() {
//       _userName = user.displayName ?? 'Student';
//     });

//     final profile = await AuthRepository.instance.getUserProfile(user.uid);
//     if (profile != null && mounted) {
//       setState(() {
//         _userName = profile.name.isNotEmpty ? profile.name : _userName;
//       });
//     }
//   }

//   void _loadChats() {
//     final user = AuthRepository.instance.currentUser;
//     if (user == null) return;

//     _chatsSub?.cancel();
//     _chatsSub = ChatRepository.instance.watchChats(user.uid).listen((chats) {
//       if (!mounted) return;
//       setState(() => _chats = chats);
//       _loadStats();
//     });
//   }

//   void _loadStats() {
//     final user = AuthRepository.instance.currentUser;
//     if (user == null) return;

//     final chats = HiveService.instance.getChatsForUser(user.uid);
//     var totalMessages = 0;
//     var aiMessages = 0;

//     for (final chat in chats) {
//       final messages =
//           HiveService.instance.getMessagesForChat(user.uid, chat.id);
//       totalMessages += messages.length;
//       aiMessages += messages.where((m) => m.sender == 'ai').length;
//     }

//     if (!mounted) return;
//     setState(() {
//       _messageCount = totalMessages;
//       _aiMessageCount = aiMessages;
//     });
//   }

//   String get _greetingPrefix {
//     final hour = DateTime.now().hour;
//     if (hour < 12) return 'Good Morning';
//     if (hour < 17) return 'Good Afternoon';
//     return 'Good Evening';
//   }

//   String _formatTimeAgo(int timestamp) {
//     if (timestamp <= 0) return 'Recently';

//     final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
//     final diff = DateTime.now().difference(date);

//     if (diff.inMinutes < 1) return 'Just now';
//     if (diff.inHours < 1) return '${diff.inMinutes}m ago';
//     if (diff.inDays < 1) return '${diff.inHours}h ago';
//     if (diff.inDays < 7) return '${diff.inDays}d ago';
//     return '${date.day}/${date.month}/${date.year}';
//   }

//   String? _findChatAttachmentPath(String userId, String chatId) {
//     final messages = HiveService.instance.getMessagesForChat(userId, chatId);
//     for (var i = messages.length - 1; i >= 0; i--) {
//       final path = messages[i].imagePath;
//       if (path != null && path.isNotEmpty) return path;
//     }
//     return null;
//   }

//   bool _isImagePath(String path) {
//     final ext = path.split('.').last.toLowerCase();
//     return ext == 'jpg' ||
//         ext == 'jpeg' ||
//         ext == 'png' ||
//         ext == 'webp' ||
//         ext == 'gif';
//   }

//   String _attachmentTag(String? path) {
//     if (path == null) return 'CHAT';
//     if (_isImagePath(path)) return 'IMAGE';
//     final ext = path.split('.').last.toLowerCase();
//     if (ext == 'pdf') return 'PDF';
//     if (ext == 'doc' || ext == 'docx') return 'DOC';
//     return 'FILE';
//   }

//   void _openChat({String? chatId, ChatLaunchAction launchAction = ChatLaunchAction.none}) {
//     AppRoutes.openChat(context, chatId: chatId, launchAction: launchAction);
//   }

//   void _openChatHistory() {
//     _openChat(launchAction: ChatLaunchAction.openDrawer);
//   }

//   void _showComingSoon(String feature) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('$feature is coming soon'),
//         behavior: SnackBarBehavior.floating,
//       ),
//     );
//   }

//   void _onFeatureTap(String label) {
//     switch (label) {
//       case 'AI Chat':
//         _openChat();
//       case 'Upload PDF':
//       case 'Flashcards':
//       case 'Generate Flashcards':
//       case 'OCR Notes':
//       case 'Quiz Gen':
//       case 'Generate Quiz':
//         _openChat(launchAction: ChatLaunchAction.attachment);
//       case 'Voice AI':
//       case 'Voice Chat':
//         _openChat(launchAction: ChatLaunchAction.voice);
//       default:
//         _showComingSoon(label);
//     }
//   }

//   void _showChatBottomSheet() {
//     final recentChats = _chats.take(3).toList();

//     showModalBottomSheet<void>(
//       context: context,
//       backgroundColor: Colors.transparent,
//       isScrollControlled: true,
//       builder: (sheetContext) {
//         return _GlassBottomSheet(
//           title: 'Chat',
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               _SheetOption(
//                 icon: Icons.add_comment_outlined,
//                 label: 'New Chat',
//                 subtitle: 'Start a fresh conversation',
//                 onTap: () {
//                   Navigator.pop(sheetContext);
//                   _openChat();
//                 },
//               ),
//               if (recentChats.isNotEmpty) ...[
//                 const _SheetSectionLabel('Recent'),
//                 ...recentChats.map(
//                   (chat) => _SheetOption(
//                     icon: Icons.chat_bubble_outline,
//                     label: chat.title,
//                     subtitle: _formatTimeAgo(chat.timestamp),
//                     onTap: () {
//                       Navigator.pop(sheetContext);
//                       _openChat(chatId: chat.id);
//                     },
//                   ),
//                 ),
//                 _SheetOption(
//                   icon: Icons.history_rounded,
//                   label: 'View All History',
//                   subtitle: '${_chats.length} saved chats',
//                   onTap: () {
//                     Navigator.pop(sheetContext);
//                     _openChatHistory();
//                   },
//                 ),
//               ],
//             ],
//           ),
//         );
//       },
//     );
//   }

//   void _showToolsBottomSheet() {
//     const tools = [
//       (Icons.upload_file_rounded, 'Upload PDF', 'Add a PDF to your chat'),
//       (Icons.style_outlined, 'Generate Flashcards', 'Turn notes into cards'),
//       (Icons.quiz_outlined, 'Generate Quiz', 'Practice with AI quizzes'),
//       (Icons.document_scanner_outlined, 'OCR Notes', 'Scan notes from images'),
//       (Icons.mic_none_outlined, 'Voice Chat', 'Talk to your AI tutor'),
//     ];

//     showModalBottomSheet<void>(
//       context: context,
//       backgroundColor: Colors.transparent,
//       isScrollControlled: true,
//       builder: (sheetContext) {
//         return _GlassBottomSheet(
//           title: 'Tools',
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: tools
//                 .map(
//                   (tool) => _SheetOption(
//                     icon: tool.$1,
//                     label: tool.$2,
//                     subtitle: tool.$3,
//                     onTap: () {
//                       Navigator.pop(sheetContext);
//                       _onFeatureTap(tool.$2);
//                     },
//                   ),
//                 )
//                 .toList(),
//           ),
//         );
//       },
//     );
//   }

//   String get _userInitial {
//     final trimmed = _userName.trim();
//     if (trimmed.isEmpty) return 'S';
//     return trimmed[0].toUpperCase();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       extendBody: true,
//       backgroundColor: const Color(0xFF0F1221),
//       body: FadeTransition(
//         opacity: _fadeAnim,
//         child: SlideTransition(
//           position: _slideAnim,
//           child: SafeArea(
//             child: Column(
//               children: [
//                 if (!_isOnline) const OfflineBanner(),
//                 Expanded(
//                   child: SingleChildScrollView(
//                     padding: const EdgeInsets.symmetric(horizontal: 20),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const SizedBox(height: 16),
//                         _buildTopBar(),
//                         const SizedBox(height: 28),
//                         _buildGreeting(),
//                         const SizedBox(height: 28),
//                         _buildFeatureGrid(),
//                         const SizedBox(height: 28),
//                         _buildRecentActivity(),
//                         const SizedBox(height: 28),
//                         _buildInsights(),
//                         const SizedBox(height: 20),
//                         _buildAIBanner(),
//                         const SizedBox(height: 100),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//       bottomNavigationBar: _buildBottomNav(),
//       floatingActionButton: _buildFAB(),
//     );
//   }

//   Widget _buildFAB() {
//     return Transform.translate(
//       offset: const Offset(0, -6),
//       child: FloatingActionButton(
//         onPressed: _openChat,
//         backgroundColor: const Color(0xFF7C5CFC),
//         elevation: 6,
//         child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
//       ),
//     );
//   }

//   Widget _buildTopBar() {
//     return Row(
//       children: [
//         CircleAvatar(
//           radius: 20,
//           backgroundColor: const Color(0xFF7C5CFC),
//           child: Text(
//             _userInitial,
//             style: const TextStyle(
//               color: Colors.white,
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ),
//         const SizedBox(width: 10),
//         Text(
//           AppStrings.appName,
//           style: const TextStyle(
//             color: Colors.white,
//             fontSize: 18,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         const Spacer(),
//         if (_chats.isNotEmpty)
//           GestureDetector(
//             onTap: _openChatHistory,
//             child: ScaleTransition(
//               scale: _pulseAnim,
//               child: Container(
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
//                 decoration: BoxDecoration(
//                   gradient: const LinearGradient(
//                     colors: [Color(0xFF7C5CFC), Color(0xFF9B7FFF)],
//                   ),
//                   borderRadius: BorderRadius.circular(20),
//                 ),
//                 child: Row(
//                   children: [
//                     const Icon(Icons.chat_bubble_outline,
//                         color: Colors.white, size: 15),
//                     const SizedBox(width: 4),
//                     Text(
//                       '${_chats.length} ${_chats.length == 1 ? 'Chat' : 'Chats'}',
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontSize: 12,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         if (_chats.isNotEmpty) const SizedBox(width: 10),
//         GestureDetector(
//           onTap: () => AppRoutes.openSettings(context),
//           child: const Icon(Icons.settings, color: Colors.white54, size: 22),
//         ),
//       ],
//     );
//   }

//   Widget _buildGreeting() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             Text(
//               '$_greetingPrefix, $_userName ',
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 22,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             const Text('👋', style: TextStyle(fontSize: 22)),
//           ],
//         ),
//         const SizedBox(height: 4),
//         Text(
//           _chats.isEmpty
//               ? 'Start your first AI chat to begin learning.'
//               : 'Ready to smash your study goals today?',
//           style: const TextStyle(color: Colors.white54, fontSize: 13),
//         ),
//       ],
//     );
//   }

//   Widget _buildFeatureGrid() {
//     final features = [
//       _FeatureItem(
//         'AI Chat',
//         Icons.chat_bubble_outline,
//         const Color(0xFF5B5BF8),
//       ),
//       _FeatureItem('Upload PDF', Icons.upload_file, const Color(0xFFE07B39)),
//       _FeatureItem('Flashcards', Icons.style_outlined, const Color(0xFF4A90D9)),
//       _FeatureItem('Quiz Gen', Icons.quiz_outlined, const Color(0xFF8B5CF6)),
//       _FeatureItem(
//         'OCR Notes',
//         Icons.document_scanner_outlined,
//         const Color(0xFFE05252),
//       ),
//       _FeatureItem(
//         'Voice AI',
//         Icons.mic_none_outlined,
//         const Color(0xFF4A90D9),
//       ),
//     ];

//     return GridView.builder(
//       shrinkWrap: true,
//       physics: const NeverScrollableScrollPhysics(),
//       itemCount: features.length,
//       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//         crossAxisCount: 2,
//         mainAxisSpacing: 14,
//         crossAxisSpacing: 14,
//         childAspectRatio: 1.5,
//       ),
//       itemBuilder: (context, i) {
//         return _AnimatedFeatureCard(
//           feature: features[i],
//           delay: i * 80,
//           onTap: () => _onFeatureTap(features[i].label),
//         );
//       },
//     );
//   }

//   Widget _buildRecentActivity() {
//     final recentChats = _chats.take(4).toList();

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             const Text(
//               'Recent Activity',
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 17,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             if (_chats.isNotEmpty)
//               GestureDetector(
//                 onTap: _openChatHistory,
//                 child: const Text(
//                   'View All',
//                   style: TextStyle(
//                     color: Color(0xFF7C5CFC),
//                     fontSize: 13,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ),
//           ],
//         ),
//         const SizedBox(height: 14),
//         if (recentChats.isEmpty)
//           Container(
//             width: double.infinity,
//             padding: const EdgeInsets.all(20),
//             decoration: BoxDecoration(
//               color: const Color(0xFF1A1F35),
//               borderRadius: BorderRadius.circular(16),
//               border: Border.all(color: Colors.white10),
//             ),
//             child: Column(
//               children: [
//                 Icon(Icons.chat_bubble_outline,
//                     color: Colors.white.withValues(alpha: 0.3), size: 32),
//                 const SizedBox(height: 10),
//                 Text(
//                   'No chats yet',
//                   style: TextStyle(
//                     color: Colors.white.withValues(alpha: 0.7),
//                     fontSize: 14,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 const Text(
//                   'Tap AI Chat or the + button to start',
//                   style: TextStyle(color: Colors.white38, fontSize: 12),
//                 ),
//               ],
//             ),
//           )
//         else
//           SizedBox(
//             height: 150,
//             child: ListView.separated(
//               scrollDirection: Axis.horizontal,
//               itemCount: recentChats.length,
//               separatorBuilder: (_, __) => const SizedBox(width: 12),
//               itemBuilder: (context, index) {
//                 final chat = recentChats[index];
//                 final userId = AuthRepository.instance.currentUser?.uid;
//                 final messageCount = userId == null
//                     ? 0
//                     : HiveService.instance
//                         .getMessagesForChat(userId, chat.id)
//                         .length;
//                 final attachmentPath = userId == null
//                     ? null
//                     : _findChatAttachmentPath(userId, chat.id);

//                 return _buildActivityCard(
//                   title: chat.title,
//                   subtitle: messageCount > 0
//                       ? '$messageCount messages · ${_formatTimeAgo(chat.timestamp)}'
//                       : _formatTimeAgo(chat.timestamp),
//                   tag: _attachmentTag(attachmentPath),
//                   attachmentPath: attachmentPath,
//                   color: const Color(0xFF1A1F35),
//                   onTap: () => _openChat(chatId: chat.id),
//                 );
//               },
//             ),
//           ),
//       ],
//     );
//   }

//   Widget _buildActivityCard({
//     required String title,
//     required String subtitle,
//     required String tag,
//     required Color color,
//     String? attachmentPath,
//     VoidCallback? onTap,
//   }) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         width: 190,
//         decoration: BoxDecoration(
//           color: color,
//           borderRadius: BorderRadius.circular(16),
//           border: Border.all(color: Colors.white10),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Expanded(
//               child: ClipRRect(
//                 borderRadius: const BorderRadius.vertical(
//                   top: Radius.circular(16),
//                 ),
//                 child: Container(
//                   width: double.infinity,
//                   color: Colors.white12,
//                   child: _buildActivityPreview(attachmentPath, tag),
//                 ),
//               ),
//             ),
//             Padding(
//               padding: const EdgeInsets.all(10),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 7,
//                       vertical: 2,
//                     ),
//                     decoration: BoxDecoration(
//                       color: const Color(0xFF7C5CFC).withValues(alpha: 0.2),
//                       borderRadius: BorderRadius.circular(6),
//                     ),
//                     child: Text(
//                       tag,
//                       style: const TextStyle(
//                         color: Color(0xFF9B7FFF),
//                         fontSize: 10,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 5),
//                   Text(
//                     title,
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 12,
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//                   Text(
//                     subtitle,
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                     style: const TextStyle(color: Colors.white38, fontSize: 11),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildActivityPreview(String? path, String tag) {
//     if (path != null && _isImagePath(path)) {
//       final file = File(path);
//       if (file.existsSync()) {
//         return Image.file(
//           file,
//           width: double.infinity,
//           height: double.infinity,
//           fit: BoxFit.cover,
//           errorBuilder: (_, __, ___) => _buildActivityPlaceholder(tag),
//         );
//       }
//     }

//     if (path != null) {
//       final ext = path.split('.').last.toLowerCase();
//       IconData icon = Icons.insert_drive_file_outlined;
//       Color iconColor = Colors.white38;
//       if (ext == 'pdf') {
//         icon = Icons.picture_as_pdf_rounded;
//         iconColor = const Color(0xFFFF4757);
//       } else if (ext == 'doc' || ext == 'docx') {
//         icon = Icons.description_rounded;
//         iconColor = const Color(0xFF4A90D9);
//       }
//       return Center(child: Icon(icon, color: iconColor, size: 40));
//     }

//     return _buildActivityPlaceholder(tag);
//   }

//   Widget _buildActivityPlaceholder(String tag) {
//     return Center(
//       child: Icon(
//         tag == 'CHAT'
//             ? Icons.chat_bubble_outline
//             : Icons.insert_drive_file_outlined,
//         color: Colors.white38,
//         size: 34,
//       ),
//     );
//   }

//   Widget _buildInsights() {
//     final insights = [
//       _InsightData(
//         '${_chats.length}',
//         'Chats Started',
//         _chats.isNotEmpty ? 'Active' : 'Start one',
//         Icons.chat_outlined,
//         const Color(0xFF4A90D9),
//       ),
//       _InsightData(
//         '$_messageCount',
//         'Messages Sent',
//         _messageCount > 0 ? 'Keep going' : 'New',
//         Icons.message_outlined,
//         const Color(0xFF7C5CFC),
//       ),
//       _InsightData(
//         '$_aiMessageCount',
//         'AI Replies',
//         _aiMessageCount > 0 ? 'Learning' : 'Ask away',
//         Icons.smart_toy_outlined,
//         const Color(0xFFE07B39),
//       ),
//       _InsightData(
//         _chats.isEmpty ? '0' : '${(_messageCount / _chats.length).round()}',
//         'Avg. Msgs/Chat',
//         'Per session',
//         Icons.analytics_outlined,
//         const Color(0xFF7C5CFC),
//       ),
//     ];

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Text(
//           'Insights',
//           style: TextStyle(
//             color: Colors.white,
//             fontSize: 17,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         const SizedBox(height: 14),
//         GridView.builder(
//           shrinkWrap: true,
//           physics: const NeverScrollableScrollPhysics(),
//           itemCount: insights.length,
//           gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//             crossAxisCount: 2,
//             mainAxisSpacing: 12,
//             crossAxisSpacing: 12,
//             childAspectRatio: 1.35,
//           ),
//           itemBuilder: (context, i) {
//             final d = insights[i];
//             return _AnimatedInsightCard(data: d, delay: i * 100);
//           },
//         ),
//       ],
//     );
//   }

//   Widget _buildAIBanner() {
//     return Container(
//       padding: const EdgeInsets.all(18),
//       decoration: BoxDecoration(
//         color: const Color(0xFF1A1F35),
//         borderRadius: BorderRadius.circular(18),
//         border: Border.all(color: const Color(0xFF7C5CFC).withValues(alpha: 0.3)),
//       ),
//       child: Row(
//         children: [
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   '${AppStrings.appName} is ready',
//                   style: const TextStyle(color: Colors.white54, fontSize: 12),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   _chats.isEmpty
//                       ? '"Ask me anything — I\'m here to help you study smarter."'
//                       : '"Pick up where you left off or start a fresh topic."',
//                   style: const TextStyle(color: Colors.white, fontSize: 13),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(width: 14),
//           ElevatedButton(
//             onPressed: _openChat,
//             style: ElevatedButton.styleFrom(
//               backgroundColor: const Color(0xFF7C5CFC),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//             ),
//             child: Text(
//               _chats.isEmpty ? 'Start\nChat' : 'Open\nChat',
//               textAlign: TextAlign.center,
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 13,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildBottomNav() {
//     final items = [
//       _NavItem(Icons.chat_bubble_outline, 'Chat', _showChatBottomSheet),
//       _NavItem(Icons.auto_awesome, 'PocketTutor', _openChat),
//       _NavItem(Icons.grid_view_rounded, 'Tools', _showToolsBottomSheet),
//       _NavItem(
//         Icons.person_outline,
//         'Profile',
//         () => AppRoutes.openSettings(context),
//       ),
//     ];

//     return Padding(
//       padding: EdgeInsets.fromLTRB(
//         20,
//         0,
//         20,
//         12 + MediaQuery.paddingOf(context).bottom,
//       ),
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(28),
//         child: BackdropFilter(
//           filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
//           child: Container(
//             padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
//             decoration: BoxDecoration(
//               color: Colors.white.withValues(alpha: 0.08),
//               borderRadius: BorderRadius.circular(28),
//               border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withValues(alpha: 0.25),
//                   blurRadius: 24,
//                   offset: const Offset(0, 8),
//                 ),
//               ],
//             ),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceAround,
//               children: items.map((item) {
//                 return _GlassNavItem(item: item);
//               }).toList(),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _FeatureItem {
//   final String label;
//   final IconData icon;
//   final Color color;
//   const _FeatureItem(this.label, this.icon, this.color);
// }

// class _AnimatedFeatureCard extends StatefulWidget {
//   final _FeatureItem feature;
//   final int delay;
//   final VoidCallback onTap;

//   const _AnimatedFeatureCard({
//     required this.feature,
//     required this.delay,
//     required this.onTap,
//   });

//   @override
//   State<_AnimatedFeatureCard> createState() => _AnimatedFeatureCardState();
// }

// class _AnimatedFeatureCardState extends State<_AnimatedFeatureCard>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _ctrl;
//   late Animation<double> _scale;
//   bool _pressed = false;

//   @override
//   void initState() {
//     super.initState();
//     _ctrl = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 500),
//     );
//     _scale = Tween<double>(
//       begin: 0.85,
//       end: 1.0,
//     ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
//     Future.delayed(Duration(milliseconds: widget.delay), () {
//       if (mounted) _ctrl.forward();
//     });
//   }

//   @override
//   void dispose() {
//     _ctrl.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return ScaleTransition(
//       scale: _scale,
//       child: GestureDetector(
//         onTap: widget.onTap,
//         onTapDown: (_) => setState(() => _pressed = true),
//         onTapUp: (_) => setState(() => _pressed = false),
//         onTapCancel: () => setState(() => _pressed = false),
//         child: AnimatedScale(
//           scale: _pressed ? 0.95 : 1.0,
//           duration: const Duration(milliseconds: 120),
//           child: Container(
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: const Color(0xFF1A1F35),
//               borderRadius: BorderRadius.circular(18),
//               border: Border.all(color: Colors.white10),
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Container(
//                   width: 40,
//                   height: 40,
//                   decoration: BoxDecoration(
//                     color: widget.feature.color.withValues(alpha: 0.2),
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child: Icon(
//                     widget.feature.icon,
//                     color: widget.feature.color,
//                     size: 20,
//                   ),
//                 ),
//                 const Spacer(),
//                 Text(
//                   widget.feature.label,
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontSize: 14,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _InsightData {
//   final String value;
//   final String label;
//   final String badge;
//   final IconData icon;
//   final Color color;
//   const _InsightData(this.value, this.label, this.badge, this.icon, this.color);
// }

// class _AnimatedInsightCard extends StatefulWidget {
//   final _InsightData data;
//   final int delay;
//   const _AnimatedInsightCard({required this.data, required this.delay});

//   @override
//   State<_AnimatedInsightCard> createState() => _AnimatedInsightCardState();
// }

// class _AnimatedInsightCardState extends State<_AnimatedInsightCard>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _ctrl;
//   late Animation<double> _fade;
//   late Animation<Offset> _slide;

//   @override
//   void initState() {
//     super.initState();
//     _ctrl = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 500),
//     );
//     _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
//     _slide = Tween<Offset>(
//       begin: const Offset(0, 0.2),
//       end: Offset.zero,
//     ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

//     Future.delayed(Duration(milliseconds: widget.delay), () {
//       if (mounted) _ctrl.forward();
//     });
//   }

//   @override
//   void dispose() {
//     _ctrl.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return FadeTransition(
//       opacity: _fade,
//       child: SlideTransition(
//         position: _slide,
//         child: Container(
//           padding: const EdgeInsets.all(12),
//           decoration: BoxDecoration(
//             color: const Color(0xFF1A1F35),
//             borderRadius: BorderRadius.circular(16),
//             border: Border.all(color: Colors.white10),
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 children: [
//                   Icon(widget.data.icon, color: widget.data.color, size: 16),
//                   const Spacer(),
//                   Flexible(
//                     child: Text(
//                       widget.data.badge,
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       textAlign: TextAlign.right,
//                       style: const TextStyle(
//                         color: Colors.white54,
//                         fontSize: 10,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//               const Spacer(),
//               FittedBox(
//                 fit: BoxFit.scaleDown,
//                 alignment: Alignment.centerLeft,
//                 child: Text(
//                   widget.data.value,
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontSize: 22,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 2),
//               Text(
//                 widget.data.label,
//                 maxLines: 1,
//                 overflow: TextOverflow.ellipsis,
//                 style: const TextStyle(color: Colors.white54, fontSize: 10),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _NavItem {
//   final IconData icon;
//   final String label;
//   final VoidCallback onTap;
//   const _NavItem(this.icon, this.label, this.onTap);
// }

// class _GlassNavItem extends StatelessWidget {
//   const _GlassNavItem({required this.item});

//   final _NavItem item;

//   @override
//   Widget build(BuildContext context) {
//     return Material(
//       color: Colors.transparent,
//       child: InkWell(
//         onTap: item.onTap,
//         borderRadius: BorderRadius.circular(16),
//         splashColor: Colors.white.withValues(alpha: 0.08),
//         highlightColor: Colors.white.withValues(alpha: 0.04),
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Icon(item.icon, color: Colors.white, size: 24),
//               const SizedBox(height: 4),
//               Text(
//                 item.label,
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 11,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _GlassBottomSheet extends StatelessWidget {
//   const _GlassBottomSheet({required this.title, required this.child});

//   final String title;
//   final Widget child;

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: EdgeInsets.fromLTRB(
//         16,
//         0,
//         16,
//         16 + MediaQuery.paddingOf(context).bottom,
//       ),
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(28),
//         child: BackdropFilter(
//           filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
//           child: Container(
//             constraints: BoxConstraints(
//               maxHeight: MediaQuery.sizeOf(context).height * 0.62,
//             ),
//             decoration: BoxDecoration(
//               color: const Color(0xFF1A1F35).withValues(alpha: 0.92),
//               borderRadius: BorderRadius.circular(28),
//               border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
//             ),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 const SizedBox(height: 12),
//                 Container(
//                   width: 40,
//                   height: 4,
//                   decoration: BoxDecoration(
//                     color: Colors.white24,
//                     borderRadius: BorderRadius.circular(2),
//                   ),
//                 ),
//                 Padding(
//                   padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
//                   child: Row(
//                     children: [
//                       Text(
//                         title,
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       const Spacer(),
//                       IconButton(
//                         onPressed: () => Navigator.pop(context),
//                         icon: const Icon(Icons.close_rounded, color: Colors.white54),
//                         visualDensity: VisualDensity.compact,
//                       ),
//                     ],
//                   ),
//                 ),
//                 Flexible(
//                   child: SingleChildScrollView(
//                     padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
//                     child: child,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _SheetSectionLabel extends StatelessWidget {
//   const _SheetSectionLabel(this.label);

//   final String label;

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
//       child: Align(
//         alignment: Alignment.centerLeft,
//         child: Text(
//           label.toUpperCase(),
//           style: const TextStyle(
//             color: Colors.white38,
//             fontSize: 11,
//             fontWeight: FontWeight.w700,
//             letterSpacing: 0.8,
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _SheetOption extends StatelessWidget {
//   const _SheetOption({
//     required this.icon,
//     required this.label,
//     required this.subtitle,
//     required this.onTap,
//   });

//   final IconData icon;
//   final String label;
//   final String subtitle;
//   final VoidCallback onTap;

//   @override
//   Widget build(BuildContext context) {
//     return Material(
//       color: Colors.transparent,
//       child: InkWell(
//         onTap: onTap,
//         borderRadius: BorderRadius.circular(16),
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//           child: Row(
//             children: [
//               Container(
//                 width: 42,
//                 height: 42,
//                 decoration: BoxDecoration(
//                   color: Colors.white.withValues(alpha: 0.08),
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border.all(color: Colors.white10),
//                 ),
//                 child: Icon(icon, color: const Color(0xFF9B7FFF), size: 20),
//               ),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       label,
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontSize: 14,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                     const SizedBox(height: 2),
//                     Text(
//                       subtitle,
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       style: const TextStyle(color: Colors.white38, fontSize: 12),
//                     ),
//                   ],
//                 ),
//               ),
//               const Icon(Icons.chevron_right_rounded, color: Colors.white24),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }




import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pocket_tutor/core/constants/app_strings.dart';
import 'package:pocket_tutor/core/navigation/app_routes.dart';
import 'package:pocket_tutor/core/navigation/chat_launch_action.dart';
import 'package:pocket_tutor/core/network/connectivity_service.dart';
import 'package:pocket_tutor/core/storage/hive_service.dart';
import 'package:pocket_tutor/features/auth/data/auth_repository.dart';
import 'package:pocket_tutor/features/chat/data/chat_repository.dart';
import 'package:pocket_tutor/features/chat/data/models/chat_model.dart';
import 'package:pocket_tutor/features/chat/presentation/widgets/offline_banner.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _pulseAnim;

  String _userName = 'Student';
  List<ChatModel> _chats = [];
  int _messageCount = 0;
  int _aiMessageCount = 0;
  bool _isOnline = true;

  StreamSubscription<List<ChatModel>>? _chatsSub;
  StreamSubscription<bool>? _connectivitySub;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _slideController.forward();

    _isOnline = ConnectivityService.instance.isOnline;
    _connectivitySub =
        ConnectivityService.instance.onConnectivityChanged.listen((online) {
      if (mounted) setState(() => _isOnline = online);
    });

    _loadUser();
    _loadChats();
    _loadStats();
  }

  @override
  void dispose() {
    _chatsSub?.cancel();
    _connectivitySub?.cancel();
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = AuthRepository.instance.currentUser;
    if (user == null) return;

    setState(() {
      _userName = user.displayName ?? 'Student';
    });

    final profile = await AuthRepository.instance.getUserProfile(user.uid);
    if (profile != null && mounted) {
      setState(() {
        _userName = profile.name.isNotEmpty ? profile.name : _userName;
      });
    }
  }

  void _loadChats() {
    final user = AuthRepository.instance.currentUser;
    if (user == null) return;

    _chatsSub?.cancel();
    _chatsSub = ChatRepository.instance.watchChats(user.uid).listen((chats) {
      if (!mounted) return;
      setState(() => _chats = chats);
      _loadStats();
    });
  }

  void _loadStats() {
    final user = AuthRepository.instance.currentUser;
    if (user == null) return;

    final chats = HiveService.instance.getChatsForUser(user.uid);
    var totalMessages = 0;
    var aiMessages = 0;

    for (final chat in chats) {
      final messages =
          HiveService.instance.getMessagesForChat(user.uid, chat.id);
      totalMessages += messages.length;
      aiMessages += messages.where((m) => m.sender == 'ai').length;
    }

    if (!mounted) return;
    setState(() {
      _messageCount = totalMessages;
      _aiMessageCount = aiMessages;
    });
  }

  String get _greetingPrefix {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _formatTimeAgo(int timestamp) {
    if (timestamp <= 0) return 'Recently';

    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final diff = DateTime.now().difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  String? _findChatAttachmentPath(String userId, String chatId) {
    final messages = HiveService.instance.getMessagesForChat(userId, chatId);
    for (var i = messages.length - 1; i >= 0; i--) {
      final path = messages[i].imagePath;
      if (path != null && path.isNotEmpty) return path;
    }
    return null;
  }

  bool _isImagePath(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ext == 'jpg' ||
        ext == 'jpeg' ||
        ext == 'png' ||
        ext == 'webp' ||
        ext == 'gif';
  }

  String _attachmentTag(String? path) {
    if (path == null) return 'CHAT';
    if (_isImagePath(path)) return 'IMAGE';
    final ext = path.split('.').last.toLowerCase();
    if (ext == 'pdf') return 'PDF';
    if (ext == 'doc' || ext == 'docx') return 'DOC';
    return 'FILE';
  }

  void _openChat({String? chatId, ChatLaunchAction launchAction = ChatLaunchAction.none}) {
    AppRoutes.openChat(context, chatId: chatId, launchAction: launchAction);
  }

  void _openChatHistory() {
    _openChat(launchAction: ChatLaunchAction.openDrawer);
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature is coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onFeatureTap(String label) {
    switch (label) {
      case 'AI Chat':
        _openChat();
      case 'Upload PDF':
      case 'Flashcards':
      case 'Generate Flashcards':
      case 'OCR Notes':
      case 'Quiz Gen':
      case 'Generate Quiz':
        _openChat(launchAction: ChatLaunchAction.attachment);
      case 'Voice AI':
      case 'Voice Chat':
        _openChat(launchAction: ChatLaunchAction.voice);
      default:
        _showComingSoon(label);
    }
  }

  void _showChatBottomSheet() {
    final recentChats = _chats.take(3).toList();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _GlassBottomSheet(
          title: 'Chat',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetOption(
                icon: Icons.add_comment_outlined,
                label: 'New Chat',
                subtitle: 'Start a fresh conversation',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openChat();
                },
              ),
              if (recentChats.isNotEmpty) ...[
                const _SheetSectionLabel('Recent'),
                ...recentChats.map(
                  (chat) => _SheetOption(
                    icon: Icons.chat_bubble_outline,
                    label: chat.title,
                    subtitle: _formatTimeAgo(chat.timestamp),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _openChat(chatId: chat.id);
                    },
                  ),
                ),
                _SheetOption(
                  icon: Icons.history_rounded,
                  label: 'View All History',
                  subtitle: '${_chats.length} saved chats',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openChatHistory();
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showToolsBottomSheet() {
    const tools = [
      (Icons.upload_file_rounded, 'Upload PDF', 'Add a PDF to your chat'),
      (Icons.style_outlined, 'Generate Flashcards', 'Turn notes into cards'),
      (Icons.quiz_outlined, 'Generate Quiz', 'Practice with AI quizzes'),
      (Icons.document_scanner_outlined, 'OCR Notes', 'Scan notes from images'),
      (Icons.mic_none_outlined, 'Voice Chat', 'Talk to your AI tutor'),
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _GlassBottomSheet(
          title: 'Tools',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: tools
                .map(
                  (tool) => _SheetOption(
                    icon: tool.$1,
                    label: tool.$2,
                    subtitle: tool.$3,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _onFeatureTap(tool.$2);
                    },
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

  String get _userInitial {
    final trimmed = _userName.trim();
    if (trimmed.isEmpty) return 'S';
    return trimmed[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFF0F1221),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SafeArea(
            child: Column(
              children: [
                if (!_isOnline) const OfflineBanner(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        _buildTopBar(),
                        const SizedBox(height: 28),
                        _buildGreeting(),
                        const SizedBox(height: 28),
                        _buildFeatureGrid(),
                        const SizedBox(height: 28),
                        _buildRecentActivity(),
                        const SizedBox(height: 28),
                        _buildInsights(),
                        const SizedBox(height: 20),
                        _buildAIBanner(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildFAB() {
    return Transform.translate(
      offset: const Offset(0, -6),
      child: FloatingActionButton(
        onPressed: _openChat,
        backgroundColor: const Color(0xFF7C5CFC),
        elevation: 6,
        child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: const Color(0xFF7C5CFC),
          child: Text(
            _userInitial,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          AppStrings.appName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        if (_chats.isNotEmpty)
          GestureDetector(
            onTap: _openChatHistory,
            child: ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C5CFC), Color(0xFF9B7FFF)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline,
                        color: Colors.white, size: 15),
                    const SizedBox(width: 4),
                    Text(
                      '${_chats.length} ${_chats.length == 1 ? 'Chat' : 'Chats'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (_chats.isNotEmpty) const SizedBox(width: 10),
        GestureDetector(
          onTap: () => AppRoutes.openSettings(context),
          child: const Icon(Icons.settings, color: Colors.white54, size: 22),
        ),
      ],
    );
  }

  Widget _buildGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '$_greetingPrefix, $_userName ',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text('👋', style: TextStyle(fontSize: 22)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _chats.isEmpty
              ? 'Start your first AI chat to begin learning.'
              : 'Ready to smash your study goals today?',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildFeatureGrid() {
    final features = [
      _FeatureItem(
        'AI Chat',
        Icons.chat_bubble_outline,
        const Color(0xFF5B5BF8),
      ),
      _FeatureItem('Upload PDF', Icons.upload_file, const Color(0xFFE07B39)),
      _FeatureItem('Flashcards', Icons.style_outlined, const Color(0xFF4A90D9)),
      _FeatureItem('Quiz Gen', Icons.quiz_outlined, const Color(0xFF8B5CF6)),
      _FeatureItem(
        'OCR Notes',
        Icons.document_scanner_outlined,
        const Color(0xFFE05252),
      ),
      _FeatureItem(
        'Voice AI',
        Icons.mic_none_outlined,
        const Color(0xFF4A90D9),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: features.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.5,
      ),
      itemBuilder: (context, i) {
        return _AnimatedFeatureCard(
          feature: features[i],
          delay: i * 80,
          onTap: () => _onFeatureTap(features[i].label),
        );
      },
    );
  }

  Widget _buildRecentActivity() {
    final recentChats = _chats.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_chats.isNotEmpty)
              GestureDetector(
                onTap: _openChatHistory,
                child: const Text(
                  'View All',
                  style: TextStyle(
                    color: Color(0xFF7C5CFC),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (recentChats.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                Icon(Icons.chat_bubble_outline,
                    color: Colors.white.withValues(alpha: 0.3), size: 32),
                const SizedBox(height: 10),
                Text(
                  'No chats yet',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tap AI Chat or the + button to start',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none, // Fixed: Removes background overlay leakage on swipe
              itemCount: recentChats.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final chat = recentChats[index];
                final userId = AuthRepository.instance.currentUser?.uid;
                final messageCount = userId == null
                    ? 0
                    : HiveService.instance
                        .getMessagesForChat(userId, chat.id)
                        .length;
                final attachmentPath = userId == null
                    ? null
                    : _findChatAttachmentPath(userId, chat.id);

                return _buildActivityCard(
                  title: chat.title,
                  subtitle: messageCount > 0
                      ? '$messageCount messages · ${_formatTimeAgo(chat.timestamp)}'
                      : _formatTimeAgo(chat.timestamp),
                  tag: _attachmentTag(attachmentPath),
                  attachmentPath: attachmentPath,
                  color: const Color(0xFF1A1F35),
                  onTap: () => _openChat(chatId: chat.id),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildActivityCard({
    required String title,
    required String subtitle,
    required String tag,
    required Color color,
    String? attachmentPath,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 190,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Container(
                  width: double.infinity,
                  color: Colors.white12,
                  child: _buildActivityPreview(attachmentPath, tag),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C5CFC).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        color: Color(0xFF9B7FFF),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityPreview(String? path, String tag) {
    if (path != null && _isImagePath(path)) {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildActivityPlaceholder(tag),
        );
      }
    }

    if (path != null) {
      final ext = path.split('.').last.toLowerCase();
      IconData icon = Icons.insert_drive_file_outlined;
      Color iconColor = Colors.white38;
      if (ext == 'pdf') {
        icon = Icons.picture_as_pdf_rounded;
        iconColor = const Color(0xFFFF4757);
      } else if (ext == 'doc' || ext == 'docx') {
        icon = Icons.description_rounded;
        iconColor = const Color(0xFF4A90D9);
      }
      return Center(child: Icon(icon, color: iconColor, size: 40));
    }

    return _buildActivityPlaceholder(tag);
  }

  Widget _buildActivityPlaceholder(String tag) {
    return Center(
      child: Icon(
        tag == 'CHAT'
            ? Icons.chat_bubble_outline
            : Icons.insert_drive_file_outlined,
        color: Colors.white38,
        size: 34,
      ),
    );
  }

  Widget _buildInsights() {
    final insights = [
      _InsightData(
        '${_chats.length}',
        'Chats Started',
        _chats.isNotEmpty ? 'Active' : 'Start one',
        Icons.chat_outlined,
        const Color(0xFF4A90D9),
      ),
      _InsightData(
        '$_messageCount',
        'Messages Sent',
        _messageCount > 0 ? 'Keep going' : 'New',
        Icons.message_outlined,
        const Color(0xFF7C5CFC),
      ),
      _InsightData(
        '$_aiMessageCount',
        'AI Replies',
        _aiMessageCount > 0 ? 'Learning' : 'Ask away',
        Icons.smart_toy_outlined,
        const Color(0xFFE07B39),
      ),
      _InsightData(
        _chats.isEmpty ? '0' : '${(_messageCount / _chats.length).round()}',
        'Avg. Msgs/Chat',
        'Per session',
        Icons.analytics_outlined,
        const Color(0xFF7C5CFC),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Insights',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: insights.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
          ),
          itemBuilder: (context, i) {
            final d = insights[i];
            return _AnimatedInsightCard(data: d, delay: i * 100);
          },
        ),
      ],
    );
  }

  Widget _buildAIBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF7C5CFC).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AppStrings.appName} is ready',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  _chats.isEmpty
                      ? '"Ask me anything — I\'m here to help you study smarter."'
                      : '"Pick up where you left off or start a fresh topic."',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          ElevatedButton(
            onPressed: _openChat,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C5CFC),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Text(
              _chats.isEmpty ? 'Start\nChat' : 'Open\nChat',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      _NavItem(Icons.chat_bubble_outline, 'Chat', _showChatBottomSheet, isCustomIcon: false),
      _NavItem(Icons.auto_awesome, 'PocketTutor', _openChat, isCustomIcon: true), // Fixed: Will render assets/images/logotrans.png
      _NavItem(Icons.grid_view_rounded, 'Tools', _showToolsBottomSheet, isCustomIcon: false),
      _NavItem(
        Icons.person_outline,
        'Profile',
        () => AppRoutes.openSettings(context),
        isCustomIcon: false,
      ),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: items.map((item) {
                return _GlassNavItem(item: item);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureItem {
  final String label;
  final IconData icon;
  final Color color;
  const _FeatureItem(this.label, this.icon, this.color);
}

class _AnimatedFeatureCard extends StatefulWidget {
  final _FeatureItem feature;
  final int delay;
  final VoidCallback onTap;

  const _AnimatedFeatureCard({
    required this.feature,
    required this.delay,
    required this.onTap,
  });

  @override
  State<_AnimatedFeatureCard> createState() => _AnimatedFeatureCardState();
}

class _AnimatedFeatureCardState extends State<_AnimatedFeatureCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scale = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F35),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.feature.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    widget.feature.icon,
                    color: widget.feature.color,
                    size: 20,
                  ),
                ),
                const Spacer(),
                Text(
                  widget.feature.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InsightData {
  final String value;
  final String label;
  final String badge;
  final IconData icon;
  final Color color;
  const _InsightData(this.value, this.label, this.badge, this.icon, this.color);
}

class _AnimatedInsightCard extends StatefulWidget {
  final _InsightData data;
  final int delay;
  const _AnimatedInsightCard({required this.data, required this.delay});

  @override
  State<_AnimatedInsightCard> createState() => _AnimatedInsightCardState();
}

class _AnimatedInsightCardState extends State<_AnimatedInsightCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(widget.data.icon, color: widget.data.color, size: 16),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      widget.data.badge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.data.value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isCustomIcon;
  const _NavItem(this.icon, this.label, this.onTap, {required this.isCustomIcon});
}

class _GlassNavItem extends StatelessWidget {
  const _GlassNavItem({required this.item});

  final _NavItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        // Fixed: Removed background leak on highlight & splash inside navigation items
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              item.isCustomIcon
                  ? Image.asset(
                      'assets/images/logotrans.png',
                      width: 30,
                      height: 30,
                      fit: BoxFit.contain,
                    )
                  : Icon(item.icon, color: Colors.white, size: 24),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassBottomSheet extends StatelessWidget {
  const _GlassBottomSheet({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.62,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F35).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: Colors.white54),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetSectionLabel extends StatelessWidget {
  const _SheetSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Icon(icon, color: const Color(0xFF9B7FFF), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white24),
            ],
          ),
        ),
      ),
    );
  }
}