import '../../models/user_model.dart';
import 'admin_home_screen.dart';

/// Legacy name for [AdminHomeScreen].
typedef AdminDashboard = AdminHomeScreen;

/// Builds admin home when only [userProfile] is available (infers [uid]).
AdminHomeScreen adminDashboardFromProfile({UserModel? userProfile}) {
  return AdminHomeScreen(
    uid: userProfile?.id ?? '',
    userProfile: userProfile,
  );
}
