import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../firebase_options.dart';
import '../models/doctor_model.dart';
import '../models/user_model.dart';
import '../utils/doctor_name_format.dart';

class DoctorService {
  static const _secondaryAuthAppName = 'doctorAccountCreation';

  /// Used when no profile photo is uploaded during doctor registration.
  static const String defaultDoctorImageUrl = '';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Trims pasted URLs and strips common wrappers (quotes, BOM) so Cloudinary links save reliably.
  static String normalizeDoctorImageUrl(String? raw) {
    if (raw == null) return '';
    var s = raw.trim();
    if (s.startsWith('\uFEFF')) {
      s = s.substring(1).trim();
    }
    if (s.length >= 2) {
      if ((s.startsWith('"') && s.endsWith('"')) ||
          (s.startsWith("'") && s.endsWith("'"))) {
        s = s.substring(1, s.length - 1).trim();
      }
    }
    if (s.startsWith('//') && s.contains('.')) {
      s = 'https:$s';
    }
    return s;
  }

  /// Creates a Firebase Auth account and aligned `users/{uid}` + `doctors/{uid}` docs.
  Future<String> createDoctorAccount({
    required String email,
    required String password,
    required String name,
    required String specialization,
    required String credentials,
    String? imageUrl,
    String phoneNumber = '',
  }) async {
    final cleanName = stripDoctorPrefix(name);
    if (cleanName.isEmpty) {
      throw 'Please enter the doctor name.';
    }

    FirebaseApp secondaryApp;
    try {
      secondaryApp = Firebase.app(_secondaryAuthAppName);
    } catch (_) {
      secondaryApp = await Firebase.initializeApp(
        name: _secondaryAuthAppName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
    UserCredential userCredential;
    try {
      userCredential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _authErrorMessage(e);
    } finally {
      try {
        await secondaryAuth.signOut();
      } catch (_) {}
    }

    final uid = userCredential.user!.uid;
    final normalizedImage = normalizeDoctorImageUrl(imageUrl);
    final now = DateTime.now();

    final userModel = UserModel(
      id: uid,
      fullName: cleanName,
      email: email.trim(),
      phoneNumber: phoneNumber.trim(),
      role: 'doctor',
      createdAt: now,
      specialization: specialization.trim(),
      doctorId: uid,
    );

    try {
      await _firestore.collection('users').doc(uid).set({
        ...userModel.toMap(),
        'uid': uid,
      });

      await _firestore.collection('doctors').doc(uid).set({
        'id': uid,
        'uid': uid,
        'userId': uid,
        'name': cleanName,
        'specialization': specialization.trim(),
        'credentials': credentials.trim(),
        'Credentials': credentials.trim(),
        'hospital': 'Hospital Kajang',
        'email': email.trim(),
        'phoneNumber': phoneNumber.trim(),
        'imageUrl': normalizedImage,
        'isActive': true,
        'approvalStatus': DoctorModel.approvalApproved,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Doctor account created in Auth but Firestore save failed: $e';
    }

    return uid;
  }

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'That email is already registered.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      default:
        return e.message ?? 'Could not create doctor account (${e.code}).';
    }
  }

  /// Adds a doctor from the admin console (no linked Firebase Auth user).
  /// Prefer [createDoctorAccount] so doctor and auth UIDs stay aligned.
  Future<String> addDoctorFromAdmin({
    required String name,
    required String specialization,
    required String credentials,
    String? imageUrl,
  }) async {
    try {
      final data = <String, dynamic>{
        'name': stripDoctorPrefix(name),
        'specialization': specialization.trim(),
        'credentials': credentials.trim(),
        'Credentials': credentials.trim(),
        'hospital': 'Hospital Kajang',
        'isActive': true,
        'approvalStatus': DoctorModel.approvalApproved,
        'userId': '',
        'email': '',
        'phoneNumber': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final image = normalizeDoctorImageUrl(imageUrl);
      data['imageUrl'] = image;
      final docRef = await _firestore.collection('doctors').add(data);
      return docRef.id;
    } catch (e) {
      throw 'Error saving doctor: $e';
    }
  }

  // Create doctor profile using a known document ID (typically Firebase Auth uid).
  Future<String> createDoctor(DoctorModel doctor) async {
    try {
      final docId = doctor.id.trim().isNotEmpty
          ? doctor.id.trim()
          : doctor.userId.trim();
      if (docId.isEmpty) {
        throw 'Doctor document id is required.';
      }

      await _firestore.collection('doctors').doc(docId).set(doctor.toMap());
      return docId;
    } catch (e) {
      throw 'Error creating doctor: $e';
    }
  }

  /// Creates `doctors/{uid}` aligned with the Firebase Auth user id.
  Future<void> createDoctorProfileForAuthUser({
    required String uid,
    required String name,
    required String email,
    required String phoneNumber,
    String? specialization,
    String? credentials,
    String? imageUrl,
    String? officialDoctorId,
  }) async {
    final docId = uid.trim();
    if (docId.isEmpty) {
      throw 'Doctor auth uid is required.';
    }

    final cleanName = stripDoctorPrefix(name);
    final creds = credentials?.trim() ?? '';
    final normalizedImage = normalizeDoctorImageUrl(
      (imageUrl == null || imageUrl.trim().isEmpty)
          ? defaultDoctorImageUrl
          : imageUrl,
    );

    final clinicDoctorId = officialDoctorId?.trim() ?? '';

    await _firestore.collection('doctors').doc(docId).set({
      'id': docId,
      'uid': docId,
      'userId': docId,
      if (clinicDoctorId.isNotEmpty) 'doctorId': clinicDoctorId,
      'name': cleanName,
      'specialization': specialization?.trim() ?? '',
      'credentials': creds,
      'Credentials': creds,
      'email': email.trim(),
      'phoneNumber': phoneNumber,
      'imageUrl': normalizedImage,
      'isActive': false,
      'approvalStatus': DoctorModel.approvalPending,
      'hospital': 'Hospital Kajang',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Get doctors awaiting admin approval (self-registration).
  Stream<List<DoctorModel>> getPendingDoctors() {
    return _firestore
        .collection('doctors')
        .where('approvalStatus', isEqualTo: DoctorModel.approvalPending)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DoctorModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Approves a pending doctor registration.
  Future<void> approveDoctor({
    required String doctorId,
    required String reviewedBy,
  }) async {
    try {
      await _firestore.collection('doctors').doc(doctorId).update({
        'isActive': true,
        'approvalStatus': DoctorModel.approvalApproved,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': reviewedBy.trim(),
        'rejectionReason': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Error approving doctor: $e';
    }
  }

  /// Rejects a pending doctor registration.
  Future<void> rejectDoctor({
    required String doctorId,
    required String reviewedBy,
    String? rejectionReason,
  }) async {
    try {
      final reason = rejectionReason?.trim() ?? '';
      await _firestore.collection('doctors').doc(doctorId).update({
        'isActive': false,
        'approvalStatus': DoctorModel.approvalRejected,
        'rejectionReason': reason.isEmpty ? 'Not approved by administrator.' : reason,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': reviewedBy.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Error rejecting doctor: $e';
    }
  }

  // Get all active doctors
  Stream<List<DoctorModel>> getActiveDoctors() {
    return _firestore
        .collection('doctors')
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .orderBy(FieldPath.documentId)
        .snapshots()
        .map((snapshot) {
          final doctors = <DoctorModel>[];
          for (final doc in snapshot.docs) {
            try {
              doctors.add(DoctorModel.fromMap(doc.data(), doc.id));
            } catch (e) {
              debugPrint('Skipping doctor ${doc.id}: $e');
            }
          }
          return doctors;
        });
  }

  // Get all doctors (including inactive)
  Stream<List<DoctorModel>> getAllDoctors() {
    return _firestore
        .collection('doctors')
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DoctorModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // Get doctor by ID
  Future<DoctorModel?> getDoctorById(String doctorId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('doctors')
          .doc(doctorId)
          .get();
      if (doc.exists) {
        return DoctorModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      throw 'Error fetching doctor: $e';
    }
  }

  // Get doctor by user ID
  Future<DoctorModel?> getDoctorByUserId(String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('doctors')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return DoctorModel.fromMap(
          snapshot.docs.first.data() as Map<String, dynamic>,
          snapshot.docs.first.id,
        );
      }
      return null;
    } catch (e) {
      throw 'Error fetching doctor: $e';
    }
  }

  // Update doctor profile
  Future<void> updateDoctor({
    required String doctorId,
    String? name,
    String? specialization,
    String? email,
    String? phoneNumber,
    bool? isActive,
    int? delayMinutes,
  }) async {
    try {
      Map<String, dynamic> updateData = {
        'updatedAt': DateTime.now().toIso8601String(),
      };
      if (name != null) updateData['name'] = name;
      if (specialization != null) updateData['specialization'] = specialization;
      if (email != null) updateData['email'] = email;
      if (phoneNumber != null) updateData['phoneNumber'] = phoneNumber;
      if (isActive != null) updateData['isActive'] = isActive;
      if (delayMinutes != null) updateData['delayMinutes'] = delayMinutes;

      await _firestore.collection('doctors').doc(doctorId).update(updateData);
    } catch (e) {
      throw 'Error updating doctor: $e';
    }
  }

  /// Full update from admin (name, specialization, credentials, Cloudinary imageUrl, active flag).
  Future<void> updateDoctorFromAdmin({
    required String doctorId,
    required String name,
    required String specialization,
    required String credentials,
    required String imageUrl,
    required bool isActive,
    String? hospital,
  }) async {
    try {
      final normalized = normalizeDoctorImageUrl(imageUrl);
      await _firestore.collection('doctors').doc(doctorId).update({
        'name': stripDoctorPrefix(name),
        'specialization': specialization.trim(),
        'credentials': credentials.trim(),
        'Credentials': credentials.trim(),
        'imageUrl': normalized,
        if (hospital != null && hospital.trim().isNotEmpty)
          'hospital': hospital.trim(),
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Error updating doctor: $e';
    }
  }

  /// Permanently removes the doctor document (admin only; ensure rules allow delete).
  Future<void> permanentlyDeleteDoctor(String doctorId) async {
    try {
      await _firestore.collection('doctors').doc(doctorId).delete();
    } catch (e) {
      throw 'Error deleting doctor: $e';
    }
  }

  // Delete doctor (soft delete by setting isActive to false)
  Future<void> deleteDoctor(String doctorId) async {
    try {
      await _firestore.collection('doctors').doc(doctorId).update({
        'isActive': false,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw 'Error deleting doctor: $e';
    }
  }

  // Get doctors by specialization/category
  Stream<List<DoctorModel>> getDoctorsBySpecialization(String specialization) {
    return _firestore
        .collection('doctors')
        .where('isActive', isEqualTo: true)
        .where('specialization', isEqualTo: specialization)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DoctorModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }
}
