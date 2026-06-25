import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:pocket_tutor/core/network/connectivity_service.dart';
import 'package:pocket_tutor/core/services/notification_service.dart';
import 'package:pocket_tutor/core/storage/hive_service.dart';
import 'package:pocket_tutor/core/constants/app_strings.dart';
import 'package:pocket_tutor/features/auth/presentation/splash_screen.dart';
import 'package:pocket_tutor/features/chat/data/chat_repository.dart';
import 'package:pocket_tutor/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await HiveService.instance.init();
  await ConnectivityService.instance.init();
  await NotificationService.instance.init();
  ChatRepository.instance.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: SplashScreen(),
    );
  }
}
