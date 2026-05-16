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

  // Doctor-specific fields
  final String? specialization;
  final String? doctorId;
  final String? staffId;
  /// Doctor document IDs this staff member may work with (set by admin; max 3).
  final List<String> assignedDoctorIds;

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
    this.specialization,
    this.doctorId,
    this.staffId,
    this.assignedDoctorIds = const [],
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'icNumber': icNumber,
      if (homeAddress != null) 'homeAddress': homeAddress,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      if (specialization != null) 'specialization': specialization,
      if (doctorId != null) 'doctorId': doctorId,
      if (staffId != null) 'staffId': staffId,
      if (assignedDoctorIds.isNotEmpty) 'assignedDoctorIds': assignedDoctorIds,
    };
  }

  // Create from Firestore document
  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      icNumber: map['icNumber']?.toString(),
      homeAddress: map['homeAddress']?.toString(),
      role: map['role'] ?? 'patient',
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
      specialization: map['specialization'],
      doctorId: map['doctorId'],
      staffId: map['staffId'],
      assignedDoctorIds: _parseAssignedDoctorIds(map['assignedDoctorIds']),
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

  // Copy with method for updates
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
    );
  }
}
















