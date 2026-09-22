import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../data/models/driver_history_model.dart';
import '../providers/driver_history_provider.dart';
import '../widgets/driver_chrome.dart';

/// Every emergency this driver has answered.
///
/// Grouped by day, because a driver looks for "that run on Tuesday", not for
/// row 14. The numbers at the top are theirs, not a performance review: most of
/// these drivers are volunteers, and this is the only place the system says
/// back what they have done.
class DriverHistoryScreen extends ConsumerWidget {
  const DriverHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(driverHistoryProvider);

    return DriverScaffold(
      title: 'Run history',
      subtitle: 'Your emergencies, newest first',
      onBack: () => context.pop(),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Resq.ready)),
        error: (e, __) => _Failed(
          message: e.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(driverHistoryProvider),
        ),
        data: (h) => RefreshIndicator(
          color: Resq.ready,
          backgroundColor: Resq.surface,
          onRefresh: () async => ref.invalidate(driverHistoryProvider),
          child: ListView(
            padding: const EdgeInsets.only(bottom: Resq.space6),
            children: [
              _Summary(stats: h.stats),
              const SizedBox(height: Resq.space5),
              if (h.trips.isEmpty)
                _Empty()
              else
                for (final entry in h.byDay.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: Resq.space3),
                    child: Text(
                      _dayLabel(entry.key),
                      style: ResqType.section(color: Resq.ink),
                    ),
                  ),
                  for (final trip in entry.value)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Resq.space3),
                      child: _TripCard(trip: trip),
                    ),
                  const SizedBox(height: Resq.space3),
                ],
            ],
          ),
        ),
      ),
    );
  }

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final difference = today.difference(day).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';

    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final label = '${day.day} ${months[day.month - 1]}';
    return day.year == now.year ? label : '$label ${day.year}';
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.stats});

  final DriverStats stats;

  String get _response {
    final seconds = stats.avgResponseSeconds;
    if (seconds == null) return '—';
    return '${seconds}s';
  }

  String get _arrival {
    final seconds = stats.avgArrivalSeconds;
    if (seconds == null) return '—';
    final minutes = (seconds / 60).round();
    return minutes <= 1 ? '1 min' : '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile(
                value: '${stats.completed}',
                label: 'Patients delivered',
                icon: Icons.local_hospital_rounded,
                color: Resq.ready,
              ),
            ),
            const SizedBox(width: Resq.space3),
            Expanded(
              child: StatTile(
                value: '${stats.accepted}/${stats.offers}',
                label: 'Offers accepted (30 days)',
                icon: Icons.call_received_rounded,
                color: Resq.info,
              ),
            ),
          ],
        ),
        const SizedBox(height: Resq.space3),
        Row(
          children: [
            Expanded(
              child: StatTile(
                value: _response,
                label: 'Average time to answer',
                icon: Icons.timer_outlined,
                color: Resq.decision,
              ),
            ),
            const SizedBox(width: Resq.space3),
            Expanded(
              child: StatTile(
                value: _arrival,
                label: 'Average time to reach',
                icon: Icons.navigation_rounded,
                color: Resq.brand,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});

  final DriverTrip trip;

  ({Color color, String label}) get _outcome => switch (trip.status) {
        'completed' => (color: Resq.ready, label: 'Completed'),
        'cancelled' => (color: Resq.inkMuted, label: 'Cancelled'),
        'driver_assigned' || 'arrived' || 'en_route' => (color: Resq.info, label: 'In progress'),
        _ => (color: Resq.inkMuted, label: trip.status),
      };

  String get _time {
    final at = trip.assignedAt ?? trip.completedAt;
    if (at == null) return '';
    final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final minute = at.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${at.hour < 12 ? 'am' : 'pm'}';
  }

  @override
  Widget build(BuildContext context) {
    final outcome = _outcome;
    final arrival = trip.arrivalSeconds;

    return DriverCard(
      accent: outcome.color,
      padding: const EdgeInsets.all(Resq.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  trip.emergencyType?.isNotEmpty == true
                      ? trip.emergencyType!
                      : 'Emergency ${trip.caseNumber}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ResqType.bodyStrong(color: Resq.ink),
                ),
              ),
              Text(_time, style: ResqType.caption(color: Resq.inkMuted)),
            ],
          ),
          const SizedBox(height: 4),
          if (trip.address?.isNotEmpty == true)
            Text(
              trip.address!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ResqType.caption(color: Resq.inkMuted),
            ),
          const SizedBox(height: Resq.space2),
          Wrap(
            spacing: Resq.space2,
            runSpacing: Resq.space2,
            children: [
              _Tag(label: outcome.label, color: outcome.color),
              if (trip.hospitalName?.isNotEmpty == true)
                _Tag(label: trip.hospitalName!, color: Resq.inkMuted),
              if (arrival != null && arrival > 0)
                _Tag(
                  label: 'Reached in ${(arrival / 60).ceil()} min',
                  color: Resq.inkMuted,
                ),
              if (trip.urgencyLevel?.isNotEmpty == true)
                _Tag(
                  label: trip.urgencyLevel!,
                  color: trip.urgencyLevel == 'critical' ? Resq.critical : Resq.decision,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Resq.space2, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(Resq.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: ResqType.micro(color: color)),
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Resq.space6),
      child: Column(
        children: [
          Image.asset(
            AppAssets.stateNoHistory,
            height: 160,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.history_rounded, size: 72, color: Resq.inkFaint),
          ),
          const SizedBox(height: Resq.space4),
          Text('No runs yet', style: ResqType.section(color: Resq.ink)),
          const SizedBox(height: Resq.space2),
          Text(
            'Go on duty and the emergencies you answer will be listed here.',
            textAlign: TextAlign.center,
            style: ResqType.body(color: Resq.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Resq.space5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: Resq.inkFaint),
            const SizedBox(height: Resq.space3),
            Text(
              'Could not load your history',
              style: ResqType.section(color: Resq.ink),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Resq.space2),
            Text(
              message,
              textAlign: TextAlign.center,
              style: ResqType.caption(color: Resq.inkMuted),
            ),
            const SizedBox(height: Resq.space4),
            DriverButton(label: 'Try again', icon: Icons.refresh_rounded, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
