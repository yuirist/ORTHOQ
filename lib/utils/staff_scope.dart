/// Staff dashboard / verification: doctors assigned to the signed-in staff user.
class StaffScope {
  StaffScope._();

  /// Reads `assignedDoctorIds` from a Firestore `users/{uid}` document map.
  static List<String> assignedDoctorIds(Map<String, dynamic>? userData) {
    if (userData == null) return [];
    final raw = userData['assignedDoctorIds'];
    if (raw is! List) return [];
    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static bool appointmentDoctorAllowed(
    Map<String, dynamic> appointmentData,
    List<String> assignedDoctorIds,
  ) {
    if (assignedDoctorIds.isEmpty) return false;
    final id = appointmentData['doctorId']?.toString().trim() ?? '';
    return id.isNotEmpty && assignedDoctorIds.contains(id);
  }

  static bool rescheduleDoctorAllowed(
    Map<String, dynamic> requestData,
    List<String> assignedDoctorIds,
  ) {
    if (assignedDoctorIds.isEmpty) return false;
    final id = requestData['doctorId']?.toString().trim() ?? '';
    if (id.isNotEmpty && assignedDoctorIds.contains(id)) return true;
    return false;
  }
}
