import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/location/location_provider.dart';
import '../../../core/realtime/realtime_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/back_guard.dart';
import '../../auth/providers/auth_provider.dart';
import '../../sos/data/models/dispatch_request_model.dart';
import '../providers/driver_history_provider.dart';
import '../providers/driver_realtime_provider.dart';
import '../widgets/driver_chrome.dart';
import 'dispatch_request_screen.dart';

/// Duty screen — the driver's home.
///
/// One decision lives here: are you taking emergencies right now. Everything
/// else on the screen exists to answer the questions that decision raises —
/// can the server hear me, does the phone know where I am, and what have I done
/// today.
class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  bool _dialogOpen = false;

  Future<void> _showDispatchRequest(DispatchRequestModel request) async {
    if (_dialogOpen) return; // don't stack overlays
    _dialogOpen = true;
    final result = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'dispatch',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => DispatchRequestScreen(request: request),
      transitionBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
    _dialogOpen = false;
    if (!mounted) return;

    if (result == 'accepted') {
      context.go(Routes.driverNavigation, extra: request.caseId);
    } else if (result == 'expired') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request expired — another ambulance took it')),
      );
    } else if (result == 'declined' || result == 'timeout') {
      // The count of what you turned down is part of your record too.
      ref.invalidate(driverHistoryProvider);
    }
  }

  Future<void> _logout(DriverOnlineState driverState) async {
    if (driverState.isOnline) {
      await ref.read(driverOnlineProvider.notifier).goOffline();
    }
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go(Routes.roleSelect);
  }

  @override
  Widget build(BuildContext context) {
    // Keep the socket connected while this screen is open.
    ref.watch(socketConnectionProvider);

    // Incoming dispatch requests → full-screen interrupt.
    ref.listen(caseUpdateStreamProvider, (_, next) {
      next.whenData((data) {
        if (data['event'] == 'case_created') {
          _showDispatchRequest(DispatchRequestModel.fromJson(data));
        }
      });
    });

    // Surface errors from going online/offline.
    ref.listen(driverOnlineProvider.select((s) => s.error), (_, error) {
      if (error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      }
    });

    final driverState = ref.watch(driverOnlineProvider);
    // Must be a reactive source. Reading socketServiceProvider's .isConnected
    // captured `false` at first build and never rebuilt, which left this screen
    // stuck on "Disconnected" with the toggle disabled.
    final isConnected = ref.watch(socketReadyProvider).value ??
        ref.read(socketServiceProvider).isAuthenticated;
    final hasInternet = ref.watch(isOnlineProvider).value ?? true;
    final position = ref.watch(currentPositionStreamProvider).asData?.value ??
        driverState.currentPosition;
    final user = ref.watch(currentUserProvider);
    final history = ref.watch(driverHistoryProvider);

    final duty = !isConnected && !driverState.isOnline
        ? DutyState.connecting
        : (driverState.isOnline ? DutyState.online : DutyState.offline);

    return ExitGuard(
      child: DriverScaffold(
        title: user?.fullName ?? 'Driver',
        subtitle: isConnected ? 'Connected to ResQPK' : 'Not connected',
        actions: [
          DriverRoundButton(
            icon: Icons.logout_rounded,
            tint: Resq.critical,
            onTap: () => _logout(driverState),
          ),
        ],
        body: RefreshIndicator(
          color: Resq.ready,
          backgroundColor: ResqDark.surface,
          onRefresh: () async => ref.invalidate(driverHistoryProvider),
          child: ListView(
            padding: const EdgeInsets.only(bottom: Resq.space6),
            children: [
              if (!hasInternet)
                const _Warning(
                  icon: Icons.wifi_off_rounded,
                  text: 'No internet. Location updates pause and resume on their own.',
                ),
              DutyToggle(
                state: duty,
                busy: driverState.isLoading,
                onTap: duty == DutyState.connecting
                    ? null
                    : () {
                        final notifier = ref.read(driverOnlineProvider.notifier);
                        driverState.isOnline ? notifier.goOffline() : notifier.goOnline();
                      },
              ),
              const SizedBox(height: Resq.space4),
              _GpsCard(position: position, broadcasting: driverState.isBroadcasting),
              const SizedBox(height: Resq.space4),

              Text('Your record', style: ResqType.section(color: ResqDark.ink)),
              const SizedBox(height: Resq.space3),
              history.when(
                loading: () => const _StatsRow(
                  today: '—',
                  completed: '—',
                  acceptRate: '—',
                ),
                error: (_, __) => const _StatsRow(today: '—', completed: '—', acceptRate: '—'),
                data: (h) => _StatsRow(
                  today: '${h.stats.today}',
                  completed: '${h.stats.completed}',
                  acceptRate: h.stats.acceptRate == null ? '—' : '${h.stats.acceptRate}%',
                ),
              ),
              const SizedBox(height: Resq.space4),

              _NavCard(
                icon: Icons.history_rounded,
                title: 'Run history',
                subtitle: 'Every emergency you have answered',
                onTap: () => context.push(Routes.driverHistory),
              ),
              const SizedBox(height: Resq.space3),
              _NavCard(
                icon: Icons.map_rounded,
                title: 'My area',
                subtitle: 'Hospitals and camps around you',
                onTap: () => context.push(Routes.driverArea),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.today, required this.completed, required this.acceptRate});

  final String today;
  final String completed;
  final String acceptRate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StatTile(
            value: today,
            label: 'Runs today',
            icon: Icons.today_rounded,
            color: Resq.ready,
          ),
        ),
        const SizedBox(width: Resq.space3),
        Expanded(
          child: StatTile(
            value: completed,
            label: 'Completed',
            icon: Icons.check_circle_outline_rounded,
            color: Resq.info,
          ),
        ),
        const SizedBox(width: Resq.space3),
        Expanded(
          child: StatTile(
            value: acceptRate,
            label: 'Offers accepted',
            icon: Icons.percent_rounded,
            color: Resq.decision,
          ),
        ),
      ],
    );
  }
}

/// GPS quality, in the only terms that matter: can dispatch find you.
class _GpsCard extends StatelessWidget {
  const _GpsCard({required this.position, required this.broadcasting});

  final Position? position;
  final bool broadcasting;

  @override
  Widget build(BuildContext context) {
    final accuracy = position?.accuracy;
    final (color, label) = switch (accuracy) {
      null => (ResqDark.inkMuted, 'Waiting for GPS…'),
      < 30 => (Resq.ready, 'GPS is good'),
      < 60 => (Resq.decision, 'GPS is rough — dispatch may misjudge your distance'),
      _ => (Resq.critical, 'GPS is poor — move away from buildings'),
    };

    return DriverCard(
      accent: color,
      child: Row(
        children: [
          Icon(Icons.gps_fixed_rounded, color: color, size: 20),
          const SizedBox(width: Resq.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: ResqType.bodyStrong(color: ResqDark.ink)),
                const SizedBox(height: 2),
                Text(
                  accuracy == null
                      ? 'Your position is what dispatch sorts ambulances by.'
                      : 'Accurate to about ${accuracy.toStringAsFixed(0)} m'
                          '${broadcasting ? ' · sharing live' : ''}',
                  style: ResqType.caption(color: ResqDark.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Resq.space3),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: ResqDark.surfaceHigh,
              borderRadius: BorderRadius.circular(Resq.radiusControl),
            ),
            child: Icon(icon, color: ResqDark.ink, size: 21),
          ),
          const SizedBox(width: Resq.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ResqType.bodyStrong(color: ResqDark.ink)),
                Text(subtitle, style: ResqType.caption(color: ResqDark.inkMuted)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: ResqDark.inkFaint),
        ],
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Resq.space3),
      padding: const EdgeInsets.all(Resq.space3),
      decoration: BoxDecoration(
        color: Resq.decision.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(Resq.radiusControl),
        border: Border.all(color: Resq.decision.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Resq.decision),
          const SizedBox(width: Resq.space2),
          Expanded(child: Text(text, style: ResqType.caption(color: Resq.decision))),
        ],
      ),
    );
  }
}
