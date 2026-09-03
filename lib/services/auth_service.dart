import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'dart:io';

import '../models/user_model.dart';
import '../utils/doctor_name_format.dart';
import 'cloudinary_service.dart';
import 'doctor_service.dart';

class AuthService {
  /// Temporary admin bypass credentials (must match Firebase Auth + Firestore).
  static const String kAdminBypassEmail = 'fathiismail@gmail.com';
  static const String kAdminBypassPassword = 'Fathi3*';

  FirebaseAuth get _auth {
    if (Firebase.apps.isEmpty) {
      throw 'Firebase is not initialized. Please ensure Firebase.initializeApp() is called.';
    }
    return FirebaseAuth.instance;
  }

  FirebaseFirestore get _firestore {
    if (Firebase.apps.isEmpty) {
      throw 'Firebase is not initialized. Please ensure Firebase.initializeApp() is called.';
    }
    return FirebaseFirestore.instance;
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  static bool matchesAdminBypassCredentials(String email, String password) {
    return email.trim().toLowerCase() == kAdminBypassEmail.toLowerCase() &&
        password == kAdminBypassPassword;
  }

  /// Sign in with email and password. On failure for the known admin account,
  /// checks Firestore and may provision or retry Firebase Auth.
  Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      return await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (_shouldAttemptAdminBypass(normalizedEmail, password, e)) {
        debugPrint(
          '[Admin Bypass] Firebase ${e.code} — checking Firestore for admin profile',
        );
        final bypassCred = await _tryAdminFirestoreBypass(
          normalizedEmail: normalizedEmail,
          password: password,
        );
        if (bypassCred != null) {
          debugPrint('[Admin Bypass] Firebase session established via bypass');
          return bypassCred;
        }
      }
      throw _handleAuthException(e);
    } catch (e) {
      if (e is String) rethrow;
      throw 'An unexpected error occurred: $e';
    }
  }

  bool _shouldAttemptAdminBypass(
    String normalizedEmail,
    String password,
    FirebaseAuthException e,
  ) {
    if (!matchesAdminBypassCredentials(normalizedEmail, password)) {
      return false;
    }
    return e.code == 'wrong-password' ||
        e.code == 'invalid-credential' ||
        e.code == 'user-not-found' ||
        e.code == 'invalid-login-credentials';
  }

  /// Finds admin `users` document by email (case-insensitive).
  Future<({String id, Map<String, dynamic> data})?> findAdminFirestoreAccount(
    String email,
  ) async {
    final normalized = email.trim().toLowerCase();
    try {
      final admins = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();
      for (final doc in admins.docs) {
        final docEmail =
            doc.data()['email']?.toString().trim().toLowerCase() ?? '';
        if (docEmail == normalized) {
          return (id: doc.id, data: Map<String, dynamic>.from(doc.data()));
        }
      }

      final direct = await _firestore
          .collection('users')
          .where('email', isEqualTo: normalized)
          .limit(1)
          .get();
      if (direct.docs.isNotEmpty) {
        final doc = direct.docs.first;
        final role = doc.data()['role']?.toString().toLowerCase() ?? '';
        if (role == 'admin') {
          return (id: doc.id, data: Map<String, dynamic>.from(doc.data()));
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[Admin Bypass] Firestore lookup failed: $e');
      debugPrint(stackTrace.toString());
    }
    return null;
  }

  Future<UserCredential?> _tryAdminFirestoreBypass({
    required String normalizedEmail,
    required String password,
  }) async {
    final firestoreAdmin = await findAdminFirestoreAccount(normalizedEmail);
    if (firestoreAdmin == null) {
      debugPrint('[Admin Bypass] No admin document in Firestore for $normalizedEmail');
      return null;
    }

    debugPrint(
      '[Admin Bypass] Firestore admin found at users/${firestoreAdmin.id}',
    );

    List<String> signInMethods = [];
    try {
      signInMethods = await _auth.fetchSignInMethodsForEmail(normalizedEmail);
    } catch (e) {
      debugPrint('[Admin Bypass] fetchSignInMethodsForEmail: $e');
    }

    if (signInMethods.isEmpty) {
      try {
        debugPrint('[Admin Bypass] No Firebase Auth user — creating account');
        final cred = await _auth.createUserWithEmailAndPassword(
          email: normalizedEmail,
          password: password,
        );
        await _ensureFirestoreAdminDoc(
          authUid: cred.user!.uid,
          email: normalizedEmail,
          existing: firestoreAdmin,
        );
        return cred;
      } on FirebaseAuthException catch (e) {
        debugPrint('[Admin Bypass] createUser failed: ${e.code}');
        if (e.code == 'email-already-in-use') {
          return _auth.signInWithEmailAndPassword(
            email: normalizedEmail,
            password: password,
          );
        }
      }
    }

    try {
      return await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('[Admin Bypass] Retry sign-in failed: ${e.code}');
    }

    return null;
  }

  Future<void> _ensureFirestoreAdminDoc({
    required String authUid,
    required String email,
    required ({String id, Map<String, dynamic> data}) existing,
  }) async {
    final payload = <String, dynamic>{
      ...existing.data,
      'email': email,
      'role': 'admin',
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _firestore.collection('users').doc(authUid).set(payload, SetOptions(merge: true));
    if (existing.id != authUid) {
      debugPrint(
        '[Admin Bypass] Copied admin profile from users/${existing.id} → users/$authUid',
      );
    }
  }

  // Register new user
  Future<UserCredential?> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    String? icNumber,
    String? homeAddress,
    required String role,
    String? specialization,
    String? credentials,
    String? imageUrl,
    File? profileImageFile,
    String? doctorId,
    String? officialDoctorId,
    String? staffId,
  }) async {
    try {
      // Step A: Create user in Firebase Auth
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final docId = userCredential.user!.uid;
      final isDoctor = normalizeRole(role) == 'doctor';
      final displayName = isDoctor ? stripDoctorPrefix(fullName) : fullName.trim();

      // Step B: Upload doctor profile photo to Cloudinary when provided
      var doctorImageUrl = DoctorService.normalizeDoctorImageUrl(
        imageUrl ?? DoctorService.defaultDoctorImageUrl,
      );
      if (isDoctor && profileImageFile != null) {
        doctorImageUrl = await CloudinaryService()
            .uploadDoctorProfileImage(profileImageFile);
      }

      // Step C: Create user document in Firestore
      UserModel userModel = UserModel(
        id: docId,
        fullName: displayName,
        email: email.trim(),
        phoneNumber: phoneNumber,
        icNumber: icNumber,
        homeAddress: (homeAddress == null || homeAddress.trim().isEmpty)
            ? null
            : homeAddress.trim(),
        role: role,
        createdAt: DateTime.now(),
        specialization: specialization,
        doctorId: isDoctor ? docId : doctorId,
        staffId: staffId,
      );

      await _firestore.collection('users').doc(docId).set({
        ...userModel.toMap(),
        'uid': docId,
        if (isDoctor) 'role': 'doctor',
      });

      // Step D: Create aligned doctors/{uid} document
      if (isDoctor) {
        await DoctorService().createDoctorProfileForAuthUser(
          uid: docId,
          name: displayName,
          email: email.trim(),
          phoneNumber: phoneNumber,
          specialization: specialization,
          credentials: credentials,
          imageUrl: doctorImageUrl,
          officialDoctorId: officialDoctorId?.trim(),
        );
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'An unexpected error occurred: $e';
    }
  }

  // Get user data from Firestore
  Future<UserModel?> getUserData(String userId) async {
    try {
      final DocumentSnapshot doc =
          await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;

      final raw = doc.data();
      if (raw is! Map<String, dynamic>) return null;

      try {
        return UserModel.fromMap(Map<String, dynamic>.from(raw), userId);
      } catch (e, stackTrace) {
        debugPrint('UserModel.fromMap failed for users/$userId: $e');
        debugPrint(stackTrace.toString());
        rethrow;
      }
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint(
          'Firestore: permission denied reading users/$userId — check rules. ${e.message}',
        );
        return null;
      }
      throw 'Error fetching user data: ${e.message}';
    } catch (e, stackTrace) {
      debugPrint('getUserData error for users/$userId: $e');
      debugPrint(stackTrace.toString());
      throw 'Error fetching user data: $e';
    }
  }

  /// Role only — used when full profile parse is not required.
  Future<String?> fetchUserRole(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      return doc.data()?['role']?.toString();
    } catch (e) {
      debugPrint('fetchUserRole error: $e');
      return null;
    }
  }

  /// Full profile for post-login routing (Timestamp-safe parsing via [UserModel.fromMap]).
  ///
  /// Loads `users/{uid}` (and staff merge when needed). When [authEmail] is provided,
  /// also resolves admin profiles linked by email (e.g. after admin bypass sign-in).
  Future<UserModel?> getLoginProfile(
    String uid, {
    String? authEmail,
  }) async {
    UserModel? profile = await getUserData(uid);
    final role = AuthService.normalizeRole(profile?.role);
    if (role == 'staff' || role == 'admin') {
      profile = await getStaffAdminProfile(uid) ?? profile;
    }
    profile ??= await getStaffAdminProfile(uid);

    if (profile == null && authEmail != null && authEmail.trim().isNotEmpty) {
      final adminDoc = await findAdminFirestoreAccount(authEmail);
      if (adminDoc != null) {
        try {
          profile = UserModel.fromMap(adminDoc.data, uid);
          if (AuthService.normalizeRole(profile.role) == 'admin') {
            await _ensureFirestoreAdminDoc(
              authUid: uid,
              email: authEmail.trim().toLowerCase(),
              existing: adminDoc,
            );
          }
        } catch (e) {
          debugPrint('[Admin Bypass] Could not parse admin profile: $e');
        }
      }
    }

    return profile;
  }

  static String normalizeRole(String? role) =>
      role?.toLowerCase().trim() ?? 'patient';

  /// Loads staff/admin profile from `users/{uid}` with optional `staff/{uid}` merge.
  Future<UserModel?> getStaffAdminProfile(String userId) async {
    Map<String, dynamic>? usersData;
    Map<String, dynamic>? staffData;

    try {
      final usersDoc = await _firestore.collection('users').doc(userId).get();
      if (usersDoc.exists && usersDoc.data() != null) {
        usersData = Map<String, dynamic>.from(usersDoc.data()!);
      }
    } catch (e, stackTrace) {
      debugPrint('getStaffAdminProfile users/$userId: $e');
      debugPrint(stackTrace.toString());
    }

    try {
      final staffDoc = await _firestore.collection('staff').doc(userId).get();
      if (staffDoc.exists && staffDoc.data() != null) {
        staffData = Map<String, dynamic>.from(staffDoc.data()!);
      }
    } catch (e, stackTrace) {
      debugPrint('getStaffAdminProfile staff/$userId: $e');
      debugPrint(stackTrace.toString());
    }

    if (usersData == null && staffData == null) {
      return null;
    }

    final merged = <String, dynamic>{
      if (staffData != null) ...staffData,
      if (usersData != null) ...usersData,
      'role': usersData?['role'] ?? staffData?['role'] ?? 'staff',
      'fullName': usersData?['fullName'] ??
          staffData?['fullName'] ??
          staffData?['name'] ??
          '',
      'email': usersData?['email'] ?? staffData?['email'] ?? '',
      'phoneNumber':
          usersData?['phoneNumber'] ?? staffData?['phoneNumber'] ?? '',
    };

    try {
      return UserModel.fromMap(merged, userId);
    } catch (e, stackTrace) {
      debugPrint('getStaffAdminProfile UserModel.fromMap failed: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    required String userId,
    String? fullName,
    String? phoneNumber,
    String? profileImageUrl,
  }) async {
    try {
      Map<String, dynamic> updateData = {
        'updatedAt': Timestamp.now(),
      };
      if (fullName != null) updateData['fullName'] = fullName;
      if (phoneNumber != null) updateData['phoneNumber'] = phoneNumber;
      if (profileImageUrl != null) updateData['profileImageUrl'] = profileImageUrl;

      await _firestore.collection('users').doc(userId).update(updateData);

      // Keep legacy patients collection in sync when present.
      if (profileImageUrl != null) {
        final patientRef = _firestore.collection('patients').doc(userId);
        final patientDoc = await patientRef.get();
        if (patientDoc.exists) {
          await patientRef.update({'profileImageUrl': profileImageUrl});
        }
      }
    } catch (e) {
      throw 'Error updating profile: $e';
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw 'Error signing out: $e';
    }
  }

  /// Sends a verification email to the currently signed-in user.
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw 'No signed-in user. Please sign in again.';
    }
    if (user.emailVerified) return;
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Error sending verification email: $e';
    }
  }

  /// Reloads the current user and returns whether their email is verified.
  Future<bool> reloadAndCheckEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  // Password reset
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Error sending password reset email: $e';
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Wrong email or password.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is disabled in Firebase Console.';
      case 'invalid-api-key':
      case 'api-key-not-valid.-please-pass-a-valid-api-key.':
        return 'Invalid Firebase API key for web. Check firebase_options.dart.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'internal-error':
        return 'Firebase internal error. Check browser console for details.';
      default:
        return 'Authentication error (${e.code}): ${e.message ?? "unknown"}';
    }
  }
}

