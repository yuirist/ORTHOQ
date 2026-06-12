import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Resolves a patient's email from appointment data, Firestore user profile,
/// or the signed-in Firebase Auth account.
class PatientEmailResolver {
  PatientEmailResolver({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Reads [email] / [patientEmail] from [data], then falls back to
  /// `users/{patientId}` and Firebase Auth when [patientId] is provided.
  Future<String?> resolve({
    required Map<String, dynamic> data,
    String? patientId,
    String? fallbackEmail,
  }) async {
    final fromData = _firstNonEmpty([
      data['email']?.toString(),
      data['patientEmail']?.toString(),
      fallbackEmail,
    ]);
    if (fromData != null) return fromData;

    final resolvedPatientId =
        patientId?.trim().isNotEmpty == true
            ? patientId!.trim()
            : data['patientId']?.toString().trim();
    if (resolvedPatientId == null || resolvedPatientId.isEmpty) {
      return _authEmailForPatient(resolvedPatientId);
    }

    try {
      final userDoc =
          await _firestore.collection('users').doc(resolvedPatientId).get();
      final fromUser = userDoc.data()?['email']?.toString().trim();
      if (fromUser != null && fromUser.isNotEmpty) return fromUser;
    } catch (e) {
      debugPrint(
        'PatientEmailResolver: could not load users/$resolvedPatientId — $e',
      );
    }

    return _authEmailForPatient(resolvedPatientId);
  }

  String? _authEmailForPatient(String? patientId) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;
    if (patientId != null &&
        patientId.isNotEmpty &&
        currentUser.uid != patientId) {
      return null;
    }
    final email = currentUser.email?.trim();
    return email != null && email.isNotEmpty ? email : null;
  }

  String? _firstNonEmpty(List<String?> candidates) {
    for (final candidate in candidates) {
      final trimmed = candidate?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }
}
