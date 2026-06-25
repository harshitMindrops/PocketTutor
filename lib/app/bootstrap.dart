import 'package:firebase_core/firebase_core.dart';
import 'package:pocket_tutor/core/network/connectivity_service.dart';
import 'package:pocket_tutor/core/storage/hive_service.dart';
import 'package:pocket_tutor/features/chat/data/chat_repository.dart';
import 'package:pocket_tutor/firebase_options.dart';

abstract final class AppBootstrap {
  static Future<void> init() async {
    await HiveService.instance.init();
    await ConnectivityService.instance.init();
    ChatRepository.instance.init();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}
