import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_router.dart';
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
      context.go(auth.role == 'driver' ? Routes.driverHome : Routes.home);
    } else if (!seenOnboarding) {
      context.go(Routes.onboarding);
    } else {
      context.go(Routes.roleSelect);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ResQPK',
              style: AppTextStyles.display.copyWith(color: AppColors.sosRed, fontSize: 44),
            ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.8, 0.8)),
            const SizedBox(height: 12),
            Text(
              'Emergency Response, Reimagined',
              style: AppTextStyles.subtitle.copyWith(color: AppColors.textSecondary),
            ).animate().fadeIn(delay: 400.ms, duration: 600.ms),
          ],
        ),
      ),
    );
  }
}
