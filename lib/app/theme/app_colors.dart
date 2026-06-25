import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Backgrounds ──────────────────────────────────────────────────────────
  static const background     = Color(0xFF0A0A1A);
  static const backgroundDark = Color(0xFF050510);
  static const surface        = Color(0xFF12122A);
  static const surfaceMuted   = Color(0xFF1A1A35);
  static const glassWhite     = Color(0x14FFFFFF); // 8% white — glass fill
  static const glassBorder    = Color(0x26FFFFFF); // 15% white — glass border

  // ── Brand ────────────────────────────────────────────────────────────────
  static const primary        = Color(0xFF7C3AED); // Electric Violet
  static const primaryLight   = Color(0xFFA78BFA); // Soft Lavender
  static const primaryAccent  = Color(0xFFDDD6FE); // Pale Violet (text on dark)
  static const secondary      = Color(0xFF06B6D4); // Cyan for AI accent
  static const secondaryLight = Color(0xFF67E8F9); // Bright Cyan

  // ── Text ─────────────────────────────────────────────────────────────────
  static const onPrimary      = Color(0xFFFFFFFF);
  static const onSurface      = Color(0xCCFFFFFF); // 80%
  static const onSurfaceMuted = Color(0x80FFFFFF); // 50%
  static const onSurfaceHint  = Color(0x4DFFFFFF); // 30%

  // ── Utility ──────────────────────────────────────────────────────────────
  static const border         = Color(0x1AFFFFFF); // 10% white
  static const error          = Color(0xFFFF4757);
  static const success        = Color(0xFF2ECC71);
  static const offline        = Color(0xFFF59E0B);
  static const online         = Color(0xFF10B981);
  static const buttonForeground = Color(0xFF0A0A1A);

  // ── Drawer ───────────────────────────────────────────────────────────────
  static const drawerGradientStart = Color(0xFF1E1040);
  static const drawerGradientEnd   = Color(0xFF0A0A1A);

  // ── Gradient helpers ─────────────────────────────────────────────────────
  static const userBubbleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
  );

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
  );

  static const meshGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.4, 1.0],
    colors: [Color(0xFF0F0A2A), Color(0xFF0A0A1A), Color(0xFF050510)],
  );
}
