import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../auth/providers/auth_provider.dart';

/// Everything that is not an emergency: account, driver sign-in, about.
///
/// Replaces the drawer, which duplicated the bottom navigation and hid the
/// driver entry point behind a hamburger menu.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isDriver = user?.role == 'driver';

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Resq.space4, Resq.space5, Resq.space4, Resq.space6),
        children: [
          Text('More', style: ResqType.display()),
          const SizedBox(height: Resq.space5),

          // First, because it is the one thing a patient with no account comes
          // to this tab for.
          _Tile(
            icon: Icons.receipt_long_rounded,
            label: 'My requests',
            subtitle: 'Track or reopen by request code',
            onTap: () => context.push(Routes.myRequests),
          ),

          if (user != null) ...[
            _Tile(
              icon: Icons.person_rounded,
              label: 'Profile',
              subtitle: user.fullName,
              onTap: () => context.push(Routes.profile),
            ),
            _Tile(
              icon: Icons.assignment_ind_rounded,
              label: 'Medical information',
              subtitle: 'Blood group, allergies, conditions',
              onTap: () => context.push(Routes.medicalProfile),
            ),
          ],

          _Tile(
            icon: Icons.local_shipping_rounded,
            label: isDriver ? 'Driver dashboard' : 'I am a driver',
            subtitle: isDriver ? 'Go on duty' : 'Sign in to receive emergencies',
            // The role has to travel with the link. Without it the login screen
            // opened in patient mode, so driver credentials were checked
            // against patient accounts and came back "invalid phone or
            // password" — and its Register link led to the patient form, which
            // is how a driver ended up with a patient account.
            onTap: () => context.push(
              isDriver ? Routes.driverHome : '${Routes.login}?role=driver',
            ),
          ),

          const SizedBox(height: Resq.space6),
          _About(),

          if (user != null) ...[
            const SizedBox(height: Resq.space5),
            TextButton(
              onPressed: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go(Routes.home);
              },
              child: Text('Sign out', style: ResqType.button(color: Resq.critical)),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.onTap, this.subtitle});

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Resq.space3),
      child: Material(
        color: Resq.surface,
        borderRadius: BorderRadius.circular(Resq.radiusCard),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Resq.radiusCard),
          child: Container(
            constraints: const BoxConstraints(minHeight: Resq.tapTarget + 12),
            padding: const EdgeInsets.symmetric(horizontal: Resq.space4, vertical: Resq.space3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Resq.radiusCard),
              border: Border.all(color: Resq.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Resq.brandTint,
                    borderRadius: BorderRadius.circular(Resq.radiusControl),
                  ),
                  child: Icon(icon, size: 20, color: Resq.brandInk),
                ),
                const SizedBox(width: Resq.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: ResqType.bodyStrong()),
                      if (subtitle != null)
                        Text(subtitle!, style: ResqType.caption(), maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Resq.inkFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _About extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(AppAssets.logoWordmark, height: 34),
        const SizedBox(height: Resq.space2),
        Text('Emergency response for Hyderabad, Sindh',
            style: ResqType.caption(), textAlign: TextAlign.center),
        const SizedBox(height: Resq.space1),
        Text('Rescue 1122 · Edhi 115 · Chhipa 1020', style: ResqType.micro()),
      ],
    );
  }
}
