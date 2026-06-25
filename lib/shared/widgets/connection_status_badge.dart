import 'package:flutter/material.dart';
import 'package:pocket_tutor/app/theme/app_colors.dart';

class ConnectionStatusBadge extends StatelessWidget {
  const ConnectionStatusBadge({super.key, required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Text(
      isOnline ? '● ONLINE' : '● OFFLINE MODE',
      style: TextStyle(
        fontSize: 10,
        color: isOnline ? AppColors.online : AppColors.offline,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}
