import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/location/location_provider.dart';
import '../../../core/location/gps_persistence_provider.dart';
import '../../../core/realtime/realtime_provider.dart';
import '../../../core/router/app_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../camps/providers/camps_provider.dart';
import '../../first_aid/providers/first_aid_provider.dart';
import '../../sos/providers/sos_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    Future.microtask(_warmLocation);
    Future.microtask(_startGpsPersistence);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh content + session + connectivity when the app comes back.
      ref.read(firstAidProvider.notifier).syncInBackground();
      ref.read(authProvider.notifier).checkAuthStatus();
      ref.read(connectivityServiceProvider).initialize();
    }
  }

  // Keep the backend's last-known location fresh so offline (SMS) SOS works.
  Future<void> _startGpsPersistence() async {
    final gps = ref.read(gpsPersistenceServiceProvider);
    await gps.initialize();
    gps.startPersisting();
  }

  Future<void> _warmLocation() async {
    final locationService = ref.read(locationServiceProvider);
    try {
      await locationService.getCurrentPosition();
      await locationService.startTracking();
    } catch (_) {
      // The SOS trigger surfaces location errors when the user actually needs help.
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(socketConnectionProvider);
    ref.watch(etaListenerProvider);

    // Auto-navigate to live tracking once a driver is assigned / en route / arrived.
    ref.listen(sosProvider.select((s) => s.status), (_, status) {
      if (status == SOSStatus.driverAssigned ||
          status == SOSStatus.enRoute ||
          status == SOSStatus.arrived) {
        context.go(Routes.tracking);
      } else if (status == SOSStatus.noDriverFound) {
        context.go(Routes.noDriver);
      }
    });

    final user = ref.watch(currentUserProvider);
    final sos = ref.watch(sosProvider);
    final isOnline = ref.watch(isOnlineProvider).value ?? true;
    final isConnected = ref.watch(socketServiceProvider).isConnected;
    final positionAsync = ref.watch(currentPositionStreamProvider);
    final locationService = ref.read(locationServiceProvider);
    final position = positionAsync.asData?.value ?? locationService.lastPosition;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            children: [
              _TopBar(
                name: user?.fullName ?? 'Patient',
                accuracyLabel:
                    position == null ? 'Locating' : locationService.getAccuracyLabel(position),
                accuracyMeters: position?.accuracy,
              ),
              _OfflineBanner(
                isOnline: isOnline,
                onTap: () => context.push(Routes.offlineSos),
              ),
              const SizedBox(height: 16),
              Expanded(
                flex: 5,
                child: _LocationMap(
                  lat: position?.latitude,
                  lng: position?.longitude,
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                flex: 6,
                child: _SOSPanel(
                  state: sos,
                  isConnected: isConnected,
                  pulse: _pulseController,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String name;
  final String accuracyLabel;
  final double? accuracyMeters;

  const _TopBar({
    required this.name,
    required this.accuracyLabel,
    required this.accuracyMeters,
  });

  @override
  Widget build(BuildContext context) {
    final color = _accuracyColor(accuracyMeters);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ResQPK', style: AppTextStyles.display.copyWith(fontSize: 28)),
              const SizedBox(height: 2),
              Text(
                'Ready, $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.borderGlass),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(accuracyLabel, style: AppTextStyles.caption.copyWith(color: color)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LocationMap extends StatefulWidget {
  final double? lat;
  final double? lng;

  const _LocationMap({required this.lat, required this.lng});

  @override
  State<_LocationMap> createState() => _LocationMapState();
}

class _LocationMapState extends State<_LocationMap> {
  final MapController _controller = MapController();
  bool _centeredOnUser = false;

  LatLng get _center => LatLng(widget.lat ?? 25.3792, widget.lng ?? 68.3683);

  @override
  void didUpdateWidget(covariant _LocationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recenter on the user the first time a real GPS fix arrives, without
    // fighting the user afterwards (they can pan/zoom freely).
    if (!_centeredOnUser && widget.lat != null && widget.lng != null) {
      _centeredOnUser = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.move(_center, 15.5);
      });
    }
  }

  void _recenter() {
    if (widget.lat == null || widget.lng == null) return;
    _controller.move(_center, 15.5);
  }

  @override
  Widget build(BuildContext context) {
    final hasFix = widget.lat != null && widget.lng != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 15.5,
              minZoom: 3,
              maxZoom: 18,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.drag |
                    InteractiveFlag.flingAnimation |
                    InteractiveFlag.pinchZoom |
                    InteractiveFlag.pinchMove |
                    InteractiveFlag.doubleTapZoom,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: AppConstants.mapTileUrl,
                userAgentPackageName: 'com.resqpk.resqpk_app',
              ),
              if (hasFix)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _center,
                      width: 72,
                      height: 72,
                      child: const _PatientPin(),
                    ),
                  ],
                ),
            ],
          ),
          // Coordinates / status chip (bottom-left).
          Positioned(
            left: 12,
            bottom: 12,
            child: _MapChip(
              child: Text(
                hasFix
                    ? '${widget.lat!.toStringAsFixed(5)}, ${widget.lng!.toStringAsFixed(5)}'
                    : 'Finding your location...',
                style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
              ),
            ),
          ),
          // Recenter-on-me button (bottom-right).
          Positioned(
            right: 12,
            bottom: 12,
            child: GestureDetector(
              onTap: _recenter,
              child: _MapChip(
                padding: const EdgeInsets.all(9),
                child: Icon(
                  Icons.my_location,
                  size: 18,
                  color: hasFix ? AppColors.sosRed : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapChip extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _MapChip({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderGlass),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PatientPin extends StatefulWidget {
  const _PatientPin();

  @override
  State<_PatientPin> createState() => _PatientPinState();
}

class _PatientPinState extends State<_PatientPin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1 + (_controller.value * 1.4);
        final opacity = 1 - _controller.value;
        return Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: scale,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.sosGlow.withValues(alpha: 0.45 * opacity),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.sosRed,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [BoxShadow(color: AppColors.sosGlow, blurRadius: 18)],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SOSPanel extends ConsumerWidget {
  final SOSState state;
  final bool isConnected;
  final Animation<double> pulse;

  const _SOSPanel({
    required this.state,
    required this.isConnected,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusText = state.error ?? _statusText(state.status);
    final isOnline = ref.watch(isOnlineProvider).value ?? true;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ConnectivityPill(isConnected: isConnected),
        if (statusText != null) ...[
          const SizedBox(height: 12),
          Text(
            statusText,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
        Expanded(
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = math
                    .min(constraints.maxWidth, constraints.maxHeight)
                    .clamp(0.0, 220.0)
                    .toDouble();
                return _emergencyButton(context, ref, size);
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          state.isSosCountingDown
              ? ''
              : !isOnline
                  ? 'Offline? Use the red banner above'
                  : state.activeCaseId == null
                      ? 'Hold 10 seconds to call for help'
                      : 'Emergency case active',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: 10),
        const _NearbyCampsCard(),
        OutlinedButton.icon(
          onPressed: () => context.push(Routes.offlineSos),
          icon: const Icon(Icons.sms_outlined, size: 16, color: AppColors.textSecondary),
          label: Text('SMS SOS (works offline)',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.borderGlass)),
        ),
        const SizedBox(height: 12),
        const _BottomNav(),
      ],
    );
  }

  /// The circular hold-to-trigger SOS button. [size] is the diameter, chosen by
  /// the parent LayoutBuilder to fit the available space.
  Widget _emergencyButton(BuildContext context, WidgetRef ref, double size) {
    final counting = state.isSosCountingDown;

    return GestureDetector(
      onLongPressStart: state.status == SOSStatus.idle
          ? (_) => ref.read(sosProvider.notifier).startSOSCountdown()
          : null,
      onLongPressEnd: (_) {
        if (state.isSosCountingDown) {
          ref.read(sosProvider.notifier).cancelSOSCountdown();
        }
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        scale: counting ? 1.04 : 1,
        child: AnimatedBuilder(
          animation: pulse,
          builder: (context, child) {
            final ring = counting ? 0.0 : pulse.value;
            return SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Idle: an expanding, fading halo ring around the circle.
                  if (!counting)
                    Transform.scale(
                      scale: 1 + (ring * 0.26),
                      child: Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.sosGlow.withValues(alpha: 0.55 * (1 - ring)),
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                  // Counting: the 10-second progress ring hugging the circle.
                  if (counting)
                    SizedBox(
                      width: size + 8,
                      height: size + 8,
                      child: CircularProgressIndicator(
                        value: (10 - state.sosCountdownSeconds) / 10,
                        strokeWidth: 6,
                        color: Colors.white,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                  // The red circle itself.
                  Container(
                    width: size,
                    height: size,
                    decoration: const BoxDecoration(
                      color: AppColors.sosRed,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: AppColors.sosGlow, blurRadius: 40, spreadRadius: 2),
                      ],
                    ),
                    child: child,
                  ),
                ],
              ),
            );
          },
          child: Center(
            child: counting
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${state.sosCountdownSeconds}',
                        style: AppTextStyles.display.copyWith(
                          color: Colors.white,
                          fontSize: 56,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Release to cancel',
                        style: AppTextStyles.caption.copyWith(color: Colors.white70),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sos_rounded, color: Colors.white, size: 46),
                      const SizedBox(height: 4),
                      Text(
                        'EMERGENCY',
                        style: AppTextStyles.buttonLabel.copyWith(
                          fontSize: 15,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Compact entry point to Nearby Camps. Renders nothing when there are no
/// camps — the home screen stays uncluttered for the emergency case.
class _NearbyCampsCard extends ConsumerWidget {
  const _NearbyCampsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final camps = ref.watch(nearbyCampsProvider).asData?.value ?? const [];
    if (camps.isEmpty) return const SizedBox.shrink();

    final nearest = camps.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => context.push(Routes.camps),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.confirmedGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.confirmedGreen.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.medical_services_outlined,
                  color: AppColors.confirmedGreen, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${camps.length} free medical camp${camps.length == 1 ? '' : 's'} near you',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.confirmedGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${nearest.name}${nearest.distanceText != null ? ' · ${nearest.distanceText}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.confirmedGreen, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  final bool isOnline;
  final VoidCallback onTap;

  const _OfflineBanner({required this.isOnline, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isOnline ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        height: isOnline ? 0 : 44,
        margin: EdgeInsets.only(top: isOnline ? 0 : 10),
        decoration: BoxDecoration(
          color: AppColors.sosRed.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        clipBehavior: Clip.hardEdge,
        child: isOnline
            ? const SizedBox.shrink()
            : Text(
                '📵 Offline — Tap for SMS emergency',
                style: AppTextStyles.caption.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}

class _ConnectivityPill extends StatelessWidget {
  final bool isConnected;

  const _ConnectivityPill({required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final color = isConnected ? AppColors.confirmedGreen : AppColors.sosRed;
    final label = isConnected ? 'Online' : 'Offline mode: SMS SOS available';
    return Align(
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surfaceTwo,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.borderGlass),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(label, style: AppTextStyles.caption.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends ConsumerWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.borderGlass),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              const _NavItem(icon: Icons.home_rounded, label: 'Home', active: true),
              _NavItem(
                icon: Icons.location_on_rounded,
                label: 'Track',
                onTap: () {
                  if (ref.read(sosProvider).activeCaseId != null) {
                    context.push(Routes.tracking);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No active emergency. Press SOS for help.'),
                        backgroundColor: AppColors.surfaceTwo,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
              _NavItem(
                icon: Icons.medical_services_rounded,
                label: 'Aid',
                onTap: () => context.push(Routes.firstAid),
              ),
              _NavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                onTap: () => context.push(Routes.profile),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.sosRed : AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: active ? 24 : 21),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.caption.copyWith(color: color, fontSize: 10)),
        ],
      ),
    );
  }
}

Color _accuracyColor(double? accuracy) {
  if (accuracy == null) return AppColors.warningAmber;
  if (accuracy < 30) return AppColors.confirmedGreen;
  if (accuracy <= 60) return AppColors.warningAmber;
  return AppColors.sosRed;
}

String? _statusText(SOSStatus status) {
  switch (status) {
    case SOSStatus.searching:
      return 'Searching for the nearest ambulance...';
    case SOSStatus.driverAssigned:
      return 'Ambulance assigned. Keep your phone nearby.';
    case SOSStatus.enRoute:
      return 'Ambulance is heading to hospital.';
    case SOSStatus.arrived:
      return 'Driver has arrived at your location.';
    case SOSStatus.noDriverFound:
      return 'No ambulance found. Call 1122, Edhi 115, or Chhipa 1020.';
    case SOSStatus.error:
      return 'Could not start SOS. Check location and connection.';
    default:
      return null;
  }
}
