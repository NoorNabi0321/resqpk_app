import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/location/location_provider.dart';
import '../../../core/location/gps_persistence_provider.dart';
import '../../../core/map/resqpk_map.dart';
import '../../../core/realtime/realtime_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/back_guard.dart';
import '../../auth/providers/auth_provider.dart';
import '../../camps/providers/camps_provider.dart';
import '../../first_aid/providers/first_aid_provider.dart';
import '../../sos/providers/sos_provider.dart';
import '../providers/home_providers.dart';

/// Patient home — light, scrollable dashboard.
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
      ref.read(firstAidProvider.notifier).syncInBackground();
      ref.read(authProvider.notifier).checkAuthStatus();
      ref.read(connectivityServiceProvider).initialize();
    }
  }

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

    // Auto-navigate to live tracking once a driver is assigned / en route.
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
    final positionAsync = ref.watch(currentPositionStreamProvider);
    final locationService = ref.read(locationServiceProvider);
    final position = positionAsync.asData?.value ?? locationService.lastPosition;

    return ExitGuard(
      child: Scaffold(
        backgroundColor: AppLight.background,
        drawer: _AppDrawer(name: user?.fullName ?? 'Patient'),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    _Header(name: user?.fullName ?? 'Patient'),
                    const SizedBox(height: 14),
                    _LocationBanner(isOnline: isOnline),
                    const SizedBox(height: 14),
                    _MapCard(lat: position?.latitude, lng: position?.longitude),
                    const SizedBox(height: 14),
                    const _NearbyHospitals(),
                    const SizedBox(height: 14),
                    _SosBanner(state: sos, pulse: _pulseController),
                    const SizedBox(height: 14),
                    _CampsAndSmsRow(isOnline: isOnline),
                    const SizedBox(height: 14),
                    const _QuickActions(),
                  ],
                ),
              ),
              const _BottomNav(),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Header ------------------------------------------------------------------

class _Header extends StatelessWidget {
  final String name;
  const _Header({required this.name});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CircleButton(
          icon: Icons.menu,
          onTap: () => Scaffold.of(context).openDrawer(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'ResQ',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppLight.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'PK',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppLight.red,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Text(
                'Swift Response, Smart Coordination',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: AppLight.textSecondary),
              ),
            ],
          ),
        ),
        _CircleButton(
          icon: Icons.notifications_none,
          badge: true,
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Alerts are coming soon')),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppLight.textPrimary,
                ),
              ),
              Text('Patient', style: TextStyle(fontSize: 11.5, color: AppLight.blue)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        CircleAvatar(
          radius: 20,
          backgroundColor: AppLight.blueTint,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
              color: AppLight.blue,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool badge;

  const _CircleButton({required this.icon, required this.onTap, this.badge = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppLight.card,
          shape: BoxShape.circle,
          border: Border.all(color: AppLight.border),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: AppLight.textPrimary, size: 21),
            if (badge)
              Positioned(
                top: 10,
                right: 11,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppLight.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppLight.card, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- Location banner ---------------------------------------------------------

class _LocationBanner extends ConsumerWidget {
  final bool isOnline;
  const _LocationBanner({required this.isOnline});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final address = ref.watch(currentAddressProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppLight.navy, AppLight.navyDeep],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppLight.blue.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.my_location, color: Colors.white, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Location',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  address.asData?.value ?? 'Locating…',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFB9C3D4), fontSize: 12.5),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: (isOnline ? AppLight.green : AppLight.red).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: isOnline ? const Color(0xFF3DDC84) : AppLight.redSoft,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  isOnline ? 'Live' : 'Offline',
                  style: TextStyle(
                    color: isOnline ? const Color(0xFF3DDC84) : AppLight.redSoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Map card ----------------------------------------------------------------

class _MapCard extends ConsumerStatefulWidget {
  final double? lat;
  final double? lng;

  const _MapCard({required this.lat, required this.lng});

  @override
  ConsumerState<_MapCard> createState() => _MapCardState();
}

class _MapCardState extends ConsumerState<_MapCard> {
  final MapController _controller = MapController();
  bool _centeredOnUser = false;

  LatLng get _center => LatLng(widget.lat ?? 25.3792, widget.lng ?? 68.3683);

  @override
  void didUpdateWidget(covariant _MapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_centeredOnUser && widget.lat != null && widget.lng != null) {
      _centeredOnUser = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.move(_center, MapSpec.navigationZoom);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFix = widget.lat != null && widget.lng != null;
    final hospitals = ref.watch(nearbyHospitalsProvider).asData?.value ?? const [];
    final camps = ref.watch(nearbyCampsProvider).asData?.value ?? const [];

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 300,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: MapSpec.navigationZoom,
                minZoom: 3,
                maxZoom: 19,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.drag |
                      InteractiveFlag.flingAnimation |
                      InteractiveFlag.pinchZoom |
                      InteractiveFlag.pinchMove |
                      InteractiveFlag.doubleTapZoom,
                ),
              ),
              children: [
                const ResQPKTileLayer(light: true),
                // Soft accuracy halo around the user, as in the reference.
                if (hasFix)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: _center,
                        radius: 90,
                        useRadiusInMeter: false,
                        color: AppLight.red.withValues(alpha: 0.10),
                        borderColor: AppLight.red.withValues(alpha: 0.18),
                        borderStrokeWidth: 1,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    for (final h in hospitals.take(6))
                      if (h['lat'] != null && h['lng'] != null)
                        Marker(
                          point: LatLng(
                            double.tryParse('${h['lat']}') ?? 0,
                            double.tryParse('${h['lng']}') ?? 0,
                          ),
                          width: MapSpec.touchTarget,
                          height: MapSpec.pinHeight,
                          alignment: Alignment.topCenter,
                          child: const MapDestinationPin(
                            color: AppLight.red,
                            icon: Icons.local_hospital,
                          ),
                        ),
                    for (final c in camps.take(6))
                      Marker(
                        point: LatLng(c.lat, c.lng),
                        width: MapSpec.touchTarget,
                        height: MapSpec.pinHeight,
                        alignment: Alignment.topCenter,
                        child: const MapDestinationPin(
                          color: AppLight.green,
                          icon: Icons.medical_services,
                        ),
                      ),
                    if (hasFix)
                      Marker(
                        point: _center,
                        width: MapSpec.touchTarget,
                        height: MapSpec.touchTarget,
                        child: const UserLocationDot(color: AppLight.blue),
                      ),
                  ],
                ),
              ],
            ),
            Positioned(
              right: 12,
              bottom: 46,
              child: _MapFab(
                icon: Icons.my_location,
                onTap: () {
                  if (widget.lat == null || widget.lng == null) return;
                  _controller.move(_center, MapSpec.navigationZoom);
                },
              ),
            ),
            Positioned(
              right: 12,
              bottom: 0,
              child: _MapFab(
                icon: Icons.navigation_outlined,
                onTap: () async {
                  if (widget.lat == null) return;
                  final uri = Uri.parse(
                    'https://www.google.com/maps/search/?api=1&query=${widget.lat},${widget.lng}',
                  );
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapFab extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapFab({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppLight.card,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8),
          ],
        ),
        child: Icon(icon, color: AppLight.blue, size: 20),
      ),
    );
  }
}

// --- Nearby hospitals --------------------------------------------------------

class _NearbyHospitals extends ConsumerWidget {
  const _NearbyHospitals();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hospitalsAsync = ref.watch(nearbyHospitalsProvider);
    final hospitals = hospitalsAsync.asData?.value ?? const [];

    return _SectionCard(
      title: 'Nearby Hospitals',
      trailing: hospitals.isEmpty
          ? null
          : GestureDetector(
              onTap: () => _showAll(context, hospitals),
              child: Text(
                'View all',
                style: TextStyle(
                  color: AppLight.blue,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
      child: hospitalsAsync.isLoading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          : hospitals.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'No hospitals found nearby.',
                    style: TextStyle(color: AppLight.textSecondary, fontSize: 13),
                  ),
                )
              : Column(
                  children: hospitals
                      .take(3)
                      .map((h) => _HospitalTile(hospital: h))
                      .toList(),
                ),
    );
  }

  void _showAll(BuildContext context, List<Map<String, dynamic>> hospitals) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppLight.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nearby Hospitals',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppLight.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: hospitals.map((h) => _HospitalTile(hospital: h)).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HospitalTile extends StatelessWidget {
  final Map<String, dynamic> hospital;
  const _HospitalTile({required this.hospital});

  Future<void> _call(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final name = hospital['name']?.toString() ?? 'Hospital';
    final distance = hospital['distanceText']?.toString() ?? '';
    final phone = hospital['emergency_phone']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppLight.cardAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppLight.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppLight.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(Icons.local_hospital, color: AppLight.red, size: 25),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppLight.textPrimary,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$distance away',
                  style: TextStyle(fontSize: 12, color: AppLight.textSecondary),
                ),
                if (hospital['has_emergency_ward'] == true) ...[
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppLight.greenTint,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '24/7 Available',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppLight.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _call(phone),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppLight.card,
                shape: BoxShape.circle,
                border: Border.all(color: AppLight.border),
              ),
              child: Icon(Icons.phone, color: AppLight.green, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// --- SOS banner --------------------------------------------------------------

class _SosBanner extends ConsumerWidget {
  final SOSState state;
  final Animation<double> pulse;

  const _SosBanner({required this.state, required this.pulse});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counting = state.isSosCountingDown;
    final active = state.activeCaseId != null;
    final searching = state.status == SOSStatus.searching && !active;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppLight.red, AppLight.redSoft],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: AppLight.red.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SOS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Tap for\nEmergency',
                  style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.3),
                ),
              ],
            ),
          ),
          GestureDetector(
            onLongPressStart: state.status == SOSStatus.idle
                ? (_) => ref.read(sosProvider.notifier).startSOSCountdown()
                : null,
            onLongPressEnd: (_) {
              if (state.isSosCountingDown) {
                ref.read(sosProvider.notifier).cancelSOSCountdown();
              }
            },
            child: AnimatedBuilder(
              animation: pulse,
              builder: (context, child) {
                final t = counting ? 0.0 : pulse.value;
                return SizedBox(
                  width: 106,
                  height: 106,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (!counting)
                        Container(
                          width: 92 * (1 + t * 0.16),
                          height: 92 * (1 + t * 0.16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.45 * (1 - t)),
                              width: 2,
                            ),
                          ),
                        ),
                      if (counting)
                        SizedBox(
                          width: 100,
                          height: 100,
                          child: CircularProgressIndicator(
                            value: (10 - state.sosCountdownSeconds) / 10,
                            strokeWidth: 5,
                            color: Colors.white,
                            backgroundColor: Colors.white24,
                          ),
                        ),
                      Container(
                        width: 88,
                        height: 88,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: child,
                      ),
                    ],
                  ),
                );
              },
              child: Center(
                child: counting
                    ? Text(
                        '${state.sosCountdownSeconds}',
                        style: TextStyle(
                          color: AppLight.red,
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.emergency_share, color: AppLight.red, size: 30),
                          Text(
                            'SOS',
                            style: TextStyle(
                              color: AppLight.red,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    counting
                        ? 'Release to cancel'
                        : searching
                            ? 'Searching for the\nnearest ambulance…'
                            : active
                                ? 'Emergency active'
                                : 'Press and hold\nfor 10 seconds',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // A failed SOS must say so — this is the one action that
                  // cannot be allowed to fail silently.
                  Text(
                    state.error ?? 'We will alert the\nnearest responders',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: state.error != null ? Colors.white : Colors.white70,
                      fontSize: 11.5,
                      height: 1.3,
                      fontWeight: state.error != null ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Camps + SMS row ---------------------------------------------------------

class _CampsAndSmsRow extends ConsumerWidget {
  final bool isOnline;
  const _CampsAndSmsRow({required this.isOnline});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final camps = ref.watch(nearbyCampsProvider).asData?.value ?? const [];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _SectionCard(
              title: 'Nearby Medical Camps',
              titleSize: 13.5,
              trailing: camps.isEmpty
                  ? null
                  : GestureDetector(
                      onTap: () => context.push(Routes.camps),
                      child: Text(
                        'View all',
                        style: TextStyle(
                          color: AppLight.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
              child: camps.isEmpty
                  ? Text(
                      'No camps running near you.',
                      style: TextStyle(fontSize: 12, color: AppLight.textSecondary),
                    )
                  : GestureDetector(
                      onTap: () => context.push(Routes.camps),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppLight.greenTint,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.medical_services,
                                color: AppLight.green, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  camps.first.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppLight.textPrimary,
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Text(
                                      camps.first.distanceText ?? '',
                                      style: TextStyle(
                                          fontSize: 11, color: AppLight.textSecondary),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: AppLight.green,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Ongoing',
                                      style: TextStyle(
                                          fontSize: 11, color: AppLight.green),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SectionCard(
              title: 'Offline SMS SOS',
              titleSize: 13.5,
              trailing: Icon(
                isOnline ? Icons.signal_cellular_alt : Icons.signal_cellular_off,
                size: 17,
                color: isOnline ? AppLight.textFaint : AppLight.red,
              ),
              child: GestureDetector(
                onTap: () => context.push(Routes.offlineSos),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppLight.blueTint,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.sms, color: AppLight.blue, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Send SOS via SMS\n(Works Offline)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppLight.textPrimary,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Works without internet',
                            style: TextStyle(fontSize: 11, color: AppLight.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Quick actions -----------------------------------------------------------

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        icon: Icons.assignment_ind,
        label: 'Medical Profile',
        tint: AppLight.blueTint,
        color: AppLight.blue,
        onTap: () => context.push(Routes.medicalProfile),
      ),
      (
        icon: Icons.favorite,
        label: 'First Aid Guide',
        tint: const Color(0xFFFDE8EA),
        color: AppLight.red,
        onTap: () => context.push(Routes.firstAid),
      ),
      (
        icon: Icons.groups,
        label: 'My Contacts',
        tint: AppLight.amberTint,
        color: AppLight.amber,
        onTap: () => context.push(Routes.profile),
      ),
      (
        icon: Icons.shield,
        label: 'Safety Tips',
        tint: AppLight.tealTint,
        color: const Color(0xFF0D9488),
        onTap: () => context.push(Routes.firstAid),
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppLight.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppLight.border),
      ),
      child: Row(
        children: items
            .map(
              (item) => Expanded(
                child: GestureDetector(
                  onTap: item.onTap,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: item.tint,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(item.icon, color: item.color, size: 21),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        item.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppLight.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// --- Shared card shell -------------------------------------------------------

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  final double titleSize;

  const _SectionCard({
    required this.title,
    required this.child,
    this.trailing,
    this.titleSize = 15.5,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppLight.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppLight.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w700,
                    color: AppLight.textPrimary,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// --- Drawer ------------------------------------------------------------------

class _AppDrawer extends ConsumerWidget {
  final String name;
  const _AppDrawer({required this.name});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget tile(IconData icon, String label, VoidCallback onTap) => ListTile(
          leading: Icon(icon, color: AppLight.textSecondary, size: 21),
          title: Text(label,
              style: TextStyle(fontSize: 14.5, color: AppLight.textPrimary)),
          onTap: onTap,
        );

    return Drawer(
      backgroundColor: AppLight.card,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppLight.blueTint,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                          color: AppLight.blue, fontWeight: FontWeight.bold, fontSize: 19),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppLight.textPrimary,
                            )),
                        Text('Patient',
                            style: TextStyle(fontSize: 12.5, color: AppLight.blue)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            tile(Icons.person, 'Profile', () {
              Navigator.pop(context);
              context.push(Routes.profile);
            }),
            tile(Icons.assignment_ind, 'Medical Profile', () {
              Navigator.pop(context);
              context.push(Routes.medicalProfile);
            }),
            tile(Icons.favorite, 'First Aid Guide', () {
              Navigator.pop(context);
              context.push(Routes.firstAid);
            }),
            tile(Icons.medical_services, 'Nearby Camps', () {
              Navigator.pop(context);
              context.push(Routes.camps);
            }),
            tile(Icons.sms, 'Offline SMS SOS', () {
              Navigator.pop(context);
              context.push(Routes.offlineSos);
            }),
            const Spacer(),
            const Divider(height: 1),
            tile(Icons.logout, 'Log out', () async {
              Navigator.pop(context);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go(Routes.roleSelect);
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// --- Bottom nav --------------------------------------------------------------

class _BottomNav extends ConsumerWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasActiveCase = ref.watch(sosProvider).activeCaseId != null;

    void notBuilt(String what) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$what is coming soon')),
        );

    return Container(
      padding: EdgeInsets.only(
        top: 8,
        bottom: 8 + MediaQuery.paddingOf(context).bottom,
        left: 8,
        right: 8,
      ),
      decoration: BoxDecoration(
        color: AppLight.card,
        border: Border(top: BorderSide(color: AppLight.border)),
      ),
      child: Row(
        children: [
          _NavItem(icon: Icons.home_rounded, label: 'Home', active: true, onTap: () {}),
          _NavItem(
            icon: Icons.location_on_rounded,
            label: 'Tracking',
            onTap: () {
              if (hasActiveCase) {
                context.go(Routes.tracking);
              } else {
                notBuilt('Tracking is available during an emergency — it');
              }
            },
          ),
          _NavItem(
            icon: Icons.history_rounded,
            label: 'History',
            onTap: () => notBuilt('Case history'),
          ),
          _NavItem(
            icon: Icons.notifications_rounded,
            label: 'Alerts',
            onTap: () => notBuilt('Alerts'),
          ),
          _NavItem(
            icon: Icons.person_rounded,
            label: 'Profile',
            onTap: () => context.push(Routes.profile),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppLight.red : AppLight.textFaint;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 23),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
