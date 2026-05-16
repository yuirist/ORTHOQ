import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/firestore_date_utils.dart';

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type; // 'appointment_confirmed', 'rescheduled', 'cancelled', 'schedule_change'
  final bool isRead;
  final DateTime createdAt;
  final String? appointmentId;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.isRead = false,
    required this.createdAt,
    this.appointmentId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      if (appointmentId != null) 'appointmentId': appointmentId,
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      id: id,
      userId: map['userId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
      type: map['type']?.toString() ?? '',
      isRead: map['isRead'] == true,
      createdAt: parseFirestoreDateTime(map['createdAt']),
      appointmentId: map['appointmentId']?.toString(),
    );
  }

  NotificationModel copyWith({
    bool? isRead,
  }) {
    return NotificationModel(
      id: id,
      userId: userId,
      title: title,
      message: message,
      type: type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      appointmentId: appointmentId,
    );
  }
}
