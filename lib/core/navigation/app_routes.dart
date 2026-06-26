import 'package:flutter/material.dart';
import 'package:pocket_tutor/core/navigation/chat_launch_action.dart';
import 'package:pocket_tutor/features/auth/presentation/login_screen.dart';
import 'package:pocket_tutor/features/chat/presentation/home_screen.dart';
import 'package:pocket_tutor/features/dashboard/presentation/dashboard_screen.dart';
import 'package:pocket_tutor/features/settings/presentation/settings_screen.dart';

abstract final class AppRoutes {
  static Route<T> dashboard<T>() =>
      MaterialPageRoute(builder: (_) => const DashboardScreen());

  static Route<T> chat<T>({
    String? chatId,
    ChatLaunchAction launchAction = ChatLaunchAction.none,
  }) =>
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          initialChatId: chatId,
          launchAction: launchAction,
        ),
      );

  static Route<T> login<T>() =>
      MaterialPageRoute(builder: (_) => const LoginScreen());

  static Route<T> settings<T>() =>
      MaterialPageRoute(builder: (_) => const SettingsScreen());

  static void goToHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(context, dashboard(), (_) => false);
  }

  static void openChat(
    BuildContext context, {
    String? chatId,
    ChatLaunchAction launchAction = ChatLaunchAction.none,
  }) {
    Navigator.push(
      context,
      chat(chatId: chatId, launchAction: launchAction),
    );
  }

  static void goToLogin(BuildContext context) {
    Navigator.pushAndRemoveUntil(context, login(), (_) => false);
  }

  static void openLogin(BuildContext context) {
    Navigator.push(context, login());
  }

  static void openSettings(BuildContext context) {
    Navigator.push(context, settings());
  }
}
