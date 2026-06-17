import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
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
  bool get isProfileLoading => _isProfileLoading;
  String? get profileLoadError => _profileLoadError;

  bool _isProfileLoading = false;
  String? _profileLoadError;

  void clearProfileLoadError() {
    if (_profileLoadError == null) return;
    _profileLoadError = null;
    notifyListeners();
  }

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

  Future<void> _failSessionMissingProfile(
    String uid, {
    required String reason,
    User? firebaseUser,
  }) async {
    if (firebaseUser != null && isAdminBypassEmail(firebaseUser.email)) {
      debugPrint(
        'applyLoginSession: using synthetic admin profile for ${firebaseUser.email}',
      );
      _profileLoadError = null;
      _currentUserData = syntheticAdminProfile(firebaseUser);
      _isProfileLoading = false;
      notifyListeners();
      return;
    }

    debugPrint('applyLoginSession: $reason (uid=$uid)');
    _profileLoadError = reason;
    _currentUserData = null;
    _isProfileLoading = false;
    notifyListeners();

    if (_authService != null) {
      try {
        await _authService!.signOut();
      } catch (e) {
        debugPrint('signOut after missing profile failed: $e');
      }
    }
    _currentUser = null;
    notifyListeners();
  }

  Future<void> _loadUserData(String userId) async {
    if (_authService == null) return;
    _isProfileLoading = true;
    notifyListeners();
    try {
      _currentUserData = await _authService!.getLoginProfile(
        userId, // Firebase uid
        authEmail: _currentUser?.email,
      );
    } catch (e, stackTrace) {
      debugPrint('Error loading user data: $e');
      debugPrint(stackTrace.toString());
      _currentUserData = null;
    } finally {
      _isProfileLoading = false;
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
    _isProfileLoading = true;
    notifyListeners();

    try {
      final profile = await _authService!.getLoginProfile(
        firebaseUser.uid,
        authEmail: firebaseUser.email,
      );
      if (profile == null) {
        await _failSessionMissingProfile(
          firebaseUser.uid,
          reason: 'No clinic profile found for this account',
          firebaseUser: firebaseUser,
        );
        return _currentUserData;
      }

      final role = normalizeRole(profile.role);
      debugPrint(
        'applyLoginSession: role=$role name=${profile.fullName}',
      );

      if (!isKnownClinicRole(role)) {
        if (isAdminBypassEmail(firebaseUser.email)) {
          _profileLoadError = null;
          _currentUserData = syntheticAdminProfile(firebaseUser);
          return _currentUserData;
        }
        await _failSessionMissingProfile(
          firebaseUser.uid,
          reason: 'Unsupported account role "$role"',
          firebaseUser: firebaseUser,
        );
        return _currentUserData;
      }

      _profileLoadError = null;
      _currentUserData = profile;
      return profile;
    } catch (e, stackTrace) {
      debugPrint('applyLoginSession failed: $e');
      debugPrint(stackTrace.toString());
      _currentUserData = null;
      rethrow;
    } finally {
      _isProfileLoading = false;
      notifyListeners();
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
      await _authService!.registerWithEmailAndPassword(
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
      _profileLoadError = null;
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

  /// Uploads a new profile photo and saves the download URL to Firestore.
  Future<void> updateProfileImage({required String filePath}) async {
    if (_currentUser == null || _authService == null) {
      throw 'You must be signed in to update your profile photo.';
    }

    final storage = StorageService();
    final downloadUrl = await storage.uploadProfilePhoto(
      userId: _currentUser!.uid,
      filePath: filePath,
    );

    await _authService!.updateUserProfile(
      userId: _currentUser!.uid,
      profileImageUrl: downloadUrl,
    );
    await _loadUserData(_currentUser!.uid);
  }

  /// Uploads profile photo from bytes when file path is unavailable.
  Future<void> updateProfileImageBytes({required List<int> bytes}) async {
    if (_currentUser == null || _authService == null) {
      throw 'You must be signed in to update your profile photo.';
    }

    final storage = StorageService();
    final downloadUrl = await storage.uploadProfilePhotoBytes(
      userId: _currentUser!.uid,
      bytes: bytes,
    );

    await _authService!.updateUserProfile(
      userId: _currentUser!.uid,
      profileImageUrl: downloadUrl,
    );
    await _loadUserData(_currentUser!.uid);
  }
}
