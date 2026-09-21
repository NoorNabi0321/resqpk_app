import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/location/gps_persistence_provider.dart';
import '../../../core/location/location_provider.dart';
import '../../../core/map/resqpk_map.dart';
import '../../../core/realtime/realtime_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/map_card.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/resq_card.dart';
import '../../../core/widgets/sos_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/providers/auth_provider.dart';
import '../../camps/providers/camps_provider.dart';
import '../../first_aid/data/models/first_aid_guide_model.dart';
import '../../first_aid/providers/first_aid_provider.dart';
import '../../sos/providers/session_provider.dart';
import '../../sos/providers/sos_provider.dart';
import '../../sos/widgets/reporter_phone_sheet.dart';
import '../providers/home_providers.dart';

/// The patient's home screen: one enormous button, and everything else in
/// service of it.
///
/// The order on this screen is the order of urgency — where you are, how to get
/// help, what is near you. Nothing above the SOS button, and nothing that has
/// to be scrolled past to reach it.
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
      // They may have just come back from the system settings screen having
      // granted location — ask again rather than keeping the warning up.
      ref.invalidate(locationAccessProvider);
    }
  }

  Future<void> _startGpsPersistence() async {
    final gps = ref.read(gpsPersistenceServiceProvider);
    await gps.initialize();
    gps.startPersisting();
  }

  Future<void> _warmLocation() async {
    final locationService = ref.read(locationServiceProvider);
    Position? position;
    try {
      position = await locationService.getCurrentPosition();
      await locationService.startTracking();
    } catch (_) {
      // The SOS trigger surfaces location errors when the user actually needs help.
    }
    if (!mounted) return;

    ref.invalidate(locationAccessProvider);

    // The lists run before the first fix exists and correctly come back empty.
    // Once there is a position, ask them again — otherwise "no hospitals near
    // you" would stand until the user thought to pull down.
    if (position != null) {
      ref.invalidate(nearbyHospitalsProvider);
      ref.invalidate(nearbyCampsProvider);
      ref.invalidate(currentAddressProvider);
    }
    setState(() {});
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
    final positionAsync = ref.watch(currentPositionStreamProvider);
    final position = positionAsync.asData?.value ?? ref.read(locationServiceProvider).lastPosition;

    // No Scaffold, drawer or bottom bar here: AppShell owns the page chrome and
    // the active-case banner, so this screen is only its content.
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: RefreshIndicator(
              color: Resq.brandInk,
              onRefresh: () async {
                ref.invalidate(nearbyHospitalsProvider);
                ref.invalidate(nearbyCampsProvider);
                ref.invalidate(currentAddressProvider);
                ref.invalidate(locationAccessProvider);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Resq.space4,
                  Resq.space3,
                  Resq.space4,
                  Resq.space6,
                ),
                children: [
                  // No account, no invented identity: a name appears only when
                  // there is a real one.
                  _Header(name: user?.fullName ?? ref.watch(sessionProvider).reporterName),
                  const SizedBox(height: Resq.space4),
                  const _LocationStrip(),
                  const SizedBox(height: Resq.space5),
                  _SosSection(state: sos),
                  const SizedBox(height: Resq.space6),
                  _MapPreview(lat: position?.latitude, lng: position?.longitude),
                  const SizedBox(height: Resq.space5),
                  const _HospitalsTile(),
                  const SizedBox(height: Resq.space5),
                  const _CampsTile(),
                  const SizedBox(height: Resq.space5),
                  const _FirstAidTile(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Header ------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(AppAssets.logoWordmark, height: 30, alignment: Alignment.centerLeft),
              const SizedBox(height: 2),
              Text('Emergency help in Hyderabad', style: ResqType.caption()),
            ],
          ),
        ),
        _RoundAction(
          icon: Icons.receipt_long_rounded,
          tooltip: 'My requests',
          onTap: () => context.push(Routes.myRequests),
        ),
        if (name != null && name!.isNotEmpty) ...[
          const SizedBox(width: Resq.space2),
          CircleAvatar(
            radius: 21,
            backgroundColor: Resq.brandTint,
            child: Text(
              name![0].toUpperCase(),
              style: ResqType.bodyStrong(color: Resq.brandInk),
            ),
          ),
        ],
      ],
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.onTap, this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: Resq.tapTarget,
          height: Resq.tapTarget,
          decoration: BoxDecoration(
            color: Resq.surface,
            shape: BoxShape.circle,
            border: Border.all(color: Resq.border),
          ),
          child: Icon(icon, size: 21, color: Resq.inkSoft),
        ),
      ),
    );
  }
}

// --- Location ----------------------------------------------------------------

/// Where the ambulance will be sent, stated plainly — and, when the phone will
/// not say, what to do about it.
///
/// This is not decoration. An SOS without a position is a phone call to someone
/// who cannot tell you where they are, so a refused permission is treated as a
/// problem to fix, not a banner to ignore.
class _LocationStrip extends ConsumerWidget {
  const _LocationStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(locationAccessProvider).value;

    if (access != null && access != LocationAccess.granted) {
      return _LocationProblem(access: access);
    }

    final address = ref.watch(currentAddressProvider);
    final isOnline = ref.watch(isOnlineProvider).value ?? true;
    final locating = address.isLoading || (address.value ?? '').isEmpty;

    return Container(
      padding: const EdgeInsets.all(Resq.space3),
      decoration: BoxDecoration(
        color: Resq.navy,
        borderRadius: BorderRadius.circular(Resq.radiusCard),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 19),
          ),
          const SizedBox(width: Resq.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your location', style: ResqType.caption(color: Colors.white70)),
                const SizedBox(height: 1),
                Text(
                  locating ? 'Finding you…' : address.value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ResqType.bodyStrong(color: Colors.white),
                ),
              ],
            ),
          ),
          _LiveDot(isOnline: isOnline),
        ],
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? Resq.ready : Resq.decision;
    final dot = Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(Resq.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // A live indicator that does not move is just a coloured circle.
          isOnline
              ? dot.animate(onPlay: (c) => c.repeat(reverse: true)).fadeIn(duration: 900.ms)
              : dot,
          const SizedBox(width: 7),
          Text(isOnline ? 'Live' : 'Offline', style: ResqType.micro(color: color)),
        ],
      ),
    );
  }
}

/// Location is off, refused, or blocked — with the one action that fixes it.
class _LocationProblem extends ConsumerStatefulWidget {
  const _LocationProblem({required this.access});

  final LocationAccess access;

  @override
  ConsumerState<_LocationProblem> createState() => _LocationProblemState();
}

class _LocationProblemState extends ConsumerState<_LocationProblem> {
  bool _busy = false;

  ({String title, String body, String action}) get _copy => switch (widget.access) {
        LocationAccess.serviceOff => (
            title: 'Location is switched off',
            body: 'The ambulance is sent to where you are, so the phone has to know.',
            action: 'Turn on location',
          ),
        LocationAccess.blocked => (
            title: 'Location is blocked',
            body: 'ResQPK cannot ask again — it has to be allowed in Settings.',
            action: 'Open settings',
          ),
        _ => (
            title: 'Allow location',
            body: 'Without it the crew has only a phone number to find you by.',
            action: 'Allow',
          ),
      };

  Future<void> _fix() async {
    setState(() => _busy = true);
    try {
      switch (widget.access) {
        case LocationAccess.serviceOff:
          await Geolocator.openLocationSettings();
        case LocationAccess.blocked:
          await Geolocator.openAppSettings();
        case LocationAccess.denied:
        case LocationAccess.granted:
          await ref.read(locationServiceProvider).getCurrentPosition();
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        ref.invalidate(locationAccessProvider);
        ref.invalidate(currentAddressProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = _copy;

    return Container(
      padding: const EdgeInsets.all(Resq.space4),
      decoration: BoxDecoration(
        color: Resq.decisionTint,
        borderRadius: BorderRadius.circular(Resq.radiusCard),
        border: Border.all(color: Resq.decision.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.location_off_rounded, color: Resq.decision, size: 20),
          const SizedBox(width: Resq.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(copy.title, style: ResqType.bodyStrong()),
                const SizedBox(height: 2),
                Text(copy.body, style: ResqType.caption(color: Resq.inkSoft)),
                const SizedBox(height: Resq.space2),
                SizedBox(
                  height: 38,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _fix,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Resq.decision,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: Resq.space4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Resq.radiusControl),
                      ),
                    ),
                    child: Text(copy.action, style: ResqType.caption(color: Colors.white)),
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

// --- Map ---------------------------------------------------------------------

/// A small map: where you are, and the nearest help around you.
///
/// Deliberately not interactive beyond panning — the full map lives on the
/// tracking screen, and a tall scrollable map here would fight the page scroll.
class _MapPreview extends ConsumerStatefulWidget {
  const _MapPreview({required this.lat, required this.lng});

  final double? lat;
  final double? lng;

  @override
  ConsumerState<_MapPreview> createState() => _MapPreviewState();
}

class _MapPreviewState extends ConsumerState<_MapPreview> {
  final MapController _controller = MapController();
  bool _centered = false;

  LatLng get _center => LatLng(widget.lat ?? 25.3792, widget.lng ?? 68.3683);

  @override
  void didUpdateWidget(covariant _MapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_centered && widget.lat != null && widget.lng != null) {
      _centered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.move(_center, MapSpec.cityZoom);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFix = widget.lat != null && widget.lng != null;
    final hospitals = ref.watch(nearbyHospitalsProvider).asData?.value ?? const [];
    final camps = ref.watch(nearbyCampsProvider).asData?.value ?? const [];

    return MapCard(
      height: 210,
      overlay: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.all(Resq.space3),
          child: MapControlButton(
            icon: Icons.my_location_rounded,
            tooltip: 'Centre on me',
            onTap: () {
              if (!hasFix) return;
              _controller.move(_center, MapSpec.navigationZoom);
            },
          ),
        ),
      ),
      child: FlutterMap(
        mapController: _controller,
        options: MapOptions(
          initialCenter: _center,
          initialZoom: MapSpec.cityZoom,
          minZoom: 3,
          maxZoom: 19,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.pinchMove,
          ),
        ),
        children: [
          const ResQPKTileLayer(light: true),
          if (hasFix)
            CircleLayer(
              circles: [
                CircleMarker(
                  point: _center,
                  radius: 70,
                  color: Resq.info.withValues(alpha: 0.10),
                  borderColor: Resq.info.withValues(alpha: 0.25),
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
                      color: Resq.critical,
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
                    color: Resq.ready,
                    icon: Icons.medical_services,
                  ),
                ),
              if (hasFix)
                Marker(
                  point: _center,
                  width: MapSpec.touchTarget,
                  height: MapSpec.touchTarget,
                  child: const UserLocationDot(color: Resq.info),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- Nearby hospitals --------------------------------------------------------

class _HospitalsTile extends ConsumerWidget {
  const _HospitalsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(nearbyHospitalsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Emergency hospitals',
          action: async.asData?.value.isNotEmpty == true
              ? TextButton(
                  onPressed: () => _showAll(context, async.value!),
                  child: Text('See all', style: ResqType.caption(color: Resq.brandInk)),
                )
              : null,
        ),
        async.when(
          loading: () => const LoadingSkeleton(lines: 2, height: 76),
          error: (_, __) => ResqCard(
            child: Row(
              children: [
                const Icon(Icons.cloud_off_rounded, size: 18, color: Resq.inkMuted),
                const SizedBox(width: Resq.space3),
                Expanded(
                  child: Text(
                    'Could not load hospitals. Pull down to try again.',
                    style: ResqType.body(color: Resq.inkMuted),
                  ),
                ),
              ],
            ),
          ),
          data: (hospitals) {
            if (hospitals.isEmpty) {
              return ResqCard(
                child: Text(
                  'No emergency hospital found near you yet.',
                  style: ResqType.body(color: Resq.inkMuted),
                ),
              );
            }
            return Column(
              children: [
                for (final h in hospitals.take(3)) _HospitalRow(hospital: h),
              ],
            );
          },
        ),
      ],
    );
  }

  void _showAll(BuildContext context, List<Map<String, dynamic>> hospitals) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Resq.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Resq.radiusCard)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Resq.space4, Resq.space5, Resq.space4, Resq.space4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(title: 'Emergency hospitals'),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: hospitals.length,
                  itemBuilder: (_, i) => _HospitalRow(hospital: hospitals[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HospitalRow extends StatelessWidget {
  const _HospitalRow({required this.hospital});

  final Map<String, dynamic> hospital;

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
    final open247 = hospital['has_emergency_ward'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: Resq.space3),
      child: ResqCard(
        padding: const EdgeInsets.all(Resq.space3),
        accent: open247 ? Resq.ready : null,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Resq.criticalTint,
                borderRadius: BorderRadius.circular(Resq.radiusControl),
              ),
              child: const Icon(Icons.local_hospital_rounded, color: Resq.critical, size: 22),
            ),
            const SizedBox(width: Resq.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: ResqType.bodyStrong()),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (distance.isNotEmpty)
                        Text('$distance away', style: ResqType.caption()),
                      if (distance.isNotEmpty && open247)
                        Text(' · ', style: ResqType.caption()),
                      if (open247) Text('Emergency ward', style: ResqType.caption(color: Resq.ready)),
                    ],
                  ),
                ],
              ),
            ),
            if (phone != null && phone.isNotEmpty)
              IconButton(
                onPressed: () => _call(phone),
                icon: const Icon(Icons.call_rounded, color: Resq.ready),
                constraints: const BoxConstraints(
                  minWidth: Resq.tapTarget,
                  minHeight: Resq.tapTarget,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- Camps -------------------------------------------------------------------

class _CampsTile extends ConsumerWidget {
  const _CampsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(nearbyCampsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Free medical camps',
          action: async.asData?.value.isNotEmpty == true
              ? TextButton(
                  onPressed: () => context.go(Routes.camps),
                  child: Text('See all', style: ResqType.caption(color: Resq.brandInk)),
                )
              : null,
        ),
        async.when(
          loading: () => const LoadingSkeleton(lines: 1, height: 76),
          error: (_, __) => ResqCard(
            child: Text('Could not load camps.', style: ResqType.body(color: Resq.inkMuted)),
          ),
          data: (camps) {
            if (camps.isEmpty) {
              return ResqCard(
                child: Text(
                  'No camps running near you this week.',
                  style: ResqType.body(color: Resq.inkMuted),
                ),
              );
            }
            final camp = camps.first;
            return ResqCard(
              padding: const EdgeInsets.all(Resq.space3),
              onTap: () => context.go('${Routes.camps}/${camp.id}'),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Resq.readyTint,
                      borderRadius: BorderRadius.circular(Resq.radiusControl),
                    ),
                    child: const Icon(Icons.medical_services_rounded, color: Resq.ready, size: 22),
                  ),
                  const SizedBox(width: Resq.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(camp.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ResqType.bodyStrong()),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (camp.distanceText != null) camp.distanceText!,
                            if (camp.daysRemaining != null)
                              camp.daysRemaining! <= 0
                                  ? 'Last day'
                                  : '${camp.daysRemaining} days left',
                          ].join(' · '),
                          style: ResqType.caption(),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Resq.inkFaint),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

// --- First aid ---------------------------------------------------------------

/// Four guides, reachable in one tap.
///
/// Someone holding a bleeding arm is not going to browse a tab. The covers are
/// here because a picture is recognised faster than a title when you are
/// panicking.
class _FirstAidTile extends ConsumerWidget {
  const _FirstAidTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(firstAidProvider);
    final guides = state.guides.where((g) => FirstAidArt.hasArt(g.slug)).take(4).toList();
    final fallback = state.guides.take(4).toList();
    final shown = guides.isNotEmpty ? guides : fallback;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'While you wait',
          action: TextButton(
            onPressed: () => context.go(Routes.firstAid),
            child: Text('All guides', style: ResqType.caption(color: Resq.brandInk)),
          ),
        ),
        if (state.isLoading && shown.isEmpty)
          const LoadingSkeleton(lines: 1, height: 96)
        else if (shown.isEmpty)
          ResqCard(
            child: Text(
              'First-aid guides download the first time you are online.',
              style: ResqType.body(color: Resq.inkMuted),
            ),
          )
        else
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: shown.length,
              separatorBuilder: (_, __) => const SizedBox(width: Resq.space3),
              itemBuilder: (_, i) => _GuideChip(guide: shown[i]),
            ),
          ),
      ],
    );
  }
}

class _GuideChip extends StatelessWidget {
  const _GuideChip({required this.guide});

  final FirstAidGuideModel guide;

  @override
  Widget build(BuildContext context) {
    final cover = FirstAidArt.cover(guide.slug);

    return GestureDetector(
      // Pushed, not gone to: a guide is a takeover now, and back should return
      // here rather than unwinding the whole shell.
      onTap: () => context.push(Routes.guideDetail, extra: guide),
      child: SizedBox(
        width: 104,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 72,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Resq.brandTint,
                borderRadius: BorderRadius.circular(Resq.radiusControl),
                border: Border.all(color: Resq.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: cover != null
                  ? Image.asset(cover, fit: BoxFit.cover)
                  : const Icon(Icons.healing_rounded, color: Resq.brandInk),
            ),
            const SizedBox(height: Resq.space2),
            Text(
              guide.titleEn,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ResqType.caption(color: Resq.ink),
            ),
          ],
        ),
      ),
    );
  }
}

// --- SOS ---------------------------------------------------------------------

/// The reason the app exists, and the largest thing on the screen.
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

class _SosSectionState extends ConsumerState<_SosSection> with SingleTickerProviderStateMixin {
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
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            _caption,
            key: ValueKey(_phase),
            textAlign: TextAlign.center,
            style: ResqType.body(color: Resq.inkMuted),
          ),
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
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, size: 18, color: Resq.critical),
                const SizedBox(width: Resq.space2),
                Expanded(child: Text(error, style: ResqType.caption(color: Resq.critical))),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
