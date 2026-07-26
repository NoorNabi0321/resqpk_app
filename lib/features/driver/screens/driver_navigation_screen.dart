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
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/location/location_provider.dart';
import '../../../core/realtime/realtime_provider.dart';
import '../../../core/router/app_router.dart';
import '../../sos/data/models/emergency_case_model.dart';
import '../../sos/data/models/quick_message_model.dart';
import '../../sos/data/sos_repository.dart';
import '../providers/driver_realtime_provider.dart';

class DriverNavigationScreen extends ConsumerStatefulWidget {
  final String caseId;

  const DriverNavigationScreen({super.key, required this.caseId});

  @override
  ConsumerState<DriverNavigationScreen> createState() => _DriverNavigationScreenState();
}

class _DriverNavigationScreenState extends ConsumerState<DriverNavigationScreen> {
  final SOSRepository _repo = SOSRepository();
  final MapController _mapController = MapController();
  EmergencyCaseModel? _case;
  String _status = 'driver_assigned';
  bool _loading = true;
  bool _busy = false;
  bool _completed = false;

  // Road-following route for the current leg.
  List<LatLng> _routePoints = [];
  Timer? _routeTimer;
  bool _fetchingRoute = false;
  StreamSubscription<Map<String, dynamic>>? _caseEvtSub;

  // v2 — hospital decision state.
  String _decision = 'awaiting_review';
  String? _acceptedHospitalName;
  String? _preparationNote;

  // v2 — quick messages.
  List<QuickMessage> _driverMessages = [];
  final List<CaseMessage> _messageLog = [];
  String? _sendingKey;
  String? _sentKey;
  int _unreadMessages = 0;

  @override
  void initState() {
    super.initState();
    // Attach the caseId so the driver's location stream powers patient/hospital ETA.
    final broadcaster = ref.read(driverLocationBroadcasterProvider);
    broadcaster.updateActiveCaseId(widget.caseId);
    if (!broadcaster.isBroadcasting) {
      broadcaster.startBroadcasting(caseId: widget.caseId);
    }
    _loadCase();
    _routeTimer = Timer.periodic(const Duration(seconds: 45), (_) => _fetchRoute());

    _loadMessages();

    _caseEvtSub = ref.read(socketServiceProvider).caseUpdateStream.listen(_onCaseEvent);
  }

  void _onCaseEvent(Map<String, dynamic> data) {
    if (!mounted) return;
    switch (data['event']?.toString()) {
      // Patient switched hospitals themselves — reload destination + route.
      case 'hospital_changed':
        _loadCase();
        _fetchRoute();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hospital changed to ${data['hospitalName'] ?? 'a new hospital'}')),
        );
        break;

      case 'hospital_accepted':
        HapticFeedback.mediumImpact();
        setState(() {
          _decision = 'accepted';
          _acceptedHospitalName = data['hospitalName']?.toString();
          _preparationNote = data['preparationNote']?.toString();
        });
        break;

      case 'hospital_redirected':
        _showRedirectAlert(data);
        break;

      case 'quick_message':
        final message = CaseMessage.fromJson(data);
        if (!message.isFromHospital) return; // our own message echoing back
        setState(() {
          _messageLog.add(message);
          _unreadMessages += 1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 4),
            backgroundColor: AppColors.surfaceTwo,
            content: Row(
              children: [
                const Icon(Icons.local_hospital, color: AppColors.confirmedGreen, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(message.messageText, style: AppTextStyles.body)),
              ],
            ),
          ),
        );
        break;

      default:
        break;
    }
  }

  Future<void> _loadMessages() async {
    try {
      final results = await Future.wait([
        _repo.getMessageConstants(),
        _repo.getCaseMessages(widget.caseId),
      ]);
      if (!mounted) return;
      setState(() {
        _driverMessages = (results[0] as List<QuickMessage>)
            .where((m) => m.role == 'driver')
            .toList();
        _messageLog
          ..clear()
          ..addAll(results[1] as List<CaseMessage>);
      });
    } catch (_) {
      // Messaging is a convenience — never block navigation on it.
    }
  }

  Future<void> _sendMessage(String key) async {
    setState(() => _sendingKey = key);
    try {
      await _repo.sendQuickMessage(widget.caseId, key);
      if (!mounted) return;
      setState(() {
        _sendingKey = null;
        _sentKey = key;
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _sentKey == key) setState(() => _sentKey = null);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendingKey = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _openMessageLog() {
    setState(() => _unreadMessages = 0);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceOne,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Messages', style: AppTextStyles.subtitle),
              const SizedBox(height: 12),
              if (_messageLog.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('No messages yet.',
                      textAlign: TextAlign.center, style: AppTextStyles.caption),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _messageLog.length,
                    itemBuilder: (_, i) {
                      final m = _messageLog[i];
                      return Align(
                        alignment:
                            m.isFromHospital ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: m.isFromHospital
                                ? AppColors.surfaceTwo
                                : AppColors.infoBlue.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.messageText, style: AppTextStyles.body),
                              if (m.createdAt != null)
                                Text(
                                  TimeOfDay.fromDateTime(m.createdAt!.toLocal()).format(context),
                                  style: AppTextStyles.caption,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // A redirect changes where this ambulance is going — it must be acknowledged,
  // so the alert is full-screen and cannot be dismissed by tapping away.
  void _showRedirectAlert(Map<String, dynamic> data) {
    final newHospital = data['newHospital'] as Map<String, dynamic>?;
    final name = newHospital?['name']?.toString() ?? 'another hospital';
    final reason = data['reason']?.toString() ?? '';
    final etaText = data['newEtaText']?.toString();

    HapticFeedback.heavyImpact();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => Dialog.fullscreen(
        backgroundColor: AppColors.warningAmber,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.alt_route, color: Colors.white, size: 84),
                const SizedBox(height: 20),
                Text(
                  'REDIRECT',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.display.copyWith(color: Colors.white, fontSize: 34),
                ),
                const SizedBox(height: 16),
                Text(
                  'Go to $name instead',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.title.copyWith(color: Colors.white),
                ),
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Reason: $reason',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(color: Colors.white70),
                  ),
                ],
                if (etaText != null && etaText.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'New ETA: $etaText',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(color: Colors.white70),
                  ),
                ],
                const SizedBox(height: 36),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogCtx).pop();
                      _applyRedirect(data);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.warningAmber,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    ),
                    child: Text(
                      'Confirm — Rerouting',
                      style: AppTextStyles.buttonLabel.copyWith(color: AppColors.warningAmber),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Point navigation at the new hospital and redraw the route to it.
  Future<void> _applyRedirect(Map<String, dynamic> data) async {
    final newHospital = data['newHospital'] as Map<String, dynamic>?;
    final name = newHospital?['name']?.toString() ?? 'the new hospital';
    final lat = double.tryParse('${newHospital?['lat']}');
    final lng = double.tryParse('${newHospital?['lng']}');

    setState(() {
      _decision = 'awaiting_review'; // the new hospital must decide for itself
      _acceptedHospitalName = null;
      _preparationNote = null;
      _routePoints = [];
      if (lat != null && lng != null) {
        _case = _case?.copyWith(
          hospitalId: newHospital?['id']?.toString(),
          hospitalName: name,
          hospitalLat: lat,
          hospitalLng: lng,
        );
      }
    });

    await _loadCase(); // authoritative destination from the backend
    await _fetchRoute();

    if (!mounted) return;
    if (lat != null && lng != null && _status == 'en_route') {
      _mapController.move(LatLng(lat, lng), _mapController.camera.zoom);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Route updated to $name')),
    );
  }

  @override
  void dispose() {
    _routeTimer?.cancel();
    _caseEvtSub?.cancel();
    super.dispose();
  }

  Future<void> _loadCase() async {
    try {
      final c = await _repo.getCaseDetails(widget.caseId);
      if (!mounted) return;
      setState(() {
        _case = c;
        _status = c.status;
        _loading = false;
      });
      _fetchRoute();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchRoute() async {
    if (_fetchingRoute || _completed) return;
    _fetchingRoute = true;
    try {
      final route = await _repo.getCaseRoute(widget.caseId);
      final coords = (route['coordinates'] as List? ?? [])
          .whereType<Map>()
          .map((p) => LatLng(
                double.tryParse('${p['lat']}') ?? 0,
                double.tryParse('${p['lng']}') ?? 0,
              ))
          .toList();
      if (mounted) setState(() => _routePoints = coords);
    } catch (_) {
      // Straight-line fallback stays if routing is unavailable.
    } finally {
      _fetchingRoute = false;
    }
  }

  Future<void> _advance(String toStatus) async {
    setState(() => _busy = true);
    try {
      await _repo.updateCaseStatus(widget.caseId, toStatus);
      if (!mounted) return;
      setState(() {
        _status = toStatus;
        _busy = false;
        _routePoints = []; // leg changed — clear stale route until refetched
      });
      if (toStatus == 'completed') {
        _onCompleted();
      } else {
        _fetchRoute();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _onCompleted() {
    ref.read(driverLocationBroadcasterProvider).updateActiveCaseId(null);
    setState(() => _completed = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) context.go(Routes.driverHome);
    });
  }

  Future<void> _callPatient() async {
    final phone = _case?.patientPhone;
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  ({String label, String next})? _nextAction() {
    switch (_status) {
      case 'driver_assigned':
        return (label: 'I Have Arrived', next: 'arrived');
      case 'arrived':
        return (label: 'Patient in Ambulance — Start Trip', next: 'en_route');
      case 'en_route':
        return (label: 'Arrived at Hospital', next: 'completed');
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.sosRed)),
      );
    }
    if (_completed) {
      return const _CompletedView();
    }

    final c = _case;
    final positionAsync = ref.watch(currentPositionStreamProvider);
    final driverPos = positionAsync.asData?.value;
    final driver = driverPos != null ? LatLng(driverPos.latitude, driverPos.longitude) : null;

    final goingToHospital = _status == 'en_route';
    final target = goingToHospital && c?.hospitalLat != null && c?.hospitalLng != null
        ? LatLng(c!.hospitalLat!, c.hospitalLng!)
        : (c != null ? LatLng(c.patientLat, c.patientLng) : null);

    final action = _nextAction();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: driver ?? target ?? const LatLng(25.3792, 68.3683), initialZoom: 14),
            children: [
              TileLayer(
                urlTemplate: AppConstants.mapTileUrl,
                userAgentPackageName: 'com.resqpk.resqpk_app',
              ),
              PolylineLayer(polylines: [
                if (_routePoints.length >= 2)
                  Polyline(
                    points: _routePoints,
                    color: goingToHospital ? AppColors.confirmedGreen : AppColors.infoBlue,
                    strokeWidth: 5,
                  )
                else if (driver != null && target != null)
                  Polyline(points: [driver, target], color: AppColors.infoBlue, strokeWidth: 4),
              ]),
              MarkerLayer(markers: [
                if (target != null)
                  Marker(
                    point: target,
                    width: 34,
                    height: 34,
                    child: Icon(
                      goingToHospital ? Icons.local_hospital : Icons.location_on,
                      color: goingToHospital ? AppColors.confirmedGreen : AppColors.sosRed,
                      size: 32,
                    ),
                  ),
                if (driver != null)
                  Marker(
                    point: driver,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: const BoxDecoration(color: AppColors.infoBlue, shape: BoxShape.circle),
                      padding: const EdgeInsets.all(8),
                      child: const Icon(Icons.airport_shuttle, color: Colors.white, size: 20),
                    ),
                  ),
              ]),
            ],
          ),
          SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceTwo,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.borderGlass),
                        ),
                        child: Text(
                          '${c?.patientName ?? 'Patient'} · ${(c?.urgencyLevel ?? 'emergency').toUpperCase()}',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption,
                        ),
                      ),
                    ),
                    _MessageLogButton(unread: _unreadMessages, onTap: _openMessageLog),
                    const SizedBox(width: 12),
                  ],
                ),
                _HospitalDecisionBanner(
                  decision: _decision,
                  hospitalName: _acceptedHospitalName ?? c?.hospitalName,
                  preparationNote: _preparationNote,
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _ActionCard(
              instruction: goingToHospital ? 'Head to the hospital' : 'Head to the patient',
              bloodGroup: c?.bloodGroup,
              conditions: c?.chronicConditions,
              busy: _busy,
              actionLabel: action?.label,
              onAction: action == null ? null : () => _advance(action.next),
              onCallPatient: _callPatient,
              quickMessages: _driverMessages,
              sendingKey: _sendingKey,
              sentKey: _sentKey,
              onSendMessage: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin strip under the patient pill: what the hospital has decided so far.
class _HospitalDecisionBanner extends StatelessWidget {
  final String decision;
  final String? hospitalName;
  final String? preparationNote;

  const _HospitalDecisionBanner({
    required this.decision,
    required this.hospitalName,
    required this.preparationNote,
  });

  @override
  Widget build(BuildContext context) {
    final accepted = decision == 'accepted';
    final label = accepted
        ? '✅ ${hospitalName ?? 'Hospital'} accepted'
            '${preparationNote != null && preparationNote!.isNotEmpty ? ' · $preparationNote' : ''}'
        : '⏳ Hospital reviewing…';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: accepted
            ? AppColors.confirmedGreen.withValues(alpha: 0.92)
            : AppColors.surfaceTwo.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accepted ? AppColors.confirmedGreen : AppColors.borderGlass,
        ),
      ),
      width: double.infinity,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppTextStyles.caption.copyWith(
          color: accepted ? Colors.white : AppColors.textSecondary,
          fontWeight: accepted ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

/// Envelope with an unread badge — opens the timestamped message feed.
class _MessageLogButton extends StatelessWidget {
  final int unread;
  final VoidCallback onTap;

  const _MessageLogButton({required this.unread, required this.onTap});

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
            const Icon(Icons.mail_outline, color: AppColors.textSecondary, size: 20),
            if (unread > 0)
              Positioned(
                top: 6,
                right: 6,
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

class _ActionCard extends StatelessWidget {
  final String instruction;
  final String? bloodGroup;
  final List<String>? conditions;
  final bool busy;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onCallPatient;
  final List<QuickMessage> quickMessages;
  final String? sendingKey;
  final String? sentKey;
  final ValueChanged<String> onSendMessage;

  const _ActionCard({
    required this.instruction,
    required this.bloodGroup,
    required this.conditions,
    required this.busy,
    required this.actionLabel,
    required this.onAction,
    required this.onCallPatient,
    required this.quickMessages,
    required this.sendingKey,
    required this.sentKey,
    required this.onSendMessage,
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
              Text(instruction, style: AppTextStyles.subtitle),
              const SizedBox(height: 12),
              if (quickMessages.isNotEmpty) ...[
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: quickMessages.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final m = quickMessages[i];
                      final sending = sendingKey == m.key;
                      final sent = sentKey == m.key;
                      return GestureDetector(
                        onTap: sending ? null : () => onSendMessage(m.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: sent
                                ? AppColors.confirmedGreen.withValues(alpha: 0.2)
                                : AppColors.surfaceTwo,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: sent ? AppColors.confirmedGreen : AppColors.borderGlass,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (sending)
                                const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.textSecondary,
                                  ),
                                )
                              else if (sent)
                                const Icon(Icons.check,
                                    size: 13, color: AppColors.confirmedGreen),
                              if (sending || sent) const SizedBox(width: 6),
                              Text(
                                m.text,
                                style: AppTextStyles.caption.copyWith(
                                  color: sent
                                      ? AppColors.confirmedGreen
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  if (bloodGroup != null && bloodGroup!.isNotEmpty)
                    _chip('🩸 $bloodGroup', AppColors.sosRed),
                  if (conditions != null)
                    ...conditions!.take(2).map((c) => _chip(c, AppColors.warningAmber)),
                  const Spacer(),
                  IconButton(
                    onPressed: onCallPatient,
                    icon: const Icon(Icons.phone, color: AppColors.confirmedGreen),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: (busy || onAction == null) ? null : onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.confirmedGreen,
                    disabledBackgroundColor: AppColors.surfaceThree,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : Text(actionLabel ?? 'Trip complete', style: AppTextStyles.buttonLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, style: AppTextStyles.caption.copyWith(color: color)),
      );
}

class _CompletedView extends StatelessWidget {
  const _CompletedView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: AppColors.confirmedGreen, size: 80),
            const SizedBox(height: 16),
            Text('Trip completed', style: AppTextStyles.title),
            const SizedBox(height: 8),
            Text('Thank you! Returning to home...',
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
