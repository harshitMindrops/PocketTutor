import 'package:flutter/material.dart';
import 'package:pocket_tutor/app/theme/app_colors.dart';
import 'package:pocket_tutor/core/constants/app_strings.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      color: AppColors.offline.withValues(alpha: 0.15),
      child: const Text(
        AppStrings.offlineBanner,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.offline,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
