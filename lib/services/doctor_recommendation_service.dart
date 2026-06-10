import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/symptom_keyword_data.dart';
import '../models/doctor_model.dart';
import '../models/recommendation_model.dart';

/// Rule-based AI service: keyword matching + Firestore doctor lookup.
class DoctorRecommendationService {
  DoctorRecommendationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const _handFirestoreSpec = 'Orthopaedic (Hand Surgeon)';
  static const _spineFirestoreSpec = 'Orthopaedic (Spine Surgery)';
  static const _footFirestoreSpec = 'Orthopaedic (Foot & Ankle)';

  /// Analyzes [symptomText], finds the best-matching specialization, and
  /// returns an active doctor from Firestore when available.
  Future<SpecialistRecommendation> recommendFromSymptoms(String symptomText) async {
    final trimmed = symptomText.trim();
    if (trimmed.isEmpty) {
      return SpecialistRecommendation(isMatchFound: false, symptoms: trimmed);
    }

    final normalized = trimmed.toLowerCase();
    final category = _determineCategory(normalized);

    if (category == null) {
      return SpecialistRecommendation(isMatchFound: false, symptoms: trimmed);
    }

    final doctor = await _fetchAvailableDoctor(category.firestoreSpecialization);

    return SpecialistRecommendation(
      isMatchFound: true,
      doctor: doctor,
      displaySpecialization: category.displaySpecialization,
      firestoreSpecialization: category.firestoreSpecialization,
      reason: category.reason,
      symptoms: trimmed,
    );
  }

  /// Returns true when the message appears to describe a physical symptom.
  bool looksLikeSymptomDescription(String message) {
    final normalized = message.toLowerCase();
    if (_hasCategoryKeywordMatch(normalized)) return true;
    return SymptomKeywordData.symptomIndicators.any(normalized.contains);
  }

  /// Determines whether the AI chat should attempt a specialist recommendation.
  bool shouldRecommendInChat(String message) {
    final normalized = message.toLowerCase();
    return _hasCategoryKeywordMatch(normalized) ||
        SymptomKeywordData.symptomIndicators.any(normalized.contains);
  }

  /// Scores each category by keyword hits and returns the highest match.
  SymptomCategoryScore? _determineCategory(String normalizedText) {
    final scores = <SymptomCategoryScore>[
      _scoreCategory(
        keywords: SymptomKeywordData.handSurgeonKeywords,
        displaySpecialization: 'Hand Surgeon',
        firestoreSpecialization: _handFirestoreSpec,
        reason: SymptomKeywordData.handReason,
        text: normalizedText,
      ),
      _scoreCategory(
        keywords: SymptomKeywordData.spineSurgeryKeywords,
        displaySpecialization: 'Spine Surgery',
        firestoreSpecialization: _spineFirestoreSpec,
        reason: SymptomKeywordData.spineReason,
        text: normalizedText,
      ),
      _scoreCategory(
        keywords: SymptomKeywordData.footAnkleKeywords,
        displaySpecialization: 'Foot & Ankle Surgery',
        firestoreSpecialization: _footFirestoreSpec,
        reason: SymptomKeywordData.footAnkleReason,
        text: normalizedText,
      ),
    ];

    scores.sort((a, b) => b.score.compareTo(a.score));
    final best = scores.first;
    return best.score > 0 ? best : null;
  }

  /// Counts keyword matches; longer keywords contribute more to reduce false positives.
  SymptomCategoryScore _scoreCategory({
    required List<String> keywords,
    required String displaySpecialization,
    required String firestoreSpecialization,
    required String reason,
    required String text,
  }) {
    var score = 0;
    for (final keyword in keywords) {
      if (text.contains(keyword.toLowerCase())) {
        score += keyword.length;
      }
    }
    return SymptomCategoryScore(
      displaySpecialization: displaySpecialization,
      firestoreSpecialization: firestoreSpecialization,
      reason: reason,
      score: score,
    );
  }

  bool _hasCategoryKeywordMatch(String normalizedText) {
    return _determineCategory(normalizedText) != null;
  }

  /// Queries Firestore for the first active doctor in the given specialization.
  Future<DoctorModel?> _fetchAvailableDoctor(String specialization) async {
    try {
      final snapshot = await _firestore
          .collection('doctors')
          .where('specialization', isEqualTo: specialization)
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      return DoctorModel.fromMap(doc.data(), doc.id);
    } catch (_) {
      // Fallback without composite index on isActive + specialization + name.
      final snapshot = await _firestore
          .collection('doctors')
          .where('specialization', isEqualTo: specialization)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final isActive = data['isActive'];
        final active = isActive is bool
            ? isActive
            : isActive?.toString().toLowerCase() != 'false';
        if (active) {
          return DoctorModel.fromMap(data, doc.id);
        }
      }
      return null;
    }
  }
}
