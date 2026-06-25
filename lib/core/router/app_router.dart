import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import '../storage/secure_storage.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/role_select_screen.dart';
import '../../features/auth/screens/patient_register_screen.dart';
import '../../features/auth/screens/driver_register_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/medical_profile_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/driver/screens/driver_home_screen.dart';
import '../../features/driver/screens/driver_navigation_screen.dart';
import '../../features/sos/screens/tracking_screen.dart';
import '../../features/sos/screens/no_driver_screen.dart';
import '../../features/ai_report/screens/ai_report_screen.dart';
import '../../features/offline_sos/screens/offline_sos_screen.dart';

/// Centralized route paths.
class Routes {
  Routes._();
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String roleSelect = '/role-select';
  static const String patientRegister = '/register/patient';
  static const String driverRegister = '/register/driver';
  static const String login = '/login';
  static const String medicalProfile = '/medical-profile';
  static const String home = '/home';
  static const String tracking = '/tracking';
  static const String noDriver = '/no-driver';
  static const String driverHome = '/driver-home';
  static const String driverNavigation = '/driver-navigation';
  static const String aiReport = '/ai-report';
  static const String offlineSos = '/offline-sos';
}

// Routes reachable without being authenticated.
const Set<String> _publicRoutes = {
  Routes.splash,
  Routes.onboarding,
  Routes.roleSelect,
  Routes.login,
  Routes.patientRegister,
  Routes.driverRegister,
};

// Fade + scale transition applied to every route.
CustomTransitionPage<void> _page(Widget child) {
  return CustomTransitionPage<void>(
    transitionDuration: const Duration(milliseconds: 280),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      );
    },
  );
}

Future<String?> _storedRole() async {
  final data = await SecureStorage.getUserData();
  if (data == null) return null;
  try {
    return (jsonDecode(data) as Map<String, dynamic>)['role']?.toString();
  } catch (_) {
    return null;
  }
}

final appRouter = GoRouter(
  initialLocation: Routes.splash,
  // Auth guard reads SecureStorage directly (not the provider) to avoid
  // rebuild loops during navigation.
  redirect: (context, state) async {
    final token = await SecureStorage.getToken();
    bool loggedIn = false;
    if (token != null && token.isNotEmpty) {
      try {
        loggedIn = !JwtDecoder.isExpired(token);
      } catch (_) {
        loggedIn = false;
      }
    }

    final loc = state.matchedLocation;

    // Logged out on a protected route → role select.
    if (!loggedIn && !_publicRoutes.contains(loc)) {
      return Routes.roleSelect;
    }

    // Logged in but on a login/register page → role-appropriate home.
    if (loggedIn &&
        (loc == Routes.login ||
            loc == Routes.patientRegister ||
            loc == Routes.driverRegister)) {
      final role = await _storedRole();
      return role == 'driver' ? Routes.driverHome : Routes.home;
    }

    return null;
  },
  routes: [
    GoRoute(path: Routes.splash, pageBuilder: (c, s) => _page(const SplashScreen())),
    GoRoute(path: Routes.onboarding, pageBuilder: (c, s) => _page(const OnboardingScreen())),
    GoRoute(path: Routes.roleSelect, pageBuilder: (c, s) => _page(const RoleSelectScreen())),
    GoRoute(
      path: Routes.patientRegister,
      pageBuilder: (c, s) => _page(const PatientRegisterScreen()),
    ),
    GoRoute(
      path: Routes.driverRegister,
      pageBuilder: (c, s) => _page(const DriverRegisterScreen()),
    ),
    GoRoute(path: Routes.login, pageBuilder: (c, s) => _page(const LoginScreen())),
    GoRoute(
      path: Routes.medicalProfile,
      pageBuilder: (c, s) => _page(const MedicalProfileScreen()),
    ),
    GoRoute(path: Routes.home, pageBuilder: (c, s) => _page(const HomeScreen())),
    GoRoute(path: Routes.tracking, pageBuilder: (c, s) => _page(const TrackingScreen())),
    GoRoute(path: Routes.noDriver, pageBuilder: (c, s) => _page(const NoDriverScreen())),
    GoRoute(
      path: Routes.driverHome,
      pageBuilder: (c, s) => _page(const DriverHomeScreen()),
    ),
    GoRoute(
      path: Routes.driverNavigation,
      pageBuilder: (c, s) => _page(DriverNavigationScreen(caseId: s.extra as String? ?? '')),
    ),
    GoRoute(
      path: Routes.aiReport,
      pageBuilder: (c, s) => _page(AIReportScreen(caseId: s.extra as String? ?? '')),
    ),
    GoRoute(
      path: Routes.offlineSos,
      pageBuilder: (c, s) => _page(const OfflineSOSScreen()),
    ),
  ],
);
