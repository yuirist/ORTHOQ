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
      'createdAt': createdAt.toIso8601String(),
      if (appointmentId != null) 'appointmentId': appointmentId,
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      type: map['type'] ?? '',
      isRead: map['isRead'] ?? false,
      createdAt: DateTime.parse(map['createdAt']),
      appointmentId: map['appointmentId'],
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
















