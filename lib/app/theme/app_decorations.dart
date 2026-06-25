import 'package:flutter/material.dart';
import 'package:pocket_tutor/app/theme/app_colors.dart';

abstract final class AppDecorations {
  static const backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.background, AppColors.backgroundDark],
  );

  static const drawerHeaderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.drawerGradientStart, AppColors.drawerGradientEnd],
  );

  static BoxDecoration card({double radius = 16}) {
    return BoxDecoration(
      color: AppColors.surface.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.border),
    );
  }
}
