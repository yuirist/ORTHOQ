import 'package:cloud_firestore/cloud_firestore.dart';

/// Helper class to check slot availability for a given date and doctor
class SlotAvailabilityChecker {
  /// Get a stream of booked time slots for a specific date and doctor
  /// This listens in real-time to prevent double-booking
  /// Uses 3-field query (doctorId, status, appointmentDate) since we need all times for the day
  static Stream<List<String>> getBookedSlots({
    required DateTime selectedDate,
    required String doctorId,
    String? excludeAppointmentId, // For rescheduling - exclude current appointment
  }) {
    // Normalize selectedDate to start of day (midnight) for exact date matching
    final normalizedDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final startOfDay = normalizedDate;
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Query for all confirmed appointments for the selected date and doctor
    // Note: We query by doctorId, status, appointmentDate (3 fields) to get all times for the day
    // The 4-field index (appointmentTime, doctorId, status, appointmentDate) is used for specific time checks
    Query query = FirebaseFirestore.instance
        .collection('appointments')
        .where('doctorId', isEqualTo: doctorId)
        .where('status', isEqualTo: 'confirmed')
        .where('appointmentDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('appointmentDate', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('appointmentDate');

    // Return a stream that updates in real-time
    return query.snapshots().map((snapshot) {
      final bookedSlots = <String>[];
      
      for (var doc in snapshot.docs) {
        // Skip the appointment being rescheduled (prevents self-conflict)
        if (excludeAppointmentId != null && doc.id == excludeAppointmentId) {
          continue;
        }
        
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          final appointmentTime = data['appointmentTime']?.toString();
          if (appointmentTime != null && appointmentTime.isNotEmpty) {
            bookedSlots.add(appointmentTime);
          }
        }
      }
      
      return bookedSlots;
    });
  }

  /// Check if a specific time slot is available (synchronous check before saving)
  /// Uses 4-field composite index: appointmentTime, doctorId, status, appointmentDate
  static Future<bool> isSlotAvailable({
    required DateTime selectedDate,
    required String doctorId,
    required String timeString,
    String? excludeAppointmentId,
  }) async {
    // Normalize selectedDate to start of day (midnight) for exact date matching
    final normalizedDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final startOfDay = normalizedDate;
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Query using 4-field composite index in exact order: appointmentTime, doctorId, status, appointmentDate
    // Note: Firestore requires isLessThan (not isLessThanOrEqualTo) for range queries
    Query query = FirebaseFirestore.instance
        .collection('appointments')
        .where('appointmentTime', isEqualTo: timeString)
        .where('doctorId', isEqualTo: doctorId)
        .where('status', isEqualTo: 'confirmed')
        .where('appointmentDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('appointmentDate', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('appointmentDate');

    final snapshot = await query.get();
    
    // Check if any conflicting appointments exist (excluding the one being rescheduled)
    if (excludeAppointmentId != null) {
      for (var doc in snapshot.docs) {
        if (doc.id != excludeAppointmentId) {
          return false; // Found a conflict
        }
      }
      return true; // Only the excluded appointment exists
    }
    
    // No conflicts found
    return snapshot.docs.isEmpty;
  }
}

