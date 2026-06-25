import 'package:flutter/material.dart';
import 'package:pocket_tutor/app/theme/app_decorations.dart';

class AppGradientBackground extends StatelessWidget {
  const AppGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppDecorations.backgroundGradient),
      child: child,
    );
  }
}
