import 'package:flutter/material.dart';
import 'package:pocket_tutor/app/theme/app_colors.dart';
import 'package:pocket_tutor/app/theme/app_decorations.dart';
import 'package:pocket_tutor/core/constants/app_strings.dart';
import 'package:pocket_tutor/core/network/connectivity_service.dart';
import 'package:pocket_tutor/features/auth/data/auth_repository.dart';
import 'package:pocket_tutor/shared/widgets/app_gradient_background.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthRepository.instance.currentUser;
    final isOnline = ConnectivityService.instance.isOnline;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: AppGradientBackground(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppDecorations.card(radius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Account',
                    style: TextStyle(
                      color: AppColors.onPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.displayName ?? 'Student',
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    user?.email ?? '',
                    style: const TextStyle(color: AppColors.onSurfaceMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppDecorations.card(radius: 20),
              child: Row(
                children: [
                  Icon(
                    isOnline ? Icons.wifi : Icons.wifi_off,
                    color: isOnline ? AppColors.online : AppColors.offline,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isOnline ? 'Connected' : 'Offline mode',
                    style: const TextStyle(color: AppColors.onPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppDecorations.card(radius: 20),
              child: const Text(
                '${AppStrings.appName} saves your chats locally so you can study even without internet.',
                style: TextStyle(color: AppColors.onSurface, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
