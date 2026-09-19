import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/map/resqpk_map.dart';
import '../../../core/realtime/realtime_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/back_guard.dart';
import '../../ai_report/data/models/ai_report_model.dart';
import '../../ai_report/providers/ai_report_provider.dart';
import '../../first_aid/providers/first_aid_provider.dart';
import '../data/sos_repository.dart';
import '../providers/session_provider.dart';
import '../providers/sos_provider.dart';

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
      final event = data['event']?.toString();

      switch (event) {
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

  Future<void> _fetchRoute() async {
    final caseId = ref.read(sosProvider).activeCaseId;
    if (caseId == null || _fetchingRoute) return;
    _fetchingRoute = true;
    try {
      final route = await _repo.getCaseRoute(caseId);
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
      backgroundColor: AppColors.surfaceOne,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Updates', style: AppTextStyles.subtitle),
              const SizedBox(height: 4),
              Text('Everything happening with your emergency',
                  style: AppTextStyles.caption),
              const SizedBox(height: 16),
              if (_updates.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Text(
                    'No updates yet. You will see hospital and ambulance news here.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption,
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 380),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _updates.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
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
                                context.push(Routes.firstAid);
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
          SnackBar(content: Text('Could not load hospitals: ${e.toString().replaceFirst('Exception: ', '')}')),
        );
      }
      return;
    }
    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceOne,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text('Choose hospital', style: AppTextStyles.subtitle),
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
                      Icons.local_hospital,
                      color: isCurrent ? AppColors.confirmedGreen : AppColors.textSecondary,
                    ),
                    title: Text(h['name']?.toString() ?? 'Hospital', style: AppTextStyles.body),
                    subtitle: Text(
                      '${h['distanceText'] ?? ''} · ${h['address'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                    trailing: isCurrent
                        ? const Icon(Icons.check_circle, color: AppColors.confirmedGreen, size: 20)
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
            const SizedBox(height: 8),
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
      await _repo.changeHospital(caseId, id);
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
        backgroundColor: AppColors.surfaceTwo,
        title: Text('Cancel emergency?', style: AppTextStyles.subtitle),
        content: Text(
          'The ambulance will be released. Only cancel if you no longer need help.',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text('Keep', style: AppTextStyles.caption),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              await ref.read(sosProvider.notifier).cancelActiveCase();
              if (mounted) context.go(Routes.home);
            },
            child: Text('Cancel SOS', style: AppTextStyles.caption.copyWith(color: AppColors.sosRed)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            backgroundColor: AppColors.surfaceTwo,
            title: Text('You have arrived', style: AppTextStyles.subtitle),
            content: Text('You reached the hospital. Stay safe!',
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(d).pop();
                  if (mounted) context.go(Routes.home);
                },
                child: Text('Done', style: AppTextStyles.caption.copyWith(color: AppColors.confirmedGreen)),
              ),
            ],
          ),
        );
      } else if (status == SOSStatus.cancelled || status == SOSStatus.idle) {
        if (mounted) context.go(Routes.home);
      }
    });

    final c = ref.watch(sosProvider).activeCase;
    if (c == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.sosRed)),
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

    // Back returns to home; the case stays active and tracking is reachable
    // again from there (and on next app launch via session restore).
    return BackTo(
      onBack: () => context.go(Routes.home),
      child: Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: driver ?? patient, initialZoom: 14),
            children: [
              const ResQPKTileLayer(),
              PolylineLayer(
                polylines: [
                  // Road-following route for the current leg (pickup = blue
                  // driver→patient; dropoff = green →hospital). Falls back to a
                  // straight line only while the road route hasn't loaded yet.
                  if (_routePoints.length >= 2)
                    ...routePolyline(
                      _routePoints,
                      color: _routeLeg == 'dropoff'
                          ? AppColors.confirmedGreen
                          : AppColors.infoBlue,
                    )
                  else if (_routeLeg != 'dropoff' && driver != null)
                    ...routePolyline([driver, patient],
                        color: AppColors.infoBlue, isAlternate: true)
                  else if (_routeLeg == 'dropoff' && hospital != null)
                    ...routePolyline([patient, hospital],
                        color: AppColors.confirmedGreen, isAlternate: true),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: patient,
                    width: MapSpec.touchTarget,
                    height: MapSpec.touchTarget,
                    child: const UserLocationDot(color: AppColors.sosRed),
                  ),
                  if (hospital != null)
                    Marker(
                      point: hospital,
                      width: MapSpec.touchTarget,
                      height: MapSpec.pinHeight,
                      alignment: Alignment.topCenter,
                      child: const MapDestinationPin(color: AppColors.confirmedGreen),
                    ),
                  if (driver != null)
                    Marker(
                      point: driver,
                      width: MapSpec.touchTarget,
                      height: MapSpec.touchTarget,
                      child: NavigationPuck(
                        headingDegrees: _driverHeading,
                        color: AppColors.infoBlue,
                        icon: Icons.navigation,
                      ),
                    ),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _StatusPill(status: ref.watch(sosProvider).status),
                    const SizedBox(width: 8),
                    _RequestCodeChip(caseId: c.id),
                    const Spacer(),
                    _UpdatesButton(
                      unread: _unreadUpdates,
                      onTap: () => _openUpdatesSheet(c.id),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatusCard(
                  driverName: c.driverName ?? 'Driver',
                  vehicleNumber: c.vehicleNumber ?? '',
                  etaText: _etaText(eta, ref.watch(sosProvider).status),
                  progress: progress,
                  hospitalName: c.hospitalName ?? 'Hospital',
                  hasReport: _latestReport != null ||
                      (ref.watch(aiReportProvider).report?.isComplete ?? false),
                  onCallDriver: () => _call(c.driverPhone),
                  // With a report in hand the document is what they want to
                  // see; otherwise take them to the generation screen.
                  onAiReport: () {
                    final existing =
                        _latestReport ?? ref.read(aiReportProvider).report;
                    if (existing != null && existing.isComplete) {
                      context.push(Routes.reportPdf,
                          extra: {'caseId': c.id, 'report': existing});
                    } else {
                      context.push(Routes.aiReport, extra: c.id);
                    }
                  },
                  onCancel: _confirmCancel,
                  onChangeHospital: _openChangeHospitalSheet,
                  hospitalConfirmed: ref.watch(sosProvider).isHospitalConfirmed,
                  preparationNote: ref.watch(sosProvider).hospitalPreparationNote,
                  hospitalSelected: c.hospitalId != null,
                  hasDriver: c.driverId != null,
                  suggestedHospital: _suggestedHospital,
                  loadingSuggestion: _loadingSuggestion,
                  confirmingHospital: _confirmingHospital,
                  onConfirmHospital: _confirmSuggestedHospital,
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  String _etaText(int? seconds, SOSStatus status) {
    if (status == SOSStatus.arrived) return 'Arrived';
    if (seconds == null) return 'Calculating...';
    final mins = (seconds / 60).ceil();
    return 'ETA: $mins min';
  }
}

enum _UpdateKind { hospital, accepted, driver, report }

class _CaseUpdate {
  final _UpdateKind kind;
  final String title;
  final String body;
  final DateTime at;

  const _CaseUpdate({
    required this.kind,
    required this.title,
    required this.body,
    required this.at,
  });
}

/// Bell-style button beside the EMERGENCY ACTIVE pill. Replaces the panel that
/// used to sit over the map and cover the route.
class _UpdatesButton extends StatelessWidget {
  final int unread;
  final VoidCallback onTap;

  const _UpdatesButton({required this.unread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surfaceTwo,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.borderGlass),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.notifications_none, color: AppColors.textPrimary, size: 21),
            if (unread > 0)
              Positioned(
                top: 8,
                right: 9,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.sosRed,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _UpdateTile extends StatelessWidget {
  final _CaseUpdate update;
  final VoidCallback? onViewReport;
  final VoidCallback? onSeeGuide;

  const _UpdateTile({required this.update, this.onViewReport, this.onSeeGuide});

  ({IconData icon, Color color}) get _style {
    switch (update.kind) {
      case _UpdateKind.accepted:
        return (icon: Icons.check_circle, color: AppColors.confirmedGreen);
      case _UpdateKind.hospital:
        return (icon: Icons.local_hospital, color: AppColors.infoBlue);
      case _UpdateKind.driver:
        return (icon: Icons.local_shipping, color: AppColors.infoBlue);
      case _UpdateKind.report:
        return (icon: Icons.description, color: AppColors.warningAmber);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceTwo,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: s.color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(s.icon, color: s.color, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(update.title,
                        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(update.body, style: AppTextStyles.caption),
                  ],
                ),
              ),
              Text(
                TimeOfDay.fromDateTime(update.at).format(context),
                style: AppTextStyles.caption,
              ),
            ],
          ),
          if (onViewReport != null || onSeeGuide != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (onViewReport != null)
                  TextButton.icon(
                    onPressed: onViewReport,
                    icon: const Icon(Icons.picture_as_pdf, size: 15, color: AppColors.infoBlue),
                    label: Text('View Report',
                        style: AppTextStyles.caption.copyWith(color: AppColors.infoBlue)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                if (onSeeGuide != null)
                  TextButton.icon(
                    onPressed: onSeeGuide,
                    icon: const Icon(Icons.medical_information,
                        size: 15, color: AppColors.confirmedGreen),
                    label: Text('First Aid Guide',
                        style: AppTextStyles.caption.copyWith(color: AppColors.confirmedGreen)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
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

class _StatusPill extends StatelessWidget {
  final SOSStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceTwo,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderGlass),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emergency, color: AppColors.sosRed, size: 16),
          const SizedBox(width: 8),
          Text('EMERGENCY ACTIVE', style: AppTextStyles.caption.copyWith(color: AppColors.sosRed)),
        ],
      ),
    );
  }
}

/// The request code, for a patient who has no account.
///
/// It is the only handle they have on this emergency — it reopens the request
/// from any phone and unlocks the report afterwards — so it belongs on screen
/// while the ambulance is coming, not only in the confirmation that scrolled
/// away. Tapping copies it.
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceTwo,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.borderGlass),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.tag_rounded, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(code, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}

/// Shown until the patient confirms a destination. No hospital is notified
/// before this; the nearest one is only a default the patient can change.
class _HospitalConfirmBlock extends StatelessWidget {
  final bool hasDriver;
  final Map<String, dynamic>? suggestedHospital;
  final bool loading;
  final bool confirming;
  final VoidCallback onConfirm;
  final VoidCallback onChooseAnother;

  const _HospitalConfirmBlock({
    required this.hasDriver,
    required this.suggestedHospital,
    required this.loading,
    required this.confirming,
    required this.onConfirm,
    required this.onChooseAnother,
  });

  @override
  Widget build(BuildContext context) {
    final name = suggestedHospital?['name']?.toString();
    final distance = suggestedHospital?['distanceText']?.toString();

    final String message;
    if (!hasDriver) {
      message = 'You can choose a hospital once an ambulance accepts your request.';
    } else if (name == null) {
      message = loading
          ? 'Finding the nearest hospital…'
          : 'Could not find a nearby hospital. Choose one from the list.';
    } else {
      message = 'Nearest: $name${distance != null ? ' · $distance' : ''}';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningAmber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warningAmber.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.local_hospital, color: AppColors.warningAmber, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasDriver ? 'Confirm your hospital' : 'Hospital',
                  style: AppTextStyles.subtitle.copyWith(fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(message, style: name != null ? AppTextStyles.body : AppTextStyles.caption),
          if (hasDriver) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: (name == null || confirming) ? null : onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.confirmedGreen,
                      disabledBackgroundColor: AppColors.surfaceThree,
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    ),
                    child: confirming
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text('Confirm', style: AppTextStyles.buttonLabel.copyWith(fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: confirming ? null : onChooseAnother,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.infoBlue),
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    ),
                    child: Text(
                      'Choose another',
                      style: AppTextStyles.caption.copyWith(color: AppColors.infoBlue),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'The hospital is only notified after you confirm.',
              style: AppTextStyles.caption.copyWith(fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String driverName;
  final String vehicleNumber;
  final String etaText;
  final double progress;
  final String hospitalName;
  final bool hasReport;
  final VoidCallback onCallDriver;
  final VoidCallback onAiReport;
  final VoidCallback onCancel;
  final VoidCallback onChangeHospital;
  final bool hospitalConfirmed;
  final String? preparationNote;
  final bool hospitalSelected;
  final bool hasDriver;
  final Map<String, dynamic>? suggestedHospital;
  final bool loadingSuggestion;
  final bool confirmingHospital;
  final VoidCallback onConfirmHospital;

  const _StatusCard({
    required this.driverName,
    required this.vehicleNumber,
    required this.etaText,
    required this.progress,
    required this.hospitalName,
    this.hasReport = false,
    required this.onCallDriver,
    required this.onAiReport,
    required this.onCancel,
    required this.onChangeHospital,
    this.hospitalConfirmed = false,
    this.preparationNote,
    this.hospitalSelected = true,
    this.hasDriver = true,
    this.suggestedHospital,
    this.loadingSuggestion = false,
    this.confirmingHospital = false,
    required this.onConfirmHospital,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          decoration: BoxDecoration(
            color: AppColors.surfaceOne.withValues(alpha: 0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppColors.borderGlass),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.infoBlue,
                    child: Text(
                      driverName.isNotEmpty ? driverName[0].toUpperCase() : '?',
                      style: AppTextStyles.subtitle.copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(driverName, style: AppTextStyles.subtitle),
                        Text(vehicleNumber, style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onCallDriver,
                    icon: const Icon(Icons.phone, color: AppColors.confirmedGreen),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(etaText, style: AppTextStyles.subtitle.copyWith(color: AppColors.confirmedGreen)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppColors.surfaceThree,
                  color: AppColors.confirmedGreen,
                ),
              ),
              const SizedBox(height: 16),
              if (!hospitalSelected)
                _HospitalConfirmBlock(
                  hasDriver: hasDriver,
                  suggestedHospital: suggestedHospital,
                  loading: loadingSuggestion,
                  confirming: confirmingHospital,
                  onConfirm: onConfirmHospital,
                  onChooseAnother: onChangeHospital,
                )
              else ...[
                Row(
                  children: [
                    const Icon(Icons.local_hospital, color: AppColors.confirmedGreen, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(hospitalName, style: AppTextStyles.body)),
                    if (hospitalConfirmed)
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.85, end: 1),
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutBack,
                        builder: (context, scale, child) =>
                            Transform.scale(scale: scale, child: child),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.confirmedGreen.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.confirmedGreen),
                          ),
                          child: Text(
                            'Hospital confirmed ✓',
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.confirmedGreen, fontWeight: FontWeight.bold),
                          ),
                        ),
                      )
                    else
                      TextButton(
                        onPressed: onChangeHospital,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Change',
                          style: AppTextStyles.caption.copyWith(color: AppColors.infoBlue),
                        ),
                      ),
                  ],
                ),
                if (!hospitalConfirmed)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 26),
                    child: Text('Waiting for the hospital to accept', style: AppTextStyles.caption),
                  ),
                if (hospitalConfirmed && preparationNote != null && preparationNote!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 26),
                    child: Text(preparationNote!, style: AppTextStyles.caption),
                  ),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onAiReport,
                icon: const Icon(Icons.smart_toy_outlined, color: AppColors.infoBlue, size: 18),
                label: Text(hasReport ? 'View Full Report' : 'Generate AI Report',
                    style: AppTextStyles.caption.copyWith(color: AppColors.infoBlue)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.infoBlue)),
              ),
              TextButton(
                onPressed: onCancel,
                child: Text('Cancel Emergency',
                    style: AppTextStyles.caption.copyWith(color: AppColors.sosRed)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
