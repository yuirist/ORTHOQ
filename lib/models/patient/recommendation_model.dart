import '../models/doctor_model.dart';

/// Result of rule-based symptom analysis and Firestore doctor lookup.
class SpecialistRecommendation {
  const SpecialistRecommendation({
    required this.isMatchFound,
    this.doctor,
    this.displaySpecialization,
    this.firestoreSpecialization,
    this.reason,
    required this.symptoms,
  });

  /// Keyword match succeeded and a specialization was determined.
  final bool isMatchFound;

  /// Recommended doctor from Firestore (null if none active for that specialty).
  final DoctorModel? doctor;

  /// Short label shown in UI, e.g. "Hand Surgeon".
  final String? displaySpecialization;

  /// Exact Firestore `specialization` field value.
  final String? firestoreSpecialization;

  /// Human-readable reason for the recommendation.
  final String? reason;

  /// Original symptom text supplied by the patient.
  final String symptoms;

  static const String noMatchMessage =
      'We are unable to determine the most suitable specialist based on the '
      'symptoms provided. Please contact the clinic for further assistance.';

  static const String disclaimer =
      'Please note that this recommendation is not a medical diagnosis and is '
      'intended only to assist in selecting an orthopaedic specialist.';

  /// Formats the recommendation for the AI Assistant chat bubble.
  String formatForChat() {
    if (!isMatchFound) return noMatchMessage;

    final buffer = StringBuffer(
      'Based on the symptoms you described, we recommend:\n\n',
    );

    if (doctor != null) {
      buffer.writeln('Doctor:\n${_formatDoctorName(doctor!.name)}');
    } else {
      buffer.writeln('Doctor:\nNo specialist currently available for this category.');
    }

    buffer.writeln('\nSpecialization:\n$displaySpecialization');
    buffer.writeln('\nReason:\n$reason');
    buffer.writeln('\n$disclaimer');

    return buffer.toString();
  }

  String _formatDoctorName(String name) {
    final trimmed = name.trim();
    if (trimmed.toLowerCase().startsWith('dr')) return trimmed;
    return 'Dr. $trimmed';
  }
}

/// Internal score for keyword matching per orthopaedic category.
class SymptomCategoryScore {
  const SymptomCategoryScore({
    required this.displaySpecialization,
    required this.firestoreSpecialization,
    required this.reason,
    required this.score,
  });

  final String displaySpecialization;
  final String firestoreSpecialization;
  final String reason;
  final int score;
}
