import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/map/resqpk_map.dart';
import '../../../core/realtime/realtime_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/back_guard.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/resq_card.dart';
import '../../ai_report/data/models/ai_report_model.dart';
import '../../ai_report/providers/ai_report_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../first_aid/providers/first_aid_provider.dart';
import '../data/sos_repository.dart';
import '../providers/session_provider.dart';
import '../providers/sos_provider.dart';

/// Live case: where the ambulance is, who is driving it, and where it is taking
/// you.
///
/// The map is the background, never the content. What matters is the card at
/// the bottom — it is what someone reads while standing over a casualty, and it
/// says a different thing at every stage of the case rather than showing empty
/// fields for a driver who has not been assigned yet.
class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  final MapController _mapController = MapController();
  final SOSRepository _repo = SOSRepository();
  LatLng? _driverPos;
  double _driverHeading = 0;
  int? _originalEtaSeconds;

  // Road-following route for the current leg (from /api/cases/:id/route).
  List<LatLng> _routePoints = [];
  String? _routeLeg;
  Timer? _routeTimer;
  bool _fetchingRoute = false;

  AIReportModel? _latestReport;
  StreamSubscription<Map<String, dynamic>>? _aiSub;
  StreamSubscription<Map<String, dynamic>>? _decisionSub;

  /// Everything that has happened on this case, shown in the updates sheet
  /// instead of stacked over the map where it hid the route.
  final List<_CaseUpdate> _updates = [];
  int _unreadUpdates = 0;

  // Destination the patient confirms. The nearest hospital is suggested once
  // an ambulance accepts, but no hospital is told until the patient confirms.
  Map<String, dynamic>? _suggestedHospital;
  bool _loadingSuggestion = false;
  bool _confirmingHospital = false;

  @override
  void initState() {
    super.initState();
    final c = ref.read(sosProvider).activeCase;
    if (c?.driverLat != null && c?.driverLng != null) {
      _driverPos = LatLng(c!.driverLat!, c.driverLng!);
      _driverHeading = c.driverHeading ?? 0;
    }
    _originalEtaSeconds = c?.estimatedDriverArrivalSeconds;

    // Surface first-aid guidance the moment the AI report is ready.
    _aiSub = ref.read(socketServiceProvider).aiReportStream.listen((evt) {
      if (evt['event'] == 'report_ready' && mounted) {
        final report = AIReportModel.fromJson(evt);
        setState(() => _latestReport = report);
        _addUpdate(_CaseUpdate(
          kind: _UpdateKind.report,
          title: 'Emergency report ready',
          body: report.firstAidSuggestion ?? 'Your AI emergency report has been generated.',
          at: DateTime.now(),
        ));
      }
    });

    // Fetch the road route now and refresh it as the driver moves.
    _fetchRoute();
    _routeTimer = Timer.periodic(const Duration(seconds: 45), (_) => _fetchRoute());
    Future.microtask(_loadSuggestion);

    // A redirect changes the destination — reassure the patient without
    // surfacing the clinical reason, which is for the driver and records only.
    _decisionSub = ref.read(socketServiceProvider).caseUpdateStream.listen((data) {
      if (!mounted) return;

      switch (data['event']?.toString()) {
        case 'driver_assigned':
          _addUpdate(_CaseUpdate(
            kind: _UpdateKind.hospital,
            title: 'Ambulance on the way',
            body: 'The hospital is reviewing your case.',
            at: DateTime.now(),
          ));
          break;

        case 'hospital_accepted':
          final note = data['preparationNote']?.toString();
          _addUpdate(_CaseUpdate(
            kind: _UpdateKind.accepted,
            title: '${data['hospitalName'] ?? 'The hospital'} confirmed',
            body: note != null && note.isNotEmpty
                ? 'They are ready for you — $note.'
                : 'They are expecting you and preparing for your arrival.',
            at: DateTime.now(),
          ));
          break;

        case 'hospital_redirected':
          final newHospital = data['newHospital'] as Map<String, dynamic>?;
          final name = newHospital?['name']?.toString() ?? 'another hospital';
          _addUpdate(_CaseUpdate(
            kind: _UpdateKind.hospital,
            // The clinical reason stays with the driver and the records.
            title: 'Hospital changed to $name',
            body: 'You are being taken here for better care availability.',
            at: DateTime.now(),
          ));
          _fetchRoute();
          break;

        case 'driver_changed':
          final driver = data['driver'] as Map<String, dynamic>?;
          final name = driver?['fullName']?.toString() ?? 'another driver';
          _addUpdate(_CaseUpdate(
            kind: _UpdateKind.driver,
            title: 'A closer ambulance is coming',
            body: '$name has taken over and is on the way to you.',
            at: DateTime.now(),
          ));
          _fetchRoute();
          break;

        default:
          break;
      }
    });
  }

  void _addUpdate(_CaseUpdate update) {
    if (!mounted) return;
    setState(() {
      _updates.insert(0, update);
      _unreadUpdates += 1;
    });
  }

  /// The token for this case when the reporter has no account.
  String? _caseToken(String caseId) => caseTokenFor(
        ref.read(sessionProvider),
        signedIn: ref.read(authProvider).isAuthenticated,
        caseId: caseId,
      );

  Future<void> _fetchRoute() async {
    final caseId = ref.read(sosProvider).activeCaseId;
    if (caseId == null || _fetchingRoute) return;
    _fetchingRoute = true;
    try {
      final route = await _repo.getCaseRoute(caseId, caseToken: _caseToken(caseId));
      final coords = (route['coordinates'] as List? ?? [])
          .whereType<Map>()
          .map((p) => LatLng(
                double.tryParse('${p['lat']}') ?? 0,
                double.tryParse('${p['lng']}') ?? 0,
              ))
          .toList();
      if (mounted) {
        setState(() {
          _routePoints = coords;
          _routeLeg = route['leg']?.toString();
        });
      }
    } catch (_) {
      // Straight-line fallback stays on screen if routing is unavailable.
    } finally {
      _fetchingRoute = false;
    }
  }

  void _openUpdatesSheet(String caseId) {
    setState(() => _unreadUpdates = 0);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Resq.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Resq.radiusCard)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Resq.space5, Resq.space5, Resq.space5, Resq.space5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Updates', style: ResqType.title()),
              const SizedBox(height: 4),
              Text(
                'Everything happening with your emergency',
                style: ResqType.caption(),
              ),
              const SizedBox(height: Resq.space4),
              if (_updates.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Resq.space8),
                  child: Text(
                    'No updates yet. Hospital and ambulance news appears here.',
                    textAlign: TextAlign.center,
                    style: ResqType.body(color: Resq.inkMuted),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 380),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _updates.length,
                    separatorBuilder: (_, __) => const SizedBox(height: Resq.space3),
                    itemBuilder: (_, i) => _UpdateTile(
                      update: _updates[i],
                      onViewReport: _updates[i].kind == _UpdateKind.report
                          ? () {
                              Navigator.of(sheetCtx).pop();
                              context.push(Routes.reportPdf, extra: {
                                'caseId': caseId,
                                'report': _latestReport,
                              });
                            }
                          : null,
                      onSeeGuide: _updates[i].kind == _UpdateKind.report
                          ? () {
                              Navigator.of(sheetCtx).pop();
                              final relevant = ref
                                  .read(firstAidProvider.notifier)
                                  .getRelevantGuidesForEmergency(
                                      _latestReport?.emergencyType ?? '');
                              if (relevant.isNotEmpty) {
                                context.push(Routes.guideDetail, extra: relevant.first);
                              } else {
                                context.go(Routes.firstAid);
                              }
                            }
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Nearest emergency hospital, offered as the default destination.
  Future<void> _loadSuggestion() async {
    final c = ref.read(sosProvider).activeCase;
    if (c == null || c.hospitalId != null) return;
    if (_loadingSuggestion || _suggestedHospital != null) return;
    // Without real coordinates "nearest" would be meaningless.
    if (c.patientLat == 0 && c.patientLng == 0) return;

    setState(() => _loadingSuggestion = true);
    try {
      final hospitals = await _repo.getNearbyHospitals(c.patientLat, c.patientLng);
      if (!mounted) return;
      setState(() => _suggestedHospital = hospitals.isNotEmpty ? hospitals.first : null);
    } catch (_) {
      // The patient can still pick from the full list.
    } finally {
      if (mounted) setState(() => _loadingSuggestion = false);
    }
  }

  Future<void> _confirmSuggestedHospital() async {
    final hospital = _suggestedHospital;
    if (hospital == null) return;
    await _changeHospital(hospital);
  }

  Future<void> _openChangeHospitalSheet() async {
    final c = ref.read(sosProvider).activeCase;
    if (c == null) return;
    List<Map<String, dynamic>> hospitals = [];
    try {
      hospitals = await _repo.getNearbyHospitals(c.patientLat, c.patientLng);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not load hospitals: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
      }
      return;
    }
    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Resq.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Resq.radiusCard)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Resq.space5, Resq.space5, Resq.space5, Resq.space2),
              child: Text('Choose hospital', style: ResqType.title()),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: hospitals.length,
                itemBuilder: (_, i) {
                  final h = hospitals[i];
                  final id = h['id']?.toString() ?? '';
                  final isCurrent = id == ref.read(sosProvider).activeCase?.hospitalId;
                  return ListTile(
                    leading: Icon(
                      Icons.local_hospital_rounded,
                      color: isCurrent ? Resq.ready : Resq.critical,
                    ),
                    title: Text(h['name']?.toString() ?? 'Hospital', style: ResqType.bodyStrong()),
                    subtitle: Text(
                      '${h['distanceText'] ?? ''} · ${h['address'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ResqType.caption(),
                    ),
                    trailing: isCurrent
                        ? const Icon(Icons.check_circle, color: Resq.ready, size: 20)
                        : null,
                    onTap: isCurrent
                        ? null
                        : () {
                            Navigator.of(sheetCtx).pop();
                            _changeHospital(h);
                          },
                  );
                },
              ),
            ),
            const SizedBox(height: Resq.space2),
          ],
        ),
      ),
    );
  }

  Future<void> _changeHospital(Map<String, dynamic> hospital) async {
    final caseId = ref.read(sosProvider).activeCaseId;
    final id = hospital['id']?.toString();
    if (caseId == null || id == null || _confirmingHospital) return;

    final isFirstChoice = ref.read(sosProvider).activeCase?.hospitalId == null;
    final name = hospital['name']?.toString() ?? 'the hospital';

    setState(() => _confirmingHospital = true);
    try {
      await _repo.changeHospital(caseId, id, caseToken: _caseToken(caseId));
      ref.read(sosProvider.notifier).applyHospitalChange(
            id: id,
            name: hospital['name']?.toString(),
            lat: double.tryParse('${hospital['lat']}'),
            lng: double.tryParse('${hospital['lng']}'),
          );
      _fetchRoute();
      _addUpdate(_CaseUpdate(
        kind: _UpdateKind.hospital,
        title: isFirstChoice ? 'Hospital confirmed: $name' : 'Hospital changed to $name',
        body: 'They have been notified and are reviewing your case.',
        at: DateTime.now(),
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFirstChoice ? '$name has been notified' : 'Hospital changed to $name'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _confirmingHospital = false);
    }
  }

  @override
  void dispose() {
    _aiSub?.cancel();
    _decisionSub?.cancel();
    _routeTimer?.cancel();
    super.dispose();
  }

  Future<void> _call(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _confirmCancel() {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Resq.surface,
        title: Text('Cancel emergency?', style: ResqType.section()),
        content: Text(
          'The ambulance will be released. Only cancel if you no longer need help.',
          style: ResqType.body(color: Resq.inkSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text('Keep it', style: ResqType.button(color: Resq.inkSoft)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              await ref.read(sosProvider.notifier).cancelActiveCase();
              if (mounted) context.go(Routes.home);
            },
            child: Text('Cancel SOS', style: ResqType.button(color: Resq.critical)),
          ),
        ],
      ),
    );
  }

  void _openReport(String caseId) {
    final existing = _latestReport ?? ref.read(aiReportProvider).report;
    if (existing != null && existing.isComplete) {
      context.push(Routes.reportResult, extra: caseId);
      return;
    }
    // Nothing recorded yet — start the flow at its first question, with no
    // leftovers from a previous case.
    ref.read(aiReportProvider.notifier).startFresh();
    context.push(Routes.reportPhoto, extra: caseId);
  }

  @override
  Widget build(BuildContext context) {
    final collapsedFraction = _collapsedSheetFraction(context);

    // Live driver position from the case room broadcasts.
    ref.listen(driverLocationStreamProvider, (_, next) {
      next.whenData((data) {
        final lat = double.tryParse('${data['lat']}');
        final lng = double.tryParse('${data['lng']}');
        if (lat == null || lng == null || !mounted) return;
        setState(() {
          _driverPos = LatLng(lat, lng);
          _driverHeading = double.tryParse('${data['heading']}') ?? _driverHeading;
        });
        _mapController.move(_driverPos!, _mapController.camera.zoom);
      });
    });

    // Refetch the road route whenever the leg changes (status transition) or
    // the destination hospital is switched.
    ref.listen(
      sosProvider.select((s) => '${s.status}:${s.activeCase?.hospitalId}'),
      (_, __) {
        _fetchRoute();
        // A case restored mid-search gains a driver later; suggest then.
        _loadSuggestion();
      },
    );

    // Navigate home when the case completes or is cancelled.
    ref.listen(sosProvider.select((s) => s.status), (_, status) {
      if (status == SOSStatus.completed) {
        showDialog<void>(
          context: context,
          builder: (d) => AlertDialog(
            backgroundColor: Resq.surface,
            title: Text('You have arrived', style: ResqType.section()),
            content: Text(
              'You reached the hospital. Your emergency report stays available under '
              'My requests.',
              style: ResqType.body(color: Resq.inkSoft),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(d).pop();
                  if (mounted) context.go(Routes.home);
                },
                child: Text('Done', style: ResqType.button(color: Resq.ready)),
              ),
            ],
          ),
        );
      } else if (status == SOSStatus.cancelled || status == SOSStatus.idle) {
        if (mounted) context.go(Routes.home);
      }
    });

    final sos = ref.watch(sosProvider);
    final c = sos.activeCase;
    if (c == null) {
      return const Scaffold(
        backgroundColor: Resq.canvas,
        body: Center(child: CircularProgressIndicator(color: Resq.critical)),
      );
    }

    final patient = LatLng(c.patientLat, c.patientLng);
    final driver = _driverPos ??
        (c.driverLat != null && c.driverLng != null ? LatLng(c.driverLat!, c.driverLng!) : null);
    final hospital = (c.hospitalLat != null && c.hospitalLng != null)
        ? LatLng(c.hospitalLat!, c.hospitalLng!)
        : null;

    final eta = c.estimatedDriverArrivalSeconds;
    _originalEtaSeconds ??= eta;
    final progress = (_originalEtaSeconds != null && _originalEtaSeconds! > 0 && eta != null)
        ? (1 - eta / _originalEtaSeconds!).clamp(0.0, 1.0)
        : 0.0;

    // Back returns to home; the case stays active and the shell's banner keeps
    // tracking one tap away.
    return BackTo(
      onBack: () => context.go(Routes.home),
      child: Scaffold(
        backgroundColor: Resq.canvas,
        body: Stack(
          children: [
            RepaintBoundary(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(initialCenter: driver ?? patient, initialZoom: 14),
                children: [
                  const ResQPKTileLayer(light: true),
                  PolylineLayer(
                    polylines: [
                      // Road-following route for the current leg (pickup = blue
                      // driver→patient; dropoff = green →hospital). Falls back
                      // to a straight line only while the road route is loading.
                      if (_routePoints.length >= 2)
                        ...routePolyline(
                          _routePoints,
                          color: _routeLeg == 'dropoff' ? Resq.ready : Resq.info,
                        )
                      else if (_routeLeg != 'dropoff' && driver != null)
                        ...routePolyline([driver, patient], color: Resq.info, isAlternate: true)
                      else if (_routeLeg == 'dropoff' && hospital != null)
                        ...routePolyline([patient, hospital],
                            color: Resq.ready, isAlternate: true),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: patient,
                        width: MapSpec.touchTarget,
                        height: MapSpec.touchTarget,
                        child: const UserLocationDot(color: Resq.critical),
                      ),
                      if (hospital != null)
                        Marker(
                          point: hospital,
                          width: MapSpec.touchTarget,
                          height: MapSpec.pinHeight,
                          alignment: Alignment.topCenter,
                          child: const MapDestinationPin(color: Resq.ready),
                        ),
                      if (driver != null)
                        Marker(
                          point: driver,
                          width: MapSpec.touchTarget,
                          height: MapSpec.touchTarget,
                          child: NavigationPuck(
                            headingDegrees: _driverHeading,
                            color: Resq.info,
                            icon: Icons.navigation,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // --- Top chrome ---------------------------------------------------
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(Resq.space3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _MapChipButton(
                          icon: Icons.arrow_back_rounded,
                          onTap: () => context.go(Routes.home),
                        ),
                        const SizedBox(width: Resq.space2),
                        Flexible(child: _TrackingStatusPill(status: sos.status)),
                        const Spacer(),
                        _UpdatesButton(
                          unread: _unreadUpdates,
                          onTap: () => _openUpdatesSheet(c.id),
                        ),
                      ],
                    ),
                    const SizedBox(height: Resq.space2),
                    _RequestCodeChip(caseId: c.id),
                  ],
                ),
              ),
            ),

            // --- The card that actually tells you what is happening -----------
            // Draggable, because the map underneath is half the point. Pull the
            // sheet down to see where the ambulance actually is, push it back
            // up for the hospital and the buttons. It snaps to three heights
            // so it never rests somewhere useless.
            DraggableScrollableSheet(
              initialChildSize: 0.46,
              minChildSize: collapsedFraction,
              maxChildSize: 0.92,
              snap: true,
              snapSizes: [collapsedFraction, 0.46, 0.92],
              builder: (context, scrollController) => _TrackingCard(
                scrollController: scrollController,
                status: sos.status,
                driverName: c.driverName,
                vehicleNumber: c.vehicleNumber,
                driverPhone: c.driverPhone,
                etaText: _etaText(eta, sos.status),
                progress: progress,
                hospitalName: c.hospitalName,
                hospitalSelected: c.hospitalId != null,
                hospitalConfirmed: sos.isHospitalConfirmed,
                preparationNote: sos.hospitalPreparationNote,
                hasDriver: c.driverId != null,
                hasReport: _latestReport != null ||
                    (ref.watch(aiReportProvider).report?.isComplete ?? false),
                suggestedHospital: _suggestedHospital,
                loadingSuggestion: _loadingSuggestion,
                confirmingHospital: _confirmingHospital,
                onCallDriver: () => _call(c.driverPhone),
                onAiReport: () => _openReport(c.id),
                onCancel: _confirmCancel,
                onChangeHospital: _openChangeHospitalSheet,
                onConfirmHospital: _confirmSuggestedHospital,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// How far down the sheet may be dragged, as a fraction of screen height.
  ///
  /// It used to be a flat 0.17, which left "Call Rescue 1122" sliced in half
  /// along the bottom edge — a button cut lengthways looks like a rendering
  /// fault, and the whole point of dragging down is to see the map. The
  /// collapsed card is a fixed stack of pixels, so any fraction of screen
  /// height lands somewhere different on every phone; it is measured instead,
  /// and stops exactly below the header text.
  ///
  /// Measured against the searching header, which is the taller of the two —
  /// its subtitle wraps to two lines where an assigned driver's vehicle number
  /// is one. So the collapsed height suits both, and does not jump when a
  /// driver accepts.
  double _collapsedSheetFraction(BuildContext context) {
    final media = MediaQuery.of(context);

    const cardTopPadding = Resq.space3;
    const handleBlock = 5.0 + Resq.space3;   // grip plus its bottom margin
    const gapBelowHandle = Resq.space2;
    const iconDiameter = 46.0;
    const gapBelowTitle = 2.0;
    // Enough that the subtitle is not flush against the cut edge.
    const breathingRoom = 12.0;

    final textWidth = media.size.width
        - Resq.space5 * 2      // card padding
        - iconDiameter
        - Resq.space3;         // gap between icon and text

    double heightOf(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: media.textScaler,
      )..layout(maxWidth: textWidth);
      final height = painter.height;
      painter.dispose();
      return height;
    }

    final titleHeight = heightOf('Finding the nearest ambulance', ResqType.section());
    final subtitleHeight = heightOf(
      'Drivers are being offered your emergency one at a time, closest first.',
      ResqType.caption(color: Resq.inkSoft),
    );

    final headerHeight = math.max(iconDiameter, titleHeight + gapBelowTitle + subtitleHeight);
    final collapsed = cardTopPadding
        + handleBlock
        + gapBelowHandle
        + headerHeight
        + breathingRoom
        // The card's own SafeArea pads the bottom of its scroll view, so that
        // inset eats into the collapsed height rather than sitting under it.
        + media.padding.bottom;

    // Only an upper bound. A floor in screen fractions is what caused this in
    // the first place: on a tall screen 0.12 is taller than the header needs,
    // and the surplus is button. The measured value already includes the whole
    // header, so it can never come out too small to grab.
    return math.min(collapsed / media.size.height, 0.40);
  }

  String _etaText(int? seconds, SOSStatus status) {
    if (status == SOSStatus.arrived) return 'The ambulance is here';
    if (seconds == null) return 'Working out the arrival time…';
    final mins = (seconds / 60).ceil();
    return mins <= 1 ? 'Arriving in about a minute' : 'About $mins minutes away';
  }
}

// --- Top chrome --------------------------------------------------------------

class _MapChipButton extends StatelessWidget {
  const _MapChipButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Resq.surface,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: Resq.tapTarget,
          height: Resq.tapTarget,
          child: Icon(icon, size: 20, color: Resq.ink),
        ),
      ),
    );
  }
}

class _TrackingStatusPill extends StatelessWidget {
  const _TrackingStatusPill({required this.status});

  final SOSStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      SOSStatus.searching => ('Finding an ambulance', Resq.critical, Icons.radar_rounded),
      SOSStatus.driverAssigned => ('Ambulance on the way', Resq.info, Icons.local_shipping_rounded),
      SOSStatus.arrived => ('Ambulance arrived', Resq.ready, Icons.check_circle_outline_rounded),
      SOSStatus.enRoute => ('On the way to hospital', Resq.info, Icons.navigation_rounded),
      SOSStatus.completed => ('Completed', Resq.ready, Icons.check_circle_outline_rounded),
      _ => ('Emergency active', Resq.critical, Icons.emergency_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Resq.space3, vertical: 10),
      decoration: BoxDecoration(
        color: Resq.surface,
        borderRadius: BorderRadius.circular(Resq.radiusPill),
        boxShadow: Resq.raisedShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: Resq.space2),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ResqType.caption(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpdatesButton extends StatelessWidget {
  const _UpdatesButton({required this.unread, required this.onTap});

  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Resq.surface,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: Resq.tapTarget,
          height: Resq.tapTarget,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.notifications_none_rounded, size: 21, color: Resq.ink),
              if (unread > 0)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Resq.critical, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$unread',
                      textAlign: TextAlign.center,
                      style: ResqType.micro(color: Colors.white),
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

/// The request code, for a patient who has no account.
///
/// It is the only handle they have on this emergency — it reopens the request
/// from any phone and unlocks the report afterwards — so it belongs on screen
/// while the ambulance is coming, not only in a confirmation that scrolled away.
/// Tapping copies it.
class _RequestCodeChip extends ConsumerWidget {
  const _RequestCodeChip({required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final code = session.caseId == caseId ? session.accessCode : null;
    if (code == null || code.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: code));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request code $code copied')),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Resq.space3, vertical: 8),
        decoration: BoxDecoration(
          color: Resq.surface,
          borderRadius: BorderRadius.circular(Resq.radiusPill),
          boxShadow: Resq.cardShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.tag_rounded, size: 15, color: Resq.inkMuted),
            const SizedBox(width: 5),
            Text(code, style: ResqType.caption(color: Resq.ink)),
            const SizedBox(width: 5),
            const Icon(Icons.copy_rounded, size: 13, color: Resq.inkFaint),
          ],
        ),
      ),
    );
  }
}

// --- The tracking card -------------------------------------------------------

/// One card, four faces: searching, assigned, en route, arrived.
///
/// Before an ambulance accepts there is no driver, no ETA and no hospital — the
/// old card showed "Driver" and an empty progress bar, which read as a system
/// that had lost the request.
class _TrackingCard extends StatelessWidget {
  const _TrackingCard({
    required this.scrollController,
    required this.status,
    required this.driverName,
    required this.vehicleNumber,
    required this.driverPhone,
    required this.etaText,
    required this.progress,
    required this.hospitalName,
    required this.hospitalSelected,
    required this.hospitalConfirmed,
    required this.preparationNote,
    required this.hasDriver,
    required this.hasReport,
    required this.suggestedHospital,
    required this.loadingSuggestion,
    required this.confirmingHospital,
    required this.onCallDriver,
    required this.onAiReport,
    required this.onCancel,
    required this.onChangeHospital,
    required this.onConfirmHospital,
  });

  /// Supplied by the sheet. Everything in the card scrolls with it, so a drag
  /// anywhere on the card moves the sheet — not just on the handle.
  final ScrollController scrollController;

  final SOSStatus status;
  final String? driverName;
  final String? vehicleNumber;
  final String? driverPhone;
  final String etaText;
  final double progress;
  final String? hospitalName;
  final bool hospitalSelected;
  final bool hospitalConfirmed;
  final String? preparationNote;
  final bool hasDriver;
  final bool hasReport;
  final Map<String, dynamic>? suggestedHospital;
  final bool loadingSuggestion;
  final bool confirmingHospital;
  final VoidCallback onCallDriver;
  final VoidCallback onAiReport;
  final VoidCallback onCancel;
  final VoidCallback onChangeHospital;
  final VoidCallback onConfirmHospital;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Resq.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(Resq.radiusCard)),
        boxShadow: Resq.raisedShadow,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          controller: scrollController,
          // Always scrollable, so the sheet still follows a drag when the card
          // is shorter than the space it has been given.
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Resq.space5,
              Resq.space3,
              Resq.space5,
              Resq.space4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The grip. It is the thing people reach for, so it sits in a
                // tall enough row to be caught by a thumb rather than aimed at.
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: Resq.space3),
                    decoration: BoxDecoration(
                      color: Resq.inkFaint.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(Resq.radiusPill),
                    ),
                  ),
                ),
                const SizedBox(height: Resq.space2),

                if (hasDriver) ..._assigned(context) else ..._searching(context),

                const SizedBox(height: Resq.space4),

                if (!hospitalSelected)
                  _HospitalChoice(
                    hasDriver: hasDriver,
                    suggested: suggestedHospital,
                    loading: loadingSuggestion,
                    confirming: confirmingHospital,
                    onConfirm: onConfirmHospital,
                    onChooseAnother: onChangeHospital,
                  )
                else
                  _HospitalRow(
                    name: hospitalName ?? 'Hospital',
                    confirmed: hospitalConfirmed,
                    preparationNote: preparationNote,
                    onChange: onChangeHospital,
                  ),

                const SizedBox(height: Resq.space4),
                // Filled, and named for what it makes. As "Add details for the
                // crew" it read as optional housekeeping and went unnoticed —
                // this is the photo, voice and AI report the hospital reads
                // before the ambulance arrives, and it is the one thing on this
                // screen the patient can still do something about.
                if (hasReport)
                  SecondaryButton(
                    label: 'View AI report',
                    icon: Icons.picture_as_pdf_rounded,
                    onPressed: onAiReport,
                    height: 52,
                  )
                else
                  PrimaryButton(
                    label: 'Create AI emergency report',
                    icon: Icons.auto_awesome_rounded,
                    onPressed: onAiReport,
                    height: 52,
                  ),
                TextButton(
                  onPressed: onCancel,
                  child: Text('Cancel emergency', style: ResqType.button(color: Resq.critical)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// No ambulance yet: say what is happening and keep 1122 within reach.
  List<Widget> _searching(BuildContext context) {
    return [
      Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(color: Resq.criticalTint, shape: BoxShape.circle),
            child: const Icon(Icons.radar_rounded, color: Resq.critical),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                duration: 900.ms,
                begin: const Offset(1, 1),
                end: const Offset(1.08, 1.08),
                curve: Curves.easeInOut,
              ),
          const SizedBox(width: Resq.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Finding the nearest ambulance', style: ResqType.section()),
                const SizedBox(height: 2),
                Text(
                  'Drivers are being offered your emergency one at a time, closest first.',
                  style: ResqType.caption(color: Resq.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: Resq.space4),
      // Waiting is the moment people reach for a phone. Give them the number
      // rather than making them leave the app to find it.
      SecondaryButton(
        label: 'Call Rescue 1122',
        icon: Icons.call_rounded,
        color: Resq.critical,
        height: Resq.tapTarget,
        onPressed: () async {
          final uri = Uri(scheme: 'tel', path: '1122');
          if (await canLaunchUrl(uri)) await launchUrl(uri);
        },
      ),
    ];
  }

  /// An ambulance is coming, or has arrived.
  List<Widget> _assigned(BuildContext context) {
    final arrived = status == SOSStatus.arrived;
    final name = (driverName?.isNotEmpty ?? false) ? driverName! : 'Your driver';

    return [
      Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Resq.infoTint,
            child: Text(name[0].toUpperCase(), style: ResqType.section(color: Resq.info)),
          ),
          const SizedBox(width: Resq.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: ResqType.section()),
                Text(
                  (vehicleNumber?.isNotEmpty ?? false) ? vehicleNumber! : 'Ambulance',
                  style: ResqType.caption(),
                ),
              ],
            ),
          ),
          if (driverPhone?.isNotEmpty ?? false)
            IconButton.filled(
              onPressed: onCallDriver,
              style: IconButton.styleFrom(
                backgroundColor: Resq.readyTint,
                foregroundColor: Resq.ready,
                minimumSize: const Size(Resq.tapTarget, Resq.tapTarget),
              ),
              icon: const Icon(Icons.call_rounded),
            ),
        ],
      ),
      const SizedBox(height: Resq.space4),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Text(
          etaText,
          key: ValueKey(etaText),
          style: ResqType.section(color: arrived ? Resq.ready : Resq.info),
        ),
      ),
      const SizedBox(height: Resq.space2),
      ClipRRect(
        borderRadius: BorderRadius.circular(Resq.radiusPill),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: arrived ? 1 : progress),
          duration: const Duration(milliseconds: 300),
          builder: (_, value, __) => LinearProgressIndicator(
            value: value,
            minHeight: 8,
            backgroundColor: Resq.surfaceAlt,
            color: arrived ? Resq.ready : Resq.info,
          ),
        ),
      ),
    ];
  }
}

/// Shown until the patient confirms a destination. No hospital is notified
/// before this; the nearest one is only a default the patient can change.
class _HospitalChoice extends StatelessWidget {
  const _HospitalChoice({
    required this.hasDriver,
    required this.suggested,
    required this.loading,
    required this.confirming,
    required this.onConfirm,
    required this.onChooseAnother,
  });

  final bool hasDriver;
  final Map<String, dynamic>? suggested;
  final bool loading;
  final bool confirming;
  final VoidCallback onConfirm;
  final VoidCallback onChooseAnother;

  @override
  Widget build(BuildContext context) {
    final name = suggested?['name']?.toString();
    final distance = suggested?['distanceText']?.toString();

    final String message;
    if (!hasDriver) {
      message = 'You can choose a hospital once an ambulance accepts.';
    } else if (name == null) {
      message = loading
          ? 'Finding the nearest hospital…'
          : 'No hospital found nearby. Choose one from the list.';
    } else {
      message = 'Nearest: $name${distance != null ? ' · $distance' : ''}';
    }

    return Container(
      padding: const EdgeInsets.all(Resq.space4),
      decoration: BoxDecoration(
        color: Resq.decisionTint,
        borderRadius: BorderRadius.circular(Resq.radiusCard),
        border: Border.all(color: Resq.decision.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.local_hospital_rounded, color: Resq.decision, size: 18),
              const SizedBox(width: Resq.space2),
              Expanded(
                child: Text(
                  hasDriver ? 'Confirm your hospital' : 'Hospital',
                  style: ResqType.bodyStrong(),
                ),
              ),
            ],
          ),
          const SizedBox(height: Resq.space2),
          Text(message, style: ResqType.body(color: Resq.inkSoft)),
          if (hasDriver) ...[
            const SizedBox(height: Resq.space3),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    label: 'Confirm',
                    color: Resq.ready,
                    height: 44,
                    loading: confirming,
                    onPressed: name == null ? null : onConfirm,
                  ),
                ),
                const SizedBox(width: Resq.space3),
                Expanded(
                  child: SecondaryButton(
                    label: 'Choose another',
                    height: 44,
                    onPressed: confirming ? null : onChooseAnother,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Resq.space2),
            Text(
              'The hospital is only notified after you confirm.',
              style: ResqType.micro(color: Resq.inkSoft),
            ),
          ],
        ],
      ),
    );
  }
}

class _HospitalRow extends StatelessWidget {
  const _HospitalRow({
    required this.name,
    required this.confirmed,
    required this.preparationNote,
    required this.onChange,
  });

  final String name;
  final bool confirmed;
  final String? preparationNote;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return ResqCard(
      padding: const EdgeInsets.all(Resq.space3),
      accent: confirmed ? Resq.ready : Resq.decision,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_hospital_rounded,
                color: confirmed ? Resq.ready : Resq.decision,
                size: 18,
              ),
              const SizedBox(width: Resq.space2),
              Expanded(child: Text(name, style: ResqType.bodyStrong())),
              if (confirmed)
                StatusPill.ready('Expecting you')
                    .animate()
                    .scale(duration: 300.ms, curve: Curves.easeOutBack)
              else
                TextButton(
                  onPressed: onChange,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: Resq.space2),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('Change', style: ResqType.caption(color: Resq.brandInk)),
                ),
            ],
          ),
          if (!confirmed)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 26),
              child: Text('Waiting for the hospital to accept', style: ResqType.caption()),
            ),
          if (confirmed && (preparationNote?.isNotEmpty ?? false))
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 26),
              child: Text(preparationNote!, style: ResqType.caption(color: Resq.inkSoft)),
            ),
        ],
      ),
    );
  }
}

// --- Updates -----------------------------------------------------------------

enum _UpdateKind { hospital, accepted, driver, report }

class _CaseUpdate {
  const _CaseUpdate({
    required this.kind,
    required this.title,
    required this.body,
    required this.at,
  });

  final _UpdateKind kind;
  final String title;
  final String body;
  final DateTime at;
}

class _UpdateTile extends StatelessWidget {
  const _UpdateTile({required this.update, this.onViewReport, this.onSeeGuide});

  final _CaseUpdate update;
  final VoidCallback? onViewReport;
  final VoidCallback? onSeeGuide;

  ({IconData icon, Color color}) get _style => switch (update.kind) {
        _UpdateKind.accepted => (icon: Icons.check_circle_rounded, color: Resq.ready),
        _UpdateKind.hospital => (icon: Icons.local_hospital_rounded, color: Resq.info),
        _UpdateKind.driver => (icon: Icons.local_shipping_rounded, color: Resq.info),
        _UpdateKind.report => (icon: Icons.description_rounded, color: Resq.decision),
      };

  @override
  Widget build(BuildContext context) {
    final s = _style;

    return ResqCard(
      padding: const EdgeInsets.all(Resq.space3),
      accent: s.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(s.icon, color: s.color, size: 18),
              const SizedBox(width: Resq.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(update.title, style: ResqType.bodyStrong()),
                    const SizedBox(height: 2),
                    Text(update.body, style: ResqType.caption(color: Resq.inkSoft)),
                  ],
                ),
              ),
              Text(TimeOfDay.fromDateTime(update.at).format(context), style: ResqType.micro()),
            ],
          ),
          if (onViewReport != null || onSeeGuide != null) ...[
            const SizedBox(height: Resq.space2),
            Row(
              children: [
                if (onViewReport != null)
                  TextButton.icon(
                    onPressed: onViewReport,
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 15, color: Resq.brandInk),
                    label: Text('View report', style: ResqType.caption(color: Resq.brandInk)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: Resq.space2),
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                if (onSeeGuide != null)
                  TextButton.icon(
                    onPressed: onSeeGuide,
                    icon: const Icon(Icons.healing_rounded, size: 15, color: Resq.ready),
                    label: Text('First aid', style: ResqType.caption(color: Resq.ready)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: Resq.space2),
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
