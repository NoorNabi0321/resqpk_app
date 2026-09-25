import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

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
            icon: isDriver ? Icons.local_shipping_rounded : Icons.login_rounded,
            label: isDriver ? 'Driver dashboard' : 'Sign in',
            subtitle: isDriver ? 'Go on duty' : 'As a patient or as a driver',
            // No role in the link. It used to say "I am a driver" and carry
            // ?role=driver, which was right when the login screen had to be
            // told which account to check. It now opens with both tabs and the
            // reader picks there, so a tile that only offers the driver side is
            // a door marked for staff on the only entrance in the building.
            onTap: () => context.push(isDriver ? Routes.driverHome : Routes.login),
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
  /// The three numbers worth dialling in Hyderabad, in the order you would
  /// try them: government rescue, then the two charity ambulance services.
  static const _numbers = [
    (service: 'Rescue', number: '1122'),
    (service: 'Edhi', number: '115'),
    (service: 'Chhipa', number: '1020'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(AppAssets.logoWordmark, height: 56),
        const SizedBox(height: Resq.space3),
        Text('Emergency response for Hyderabad, Sindh',
            style: ResqType.caption(), textAlign: TextAlign.center),
        const SizedBox(height: Resq.space4),
        // These were a line of grey text. They are the fallback for when the
        // app itself cannot find anyone — which is the moment someone is least
        // able to copy a number out of a caption and type it into a dialer.
        Row(
          children: [
            for (final n in _numbers) ...[
              if (n != _numbers.first) const SizedBox(width: Resq.space2),
              Expanded(child: _EmergencyNumber(service: n.service, number: n.number)),
            ],
          ],
        ),
      ],
    );
  }
}

/// One emergency number, as a button that opens the dialer.
class _EmergencyNumber extends StatelessWidget {
  const _EmergencyNumber({required this.service, required this.number});

  final String service;
  final String number;

  Future<void> _dial(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }
    // A phone with no dialer at all — a tablet, usually. Saying so beats a
    // button that looks tappable and does nothing, which is what the whole
    // app did on Android 11+ before the manifest declared the dial intent.
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot open the dialer. $service is $number.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Resq.surface,
      borderRadius: BorderRadius.circular(Resq.radiusControl),
      child: InkWell(
        onTap: () => _dial(context),
        borderRadius: BorderRadius.circular(Resq.radiusControl),
        child: Container(
          constraints: const BoxConstraints(minHeight: Resq.tapTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: Resq.space2,
            vertical: Resq.space3,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Resq.radiusControl),
            border: Border.all(color: Resq.critical.withValues(alpha: 0.35)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.call_rounded, size: 16, color: Resq.critical),
              const SizedBox(height: 4),
              // The number leads. It is what gets dialled, and on a narrow
              // phone it is the part that must survive being squeezed.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(number, style: ResqType.bodyStrong(color: Resq.critical)),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(service, style: ResqType.micro()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
