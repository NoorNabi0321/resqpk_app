import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../../features/sos/providers/sos_provider.dart';
import 'app_router.dart';

/// The four-tab shell every patient screen lives in.
///
/// Each tab keeps its own navigation stack and scroll position, so returning to
/// First Aid lands where you left it rather than at the top of the list.
///
/// Tracking is deliberately NOT a tab: during an emergency the tabs are noise,
/// so it takes over the whole screen and the banner below keeps it one tap away.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _tabs = [
    (icon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.medical_services_rounded, label: 'First Aid'),
    (icon: Icons.local_hospital_rounded, label: 'Camps'),
    (icon: Icons.more_horiz_rounded, label: 'More'),
  ];

  Future<bool> _confirmExit(BuildContext context) async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Resq.surface,
        title: Text('Close ResQPK?', style: ResqType.section()),
        content: Text(
          'You can request an ambulance any time the app is open.',
          style: ResqType.body(color: Resq.inkSoft),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Stay')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Close', style: ResqType.button(color: Resq.critical)),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      // One policy for the whole app, instead of a guard bolted onto each
      // screen. Pressing back used to close ResQPK from anywhere, which is
      // alarming when an ambulance is on its way.
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;

        // A pushed screen inside the current tab pops first — that is handled
        // by the tab's own Navigator before this ever runs.
        if (navigationShell.currentIndex != 0) {
          navigationShell.goBranch(0);
          return;
        }
        if (await _confirmExit(context)) {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Resq.canvas,
        body: navigationShell,
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _CaseBanner(),
            _TabBar(
              currentIndex: navigationShell.currentIndex,
              onTap: (i) => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Ambulance on the way" — sits above the tabs whenever a case is running, so
/// tracking is always one tap away without occupying a tab of its own.
class _CaseBanner extends ConsumerWidget {
  const _CaseBanner();

  static const _live = {
    SOSStatus.searching,
    SOSStatus.driverAssigned,
    SOSStatus.arrived,
    SOSStatus.enRoute,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sos = ref.watch(sosProvider);
    if (!_live.contains(sos.status)) return const SizedBox.shrink();

    final searching = sos.status == SOSStatus.searching;
    final label = switch (sos.status) {
      SOSStatus.searching => 'Finding the nearest ambulance…',
      SOSStatus.driverAssigned => 'Ambulance on the way',
      SOSStatus.arrived => 'The ambulance has reached you',
      SOSStatus.enRoute => 'On the way to hospital',
      _ => 'Emergency in progress',
    };

    return Material(
      color: searching ? Resq.criticalTint : Resq.infoTint,
      child: InkWell(
        onTap: () => context.push(Routes.tracking),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Resq.space4, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: searching ? Resq.critical : Resq.info,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: Resq.space3),
              Expanded(
                child: Text(
                  label,
                  style: ResqType.bodyStrong(color: searching ? Resq.critical : Resq.info),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: searching ? Resq.critical : Resq.info),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Resq.surface,
        border: Border(top: BorderSide(color: Resq.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < AppShell._tabs.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onTap(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          AppShell._tabs[i].icon,
                          size: 24,
                          color: i == currentIndex ? Resq.brand : Resq.inkFaint,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          AppShell._tabs[i].label,
                          style: ResqType.micro(
                            color: i == currentIndex ? Resq.brand : Resq.inkFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
