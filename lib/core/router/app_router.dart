import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import '../storage/secure_storage.dart';
import 'app_shell.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/signup_choice_screen.dart';
import '../../features/auth/screens/patient_register_screen.dart';
import '../../features/auth/screens/driver_register_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/medical_profile_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/more/screens/more_screen.dart';
import '../../features/driver/screens/driver_area_screen.dart';
import '../../features/driver/screens/driver_history_screen.dart';
import '../../features/driver/screens/driver_home_screen.dart';
import '../../features/driver/screens/driver_navigation_screen.dart';
import '../../features/sos/screens/my_requests_screen.dart';
import '../../features/sos/screens/tracking_screen.dart';
import '../../features/sos/screens/no_driver_screen.dart';
import '../../features/ai_report/screens/ai_report_screen.dart';
import '../../features/ai_report/screens/report_pdf_screen.dart';
import '../../features/ai_report/screens/flow/report_photo_screen.dart';
import '../../features/ai_report/screens/flow/report_method_screen.dart';
import '../../features/ai_report/screens/flow/report_text_screen.dart';
import '../../features/ai_report/screens/flow/report_voice_screen.dart';
import '../../features/ai_report/screens/flow/report_generating_screen.dart';
import '../../features/ai_report/screens/flow/report_result_screen.dart';
import '../../features/first_aid/screens/first_aid_screen.dart';
import '../../features/first_aid/screens/guide_detail_screen.dart';
import '../../features/first_aid/data/models/first_aid_guide_model.dart';
import '../../features/ai_report/data/models/ai_report_model.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/camps/screens/camps_screen.dart';
import '../../features/camps/screens/camp_detail_screen.dart';
import '../../features/camps/data/models/camp_model.dart';

/// Centralized route paths.
class Routes {
  Routes._();
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  /// Which kind of account to create. Reached from the login screen's Sign up
  /// button — there is no role screen in front of the app any more.
  static const String signupChoice = '/signup';
  static const String patientRegister = '/register/patient';
  static const String driverRegister = '/register/driver';
  static const String login = '/login';
  static const String medicalProfile = '/medical-profile';

  // Shell tabs
  static const String home = '/home';
  static const String firstAid = '/first-aid';
  static const String camps = '/camps';
  static const String more = '/more';

  // Takeovers — full screen, outside the tabs
  //
  // A guide is one of them: while someone is following steps, nothing on the
  // tab bar is what they should do next, and the picture wants the room.
  static const String guideDetail = '/guide';
  static const String myRequests = '/my-requests';
  static const String tracking = '/tracking';
  static const String noDriver = '/no-driver';
  static const String aiReport = '/ai-report';
  static const String reportPdf = '/ai-report/pdf';

  // The report, one question per screen.
  static const String reportPhoto = '/report/photo';
  static const String reportMethod = '/report/method';
  static const String reportText = '/report/text';
  static const String reportVoice = '/report/voice';
  static const String reportGenerating = '/report/generating';
  static const String reportResult = '/report/result';

  // Driver
  static const String driverHome = '/driver-home';
  static const String driverNavigation = '/driver-navigation';
  static const String driverHistory = '/driver/history';
  static const String driverArea = '/driver/area';
  static const String profile = '/profile';
}

/// Routes that still require an account.
///
/// Everything else is open. A patient never signs in: the SOS button, tracking,
/// first aid and camps all work on a fresh install, because asking someone to
/// register while they are looking at a casualty is the one thing this app must
/// never do. Drivers and hospital staff still sign in — they are accountable for
/// what they do in the system, and their screens are useless without an identity.
const Set<String> _guardedRoutes = {
  Routes.driverHome,
  Routes.driverNavigation,
  Routes.driverHistory,
  Routes.driverArea,
  Routes.profile,
  Routes.medicalProfile,
};

/// Fade + scale transition for takeover routes.
CustomTransitionPage<void> _page(Widget child) {
  return CustomTransitionPage<void>(
    transitionDuration: const Duration(milliseconds: 240),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.97, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      );
    },
  );
}

/// Tabs switch without a transition — the shell swaps them instantly, and an
/// animation on top of that reads as lag.
NoTransitionPage<void> _tab(Widget child) => NoTransitionPage<void>(child: child);

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

    if (!loggedIn && _guardedRoutes.contains(loc)) {
      // Straight to sign-in, in the right mode for where they were heading.
      return loc.startsWith('/driver') ? '${Routes.login}?role=driver' : Routes.login;
    }

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
    // --- The patient shell: four tabs, each keeping its own stack -----------
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: Routes.home, pageBuilder: (c, s) => _tab(const HomeScreen()))],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.firstAid,
              pageBuilder: (c, s) => _tab(const FirstAidScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.camps,
              pageBuilder: (c, s) => _tab(const CampsScreen()),
              routes: [
                GoRoute(
                  path: ':id',
                  pageBuilder: (c, s) => _page(
                    CampDetailScreen(
                      campId: s.pathParameters['id'] ?? '',
                      camp: s.extra as CampModel?,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: Routes.more, pageBuilder: (c, s) => _tab(const MoreScreen()))],
        ),
      ],
    ),

    // --- Entry ---------------------------------------------------------------
    GoRoute(path: Routes.splash, pageBuilder: (c, s) => _page(const SplashScreen())),
    GoRoute(path: Routes.onboarding, pageBuilder: (c, s) => _page(const OnboardingScreen())),
    GoRoute(path: Routes.signupChoice, pageBuilder: (c, s) => _page(const SignupChoiceScreen())),
    GoRoute(path: Routes.login, pageBuilder: (c, s) => _page(const LoginScreen())),
    GoRoute(
      path: Routes.patientRegister,
      pageBuilder: (c, s) => _page(const PatientRegisterScreen()),
    ),
    GoRoute(
      path: Routes.driverRegister,
      pageBuilder: (c, s) => _page(const DriverRegisterScreen()),
    ),
    GoRoute(
      path: Routes.medicalProfile,
      pageBuilder: (c, s) => _page(const MedicalProfileScreen()),
    ),
    GoRoute(path: Routes.profile, pageBuilder: (c, s) => _page(const ProfileScreen())),

    // --- Takeovers: an emergency owns the whole screen ----------------------
    GoRoute(
      path: Routes.guideDetail,
      pageBuilder: (c, s) => _page(GuideDetailScreen(guide: s.extra as FirstAidGuideModel)),
    ),
    GoRoute(path: Routes.myRequests, pageBuilder: (c, s) => _page(const MyRequestsScreen())),
    GoRoute(path: Routes.tracking, pageBuilder: (c, s) => _page(const TrackingScreen())),
    GoRoute(path: Routes.noDriver, pageBuilder: (c, s) => _page(const NoDriverScreen())),
    GoRoute(
      path: Routes.aiReport,
      pageBuilder: (c, s) => _page(AIReportScreen(caseId: s.extra as String? ?? '')),
    ),
    // --- The report flow ------------------------------------------------------
    GoRoute(
      path: Routes.reportPhoto,
      pageBuilder: (c, s) => _page(ReportPhotoScreen(caseId: s.extra as String? ?? '')),
    ),
    GoRoute(
      path: Routes.reportMethod,
      pageBuilder: (c, s) => _page(ReportMethodScreen(caseId: s.extra as String? ?? '')),
    ),
    GoRoute(
      path: Routes.reportText,
      pageBuilder: (c, s) => _page(ReportTextScreen(caseId: s.extra as String? ?? '')),
    ),
    GoRoute(
      path: Routes.reportVoice,
      pageBuilder: (c, s) => _page(ReportVoiceScreen(caseId: s.extra as String? ?? '')),
    ),
    GoRoute(
      path: Routes.reportGenerating,
      pageBuilder: (c, s) => _page(ReportGeneratingScreen(caseId: s.extra as String? ?? '')),
    ),
    GoRoute(
      path: Routes.reportResult,
      pageBuilder: (c, s) => _page(ReportResultScreen(caseId: s.extra as String? ?? '')),
    ),
    GoRoute(
      path: Routes.reportPdf,
      pageBuilder: (c, s) {
        final args = s.extra as Map<String, dynamic>? ?? const {};
        return _page(ReportPdfScreen(
          caseId: args['caseId']?.toString() ?? '',
          report: args['report'] as AIReportModel?,
        ));
      },
    ),

    // --- Driver --------------------------------------------------------------
    GoRoute(path: Routes.driverHome, pageBuilder: (c, s) => _page(const DriverHomeScreen())),
    GoRoute(
      path: Routes.driverNavigation,
      pageBuilder: (c, s) => _page(DriverNavigationScreen(caseId: s.extra as String? ?? '')),
    ),
    GoRoute(path: Routes.driverHistory, pageBuilder: (c, s) => _page(const DriverHistoryScreen())),
    GoRoute(path: Routes.driverArea, pageBuilder: (c, s) => _page(const DriverAreaScreen())),
  ],
);
