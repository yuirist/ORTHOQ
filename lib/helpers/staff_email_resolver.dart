import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Resolves staff email addresses for operational alerts (e.g. doctor delays).
class StaffEmailResolver {
  StaffEmailResolver({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Returns a deduplicated list of staff emails from:
  /// 1. All `users` documents with `role == 'staff'`
  /// 2. Staff whose `assignedDoctorIds` includes [doctorDocumentId]
  Future<List<String>> resolveDelayAlertRecipients({
    String? doctorDocumentId,
  }) async {
    final seen = <String>{};
    final recipients = <String>[];

    void addEmail(String? raw) {
      final email = raw?.trim();
      if (email == null || email.isEmpty) return;
      final key = email.toLowerCase();
      if (seen.add(key)) recipients.add(email);
    }

    try {
      final allStaffSnap = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'staff')
          .get();
      for (final doc in allStaffSnap.docs) {
        addEmail(doc.data()['email']?.toString());
      }
    } catch (e) {
      debugPrint('StaffEmailResolver: could not load all staff — $e');
    }

    final docId = doctorDocumentId?.trim();
    if (docId != null && docId.isNotEmpty) {
      try {
        final assignedSnap = await _firestore
            .collection('users')
            .where('role', isEqualTo: 'staff')
            .where('assignedDoctorIds', arrayContains: docId)
            .get();
        for (final doc in assignedSnap.docs) {
          addEmail(doc.data()['email']?.toString());
        }
      } catch (e) {
        debugPrint(
          'StaffEmailResolver: could not load assigned staff for $docId — $e',
        );
      }
    }

    return recipients;
  }
}
