import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat_message_model.dart';

class ChatStorageService {
  ChatStorageService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const _collection = 'chat_messages';

  Stream<List<ChatMessageModel>> watchMessages(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ChatMessageModel.fromMap(
                  doc.data(),
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  Future<ChatMessageModel> saveMessage({
    required String userId,
    required ChatSender sender,
    required String message,
  }) async {
    final docRef = _firestore.collection(_collection).doc();
    final model = ChatMessageModel(
      messageId: docRef.id,
      userId: userId,
      sender: sender,
      message: message,
      timestamp: DateTime.now(),
    );
    await docRef.set(model.toMap());
    return model;
  }

  Future<void> deleteAllForUser(String userId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
