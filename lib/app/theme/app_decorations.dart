import 'package:flutter/material.dart';
import 'package:pocket_tutor/app/theme/app_colors.dart';

abstract final class AppDecorations {
  // ── Background gradients ─────────────────────────────────────────────────
  static const backgroundGradient = AppColors.meshGradient;

  static const drawerHeaderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.drawerGradientStart, AppColors.drawerGradientEnd],
  );

  // ── Glassmorphism card ───────────────────────────────────────────────────
  static BoxDecoration glass({double radius = 20, Color? borderColor}) {
    return BoxDecoration(
      color: AppColors.glassWhite,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? AppColors.glassBorder, width: 1),
    );
  }

  // ── Standard dark card ───────────────────────────────────────────────────
  static BoxDecoration card({double radius = 16}) {
    return BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.border),
    );
  }

  // ── Gradient-bordered card ────────────────────────────────────────────────
  static BoxDecoration gradientCard({double radius = 16}) {
    return BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.3)),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.15),
          blurRadius: 20,
          spreadRadius: 0,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // ── Glow shadow for buttons ──────────────────────────────────────────────
  static List<BoxShadow> glowShadow({Color? color, double intensity = 0.4}) {
    return [
      BoxShadow(
        color: (color ?? AppColors.primary).withValues(alpha: intensity),
        blurRadius: 20,
        spreadRadius: 0,
      ),
    ];
  }
}
