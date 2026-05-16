import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../screens/admin/admin_home_screen.dart';
import '../screens/doctor/doctor_home_screen.dart';
import '../screens/patient/patient_home_screen.dart';
import '../screens/staff/staff_home_screen.dart';

/// Normalizes Firestore `role` values.
String normalizeRole(String? role) {
  return role?.toLowerCase().trim() ?? 'patient';
}

bool isKnownClinicRole(String? role) {
  switch (normalizeRole(role)) {
    case 'patient':
    case 'doctor':
    case 'staff':
    case 'admin':
      return true;
    default:
      return false;
  }
}

bool isStaffOrAdminPortal(String loginUserType) {
  final t = loginUserType.toLowerCase();
  return t == 'staff' || t == 'admin';
}

bool isStaffOrAdminRole(String? role) {
  final r = normalizeRole(role);
  return r == 'staff' || r == 'admin';
}

String roleDashboardName(String role) {
  switch (normalizeRole(role)) {
    case 'doctor':
      return 'Doctor';
    case 'staff':
      return 'Staff';
    case 'admin':
      return 'Admin';
    case 'patient':
    default:
      return 'Patient';
  }
}

/// Ensures profile [id] matches Firebase [uid] before passing to home screens.
UserModel profileForUid(String uid, UserModel userData) {
  if (userData.id == uid) return userData;
  return UserModel(
    id: uid,
    fullName: userData.fullName,
    email: userData.email,
    phoneNumber: userData.phoneNumber,
    icNumber: userData.icNumber,
    homeAddress: userData.homeAddress,
    role: userData.role,
    createdAt: userData.createdAt,
    updatedAt: userData.updatedAt,
    joiningDate: userData.joiningDate,
    specialization: userData.specialization,
    doctorId: userData.doctorId,
    staffId: userData.staffId,
    assignedDoctorIds: userData.assignedDoctorIds,
  );
}

/// Ensures a [UserModel] exists for navigation.
UserModel ensureUserProfile({
  required User user,
  UserModel? profile,
  String fallbackRole = 'patient',
}) {
  if (profile != null) {
    return profileForUid(user.uid, profile);
  }
  return UserModel(
    id: user.uid,
    fullName: user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : 'User',
    email: user.email ?? '',
    phoneNumber: '',
    role: fallbackRole,
    createdAt: DateTime.now(),
  );
}

Widget patientDashboard({
  required String uid,
  required UserModel userData,
}) =>
    PatientHomeScreen(userProfile: profileForUid(uid, userData));

Widget doctorDashboard({
  required String uid,
  required UserModel userData,
}) =>
    DoctorHomeScreen(userProfile: profileForUid(uid, userData));

/// Staff home — requires resolved [userData] (and matching [uid]).
Widget staffHomeScreen({
  required String uid,
  required UserModel userData,
}) {
  final profile = profileForUid(uid, userData);
  return StaffHomeScreen(userProfile: profile);
}

/// Admin home — requires [uid] and [userData] for session display.
Widget adminHomeScreen({
  required String uid,
  required UserModel userData,
}) {
  final profile = profileForUid(uid, userData);
  return AdminHomeScreen(uid: uid, userProfile: profile);
}

/// Builds the correct home screen from Firestore [userData.role].
Widget homeScreenForRole(
  String role, {
  required String uid,
  required UserModel userData,
}) {
  final resolved = profileForUid(uid, userData);
  switch (normalizeRole(role)) {
    case 'doctor':
      return doctorDashboard(uid: uid, userData: resolved);
    case 'admin':
      return adminHomeScreen(uid: uid, userData: resolved);
    case 'staff':
      return staffHomeScreen(uid: uid, userData: resolved);
    case 'patient':
    default:
      return patientDashboard(uid: uid, userData: resolved);
  }
}

/// Navigate using Firestore [userData.role].
Future<void> navigateAfterLogin({
  required BuildContext context,
  required User user,
  required UserModel profile,
  String? loginPortal,
}) async {
  final role = normalizeRole(profile.role);
  debugPrint('[Role Check] navigateAfterLogin role=$role portal=$loginPortal');

  if (!isKnownClinicRole(role)) {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unknown role "$role". Contact support.'),
          backgroundColor: Colors.red,
        ),
      );
    }
    return;
  }

  final portal = loginPortal != null ? normalizeRole(loginPortal) : null;
  if (portal == 'admin' && role != 'admin') {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Access denied. Your Firestore role is not administrator.',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
    return;
  }

  if (context.mounted && portal != null && portal != role) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Your account is registered as $role. '
          'Opening the ${roleDashboardName(role)} dashboard.',
        ),
        backgroundColor: const Color(0xFF1B3C68),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  final resolved = ensureUserProfile(
    user: user,
    profile: profile,
    fallbackRole: role,
  );

  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (_) => homeScreenForRole(
        role,
        uid: user.uid,
        userData: resolved,
      ),
    ),
    (route) => false,
  );
}
