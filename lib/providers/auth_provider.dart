import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../utils/auth_navigation.dart';

class AuthProvider with ChangeNotifier {
  final AuthService? _authService;
  UserModel? _currentUserData;
  User? _currentUser;
  final bool _firebaseInitialized;

  AuthProvider({bool firebaseInitialized = false})
      : _firebaseInitialized = firebaseInitialized,
        _authService = firebaseInitialized ? AuthService() : null {
    if (_firebaseInitialized && _authService != null) {
      _initAuthState();
    }
  }

  bool get isFirebaseInitialized => _firebaseInitialized;
  UserModel? get currentUserData => _currentUserData;
  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  void _initAuthState() {
    if (_authService == null) return;
    _currentUser = _authService!.currentUser;
    if (_currentUser != null) {
      _loadUserData(_currentUser!.uid);
    }
    _authService!.authStateChanges.listen((User? user) async {
      _currentUser = user;
      if (user != null) {
        await _loadUserData(user.uid);
      } else {
        _currentUserData = null;
      }
      notifyListeners();
    });
  }

  Future<void> _loadUserData(String userId) async {
    if (_authService == null) return;
    try {
      _currentUserData = await _authService!.getLoginProfile(
        userId, // Firebase uid
        authEmail: _currentUser?.email,
      );
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('Error loading user data: $e');
      debugPrint(stackTrace.toString());
      _currentUserData = null;
      notifyListeners();
    }
  }

  /// Fetches Firestore profile, applies Timestamp-safe parsing, stores session.
  ///
  /// Returns the parsed [UserModel] or `null` if no profile document exists.
  Future<UserModel?> applyLoginSession({required User firebaseUser}) async {
    if (_authService == null) {
      debugPrint('applyLoginSession: Firebase AuthService is not available');
      return null;
    }

    _currentUser = firebaseUser;

    try {
      final profile = await _authService!.getLoginProfile(
        firebaseUser.uid,
        authEmail: firebaseUser.email,
      );
      if (profile == null) {
        debugPrint('applyLoginSession: no users/staff profile for ${firebaseUser.uid}');
        _currentUserData = null;
        notifyListeners();
        return null;
      }

      final role = normalizeRole(profile.role);
      debugPrint(
        'applyLoginSession: role=$role name=${profile.fullName}',
      );

      if (!isKnownClinicRole(role)) {
        debugPrint('applyLoginSession: unsupported role "$role"');
        _currentUserData = null;
        notifyListeners();
        return null;
      }

      _currentUserData = profile;
      notifyListeners();
      return profile;
    } catch (e, stackTrace) {
      debugPrint('applyLoginSession failed: $e');
      debugPrint(stackTrace.toString());
      _currentUserData = null;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    if (_authService == null) {
      throw 'Firebase is not initialized. Please run: flutterfire configure';
    }
    try {
      UserCredential? userCredential = await _authService!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential?.user != null) {
        await applyLoginSession(firebaseUser: userCredential!.user!);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    String? icNumber,
    String? homeAddress,
    required String role,
    String? specialization,
    String? doctorId,
    String? staffId,
  }) async {
    if (_authService == null) {
      throw 'Firebase is not initialized. Please run: flutterfire configure';
    }
    try {
      UserCredential? userCredential = await _authService!.registerWithEmailAndPassword(
        email: email,
        password: password,
        fullName: fullName,
        phoneNumber: phoneNumber,
        icNumber: icNumber,
        homeAddress: homeAddress,
        role: role,
        specialization: specialization,
        doctorId: doctorId,
        staffId: staffId,
      );

      if (userCredential?.user != null) {
        await applyLoginSession(firebaseUser: userCredential!.user!);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (_authService == null) return;
    try {
      await _authService!.signOut();
      _currentUser = null;
      _currentUserData = null;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateProfile({
    String? fullName,
    String? phoneNumber,
  }) async {
    if (_currentUser == null || _authService == null) return;

    try {
      await _authService!.updateUserProfile(
        userId: _currentUser!.uid,
        fullName: fullName,
        phoneNumber: phoneNumber,
      );
      await _loadUserData(_currentUser!.uid);
    } catch (e) {
      rethrow;
    }
  }
}
