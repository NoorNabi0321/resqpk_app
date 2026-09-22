import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';

/// Two cards. Nothing else.
///
/// The old role screen explained itself at length and offered four buttons,
/// two of which were sign-in links that the login screen already handles. All
/// this has to answer is which form to open.
class SignupChoiceScreen extends StatelessWidget {
  const SignupChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Resq.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Resq.ink,
        title: Text('Sign up', style: ResqType.title()),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Resq.space5),
          child: Column(
            children: [
              Expanded(
                child: _Choice(
                  icon: Icons.person_rounded,
                  label: 'Patient',
                  color: Resq.info,
                  tint: Resq.infoTint,
                  onTap: () => context.push(Routes.patientRegister),
                ),
              ),
              const SizedBox(height: Resq.space4),
              Expanded(
                child: _Choice(
                  icon: Icons.airport_shuttle_rounded,
                  label: 'Driver',
                  color: Resq.ready,
                  tint: Resq.readyTint,
                  onTap: () => context.push(Routes.driverRegister),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.icon,
    required this.label,
    required this.color,
    required this.tint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tint,
      borderRadius: BorderRadius.circular(Resq.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Resq.radiusCard),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Resq.radiusCard),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 42, color: color),
              ),
              const SizedBox(height: Resq.space4),
              Text(label, style: ResqType.display(color: color).copyWith(fontSize: 26)),
            ],
          ),
        ),
      ),
    );
  }
}
