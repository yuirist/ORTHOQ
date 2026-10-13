import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/firestore_date_utils.dart';

class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String? icNumber;
  /// Patient home address (optional; primarily stored under `patients` as well).
  final String? homeAddress;
  final String role; // 'patient', 'doctor', 'staff', 'admin'
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? joiningDate;

  // Doctor-specific fields
  final String? specialization;
  final String? doctorId;
  final String? staffId;
  /// Doctor document IDs this staff member may work with (set by admin; max 3).
  final List<String> assignedDoctorIds;

  /// Patient profile photo URL (Firebase Storage).
  final String? profileImageUrl;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    this.icNumber,
    this.homeAddress,
    required this.role,
    required this.createdAt,
    this.updatedAt,
    this.joiningDate,
    this.specialization,
    this.doctorId,
    this.staffId,
    this.assignedDoctorIds = const [],
    this.profileImageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'icNumber': icNumber,
      if (homeAddress != null) 'homeAddress': homeAddress,
      'role': role,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt':
          updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      if (specialization != null) 'specialization': specialization,
      if (doctorId != null) 'doctorId': doctorId,
      if (staffId != null) 'staffId': staffId,
      if (assignedDoctorIds.isNotEmpty) 'assignedDoctorIds': assignedDoctorIds,
      if (profileImageUrl != null && profileImageUrl!.isNotEmpty)
        'profileImageUrl': profileImageUrl,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      fullName: map['fullName']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      phoneNumber: map['phoneNumber']?.toString() ?? '',
      icNumber: map['icNumber']?.toString(),
      homeAddress: map['homeAddress']?.toString(),
      role: map['role']?.toString() ?? 'patient',
      createdAt: parseFirestoreDateTime(map['createdAt']),
      updatedAt: parseFirestoreDateTimeNullable(map['updatedAt']),
      joiningDate: parseFirestoreDateTimeNullable(
        map['joiningDate'] ?? map['date'],
      ),
      specialization: map['specialization']?.toString(),
      doctorId: map['doctorId']?.toString(),
      staffId: map['staffId']?.toString(),
      assignedDoctorIds: _parseAssignedDoctorIds(map['assignedDoctorIds']),
      profileImageUrl: map['profileImageUrl']?.toString(),
    );
  }

  static List<String> _parseAssignedDoctorIds(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .take(10)
        .toList();
  }

  UserModel copyWith({
    String? fullName,
    String? email,
    String? phoneNumber,
    String? icNumber,
    String? homeAddress,
    String? role,
    DateTime? updatedAt,
    String? specialization,
    String? doctorId,
    String? staffId,
    List<String>? assignedDoctorIds,
    String? profileImageUrl,
  }) {
    return UserModel(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      icNumber: icNumber ?? this.icNumber,
      homeAddress: homeAddress ?? this.homeAddress,
      role: role ?? this.role,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      specialization: specialization ?? this.specialization,
      doctorId: doctorId ?? this.doctorId,
      staffId: staffId ?? this.staffId,
      assignedDoctorIds: assignedDoctorIds ?? this.assignedDoctorIds,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }
}
