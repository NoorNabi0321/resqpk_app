import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/location/location_provider.dart';
import '../../../core/realtime/realtime_provider.dart';
import '../../../core/router/app_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../sos/data/models/dispatch_request_model.dart';
import '../providers/driver_realtime_provider.dart';
import 'dispatch_request_screen.dart';

/// Module 3 working driver screen: go online/offline + live GPS broadcast.
/// Module 4 replaces this with the full dispatch UI.
class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  int _broadcastCount = 0;
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
        const SnackBar(content: Text('Request expired — another driver took it')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep the socket connected while this screen is open.
    ref.watch(socketConnectionProvider);

    // Incoming dispatch requests → full-screen overlay.
    ref.listen(caseUpdateStreamProvider, (_, next) {
      next.whenData((data) {
        if (data['event'] == 'case_created') {
          _showDispatchRequest(DispatchRequestModel.fromJson(data));
        }
      });
    });

    // Count each location broadcast the backend echoes back to us.
    ref.listen(driverLocationStreamProvider, (_, next) {
      next.whenData((_) {
        if (mounted) setState(() => _broadcastCount++);
      });
    });

    // Reset the counter when going offline.
    ref.listen(driverOnlineProvider.select((s) => s.isOnline), (_, isOnline) {
      if (!isOnline && mounted) setState(() => _broadcastCount = 0);
    });

    // Surface errors from going online/offline.
    ref.listen(driverOnlineProvider.select((s) => s.error), (_, error) {
      if (error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      }
    });

    final driverState = ref.watch(driverOnlineProvider);
    final isConnected = ref.watch(socketServiceProvider).isConnected;
    final isOnline = ref.watch(isOnlineProvider).value ?? true;
    final positionAsync = ref.watch(currentPositionStreamProvider);
    final position = positionAsync.asData?.value ?? driverState.currentPosition;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text('Driver', style: AppTextStyles.display.copyWith(fontSize: 28)),
              const SizedBox(height: 6),
              _connectionRow(isConnected),
              if (!isOnline) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.warningAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warningAmber.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '📵 Offline — location updates paused. They resume automatically when back online.',
                    style: AppTextStyles.caption.copyWith(color: AppColors.warningAmber),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              _toggle(driverState),
              const SizedBox(height: 24),
              _gpsCard(position),
              const SizedBox(height: 16),
              _infoCard('Location updates sent', '$_broadcastCount'),
              const SizedBox(height: 16),
              _infoCard(
                'Coordinates',
                position != null
                    ? '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}'
                    : '—',
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () async {
                  if (driverState.isOnline) {
                    await ref.read(driverOnlineProvider.notifier).goOffline();
                  }
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go(Routes.roleSelect);
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.sosRed),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('Logout',
                    style: AppTextStyles.buttonLabel.copyWith(color: AppColors.sosRed)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _connectionRow(bool isConnected) {
    final color = isConnected ? AppColors.confirmedGreen : AppColors.sosRed;
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(isConnected ? 'Connected to ResQPK' : 'Disconnected',
            style: AppTextStyles.caption.copyWith(color: color)),
      ],
    );
  }

  Widget _toggle(DriverOnlineState s) {
    final online = s.isOnline;
    return GestureDetector(
      onTap: s.isLoading
          ? null
          : () {
              final notifier = ref.read(driverOnlineProvider.notifier);
              if (online) {
                notifier.goOffline();
              } else {
                notifier.goOnline();
              }
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 72,
        decoration: BoxDecoration(
          color: online ? AppColors.confirmedGreen : AppColors.surfaceThree,
          borderRadius: BorderRadius.circular(36),
        ),
        alignment: Alignment.center,
        child: s.isLoading
            ? const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
              )
            : Text(
                online ? 'You are Online' : 'You are Offline',
                style: AppTextStyles.buttonLabel
                    .copyWith(color: online ? Colors.white : AppColors.textSecondary),
              ),
      ),
    );
  }

  Widget _gpsCard(Position? position) {
    String label = 'Waiting for GPS…';
    Color color = AppColors.textSecondary;
    if (position != null) {
      final acc = position.accuracy;
      label = 'GPS accuracy: ${acc.toStringAsFixed(0)} m';
      color = acc < 30
          ? AppColors.confirmedGreen
          : (acc <= 60 ? AppColors.warningAmber : AppColors.sosRed);
    }
    return _shell(
      child: Row(
        children: [
          Icon(Icons.gps_fixed, color: color, size: 20),
          const SizedBox(width: 12),
          Text(label, style: AppTextStyles.body.copyWith(color: color)),
        ],
      ),
    );
  }

  Widget _infoCard(String label, String value) {
    return _shell(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.caption),
          Text(value, style: AppTextStyles.subtitle),
        ],
      ),
    );
  }

  Widget _shell({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceTwo,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGlass),
      ),
      child: child,
    );
  }
}
