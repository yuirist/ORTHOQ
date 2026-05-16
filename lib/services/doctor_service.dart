import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/doctor_model.dart';

class DoctorService {
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

  /// Adds a doctor from the admin console (no linked Firebase Auth user).
  /// Appears in [getActiveDoctors] for patients as soon as Firestore syncs.
  Future<String> addDoctorFromAdmin({
    required String name,
    required String specialization,
    required String credentials,
    String? imageUrl,
  }) async {
    try {
      final data = <String, dynamic>{
        'name': name.trim(),
        'specialization': specialization.trim(),
        'credentials': credentials.trim(),
        'Credentials': credentials.trim(),
        'hospital': 'Hospital Kajang',
        'isActive': true,
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

  // Create doctor profile
  Future<String> createDoctor(DoctorModel doctor) async {
    try {
      DocumentReference docRef = await _firestore
          .collection('doctors')
          .add(doctor.toMap());
      return docRef.id;
    } catch (e) {
      throw 'Error creating doctor: $e';
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
  }) async {
    try {
      final normalized = normalizeDoctorImageUrl(imageUrl);
      await _firestore.collection('doctors').doc(doctorId).update({
        'name': name.trim(),
        'specialization': specialization.trim(),
        'credentials': credentials.trim(),
        'Credentials': credentials.trim(),
        'imageUrl': normalized,
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
