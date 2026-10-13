class Doctor {
  final String name;
  final String specialty;
  final String credentials;
  final Map<String, String> clinicSchedule;

  const Doctor({
    required this.name,
    required this.specialty,
    required this.credentials,
    required this.clinicSchedule,
  });

  static const Map<String, Doctor> predefinedByName = {
    'DR JAMAL BIN KASSIM': Doctor(
      name: 'DR JAMAL BIN KASSIM',
      specialty: 'Orthopaedic (Hand Surgeon)',
      credentials: 'MBBCh (Ain Shams Uni), M.Med (Ortho) (USM)',
      clinicSchedule: {'MON - SAT': '8.00 AM - 12.00 PM'},
    ),
    'DR SITI MAIMUNAH BINTI AHMAD': Doctor(
      name: 'DR SITI MAIMUNAH BINTI AHMAD',
      specialty: 'Orthopaedic (Spine Surgery)',
      credentials:
          'MD (UKM), MS ORTH (UKM), Fellow in Hand Surgery (Singapore)',
      clinicSchedule: {'MON - SAT': '8.00 AM - 12.00 PM'},
    ),
    'DR HALIM BIN TONGKOL': Doctor(
      name: 'DR HALIM BIN TONGKOL',
      specialty: 'Orthopaedic (Foot and Ankle)',
      credentials: 'MBBS (Monash), MS Ortho (UM), CMIA(NIOSH)',
      clinicSchedule: {'MON - SAT': '8.00 AM - 12.00 PM'},
    ),
  };

  factory Doctor.fromSelection({
    required String name,
    required String specialty,
  }) {
    final normalizedName = name.trim().toUpperCase();
    final predefined = predefinedByName[normalizedName];
    if (predefined != null) {
      return predefined;
    }

    return Doctor(
      name: name.trim().isEmpty ? 'UNKNOWN DOCTOR' : name.trim().toUpperCase(),
      specialty: specialty.trim().isEmpty ? 'Orthopaedic' : specialty.trim(),
      credentials: 'Credentials will be updated soon.',
      clinicSchedule: const {'MON - SAT': '8.00 AM - 12.00 PM'},
    );
  }
}
