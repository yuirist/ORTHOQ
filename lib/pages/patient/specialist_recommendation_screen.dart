import 'package:flutter/material.dart';

import '../../models/doctor_model.dart';
import '../../models/recommendation_model.dart';
import '../../services/doctor_recommendation_service.dart';
import '../../theme/orthoq_colors.dart';
import '../../theme/orthoq_typography.dart';
import '../../theme/orthoq_widgets.dart';
import 'book_appointment_screen.dart';

/// Symptom-based orthopaedic specialist recommendation screen.
class SpecialistRecommendationScreen extends StatefulWidget {
  const SpecialistRecommendationScreen({super.key});

  @override
  State<SpecialistRecommendationScreen> createState() =>
      _SpecialistRecommendationScreenState();
}

class _SpecialistRecommendationScreenState
    extends State<SpecialistRecommendationScreen> {
  final _symptomController = TextEditingController();
  final _recommendationService = DoctorRecommendationService();

  SpecialistRecommendation? _result;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _symptomController.dispose();
    super.dispose();
  }

  /// Runs keyword matching and Firestore doctor lookup.
  Future<void> _findSpecialist() async {
    final symptoms = _symptomController.text.trim();
    if (symptoms.isEmpty) {
      setState(() {
        _errorMessage = 'Please describe your symptoms before searching.';
        _result = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final recommendation =
          await _recommendationService.recommendFromSymptoms(symptoms);
      if (!mounted) return;
      setState(() => _result = recommendation);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Unable to load a recommendation. Please check your connection and try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Opens booking with a matching specialist pre-selected.
  void _bookDoctor(DoctorModel doctor, String specialization) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookAppointmentScreen(
          preselectedDoctorId: doctor.id,
          preselectedDoctorName: doctor.name,
          preselectedSpecialization: specialization,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OrthoqColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('AI Specialist Recommendation'),
        backgroundColor: OrthoqColors.navy,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: OrthoqSpacing.screen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Find The Right Orthopaedic Specialist',
                style: OrthoqTypography.headingMedium(),
              ),
              const SizedBox(height: OrthoqSpacing.xs),
              Text(
                'Describe your symptoms and we will recommend the most suitable doctor.',
                style: OrthoqTypography.bodyMedium(
                  color: OrthoqColors.textSecondary,
                ),
              ),
              const SizedBox(height: OrthoqSpacing.lg),
              TextField(
                controller: _symptomController,
                minLines: 4,
                maxLines: 6,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _findSpecialist(),
                decoration: InputDecoration(
                  hintText:
                      'Example:\n"My hand hurts after a fall"\n"I have back pain"\n"My ankle is swollen"',
                  hintStyle: OrthoqTypography.bodyMedium(
                    color: OrthoqColors.textSecondary.withValues(alpha: 0.7),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: OrthoqColors.navy.withValues(alpha: 0.12),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: OrthoqColors.navy.withValues(alpha: 0.12),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: OrthoqColors.navy, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: OrthoqSpacing.md),
              FilledButton.icon(
                onPressed: _isLoading ? null : _findSpecialist,
                icon: _isLoading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      )
                    : const Icon(Icons.search_rounded),
                label: Text(_isLoading ? 'Finding Specialist…' : 'Find Specialist'),
                style: FilledButton.styleFrom(
                  backgroundColor: OrthoqColors.navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: OrthoqSpacing.md),
                _InfoBanner(
                  message: _errorMessage!,
                  icon: Icons.error_outline_rounded,
                  color: Colors.red.shade700,
                  background: Colors.red.shade50,
                ),
              ],
              if (_result != null) ...[
                const SizedBox(height: OrthoqSpacing.lg),
                _ResultSection(
                  result: _result!,
                  recommendationService: _recommendationService,
                  onBookDoctor: (doctor) {
                    final spec = _result!.firestoreSpecialization;
                    if (spec == null) return;
                    _bookDoctor(doctor, spec);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({
    required this.result,
    required this.recommendationService,
    required this.onBookDoctor,
  });

  final SpecialistRecommendation result;
  final DoctorRecommendationService recommendationService;
  final void Function(DoctorModel doctor) onBookDoctor;

  @override
  Widget build(BuildContext context) {
    if (!result.isMatchFound) {
      return _InfoBanner(
        message: SpecialistRecommendation.noMatchMessage,
        icon: Icons.info_outline_rounded,
        color: OrthoqColors.navy,
        background: OrthoqColors.navy.withValues(alpha: 0.06),
      );
    }

    final firestoreSpec = result.firestoreSpecialization;
    if (firestoreSpec == null || firestoreSpec.isEmpty) {
      return _InfoBanner(
        message: SpecialistRecommendation.noMatchMessage,
        icon: Icons.info_outline_rounded,
        color: OrthoqColors.navy,
        background: OrthoqColors.navy.withValues(alpha: 0.06),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Recommendation', style: OrthoqTypography.sectionTitle()),
        const SizedBox(height: OrthoqSpacing.sm),
        OrthoqInteractiveCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(OrthoqSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ResultRow(
                label: 'Specialization',
                value: result.displaySpecialization ?? '—',
              ),
              const SizedBox(height: OrthoqSpacing.sm),
              _ResultRow(
                label: 'Reason',
                value: result.reason ?? '—',
              ),
            ],
          ),
        ),
        const SizedBox(height: OrthoqSpacing.md),
        StreamBuilder<List<DoctorModel>>(
          stream: recommendationService.watchMatchingDoctors(firestoreSpec),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return _InfoBanner(
                message:
                    'Could not load matching specialists. Please try again.',
                icon: Icons.error_outline_rounded,
                color: Colors.red.shade700,
                background: Colors.red.shade50,
              );
            }

            final doctors = snapshot.data ?? const <DoctorModel>[];

            if (doctors.isEmpty) {
              return _InfoBanner(
                message:
                    'No specialist is currently available for this category. '
                    'Please contact the clinic for assistance.',
                icon: Icons.info_outline_rounded,
                color: OrthoqColors.navy,
                background: OrthoqColors.navy.withValues(alpha: 0.06),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: doctors.length,
              itemBuilder: (context, index) {
                final doctor = doctors[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < doctors.length - 1 ? OrthoqSpacing.md : 0,
                  ),
                  child: _RecommendedDoctorCard(
                    doctor: doctor,
                    specialization: result.displaySpecialization ?? '',
                    onBook: () => onBookDoctor(doctor),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: OrthoqSpacing.sm),
        _InfoBanner(
          message: SpecialistRecommendation.disclaimer,
          icon: Icons.medical_information_outlined,
          color: OrthoqColors.textSecondary,
          background: OrthoqColors.inputFill,
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: OrthoqTypography.bodySmall(color: OrthoqColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(value, style: OrthoqTypography.bodyMedium()),
      ],
    );
  }
}

class _RecommendedDoctorCard extends StatelessWidget {
  const _RecommendedDoctorCard({
    required this.doctor,
    required this.specialization,
    required this.onBook,
  });

  final DoctorModel doctor;
  final String specialization;
  final VoidCallback? onBook;

  String get _displayName {
    final name = doctor.name.trim();
    if (name.toLowerCase().startsWith('dr')) return name;
    return 'Dr. $name';
  }

  @override
  Widget build(BuildContext context) {
    return OrthoqInteractiveCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(OrthoqSpacing.md),
      child: Column(
        children: [
          Row(
            children: [
              _DoctorAvatar(imageUrl: doctor.imageUrl),
              const SizedBox(width: OrthoqSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName,
                      style: OrthoqTypography.sectionTitle(),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      specialization,
                      style: OrthoqTypography.bodyMedium(
                        color: OrthoqColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          doctor.isActive
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          size: 16,
                          color:
                              doctor.isActive ? Colors.green.shade700 : Colors.red,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          doctor.isActive ? 'Available' : 'Not available',
                          style: OrthoqTypography.bodySmall(
                            color: doctor.isActive
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: OrthoqSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onBook,
              icon: const Icon(Icons.calendar_month_rounded),
              label: const Text('Book Appointment'),
              style: FilledButton.styleFrom(
                backgroundColor: OrthoqColors.navy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorAvatar extends StatelessWidget {
  const _DoctorAvatar({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    const radius = 32.0;
    final url = imageUrl?.trim();

    if (url == null || url.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: OrthoqColors.navy.withValues(alpha: 0.08),
        child: const Icon(Icons.person_rounded, color: OrthoqColors.navy, size: 34),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: OrthoqColors.navy.withValues(alpha: 0.08),
      child: ClipOval(
        child: Image.network(
          url,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.person_rounded,
            color: OrthoqColors.navy,
            size: 34,
          ),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.message,
    required this.icon,
    required this.color,
    required this.background,
  });

  final String message;
  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(OrthoqSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: OrthoqSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: OrthoqTypography.bodyMedium(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
