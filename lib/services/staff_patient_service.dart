import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/notification_model.dart';
import '../utils/firestore_date_utils.dart';

/// Patient row derived from appointments linked to a doctor.
class StaffDoctorPatient {
  const StaffDoctorPatient({
    required this.key,
    this.patientId,
    required this.fullName,
    required this.icNumber,
    this.email,
    this.profileImageUrl,
    this.latestAppointmentId,
    this.latestAppointmentDate,
    this.latestAppointmentTime,
  });

  final String key;
  final String? patientId;
  final String fullName;
  final String icNumber;
  final String? email;
  final String? profileImageUrl;
  final String? latestAppointmentId;
  final DateTime? latestAppointmentDate;
  final String? latestAppointmentTime;
}

class StaffPatientHistoryEntry {
  const StaffPatientHistoryEntry({
    required this.title,
    required this.body,
    required this.createdAt,
    required this.source,
  });

  final String title;
  final String body;
  final DateTime createdAt;
  final String source;
}

class StaffPatientService {
  StaffPatientService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<StaffDoctorPatient>> watchPatientsForDoctor(String doctorId) {
    if (doctorId.trim().isEmpty) {
      return Stream.value(const []);
    }

    return _firestore
        .collection('appointments')
        .where('doctorId', isEqualTo: doctorId.trim())
        .snapshots()
        .asyncMap(_mapAppointmentsToPatients);
  }

  Future<List<StaffDoctorPatient>> _mapAppointmentsToPatients(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    final byKey = <String, _PatientAccumulator>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final patientId = data['patientId']?.toString().trim();
      final ic = data['icNumber']?.toString().trim() ?? '';
      final name = data['patientName']?.toString().trim();
      final email = data['email']?.toString().trim();
      final key = (patientId != null && patientId.isNotEmpty)
          ? 'uid:$patientId'
          : (ic.isNotEmpty ? 'ic:$ic' : 'name:${name ?? doc.id}');

      final apptDate = _parseAppointmentDate(data['appointmentDate']);
      final apptTime = data['appointmentTime']?.toString().trim() ?? '';

      final existing = byKey[key];
      if (existing == null) {
        byKey[key] = _PatientAccumulator(
          key: key,
          patientId: patientId?.isNotEmpty == true ? patientId : null,
          fullName: name?.isNotEmpty == true ? name! : 'Patient',
          icNumber: ic.isNotEmpty ? ic : '—',
          email: email?.isNotEmpty == true ? email : null,
          latestAppointmentId: doc.id,
          latestAppointmentDate: apptDate,
          latestAppointmentTime: apptTime.isNotEmpty ? apptTime : null,
        );
        continue;
      }

      if (_isNewerAppointment(apptDate, apptTime, existing)) {
        byKey[key] = existing.copyWithLatest(
          appointmentId: doc.id,
          appointmentDate: apptDate,
          appointmentTime: apptTime.isNotEmpty ? apptTime : null,
          email: email?.isNotEmpty == true ? email : existing.email,
          fullName: name?.isNotEmpty == true ? name! : existing.fullName,
        );
      }
    }

    final patientIds = byKey.values
        .map((p) => p.patientId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final userProfiles = <String, Map<String, dynamic>>{};
    for (var i = 0; i < patientIds.length; i += 10) {
      final chunk = patientIds.skip(i).take(10).toList();
      final snaps = await Future.wait(
        chunk.map((id) => _firestore.collection('users').doc(id).get()),
      );
      for (final snap in snaps) {
        if (snap.exists && snap.data() != null) {
          userProfiles[snap.id] = snap.data()!;
        }
      }
    }

    final enriched = <StaffDoctorPatient>[];
    for (final patient in byKey.values) {
      final profile = patient.patientId != null
          ? userProfiles[patient.patientId!]
          : null;
      enriched.add(
        StaffDoctorPatient(
          key: patient.key,
          patientId: patient.patientId,
          fullName: profile?['fullName']?.toString().trim().isNotEmpty == true
              ? profile!['fullName'].toString().trim()
              : patient.fullName,
          icNumber: profile?['icNumber']?.toString().trim().isNotEmpty == true
              ? profile!['icNumber'].toString().trim()
              : patient.icNumber,
          email: profile?['email']?.toString().trim().isNotEmpty == true
              ? profile!['email'].toString().trim()
              : patient.email,
          profileImageUrl:
              profile?['profileImageUrl']?.toString().trim(),
          latestAppointmentId: patient.latestAppointmentId,
          latestAppointmentDate: patient.latestAppointmentDate,
          latestAppointmentTime: patient.latestAppointmentTime,
        ),
      );
    }

    enriched.sort(
      (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    );
    return enriched;
  }

  Stream<List<NotificationModel>> watchInAppNotifications(String userId) {
    if (userId.trim().isEmpty) {
      return Stream.value(const []);
    }
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId.trim())
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => NotificationModel.fromMap(
                  doc.data(),
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  Stream<List<StaffPatientHistoryEntry>> watchPatientEmailHistory(
    String patientId,
  ) {
    if (patientId.trim().isEmpty) {
      return Stream.value(const []);
    }

    return _firestore
        .collection('patients')
        .doc(patientId.trim())
        .collection('history')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            return StaffPatientHistoryEntry(
              title: data['title']?.toString().trim().isNotEmpty == true
                  ? data['title'].toString().trim()
                  : 'Email',
              body: data['description']?.toString().trim().isNotEmpty == true
                  ? data['description'].toString().trim()
                  : '',
              createdAt: parseFirestoreDateTime(data['timestamp']),
              source: 'Email · ${data['status']?.toString() ?? 'sent'}',
            );
          }).toList(),
        );
  }

  Future<List<StaffPatientHistoryEntry>> fetchEmailLogs(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return [];

    try {
      final snapshot = await _firestore
          .collection('outbound_mail')
          .where('to', isEqualTo: trimmed)
          .limit(50)
          .get();

      final entries = snapshot.docs.map((doc) {
        final data = doc.data();
        return StaffPatientHistoryEntry(
          title: data['subject']?.toString().trim().isNotEmpty == true
              ? data['subject'].toString().trim()
              : 'Email',
          body: data['contextLabel']?.toString().trim().isNotEmpty == true
              ? data['contextLabel'].toString().trim()
              : (data['text']?.toString().trim() ?? ''),
          createdAt: parseFirestoreDateTime(data['createdAt']),
          source: 'Email · ${data['status']?.toString() ?? 'sent'}',
        );
      }).toList();

      entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return entries;
    } catch (_) {
      return [];
    }
  }
}

class _PatientAccumulator {
  const _PatientAccumulator({
    required this.key,
    this.patientId,
    required this.fullName,
    required this.icNumber,
    this.email,
    this.latestAppointmentId,
    this.latestAppointmentDate,
    this.latestAppointmentTime,
  });

  final String key;
  final String? patientId;
  final String fullName;
  final String icNumber;
  final String? email;
  final String? latestAppointmentId;
  final DateTime? latestAppointmentDate;
  final String? latestAppointmentTime;

  _PatientAccumulator copyWithLatest({
    required String appointmentId,
    DateTime? appointmentDate,
    String? appointmentTime,
    String? email,
    String? fullName,
  }) {
    return _PatientAccumulator(
      key: key,
      patientId: patientId,
      fullName: fullName ?? this.fullName,
      icNumber: icNumber,
      email: email ?? this.email,
      latestAppointmentId: appointmentId,
      latestAppointmentDate: appointmentDate,
      latestAppointmentTime: appointmentTime,
    );
  }
}

bool _isNewerAppointment(
  DateTime? candidateDate,
  String candidateTime,
  _PatientAccumulator existing,
) {
  final existingDate = existing.latestAppointmentDate;
  if (candidateDate == null) return false;
  if (existingDate == null) return true;
  if (candidateDate.isAfter(existingDate)) return true;
  if (candidateDate.isBefore(existingDate)) return false;
  return candidateTime.compareTo(existing.latestAppointmentTime ?? '') > 0;
}

DateTime? _parseAppointmentDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
