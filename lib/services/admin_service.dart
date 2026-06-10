import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/appointment_model.dart';
import '../models/user_model.dart';
import 'appointment_service.dart';

/// Clinic-wide metrics for the admin overview.
class AdminOverviewStats {
  final int totalPatients;
  final int totalDoctors;
  final int totalStaff;

  const AdminOverviewStats({
    this.totalPatients = 0,
    this.totalDoctors = 0,
    this.totalStaff = 0,
  });
}

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AppointmentService _appointments = AppointmentService();

  Stream<AdminOverviewStats> watchOverviewStats() {
    return _firestore.collection('users').snapshots().asyncMap((snap) async {
      var patients = 0;
      var staff = 0;
      var doctorsFromUsers = 0;

      for (final doc in snap.docs) {
        final role = doc.data()['role']?.toString().toLowerCase().trim() ?? '';
        switch (role) {
          case 'patient':
            patients++;
            break;
          case 'staff':
            staff++;
            break;
          case 'doctor':
            doctorsFromUsers++;
            break;
        }
      }

      var totalDoctors = doctorsFromUsers;
      try {
        final doctorsSnap = await _firestore
            .collection('doctors')
            .where('isActive', isEqualTo: true)
            .get();
        if (doctorsSnap.size > totalDoctors) {
          totalDoctors = doctorsSnap.size;
        }
      } catch (_) {
        // Fall back to users collection doctor count.
      }

      return AdminOverviewStats(
        totalPatients: patients,
        totalDoctors: totalDoctors,
        totalStaff: staff,
      );
    });
  }

  Stream<List<AppointmentModel>> watchRecentAppointments({int limit = 8}) {
    return _appointments.getAllAppointments().map((list) {
      final sorted = List<AppointmentModel>.from(list)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return sorted.take(limit).toList();
    });
  }

  Stream<List<UserModel>> watchStaffMembers() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'staff')
        .snapshots()
        .map((snap) {
      final list = <UserModel>[];
      for (final doc in snap.docs) {
        try {
          list.add(UserModel.fromMap(doc.data(), doc.id));
        } catch (_) {
          // Skip malformed staff documents.
        }
      }
      list.sort(
        (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
      );
      return list;
    });
  }

  Stream<List<UserModel>> watchPatientMembers() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'patient')
        .snapshots()
        .map((snap) {
      final list = <UserModel>[];
      for (final doc in snap.docs) {
        try {
          list.add(UserModel.fromMap(doc.data(), doc.id));
        } catch (_) {
          // Skip malformed patient documents.
        }
      }
      list.sort(
        (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
      );
      return list;
    });
  }

  Future<void> updateStaffMember({
    required String userId,
    required String fullName,
    required String phoneNumber,
    String? staffId,
  }) async {
    await _firestore.collection('users').doc(userId).update({
      'fullName': fullName.trim(),
      'phoneNumber': phoneNumber.trim(),
      if (staffId != null && staffId.trim().isNotEmpty) 'staffId': staffId.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
