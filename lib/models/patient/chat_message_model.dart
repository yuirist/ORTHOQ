import 'package:cloud_firestore/cloud_firestore.dart';

enum ChatSender { user, assistant }

class ChatMessageModel {
  const ChatMessageModel({
    required this.messageId,
    required this.userId,
    required this.sender,
    required this.message,
    required this.timestamp,
  });

  final String messageId;
  final String userId;
  final ChatSender sender;
  final String message;
  final DateTime timestamp;

  bool get isUser => sender == ChatSender.user;

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'userId': userId,
      'sender': sender.name,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory ChatMessageModel.fromMap(Map<String, dynamic> map, String docId) {
    final rawSender = map['sender']?.toString() ?? 'user';
    return ChatMessageModel(
      messageId: map['messageId']?.toString() ?? docId,
      userId: map['userId']?.toString() ?? '',
      sender: rawSender == 'assistant' ? ChatSender.assistant : ChatSender.user,
      message: map['message']?.toString() ?? '',
      timestamp: _parseTimestamp(map['timestamp']),
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}
