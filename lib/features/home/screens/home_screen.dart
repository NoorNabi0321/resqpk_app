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
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/sos_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../../camps/providers/camps_provider.dart';
import '../../first_aid/providers/first_aid_provider.dart';
import '../../sos/providers/session_provider.dart';
import '../../sos/providers/sos_provider.dart';
import '../../sos/widgets/reporter_phone_sheet.dart';
import '../providers/home_providers.dart';

/// Patient home — light, scrollable dashboard.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

    // No Scaffold, drawer or bottom bar here any more: AppShell owns the page
    // chrome, so this screen is only its content. The drawer duplicated the
    // tabs and hid the driver entry behind a hamburger menu.
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          // No account, no invented identity: the header shows a name only when
          // there is a real one to show.
          _Header(name: user?.fullName ?? ref.watch(sessionProvider).reporterName),
          const SizedBox(height: 14),
          _LocationBanner(isOnline: isOnline),
          const SizedBox(height: 22),
          // The SOS control sits above everything else on the screen. Nothing
          // should be scrolled past to reach it.
          _SosSection(state: sos),
          const SizedBox(height: 22),
          _MapCard(lat: position?.latitude, lng: position?.longitude),
          const SizedBox(height: 14),
          const _NearbyHospitals(),
          const SizedBox(height: 14),
          const _CampsCard(),
        ],
      ),
    );
  }
}

// --- Header ------------------------------------------------------------------

class _Header extends StatelessWidget {
  final String? name;
  const _Header({required this.name});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
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
        if (name != null && name!.isNotEmpty) ...[
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name!,
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
              name![0].toUpperCase(),
              style: TextStyle(
                color: AppLight.blue,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
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

class _CampsCard extends ConsumerWidget {
  const _CampsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final camps = ref.watch(nearbyCampsProvider).asData?.value ?? const [];

    return _SectionCard(
      title: 'Nearby Medical Camps',
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
              style: TextStyle(fontSize: 12.5, color: AppLight.textSecondary),
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
                    child: Icon(Icons.medical_services, color: AppLight.green, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          camps.first.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppLight.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              camps.first.distanceText ?? '',
                              style: TextStyle(fontSize: 11.5, color: AppLight.textSecondary),
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
                              style: TextStyle(fontSize: 11.5, color: AppLight.green),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppLight.textFaint, size: 20),
                ],
              ),
            ),
    );
  }
}

// --- Quick actions -----------------------------------------------------------

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.child,
    this.trailing,
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
                    fontSize: 15.5,
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


// --- SOS ---------------------------------------------------------------------

/// The reason the app exists, and now the largest thing on the screen.
///
/// The ring is driven by a local controller rather than the notifier's
/// one-second timer: a ring that jumps in thirds looks broken, and the user
/// needs to see continuous progress to know the hold is working.
class _SosSection extends ConsumerStatefulWidget {
  const _SosSection({required this.state});

  final SOSState state;

  @override
  ConsumerState<_SosSection> createState() => _SosSectionState();
}

class _SosSectionState extends ConsumerState<_SosSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: const Duration(seconds: SOSNotifier.holdSeconds),
  );

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _SosSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Cancelled elsewhere (case completed, error, cancel button) — put the ring
    // back so the next hold starts from empty.
    if (!widget.state.isSosCountingDown && _hold.value > 0 && _phase != SosButtonPhase.holding) {
      _hold.reset();
    }
  }

  /// A reporter with no account must leave a number the crew can ring — the
  /// backend refuses a case nobody can be called back on. Asked once, on the
  /// first emergency, and never again.
  bool get _needsPhone {
    if (ref.read(authProvider).isAuthenticated) return false;
    return !ref.read(sessionProvider).hasPhone;
  }

  /// The sheet's own button says "Save and call ambulance", so saving is the
  /// confirmation — making someone hold the button again after that would read
  /// as the app having ignored them.
  Future<void> _askForPhoneThenTrigger() async {
    final saved = await showReporterPhoneSheet(context);
    if (!saved || !mounted) return;
    await ref.read(sosProvider.notifier).triggerNow();
  }

  SosButtonPhase get _phase {
    final s = widget.state;
    if (s.status == SOSStatus.searching) return SosButtonPhase.searching;
    if (s.activeCaseId != null) return SosButtonPhase.active;
    if (s.isSosCountingDown) return SosButtonPhase.holding;
    return SosButtonPhase.idle;
  }

  String get _caption => switch (_phase) {
        SosButtonPhase.idle => 'Hold for 3 seconds to call an ambulance',
        SosButtonPhase.holding => 'Keep holding — let go to cancel',
        SosButtonPhase.searching => 'Offering your emergency to nearby ambulances',
        SosButtonPhase.active => 'An ambulance is assigned to you',
      };

  @override
  Widget build(BuildContext context) {
    final error = widget.state.error;

    return Column(
      children: [
        AnimatedBuilder(
          animation: _hold,
          builder: (_, __) => SosButton(
            phase: _phase,
            progress: _hold.value,
            onHoldStart: () {
              if (_needsPhone) {
                _askForPhoneThenTrigger();
                return;
              }
              _hold.forward(from: 0);
              ref.read(sosProvider.notifier).startSOSCountdown();
            },
            onHoldEnd: () {
              if (_hold.status != AnimationStatus.completed) {
                _hold.reverse();
                ref.read(sosProvider.notifier).cancelSOSCountdown();
              }
            },
            onTapWhenActive: () => context.push(Routes.tracking),
          ),
        ),
        const SizedBox(height: Resq.space4),
        Text(
          _caption,
          textAlign: TextAlign.center,
          style: ResqType.body(color: Resq.inkMuted),
        ),
        if (error != null) ...[
          const SizedBox(height: Resq.space3),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Resq.space3),
            decoration: BoxDecoration(
              color: Resq.criticalTint,
              borderRadius: BorderRadius.circular(Resq.radiusControl),
              border: Border.all(color: Resq.critical.withValues(alpha: 0.3)),
            ),
            child: Text(error, style: ResqType.caption(color: Resq.critical)),
          ),
        ],
      ],
    );
  }
}
