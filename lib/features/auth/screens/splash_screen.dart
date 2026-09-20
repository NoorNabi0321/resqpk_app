import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/router/app_router.dart';
import '../../sos/data/sos_repository.dart';
import '../../sos/providers/sos_provider.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;
    await ref.read(authProvider.notifier).checkAuthStatus();
    if (!mounted) return;

    final auth = ref.read(authProvider);
    final prefs = await SharedPreferences.getInstance();
    final seenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
    if (!mounted) return;

    if (auth.isAuthenticated) {
      // Resume an in-progress emergency rather than dropping the user back on
      // the home screen — a live case is the whole reason the app is open.
      final resumed = await _resumeActiveCase(auth.role);
      if (resumed || !mounted) return;
      context.go(auth.role == 'driver' ? Routes.driverHome : Routes.home);
    } else if (!seenOnboarding) {
      context.go(Routes.onboarding);
    } else {
      // No account, and none needed. A case saved on this device is picked back
      // up first: a force-close during an emergency must not lose the ambulance
      // already on its way.
      final resumed = await _resumeAnonymousCase();
      if (resumed || !mounted) return;
      context.go(Routes.home);
    }
  }

  /// Returns true when it navigated to a restored case.
  Future<bool> _resumeAnonymousCase() async {
    await ref.read(sosProvider.notifier).restoreFromSession();
    if (!mounted) return false;
    if (ref.read(sosProvider).activeCaseId == null) return false;
    context.go(Routes.tracking);
    return true;
  }

  /// Sends the user straight back to their live case, if they have one.
  /// Returns true when it navigated.
  Future<bool> _resumeActiveCase(String? role) async {
    final activeCase = await SOSRepository().getMyActiveCase();
    if (activeCase == null || !mounted) return false;

    if (role == 'driver') {
      context.go(Routes.driverNavigation, extra: activeCase.id);
      return true;
    }

    // Patient: rehydrate SOS state, rejoin the case room, then open tracking.
    await ref.read(sosProvider.notifier).restoreActiveCase(activeCase);
    if (!mounted) return false;
    context.go(Routes.tracking);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Resq.canvas,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              AppAssets.splashLogo,
              height: 132,
              errorBuilder: (_, __, ___) => Text(
                'ResQPK',
                style: ResqType.display(color: Resq.brandInk).copyWith(fontSize: 44),
              ),
            ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.8, 0.8)),
            const SizedBox(height: Resq.space4),
            Text(
              'Emergency help for Hyderabad',
              style: ResqType.section(color: Resq.inkSoft),
            ).animate().fadeIn(delay: 400.ms, duration: 600.ms),
          ],
        ),
      ),
    );
  }
}
