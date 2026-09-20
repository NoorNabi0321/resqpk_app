import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/router/app_router.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Resq.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: Resq.space4),
              Image.asset(
                AppAssets.logoWordmark,
                height: 36,
                alignment: Alignment.centerLeft,
                errorBuilder: (_, __, ___) =>
                    Text('ResQPK', style: ResqType.display(color: Resq.brandInk)),
              ),
              const SizedBox(height: Resq.space3),
              Text('Signing in is for crews', style: ResqType.title()),
              const SizedBox(height: Resq.space2),
              Text(
                'Drivers and hospital staff sign in because they are accountable '
                'for what they do in the system. Anyone who needs an ambulance '
                'does not.',
                style: ResqType.body(color: Resq.inkSoft),
              ),
              const SizedBox(height: Resq.space6),
              _RoleCard(
                icon: Icons.airport_shuttle_rounded,
                title: 'I drive an ambulance',
                subtitle: 'Register or sign in as a driver',
                accent: Resq.ready,
                onTap: () => context.go(Routes.driverRegister),
                onLogin: () => context.go('${Routes.login}?role=driver'),
              ),
              const SizedBox(height: Resq.space3),
              // An account is optional for patients, and only ever about
              // history and medical details — never about calling for help.
              _RoleCard(
                icon: Icons.person_rounded,
                title: 'I have a patient account',
                subtitle: 'For your medical details and past requests',
                accent: Resq.info,
                onTap: () => context.go(Routes.patientRegister),
                onLogin: () => context.go('${Routes.login}?role=patient'),
              ),
              const SizedBox(height: Resq.space4),
              OutlinedButton.icon(
                onPressed: () => context.go(Routes.home),
                icon: const Icon(Icons.emergency_rounded, size: 18, color: Resq.critical),
                label: Text(
                  'I just need an ambulance',
                  style: ResqType.button(color: Resq.critical),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(Resq.tapTarget),
                  side: BorderSide(color: Resq.critical.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Resq.radiusControl),
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Hospital dashboard is available at resqpk.app/hospital'),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Resq.border),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.business, color: Resq.inkSoft, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hospital Dashboard', style: ResqType.section()),
                            Text('Log in via web browser', style: ResqType.caption()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onLogin;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
    required this.onLogin,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        GestureDetector(
          onTapDown: (_) => setState(() => _scale = 0.97),
          onTapUp: (_) => setState(() => _scale = 1),
          onTapCancel: () => setState(() => _scale = 1),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _scale,
            duration: const Duration(milliseconds: 120),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Resq.surfaceAlt,
                border: Border.all(color: Resq.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: widget.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(widget.icon, color: widget.accent),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: ResqType.section()),
                        const SizedBox(height: 4),
                        Text(widget.subtitle, style: ResqType.caption()),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Resq.inkSoft),
                ],
              ),
            ),
          ),
        ),
        TextButton(
          onPressed: widget.onLogin,
          child: Text('Already have an account? Login',
              style: ResqType.caption().copyWith(color: Resq.info)),
        ),
      ],
    );
  }
}
