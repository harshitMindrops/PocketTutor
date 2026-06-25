import 'package:flutter/material.dart';
import 'package:pocket_tutor/features/auth/presentation/login_screen.dart';
import 'package:pocket_tutor/features/chat/presentation/home_screen.dart';
import 'package:pocket_tutor/features/settings/presentation/settings_screen.dart';

abstract final class AppRoutes {
  static Route<T> home<T>() =>
      MaterialPageRoute(builder: (_) => const HomeScreen());

  static Route<T> login<T>() =>
      MaterialPageRoute(builder: (_) => const LoginScreen());

  static Route<T> settings<T>() =>
      MaterialPageRoute(builder: (_) => const SettingsScreen());

  static void goToHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(context, home(), (_) => false);
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
