/// Rule-based keyword lists for orthopaedic specialist matching.
/// Supports English and common Malay terms used by patients at Hospital Kajang.
abstract final class SymptomKeywordData {
  static const handSurgeonKeywords = [
    'hand',
    'tangan',
    'finger',
    'jari',
    'thumb',
    'ibu jari',
    'wrist',
    'pergelangan tangan',
    'carpal',
    'palm',
    'tapak tangan',
  ];

  static const spineSurgeryKeywords = [
    'back pain',
    'belakang',
    'spine',
    'tulang belakang',
    'neck',
    'leher',
    'slipped disc',
    'scoliosis',
    'spinal',
    'lumbar',
    'cervical',
  ];

  static const footAnkleKeywords = [
    'foot',
    'kaki',
    'ankle',
    'buku lali',
    'heel',
    'tumit',
    'toe',
    'jari kaki',
    'plantar',
    'achilles',
  ];

  /// Words that suggest the patient is describing a symptom (not a general app question).
  static const symptomIndicators = [
    'hurt',
    'pain',
    'sakit',
    'ache',
    'aching',
    'swollen',
    'bengkak',
    'injury',
    'injured',
    'fall',
    'jatuh',
    'sprain',
    'strain',
    'fracture',
    'broken',
    'patah',
    'numb',
    'numbness',
    'stiff',
    'stiffness',
    'tingling',
    'cramp',
  ];

  static const handReason =
      'Your symptoms indicate a condition involving the hand, finger, wrist, or palm.';

  static const spineReason =
      'Your symptoms suggest a condition involving the back, neck, or spine.';

  static const footAnkleReason =
      'Your symptoms indicate a condition involving the foot, ankle, or heel.';
}
