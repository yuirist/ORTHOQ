import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';

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

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key, this.userProfile});

  final UserModel? userProfile;

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OrthoqColors.scaffoldBg,
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          _HomeTab(),
          BookAppointmentScreen(),
          MyAppointmentsScreen(),
          PatientProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).bottomNavigationBarTheme.selectedItemColor,
        unselectedItemColor:
            Theme.of(context).bottomNavigationBarTheme.unselectedItemColor,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Book',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_note_outlined),
            activeIcon: Icon(Icons.event_note),
            label: 'Appointments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userId = authProvider.currentUser?.uid ?? '';
    final appointmentService = AppointmentService();
    final userFullName = authProvider.currentUserData?.fullName ?? 'Patient';

    return Scaffold(
      backgroundColor: OrthoqColors.scaffoldBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        toolbarHeight: 96,
        title: SizedBox(
          height: 96,
          child: Center(
            child: Image.asset(
              'assets/images/LOGO ORTHOQ.png',
              height: 78,
              fit: BoxFit.contain,
            ),
          ),
        ),
        backgroundColor: OrthoqColors.slateNavy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome,',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userFullName,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: OrthoqColors.slateNavy,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Category',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (context) => const AllCategoriesPage(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Text(
                        'See All',
                        style: TextStyle(
                          color: OrthoqColors.techBlue,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _CategoryButton(
                    icon: Icons.medical_services,
                    label: 'Hand Surgeon',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FilteredDoctorsPage(
                            selectedCategory: 'Orthopaedic (Hand Surgeon)',
                          ),
                        ),
                      );
                    },
                  ),
                  _CategoryButton(
                    icon: Icons.healing,
                    label: 'Spine Surgery',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FilteredDoctorsPage(
                            selectedCategory: 'Orthopaedic (Spine Surgery)',
                          ),
                        ),
                      );
                    },
                  ),
                  _CategoryButton(
                    icon: Icons.directions_walk,
                    label: 'Foot and Ankle',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FilteredDoctorsPage(
                            selectedCategory: 'Orthopaedic (Foot & Ankle)',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                'Next Visit',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                ),
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<AppointmentModel>>(
              stream: appointmentService.getUpcomingPatientAppointments(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: OrthoqColors.techBlue,
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Center(child: Text('Error: ${snapshot.error}')),
                  );
                }

                final appointments = snapshot.data ?? [];

                if (appointments.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Card(
                      color: OrthoqColors.slateNavy,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.calendar_today,
                                  size: 64, color: Colors.white),
                              SizedBox(height: 16),
                              Text(
                                'No upcoming appointments',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Book an appointment to get started',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }

                final nextAppointment = appointments.first;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: _NextVisitCard(appointment: nextAppointment),
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: OrthoqColors.lightSlate),
          boxShadow: [
            BoxShadow(
              color: OrthoqColors.slateNavy.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: OrthoqColors.techBlue),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: OrthoqColors.slateNavy,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NextVisitCard extends StatelessWidget {
  const _NextVisitCard({required this.appointment});

  final AppointmentModel appointment;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: OrthoqColors.slateNavy,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 30, color: OrthoqColors.techBlue),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dr. ${appointment.doctorName}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        appointment.appointmentType == 'new_patient'
                            ? 'New Patient Appointment'
                            : 'Follow-Up Appointment',
                        style: const TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: OrthoqColors.scaffoldBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.calendar_today,
                                size: 16, color: OrthoqColors.slateNavy),
                            SizedBox(width: 8),
                            Text(
                              'Date',
                              style: TextStyle(
                                fontSize: 12,
                                color: OrthoqColors.slateNavy,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('d MMMM y').format(appointment.appointmentDate),
                          style: const TextStyle(
                            fontSize: 14,
                            color: OrthoqColors.slateNavy,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: OrthoqColors.scaffoldBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.access_time,
                                size: 16, color: OrthoqColors.slateNavy),
                            SizedBox(width: 8),
                            Text(
                              'Time',
                              style: TextStyle(
                                fontSize: 12,
                                color: OrthoqColors.slateNavy,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          appointment.appointmentTime,
                          style: const TextStyle(
                            fontSize: 14,
                            color: OrthoqColors.slateNavy,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AppointmentDetailsScreen(
                        appointment: appointment,
                      ),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  backgroundColor: OrthoqColors.techBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'See Details',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
