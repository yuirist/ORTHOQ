import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';
import 'package:orthoq_app/theme/orthoq_navigation.dart';
import 'package:orthoq_app/theme/orthoq_typography.dart';
import 'package:orthoq_app/theme/orthoq_widgets.dart';

import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/appointment_service.dart';
import '../../models/appointment_model.dart';
import 'book_appointment_screen.dart';
import 'my_appointments_screen.dart';
import 'patient_profile_screen.dart';
import 'appointment_details_screen.dart';
import 'all_categories_page.dart';
import 'filtered_doctors_page.dart';
import 'ai_assistant_screen.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key, this.userProfile, this.initialTabIndex = 0});

  final UserModel? userProfile;
  final int initialTabIndex;

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex.clamp(0, 3);
  }

  Future<void> _openAiAssistant() async {
    final action = await openAiAssistant(context);
    if (action == null || !mounted) return;
    setState(() => _selectedIndex = tabIndexForQuickAction(action));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OrthoqColors.scaffoldBg,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _HomeTab(onOpenAiAssistant: _openAiAssistant),
          BookAppointmentScreen(),
          MyAppointmentsScreen(),
          PatientProfileScreen(),
        ],
      ),
      bottomNavigationBar: OrthoqModernBottomNav(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Book',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note_rounded),
            label: 'Visits',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.onOpenAiAssistant});

  static const Color _headerBlue = Color(0xFFEBF3FF);

  final VoidCallback onOpenAiAssistant;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userId = authProvider.currentUser?.uid ?? '';
    final appointmentService = AppointmentService();
    final userFullName = authProvider.currentUserData?.fullName ?? 'Patient';

    return Scaffold(
      backgroundColor: OrthoqColors.scaffoldBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: _headerBlue,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
            ),
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + 16,
              bottom: 20,
              left: 20,
              right: 20,
            ),
            child: Row(
              children: [
                const SizedBox(width: 48),
                Expanded(
                  child: Center(
                    child: Image.asset(
                      'assets/images/LOGOORTHOQ.png',
                      height: 75,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onOpenAiAssistant,
                  child: Tooltip(
                    message: 'AI Assistant',
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.smart_toy_outlined,
                            color: Color(0xFF1E3A8A),
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'AI Assistant',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome back', style: OrthoqTypography.bodyMedium()),
                        const SizedBox(height: 4),
                        Text(userFullName, style: OrthoqTypography.headingMedium()),
                      ],
                    ),
                  ),
            const SizedBox(height: OrthoqSpacing.sm),
            OrthoqSectionHeader(
              title: 'Specialties',
              actionLabel: 'See all',
              onAction: () {
                pushOrthoQPage(context, const AllCategoriesPage());
              },
            ),
            const SizedBox(height: OrthoqSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _CategoryButton(
                      icon: Icons.back_hand_outlined,
                      label: 'Hand',
                      onTap: () => pushOrthoQPage(
                        context,
                        const FilteredDoctorsPage(
                          selectedCategory: 'Orthopaedic (Hand Surgeon)',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: OrthoqSpacing.sm),
                  Expanded(
                    child: _CategoryButton(
                      icon: Icons.accessibility_new_rounded,
                      label: 'Spine',
                      onTap: () => pushOrthoQPage(
                        context,
                        const FilteredDoctorsPage(
                          selectedCategory: 'Orthopaedic (Spine Surgery)',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: OrthoqSpacing.sm),
                  Expanded(
                    child: _CategoryButton(
                      icon: Icons.directions_walk_rounded,
                      label: 'Foot & Ankle',
                      onTap: () => pushOrthoQPage(
                        context,
                        const FilteredDoctorsPage(
                          selectedCategory: 'Orthopaedic (Foot & Ankle)',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: OrthoqSpacing.lg),
            const OrthoqSectionHeader(title: 'Next visit'),
            const SizedBox(height: OrthoqSpacing.sm),
            StreamBuilder<List<AppointmentModel>>(
              stream: appointmentService.getUpcomingPatientAppointments(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: OrthoqSkeletonAppointmentCard(),
                  );
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: OrthoqSpacing.list,
                    child: Text(
                      'Unable to load appointments',
                      style: OrthoqTypography.bodyMedium(
                        color: Colors.red.shade700,
                      ),
                    ),
                  );
                }

                final appointments = snapshot.data ?? [];

                if (appointments.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: OrthoqInteractiveCard(
                      color: OrthoqColors.navy,
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_busy_rounded,
                            size: 48,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          const SizedBox(height: OrthoqSpacing.sm),
                          Text(
                            'No upcoming visits',
                            style: OrthoqTypography.sectionTitle(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: OrthoqSpacing.xs),
                          Text(
                            'Book an appointment with a specialist',
                            textAlign: TextAlign.center,
                            style: OrthoqTypography.bodyMedium(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _NextVisitCard(appointment: appointments.first),
                );
              },
            ),
            const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryButton extends StatelessWidget {
  const _CategoryButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OrthoqInteractiveCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: OrthoqColors.navy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 26, color: OrthoqColors.navy),
          ),
          const SizedBox(height: OrthoqSpacing.xs),
          Text(
            label,
            style: OrthoqTypography.bodySmall(color: OrthoqColors.navy),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _NextVisitCard extends StatelessWidget {
  const _NextVisitCard({required this.appointment});

  final AppointmentModel appointment;

  @override
  Widget build(BuildContext context) {
    return OrthoqInteractiveCard(
      margin: EdgeInsets.zero,
      color: OrthoqColors.navy,
      onTap: () {
        pushOrthoQPage(
          context,
          AppointmentDetailsScreen(appointment: appointment),
        );
      },
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                child: const Icon(Icons.medical_services_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: OrthoqSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dr. ${appointment.doctorName}',
                      style: OrthoqTypography.sectionTitle(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appointment.appointmentType == 'new_patient'
                          ? 'New patient visit'
                          : 'Follow-up visit',
                      style: OrthoqTypography.bodySmall(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ],
          ),
          const SizedBox(height: OrthoqSpacing.md),
          Row(
            children: [
              Expanded(
                child: _VisitInfoChip(
                  icon: Icons.calendar_today_rounded,
                  label: DateFormat('d MMM y').format(appointment.appointmentDate),
                ),
              ),
              const SizedBox(width: OrthoqSpacing.sm),
              Expanded(
                child: _VisitInfoChip(
                  icon: Icons.schedule_rounded,
                  label: appointment.appointmentTime,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VisitInfoChip extends StatelessWidget {
  const _VisitInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: OrthoqTypography.bodySmall(color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
