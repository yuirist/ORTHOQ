import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/firestore_date_utils.dart';

class DoctorModel {
  static const String approvalPending = 'pending';
  static const String approvalApproved = 'approved';
  static const String approvalRejected = 'rejected';

  final String id;
  final String userId; // Reference to users collection
  final String name;
  final String specialization;
  final String email;
  final String phoneNumber;
  final bool isActive;
  final String approvalStatus;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? hospital;
  final String? imageUrl;
  final String? credentials;
  final int? delayMinutes; // Delay in minutes for the doctor
  final String? rejectionReason;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  /// Official clinic-assigned ID (e.g. DOC-2026-001), stored as `doctorId` in Firestore.
  final String? officialDoctorId;

  DoctorModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.specialization,
    required this.email,
    required this.phoneNumber,
    this.isActive = true,
    this.approvalStatus = approvalApproved,
    required this.createdAt,
    this.updatedAt,
    this.hospital,
    this.imageUrl,
    this.credentials,
    this.delayMinutes,
    this.rejectionReason,
    this.reviewedAt,
    this.reviewedBy,
    this.officialDoctorId,
  });

  bool get isApprovalPending => approvalStatus == approvalPending;

  bool get isApprovalRejected => approvalStatus == approvalRejected;

  /// True when the doctor may use the portal (approved or legacy record without status).
  bool get canAccessPortal {
    if (approvalStatus == approvalPending || approvalStatus == approvalRejected) {
      return false;
    }
    return isActive;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'specialization': specialization,
      'email': email,
      'phoneNumber': phoneNumber,
      'isActive': isActive,
      'approvalStatus': approvalStatus,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt':
          updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      if (hospital != null) 'hospital': hospital,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (credentials != null && credentials!.isNotEmpty) 'credentials': credentials,
      if (delayMinutes != null) 'delayMinutes': delayMinutes,
      if (rejectionReason != null && rejectionReason!.isNotEmpty)
        'rejectionReason': rejectionReason,
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
      if (reviewedBy != null && reviewedBy!.isNotEmpty) 'reviewedBy': reviewedBy,
      if (officialDoctorId != null && officialDoctorId!.isNotEmpty)
        'doctorId': officialDoctorId,
    };
  }

  static String _parseApprovalStatus(Map<String, dynamic> map, bool isActive) {
    final raw = map['approvalStatus']?.toString().trim().toLowerCase();
    if (raw == approvalPending ||
        raw == approvalApproved ||
        raw == approvalRejected) {
      return raw!;
    }
    // Legacy doctors without approvalStatus were provisioned before this workflow.
    return approvalApproved;
  }

  factory DoctorModel.fromMap(Map<String, dynamic> map, String id) {
    final isActive = map['isActive'] is bool
        ? map['isActive'] as bool
        : (map['isActive']?.toString().toLowerCase() == 'true' ||
            map['isActive'] == true);
    return DoctorModel(
      id: id,
      userId: map['userId']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Unknown Doctor',
      specialization: map['specialization']?.toString() ?? 'General Practitioner',
      email: map['email']?.toString() ?? '',
      phoneNumber: map['phoneNumber']?.toString() ?? '',
      isActive: isActive,
      approvalStatus: _parseApprovalStatus(map, isActive),
      createdAt: parseFirestoreDateTime(map['createdAt']),
      updatedAt: parseFirestoreDateTimeNullable(map['updatedAt']),
      hospital: map['hospital']?.toString(),
      imageUrl: map['imageUrl']?.toString(),
      credentials: map['credentials']?.toString() ??
          map['Credentials']?.toString(),
      delayMinutes: map['delayMinutes'] != null ? (map['delayMinutes'] is int ? map['delayMinutes'] as int : int.tryParse(map['delayMinutes'].toString())) : null,
      rejectionReason: map['rejectionReason']?.toString(),
      reviewedAt: parseFirestoreDateTimeNullable(map['reviewedAt']),
      reviewedBy: map['reviewedBy']?.toString(),
      officialDoctorId: map['doctorId']?.toString(),
    );
  }

  DoctorModel copyWith({
    String? name,
    String? specialization,
    String? email,
    String? phoneNumber,
    bool? isActive,
    String? approvalStatus,
    DateTime? updatedAt,
    String? credentials,
    int? delayMinutes,
    String? rejectionReason,
    DateTime? reviewedAt,
    String? reviewedBy,
    String? officialDoctorId,
  }) {
    return DoctorModel(
      id: id,
      userId: userId,
      name: name ?? this.name,
      specialization: specialization ?? this.specialization,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isActive: isActive ?? this.isActive,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      hospital: hospital,
      imageUrl: imageUrl,
      credentials: credentials ?? this.credentials,
      delayMinutes: delayMinutes ?? this.delayMinutes,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      officialDoctorId: officialDoctorId ?? this.officialDoctorId,
    );
  }
}




