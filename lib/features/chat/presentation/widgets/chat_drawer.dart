import 'package:flutter/material.dart';
import 'package:pocket_tutor/app/theme/app_colors.dart';
import 'package:pocket_tutor/app/theme/app_decorations.dart';
import 'package:pocket_tutor/features/chat/data/models/chat_model.dart';

class ChatDrawer extends StatelessWidget {
  const ChatDrawer({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.chats,
    required this.isLoading,
    required this.currentChatId,
    required this.onNewChat,
    required this.onSelectChat,
    required this.onDeleteChat,
    required this.onLogout,
  });

  final String userName;
  final String userEmail;
  final List<ChatModel> chats;
  final bool isLoading;
  final String? currentChatId;
  final VoidCallback onNewChat;
  final ValueChanged<String> onSelectChat;
  final ValueChanged<String> onDeleteChat;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: AppDecorations.drawerHeaderGradient,
            ),
            currentAccountPicture: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white10,
              ),
              child: const Icon(
                Icons.school_rounded,
                color: AppColors.primaryAccent,
                size: 40,
              ),
            ),
            accountName: Text(
              userName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.onPrimary,
              ),
            ),
            accountEmail: Text(
              userEmail,
              style: const TextStyle(color: AppColors.onSurface),
            ),
          ),
          ListTile(
            leading: const Icon(
              Icons.add_circle_outline_rounded,
              color: AppColors.primaryAccent,
            ),
            title: const Text(
              'New Chat',
              style: TextStyle(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              onNewChat();
            },
          ),
          const Divider(color: AppColors.border),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'PREVIOUS CHATS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white30,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryAccent,
                      ),
                    ),
                  )
                : chats.isEmpty
                    ? const Center(
                        child: Text(
                          'No previous chats',
                          style: TextStyle(
                            color: Colors.white24,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: chats.length,
                        itemBuilder: (context, index) {
                          final chat = chats[index];
                          final isCurrent = currentChatId == chat.id;
                          return ListTile(
                            leading: Icon(
                              chat.isLocalOnly
                                  ? Icons.cloud_off_outlined
                                  : Icons.chat_bubble_outline_rounded,
                              color: isCurrent
                                  ? AppColors.primaryAccent
                                  : AppColors.onSurfaceMuted,
                            ),
                            title: Text(
                              chat.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isCurrent
                                    ? AppColors.onPrimary
                                    : AppColors.onSurface,
                                fontWeight: isCurrent
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: AppColors.error,
                                size: 20,
                              ),
                              onPressed: () => onDeleteChat(chat.id),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              onSelectChat(chat.id);
                            },
                          );
                        },
                      ),
          ),
          const Divider(color: AppColors.border),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.error),
            title: const Text(
              'Logout',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              onLogout();
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
