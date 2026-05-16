import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/user_model.dart';

class AuthService {
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

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'An unexpected error occurred: $e';
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
    String? doctorId,
    String? staffId,
  }) async {
    try {
      // Create user in Firebase Auth
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Create user document in Firestore
      UserModel userModel = UserModel(
        id: userCredential.user!.uid,
        fullName: fullName,
        email: email.trim(),
        phoneNumber: phoneNumber,
        icNumber: icNumber,
        homeAddress: (homeAddress == null || homeAddress.trim().isEmpty)
            ? null
            : homeAddress.trim(),
        role: role,
        createdAt: DateTime.now(),
        specialization: specialization,
        doctorId: doctorId,
        staffId: staffId,
      );

      await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .set(userModel.toMap());

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
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, userId);
      }
      return null;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint(
          'Firestore: permission denied reading users/$userId — check rules. ${e.message}',
        );
        return null;
      }
      throw 'Error fetching user data: ${e.message}';
    } catch (e) {
      throw 'Error fetching user data: $e';
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    required String userId,
    String? fullName,
    String? phoneNumber,
  }) async {
    try {
      Map<String, dynamic> updateData = {
        'updatedAt': DateTime.now().toIso8601String(),
      };
      if (fullName != null) updateData['fullName'] = fullName;
      if (phoneNumber != null) updateData['phoneNumber'] = phoneNumber;

      await _firestore.collection('users').doc(userId).update(updateData);
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
        return 'Wrong password provided.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'operation-not-allowed':
        return 'This operation is not allowed.';
      default:
        return 'Authentication error: ${e.message}';
    }
  }
}

