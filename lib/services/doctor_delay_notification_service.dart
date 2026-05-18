import 'package:cloud_firestore/cloud_firestore.dart';

/// Real-time pending doctor delay alerts for staff navigation badges.
abstract final class DoctorDelayNotificationService {
  static const String collection = 'doctor_delays';
  static const String pendingStatus = 'pending_staff_action';

  /// Live stream of delay documents awaiting staff action.
  ///
  /// Requires a Firestore composite index:
  /// `doctor_delays`: `status` ASC, `createdAt` DESC
  /// (create via the link in the debug console if queries fail).
  static Stream<QuerySnapshot<Map<String, dynamic>>>
      getPendingDoctorDelaysStream() {
    return FirebaseFirestore.instance
        .collection(collection)
        .where('status', isEqualTo: pendingStatus)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Count-only stream (no ordering) — optional fallback if index is missing.
  static Stream<QuerySnapshot<Map<String, dynamic>>>
      getPendingDoctorDelaysCountStream() {
    return FirebaseFirestore.instance
        .collection(collection)
        .where('status', isEqualTo: pendingStatus)
        .snapshots();
  }

  static int pendingCount(QuerySnapshot<Object?> snapshot) =>
      snapshot.docs.length;
}
