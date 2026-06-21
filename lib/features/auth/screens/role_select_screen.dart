import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_router.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text('ResQPK', style: AppTextStyles.display.copyWith(color: AppColors.sosRed)),
              const SizedBox(height: 8),
              Text('How are you using ResQPK?',
                  style: AppTextStyles.subtitle.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 32),
              _RoleCard(
                icon: Icons.local_hospital,
                title: 'I need emergency help',
                subtitle: 'Register or log in as a patient',
                accent: AppColors.sosRed,
                onTap: () => context.go(Routes.patientRegister),
                onLogin: () => context.go('${Routes.login}?role=patient'),
              ),
              const SizedBox(height: 12),
              _RoleCard(
                icon: Icons.airport_shuttle,
                title: 'I drive an ambulance',
                subtitle: 'Register or log in as a driver',
                accent: AppColors.confirmedGreen,
                onTap: () => context.go(Routes.driverRegister),
                onLogin: () => context.go('${Routes.login}?role=driver'),
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
                    border: Border.all(color: AppColors.borderGlass),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.business, color: AppColors.textSecondary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hospital Dashboard', style: AppTextStyles.subtitle),
                            Text('Log in via web browser', style: AppTextStyles.caption),
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
                color: AppColors.surfaceTwo,
                border: Border.all(color: AppColors.borderGlass),
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
                        Text(widget.title, style: AppTextStyles.subtitle),
                        const SizedBox(height: 4),
                        Text(widget.subtitle, style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ),
        TextButton(
          onPressed: widget.onLogin,
          child: Text('Already have an account? Login',
              style: AppTextStyles.caption.copyWith(color: AppColors.infoBlue)),
        ),
      ],
    );
  }
}
