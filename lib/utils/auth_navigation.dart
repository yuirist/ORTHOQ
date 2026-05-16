import 'package:flutter/material.dart';

import '../screens/admin/admin_dashboard.dart';
import '../screens/doctor/doctor_home_screen.dart';
import '../screens/patient/patient_home_screen.dart';
import '../screens/staff/staff_home_screen.dart';

/// Home screen for a Firestore `users.role` value after Firebase Auth sign-in.
Widget homeScreenForRole(String role) {
  switch (role.toLowerCase()) {
    case 'doctor':
      return const DoctorHomeScreen();
    case 'admin':
      return const AdminDashboard();
    case 'staff':
      return const StaffHomeScreen();
    case 'patient':
    default:
      return const PatientHomeScreen();
  }
}

/// Whether [actualRole] is allowed for a login entry point labeled [expectedUserType].
bool roleMatchesLoginType(String expectedUserType, String actualRole) {
  final expected = expectedUserType.toLowerCase();
  final actual = actualRole.toLowerCase();
  if (expected == 'staff') {
    return actual == 'staff' || actual == 'admin';
  }
  return actual == expected;
}
