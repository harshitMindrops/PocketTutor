import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:pocket_tutor/core/network/connectivity_service.dart';
import 'package:pocket_tutor/core/storage/hive_service.dart';
import 'package:pocket_tutor/features/auth/data/models/user_model.dart';

class AuthRepository {
  AuthRepository._();

  static final instance = AuthRepository._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final HiveService _hive = HiveService.instance;
  final ConnectivityService _connectivity = ConnectivityService.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel?> getUserProfile(String uid) async {
    final cached = _hive.getUser(uid);
    if (cached != null && !_connectivity.isOnline) return cached;

    try {
      final snapshot = await _database.ref('users/$uid').get();
      if (snapshot.exists) {
        final userModel = UserModel.fromMap(
          Map<dynamic, dynamic>.from(snapshot.value as Map),
        );
        await _hive.saveUser(userModel);
        return userModel;
      }
    } catch (_) {
      return cached;
    }

    return cached;
  }

  Future<UserModel?> signUpWithEmailAndPassword(
    String email,
    String password,
    String name,
  ) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = userCredential.user;
    if (user == null) return null;

    await user.updateDisplayName(name);

    final userModel = UserModel(
      uid: user.uid,
      name: name,
      email: email,
      createdAt: DateTime.now().toIso8601String(),
    );

    await _hive.saveUser(userModel);
    if (_connectivity.isOnline) {
      await _database.ref('users/${user.uid}').set(userModel.toMap());
    }

    return userModel;
  }

  Future<UserModel?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = userCredential.user;
    if (user == null) return null;

    final cached = _hive.getUser(user.uid);
    if (!_connectivity.isOnline && cached != null) return cached;

    final userRef = _database.ref('users/${user.uid}');
    final snapshot = await userRef.get();

    if (!snapshot.exists) {
      final userModel = UserModel(
        uid: user.uid,
        name: user.displayName ?? cached?.name ?? '',
        email: user.email ?? cached?.email ?? '',
        createdAt: cached?.createdAt ?? DateTime.now().toIso8601String(),
      );
      await _hive.saveUser(userModel);
      if (_connectivity.isOnline) {
        await userRef.set(userModel.toMap());
      }
      return userModel;
    }

    final userModel = UserModel.fromMap(
      Map<dynamic, dynamic>.from(snapshot.value as Map),
    );
    await _hive.saveUser(userModel);
    return userModel;
  }

  Future<void> signOut() => _auth.signOut();
}
