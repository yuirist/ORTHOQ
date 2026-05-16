import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment_model.dart';

class AppointmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create new appointment
  Future<String> createAppointment(AppointmentModel appointment) async {
    try {
      final appointmentData = appointment.toMap();
      appointmentData['icNumber'] = appointment.icNumber;
      DocumentReference docRef = await _firestore
          .collection('appointments')
          .add(appointmentData);
      return docRef.id;
    } catch (e) {
      throw 'Error creating appointment: $e';
    }
  }

  // Get appointments for a patient
  Stream<List<AppointmentModel>> getPatientAppointments(String patientId) {
    return _firestore
        .collection('appointments')
        .where('patientId', isEqualTo: patientId)
        .orderBy('appointmentDate', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppointmentModel.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // Get upcoming appointments for a patient
  Stream<List<AppointmentModel>> getUpcomingPatientAppointments(String patientId) {
    DateTime now = DateTime.now();
    // Get start of today to include today's appointments
    final startOfToday = DateTime(now.year, now.month, now.day);
    
    return _firestore
        .collection('appointments')
        .where('patientId', isEqualTo: patientId)
        .where('status', isEqualTo: 'confirmed')
        .where('appointmentDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
        .orderBy('appointmentDate', descending: false)
        .limit(1)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppointmentModel.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // Get appointments for a doctor
  Stream<List<AppointmentModel>> getDoctorAppointments(String doctorId) {
    return _firestore
        .collection('appointments')
        .where('doctorId', isEqualTo: doctorId)
        .orderBy('appointmentDate', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppointmentModel.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // Get appointments for a specific date (doctor's daily schedule)
  Stream<List<AppointmentModel>> getDoctorAppointmentsByDate(
      String doctorId, DateTime date) {
    DateTime startOfDay = DateTime(date.year, date.month, date.day);
    DateTime endOfDay = startOfDay.add(const Duration(days: 1));
    
    return _firestore
        .collection('appointments')
        .where('doctorId', isEqualTo: doctorId)
        .where('appointmentDate', isGreaterThanOrEqualTo: startOfDay)
        .where('appointmentDate', isLessThan: endOfDay)
        .where('status', whereIn: ['booked', 'rescheduled'])
        .orderBy('appointmentDate')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppointmentModel.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // Get all appointments (for staff/admin)
  Stream<List<AppointmentModel>> getAllAppointments() {
    return _firestore
        .collection('appointments')
        .orderBy('appointmentDate', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppointmentModel.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // Get appointment by ID
  Future<AppointmentModel?> getAppointmentById(String appointmentId) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('appointments').doc(appointmentId).get();
      if (doc.exists) {
        return AppointmentModel.fromMap(
            doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      throw 'Error fetching appointment: $e';
    }
  }

  // Request reschedule (patient)
  Future<void> requestReschedule({
    required String appointmentId,
    required DateTime requestedDate,
    required String requestedTime,
    String? reason,
  }) async {
    try {
      // Normalize requestedDate to start of day
      final normalizedDate = DateTime(requestedDate.year, requestedDate.month, requestedDate.day);
      await _firestore.collection('appointments').doc(appointmentId).update({
        'hasRescheduleRequest': true,
        'requestedDate': Timestamp.fromDate(normalizedDate),
        'requestedTime': requestedTime,
        if (reason != null) 'rescheduleReason': reason,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw 'Error requesting reschedule: $e';
    }
  }

  // Request schedule change (doctor)
  Future<void> requestScheduleChange({
    required String appointmentId,
    required DateTime requestedDate,
    required String requestedTime,
    String? reason,
  }) async {
    try {
      // Normalize requestedDate to start of day
      final normalizedDate = DateTime(requestedDate.year, requestedDate.month, requestedDate.day);
      await _firestore.collection('appointments').doc(appointmentId).update({
        'hasDoctorScheduleChange': true,
        'doctorRequestedDate': Timestamp.fromDate(normalizedDate),
        'doctorRequestedTime': requestedTime,
        if (reason != null) 'doctorChangeReason': reason,
        'scheduleChangeApproved': false,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw 'Error requesting schedule change: $e';
    }
  }

  // Approve reschedule request (staff)
  Future<void> approveReschedule({
    required String appointmentId,
    DateTime? newDate,
    String? newTime,
  }) async {
    try {
      AppointmentModel? appointment = await getAppointmentById(appointmentId);
      if (appointment == null) throw 'Appointment not found';

      Map<String, dynamic> updateData = {
        'hasRescheduleRequest': false,
        'status': 'rescheduled',
        'updatedAt': Timestamp.now(),
      };

      if (newDate != null) {
        // Normalize to start of day for exact date matching
        final normalizedDate = DateTime(newDate.year, newDate.month, newDate.day);
        updateData['appointmentDate'] = Timestamp.fromDate(normalizedDate);
      } else if (appointment.requestedDate != null) {
        final normalizedDate = DateTime(
          appointment.requestedDate!.year,
          appointment.requestedDate!.month,
          appointment.requestedDate!.day,
        );
        updateData['appointmentDate'] = Timestamp.fromDate(normalizedDate);
      }

      if (newTime != null) {
        updateData['appointmentTime'] = newTime;
      } else if (appointment.requestedTime != null) {
        updateData['appointmentTime'] = appointment.requestedTime;
      }

      updateData['requestedDate'] = null;
      updateData['requestedTime'] = null;
      updateData['rescheduleReason'] = null;

      await _firestore.collection('appointments').doc(appointmentId).update(updateData);
    } catch (e) {
      throw 'Error approving reschedule: $e';
    }
  }

  // Reject reschedule request (staff)
  Future<void> rejectReschedule(String appointmentId) async {
    try {
      await _firestore.collection('appointments').doc(appointmentId).update({
        'hasRescheduleRequest': false,
        'requestedDate': null,
        'requestedTime': null,
        'rescheduleReason': null,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw 'Error rejecting reschedule: $e';
    }
  }

  // Approve doctor schedule change (staff)
  Future<void> approveDoctorScheduleChange({
    required String appointmentId,
    DateTime? newDate,
    String? newTime,
  }) async {
    try {
      AppointmentModel? appointment = await getAppointmentById(appointmentId);
      if (appointment == null) throw 'Appointment not found';

      Map<String, dynamic> updateData = {
        'hasDoctorScheduleChange': false,
        'scheduleChangeApproved': true,
        'status': 'rescheduled',
        'updatedAt': Timestamp.now(),
      };

      if (newDate != null) {
        // Normalize to start of day for exact date matching
        final normalizedDate = DateTime(newDate.year, newDate.month, newDate.day);
        updateData['appointmentDate'] = Timestamp.fromDate(normalizedDate);
      } else if (appointment.doctorRequestedDate != null) {
        final normalizedDate = DateTime(
          appointment.doctorRequestedDate!.year,
          appointment.doctorRequestedDate!.month,
          appointment.doctorRequestedDate!.day,
        );
        updateData['appointmentDate'] = Timestamp.fromDate(normalizedDate);
      }

      if (newTime != null) {
        updateData['appointmentTime'] = newTime;
      } else if (appointment.doctorRequestedTime != null) {
        updateData['appointmentTime'] = appointment.doctorRequestedTime;
      }

      updateData['doctorRequestedDate'] = null;
      updateData['doctorRequestedTime'] = null;
      updateData['doctorChangeReason'] = null;

      await _firestore.collection('appointments').doc(appointmentId).update(updateData);
    } catch (e) {
      throw 'Error approving doctor schedule change: $e';
    }
  }

  // Update appointment status (staff)
  Future<void> updateAppointmentStatus({
    required String appointmentId,
    required String status,
  }) async {
    try {
      await _firestore.collection('appointments').doc(appointmentId).update({
        'status': status,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw 'Error updating appointment status: $e';
    }
  }

  // Cancel appointment (patient)
  Future<void> cancelAppointment(String appointmentId) async {
    try {
      await _firestore.collection('appointments').doc(appointmentId).update({
        'status': 'cancelled',
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw 'Error cancelling appointment: $e';
    }
  }

  // Update referral verification status (staff)
  Future<void> verifyReferralLetter({
    required String appointmentId,
    required bool verified,
  }) async {
    try {
      await _firestore.collection('appointments').doc(appointmentId).update({
        'referralVerified': verified,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw 'Error verifying referral letter: $e';
    }
  }
}






