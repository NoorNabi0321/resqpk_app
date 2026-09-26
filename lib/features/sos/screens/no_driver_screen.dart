import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/resq_card.dart';
import '../providers/sos_provider.dart';

class _Service {
  const _Service(this.name, this.number, this.icon, this.color);

  final String name;
  final String number;
  final IconData icon;
  final Color color;
}

const _services = [
  _Service('Rescue 1122', '1122', Icons.emergency_rounded, Resq.critical),
  _Service('Edhi Foundation', '115', Icons.local_hospital_rounded, Resq.brandInk),
  _Service('Chhipa Welfare', '1020', Icons.medical_services_rounded, Resq.ready),
  _Service('Police Emergency', '15', Icons.local_police_rounded, Resq.info),
];

/// Every nearby ambulance declined or timed out.
///
/// The worst screen in the app, so it does the one useful thing it can: hand
/// over working phone numbers, large enough to tap without aiming, before
/// offering to try again.
class NoDriverScreen extends ConsumerWidget {
  const NoDriverScreen({super.key});

  Future<void> _call(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Resq.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Resq.space5, Resq.space4, Resq.space5, Resq.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Image.asset(
                  AppAssets.stateNoDriver,
                  // The picture carries the bad news before the heading does,
                  // and at a flat 160 it sat in the middle of the screen
                  // looking incidental. A share of the screen rather than a
                  // number, because at 220 on a 640pt phone it pushed three of
                  // the four numbers below the fold — and those numbers are
                  // the entire reason for this screen.
                  height: math.min(220, MediaQuery.sizeOf(context).height * 0.24),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.no_transfer_rounded,
                    size: 96,
                    color: Resq.decision,
                  ),
                ),
              ),
              const SizedBox(height: Resq.space4),
              Text('No ambulance could take it', style: ResqType.title()),
              const SizedBox(height: Resq.space2),
              Text(
                'Every ambulance nearby is busy. Call one of these now — they answer '
                'without the app.',
                style: ResqType.body(color: Resq.inkSoft),
              ),
              const SizedBox(height: Resq.space5),
              Expanded(
                child: ListView.separated(
                  itemCount: _services.length,
                  separatorBuilder: (_, __) => const SizedBox(height: Resq.space3),
                  itemBuilder: (_, i) {
                    final s = _services[i];
                    return ResqCard(
                      padding: const EdgeInsets.all(Resq.space3),
                      accent: s.color,
                      onTap: () => _call(s.number),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: s.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(Resq.radiusControl),
                            ),
                            child: Icon(s.icon, color: s.color, size: 22),
                          ),
                          const SizedBox(width: Resq.space3),
                          Expanded(child: Text(s.name, style: ResqType.bodyStrong())),
                          Text(s.number, style: ResqType.title(color: s.color)),
                          const SizedBox(width: Resq.space2),
                          const Icon(Icons.call_rounded, color: Resq.ready, size: 20),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: Resq.space3),
              PrimaryButton.critical(
                label: 'Try again',
                icon: Icons.refresh_rounded,
                onPressed: () {
                  ref.read(sosProvider.notifier).retry();
                  context.go(Routes.home);
                },
              ),
              TextButton(
                onPressed: () {
                  ref.read(sosProvider.notifier).reset();
                  context.go(Routes.home);
                },
                child: Text('Back to home', style: ResqType.button(color: Resq.inkSoft)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
