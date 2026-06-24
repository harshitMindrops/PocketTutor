import 'package:flutter/material.dart';
import 'package:pocket_tutor/utils/services/auth_service.dart';
import 'login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await AuthService.instance.signOut();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const AuthScreen(),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {

    final user =
        AuthService.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PocketTutor'),
        actions: [
          IconButton(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Text(
          'Welcome ${user?.displayName}',
        ),
      ),
    );
  }
}