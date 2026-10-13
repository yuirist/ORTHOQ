import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/firestore_date_utils.dart';

class DoctorModel {
  final String id;
  final String userId; // Reference to users collection
  final String name;
  final String specialization;
  final String email;
  final String phoneNumber;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? hospital;
  final String? imageUrl;
  final String? credentials;
  final int? delayMinutes; // Delay in minutes for the doctor

  DoctorModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.specialization,
    required this.email,
    required this.phoneNumber,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
    this.hospital,
    this.imageUrl,
    this.credentials,
    this.delayMinutes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'specialization': specialization,
      'email': email,
      'phoneNumber': phoneNumber,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt':
          updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      if (hospital != null) 'hospital': hospital,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (credentials != null && credentials!.isNotEmpty) 'credentials': credentials,
      if (delayMinutes != null) 'delayMinutes': delayMinutes,
    };
  }

  factory DoctorModel.fromMap(Map<String, dynamic> map, String id) {
    return DoctorModel(
      id: id,
      userId: map['userId']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Unknown Doctor',
      specialization: map['specialization']?.toString() ?? 'General Practitioner',
      email: map['email']?.toString() ?? '',
      phoneNumber: map['phoneNumber']?.toString() ?? '',
      isActive: map['isActive'] is bool ? map['isActive'] as bool : (map['isActive']?.toString().toLowerCase() == 'true' || map['isActive'] == true),
      createdAt: parseFirestoreDateTime(map['createdAt']),
      updatedAt: parseFirestoreDateTimeNullable(map['updatedAt']),
      hospital: map['hospital']?.toString(),
      imageUrl: map['imageUrl']?.toString(),
      credentials: map['credentials']?.toString() ??
          map['Credentials']?.toString(),
      delayMinutes: map['delayMinutes'] != null ? (map['delayMinutes'] is int ? map['delayMinutes'] as int : int.tryParse(map['delayMinutes'].toString())) : null,
    );
  }

  DoctorModel copyWith({
    String? name,
    String? specialization,
    String? email,
    String? phoneNumber,
    bool? isActive,
    DateTime? updatedAt,
    String? credentials,
    int? delayMinutes,
  }) {
    return DoctorModel(
      id: id,
      userId: userId,
      name: name ?? this.name,
      specialization: specialization ?? this.specialization,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      hospital: hospital,
      imageUrl: imageUrl,
      credentials: credentials ?? this.credentials,
      delayMinutes: delayMinutes ?? this.delayMinutes,
    );
  }
}




