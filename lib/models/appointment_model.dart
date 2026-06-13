import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentModel {
  final String id;
  final String patientId;
  final String patientName;
  final String doctorId;
  final String doctorName;
  final String appointmentType; // 'new_patient' or 'follow_up'
  final String patientType; // 'New' or 'Follow-up'
  final DateTime appointmentDate;
  final String appointmentTime;
  /// Session length in minutes (clinic default 15; stored for calendar/overlap logic).
  final int durationMinutes;
  final String status; // 'Pending', 'booked', 'rescheduled', 'cancelled', 'completed', 'pending_verification', 'confirmed'
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  // Patient information fields
  final String? phoneNumber;
  final String? email;
  final String? icNumber;
  final String? paymentType; // 'Self-pay' or 'Insurance'
  final String? insuranceProvider; // required when paymentType is Insurance
  final String? bookingFor; // 'Self' or 'Others' (who the appointment is for)
  final String? gender; // 'Male' or 'Female' (extracted from IC number)
  
  // Reschedule request fields
  final bool hasRescheduleRequest;
  final DateTime? requestedDate;
  final String? requestedTime;
  final String? rescheduleReason;
  
  // Referral letter (for new patient appointments)
  final String? referralLetterUrl;
  final bool referralVerified;
  
  // Schedule change request from doctor
  final bool hasDoctorScheduleChange;
  final DateTime? doctorRequestedDate;
  final String? doctorRequestedTime;
  final String? doctorChangeReason;
  final bool scheduleChangeApproved;

  AppointmentModel({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    required this.appointmentType,
    required this.patientType,
    required this.appointmentDate,
    required this.appointmentTime,
    this.durationMinutes = 15,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.phoneNumber,
    this.email,
    this.icNumber,
    this.paymentType,
    this.insuranceProvider,
    this.bookingFor,
    this.gender,
    this.hasRescheduleRequest = false,
    this.requestedDate,
    this.requestedTime,
    this.rescheduleReason,
    this.referralLetterUrl,
    this.referralVerified = false,
    this.hasDoctorScheduleChange = false,
    this.doctorRequestedDate,
    this.doctorRequestedTime,
    this.doctorChangeReason,
    this.scheduleChangeApproved = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'appointmentType': appointmentType,
      'patientType': patientType,
      'appointmentDate': Timestamp.fromDate(appointmentDate),
      'appointmentTime': appointmentTime,
      'durationMinutes': durationMinutes,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'phoneNumber': phoneNumber,
      'email': email,
      'icNumber': icNumber,
      'paymentType': paymentType,
      if (insuranceProvider != null) 'insuranceProvider': insuranceProvider,
      if (bookingFor != null) 'bookingFor': bookingFor,
      'gender': gender,
      'hasRescheduleRequest': hasRescheduleRequest,
      'requestedDate': requestedDate != null ? Timestamp.fromDate(requestedDate!) : null,
      'requestedTime': requestedTime,
      'rescheduleReason': rescheduleReason,
      'referralLetterUrl': referralLetterUrl,
      'referralVerified': referralVerified,
      'hasDoctorScheduleChange': hasDoctorScheduleChange,
      'doctorRequestedDate': doctorRequestedDate != null ? Timestamp.fromDate(doctorRequestedDate!) : null,
      'doctorRequestedTime': doctorRequestedTime,
      'doctorChangeReason': doctorChangeReason,
      'scheduleChangeApproved': scheduleChangeApproved,
    };
  }

  factory AppointmentModel.fromMap(Map<String, dynamic> map, String id) {
    // Helper function to safely parse DateTime
    DateTime parseDateTime(dynamic value) {
      if (value is String) {
        return DateTime.parse(value);
      } else if (value is Timestamp) {
        return value.toDate();
      } else {
        return DateTime.now();
      }
    }

    DateTime? parseDateTimeNullable(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        return DateTime.parse(value);
      } else if (value is Timestamp) {
        return value.toDate();
      }
      return null;
    }

    int parseDurationMinutes(dynamic value) {
      if (value is int) return value.clamp(5, 120);
      if (value is num) return value.round().clamp(5, 120).toInt();
      return 15;
    }

    return AppointmentModel(
      id: id,
      patientId: map['patientId']?.toString() ?? '',
      patientName: map['patientName']?.toString() ?? '',
      doctorId: map['doctorId']?.toString() ?? '',
      doctorName: map['doctorName']?.toString() ?? '',
      appointmentType: _appointmentTypeFromMap(map),
      patientType: _patientTypeFromMap(map),
      appointmentDate: parseDateTime(map['appointmentDate']),
      appointmentTime: map['appointmentTime']?.toString() ?? '',
      durationMinutes: parseDurationMinutes(map['durationMinutes']),
      status: map['status']?.toString() ?? 'Pending',
      createdAt: parseDateTime(map['createdAt']),
      updatedAt: parseDateTimeNullable(map['updatedAt']),
      phoneNumber: map['phoneNumber']?.toString(),
      email: map['email']?.toString(),
      icNumber: map['icNumber']?.toString(),
      paymentType: map['paymentType']?.toString(),
      insuranceProvider: map['insuranceProvider']?.toString(),
      bookingFor: map['bookingFor']?.toString(),
      gender: map['gender']?.toString(),
      hasRescheduleRequest: map['hasRescheduleRequest'] ?? false,
      requestedDate: parseDateTimeNullable(map['requestedDate']),
      requestedTime: map['requestedTime']?.toString(),
      rescheduleReason: map['rescheduleReason']?.toString(),
      referralLetterUrl: map['referralLetterUrl']?.toString(),
      referralVerified: map['referralVerified'] ?? false,
      hasDoctorScheduleChange: map['hasDoctorScheduleChange'] ?? false,
      doctorRequestedDate: parseDateTimeNullable(map['doctorRequestedDate']),
      doctorRequestedTime: map['doctorRequestedTime']?.toString(),
      doctorChangeReason: map['doctorChangeReason']?.toString(),
      scheduleChangeApproved: map['scheduleChangeApproved'] ?? false,
    );
  }

  /// True when Firestore marks this as a new-patient visit.
  bool get isNewPatientVisit {
    final patientTypeLower = patientType.toLowerCase();
    final appointmentTypeLower = appointmentType.toLowerCase();
    return patientTypeLower.contains('new') ||
        appointmentTypeLower.contains('new');
  }

  /// Display label for visit-type badges (New Patient vs Follow Up).
  String get visitTypeDisplayLabel {
    if (isNewPatientVisit) return 'New Patient';
    final patientTypeLower = patientType.toLowerCase();
    final appointmentTypeLower = appointmentType.toLowerCase();
    if (patientTypeLower.contains('follow') ||
        appointmentTypeLower.contains('follow')) {
      return 'Follow Up';
    }
    final raw = patientType.trim();
    return raw.isEmpty ? 'Follow Up' : raw;
  }

  AppointmentModel copyWith({
    String? status,
    DateTime? updatedAt,
    String? phoneNumber,
    String? email,
    String? icNumber,
    String? paymentType,
    String? insuranceProvider,
    String? bookingFor,
    String? gender,
    bool? hasRescheduleRequest,
    DateTime? requestedDate,
    String? requestedTime,
    String? rescheduleReason,
    bool? referralVerified,
    bool? hasDoctorScheduleChange,
    DateTime? doctorRequestedDate,
    String? doctorRequestedTime,
    String? doctorChangeReason,
    bool? scheduleChangeApproved,
    DateTime? appointmentDate,
    String? appointmentTime,
    int? durationMinutes,
  }) {
    return AppointmentModel(
      id: id,
      patientId: patientId,
      patientName: patientName,
      doctorId: doctorId,
      doctorName: doctorName,
      appointmentType: appointmentType,
      patientType: patientType,
      appointmentDate: appointmentDate ?? this.appointmentDate,
      appointmentTime: appointmentTime ?? this.appointmentTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      icNumber: icNumber ?? this.icNumber,
      paymentType: paymentType ?? this.paymentType,
      insuranceProvider: insuranceProvider ?? this.insuranceProvider,
      bookingFor: bookingFor ?? this.bookingFor,
      gender: gender ?? this.gender,
      hasRescheduleRequest: hasRescheduleRequest ?? this.hasRescheduleRequest,
      requestedDate: requestedDate ?? this.requestedDate,
      requestedTime: requestedTime ?? this.requestedTime,
      rescheduleReason: rescheduleReason ?? this.rescheduleReason,
      referralLetterUrl: referralLetterUrl,
      referralVerified: referralVerified ?? this.referralVerified,
      hasDoctorScheduleChange: hasDoctorScheduleChange ?? this.hasDoctorScheduleChange,
      doctorRequestedDate: doctorRequestedDate ?? this.doctorRequestedDate,
      doctorRequestedTime: doctorRequestedTime ?? this.doctorRequestedTime,
      doctorChangeReason: doctorChangeReason ?? this.doctorChangeReason,
      scheduleChangeApproved: scheduleChangeApproved ?? this.scheduleChangeApproved,
    );
  }
}

String _patientTypeFromMap(Map<String, dynamic> map) {
  final patientType = map['patientType']?.toString().trim();
  if (patientType != null && patientType.isNotEmpty) return patientType;

  final visitType = map['visitType']?.toString().trim();
  if (visitType != null && visitType.isNotEmpty) return visitType;

  final appointmentType =
      (map['appointmentType'] ?? '').toString().toLowerCase();
  if (appointmentType.contains('follow')) return 'Follow-up';
  if (appointmentType.contains('new')) return 'New';
  return 'New';
}

String _appointmentTypeFromMap(Map<String, dynamic> map) {
  final appointmentType = map['appointmentType']?.toString().trim();
  if (appointmentType != null && appointmentType.isNotEmpty) {
    return appointmentType;
  }

  final visitType = (map['visitType'] ?? '').toString().toLowerCase();
  if (visitType.contains('new')) return 'new_patient';
  if (visitType.contains('follow')) return 'follow_up';

  final patientType = (map['patientType'] ?? '').toString().toLowerCase();
  if (patientType.contains('follow')) return 'follow_up';
  if (patientType.contains('new')) return 'new_patient';
  return 'new_patient';
}




