import 'package:flutter/material.dart';
import 'package:pocket_tutor/app/theme/app_theme.dart';
import 'package:pocket_tutor/core/constants/app_strings.dart';
import 'package:pocket_tutor/features/auth/presentation/splash_screen.dart';

class PocketTutorApp extends StatelessWidget {
  const PocketTutorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const SplashScreen(),
    );
  }
}
