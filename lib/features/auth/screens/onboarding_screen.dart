import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/primary_button.dart';

class _OnboardingPage {
  const _OnboardingPage(this.headline, this.body, this.illustration, this.tint);

  final String headline;
  final String body;
  final String illustration;
  final Color tint;
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  // Three promises, in the order they matter: help comes, the hospital is
  // ready, and you choose which one. No account is mentioned, because none is
  // needed to do any of it.
  static const List<_OnboardingPage> _pages = [
    _OnboardingPage(
      'Hold SOS. That is all.',
      'No sign-up, no password. Hold the button for three seconds and the '
          'nearest ambulances are offered your emergency.',
      AppAssets.onboardingSos,
      Resq.criticalTint,
    ),
    _OnboardingPage(
      'The hospital knows before you arrive',
      'Your location, and anything you tell us on the way, reaches the '
          'emergency ward while the ambulance is still moving.',
      AppAssets.onboardingHospital,
      Resq.infoTint,
    ),
    _OnboardingPage(
      'Your hospital, your choice',
      'Take the nearest one or pick another. Only the hospital you confirm '
          'is alerted.',
      AppAssets.onboardingChoice,
      Resq.readyTint,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    if (!mounted) return;
    // Straight to the SOS button. Choosing a role is something drivers do from
    // More; a patient has nothing to choose.
    context.go(Routes.home);
  }

  void _next() {
    if (_index == _pages.length - 1) {
      _finish();
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Resq.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) {
                  final p = _pages[i];
                  return Column(
                    children: [
                      Expanded(
                        flex: 55,
                        child: Container(
                          margin: const EdgeInsets.all(Resq.space6),
                          decoration: BoxDecoration(
                            color: p.tint,
                            borderRadius: BorderRadius.circular(Resq.radiusCard),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset(
                            p.illustration,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 45,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: Resq.space8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.headline, style: ResqType.display()),
                              const SizedBox(height: Resq.space3),
                              Text(p.body, style: ResqType.body(color: Resq.inkSoft)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? Resq.brandInk : Resq.border,
                    borderRadius: BorderRadius.circular(Resq.radiusPill),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: PrimaryButton(
                label: _index == _pages.length - 1 ? 'Get Started' : 'Next',
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
