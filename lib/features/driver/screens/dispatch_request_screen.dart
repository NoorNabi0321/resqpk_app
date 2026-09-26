import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/map/resqpk_map.dart';
import '../../../core/realtime/realtime_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../sos/data/models/dispatch_request_model.dart';
import '../../sos/data/sos_repository.dart';
import '../widgets/driver_chrome.dart';

/// Why a driver turned an emergency down.
///
/// Optional, and never in the way: the timer is running, and a driver who taps
/// Decline and nothing else must free the case for the next ambulance
/// immediately. The reason is asked after the decline is already sent.
const List<({String key, String label, IconData icon})> kDeclineReasons = [
  (key: 'on_another_case', label: 'On another case', icon: Icons.local_shipping_rounded),
  (key: 'too_far', label: 'Too far to reach in time', icon: Icons.route_rounded),
  (key: 'vehicle_issue', label: 'Vehicle problem', icon: Icons.build_rounded),
  (key: 'not_available', label: 'Not available right now', icon: Icons.schedule_rounded),
  (key: 'other', label: 'Something else', icon: Icons.more_horiz_rounded),
];

/// Full-screen interrupt when a dispatch request arrives.
/// Pops with 'accepted' | 'declined' | 'timeout' | 'expired' | 'error'
/// | 'cancelled'.
class DispatchRequestScreen extends ConsumerStatefulWidget {
  const DispatchRequestScreen({super.key, required this.request});

  final DispatchRequestModel request;

  @override
  ConsumerState<DispatchRequestScreen> createState() => _DispatchRequestScreenState();
}

class _DispatchRequestScreenState extends ConsumerState<DispatchRequestScreen> {
  final SOSRepository _repo = SOSRepository();
  Timer? _timer;
  StreamSubscription<Map<String, dynamic>>? _caseEvtSub;
  int _remainingMs = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _remainingMs = widget.request.timeoutMs;
    HapticFeedback.heavyImpact();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() => _remainingMs -= 100);
      if (_remainingMs <= 0) _respondAndPop('declined', 'timeout');
    });

    // The patient can call it off while this is still counting down. Without
    // this the offer stayed up for the rest of the fifteen seconds, and a
    // driver who accepted in that window was told "another ambulance took it"
    // — the wrong reason for the right outcome, and one that makes the app
    // look like it lost a race it was never in.
    _caseEvtSub = ref.read(socketServiceProvider).caseUpdateStream.listen((data) {
      if (!mounted) return;
      if (data['event']?.toString() != 'cancelled') return;
      // Another case entirely — a stale room, or one this driver is not being
      // offered — must not close this offer.
      final caseId = data['caseId']?.toString();
      if (caseId != null && caseId != widget.request.caseId) return;
      _popCancelled();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _caseEvtSub?.cancel();
    super.dispose();
  }

  /// Close the offer without answering it. There is nothing left to accept or
  /// decline, and the server has already freed this driver.
  void _popCancelled() {
    if (_busy) return;
    _busy = true;
    _timer?.cancel();
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop('cancelled');
  }

  Future<void> _respondAndPop(String response, String popResult, {String? reason}) async {
    if (_busy) return;
    _busy = true;
    _timer?.cancel();
    try {
      final ok = await _repo.respondToDispatch(
        widget.request.caseId,
        response,
        reason: reason,
      );
      if (!mounted) return;
      Navigator.of(context).pop(response == 'accepted' && !ok ? 'expired' : popResult);
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop('error');
    }
  }

  /// Declines first, then asks why.
  ///
  /// The other way round would hold the ambulance queue open while a driver
  /// reads five options — and the patient is the one paying for that pause.
  Future<void> _decline() async {
    if (_busy) return;
    _timer?.cancel();
    _busy = true;

    try {
      await _repo.respondToDispatch(widget.request.caseId, 'declined');
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop('error');
      return;
    }
    if (!mounted) return;

    final reason = await _askReason();
    if (reason != null) {
      // Best-effort: the decline already counted, this only labels it.
      try {
        await _repo.respondToDispatch(widget.request.caseId, 'declined', reason: reason);
      } catch (_) {
        // Nothing to tell the driver — the case has already moved on.
      }
    }
    if (mounted) Navigator.of(context).pop('declined');
  }

  Future<String?> _askReason() {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Resq.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Resq.radiusCard)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Resq.space5, Resq.space5, Resq.space5, Resq.space4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Declined — why?', style: ResqType.title(color: Resq.ink)),
              const SizedBox(height: 4),
              Text(
                'The case has already gone to the next ambulance. This only helps '
                'dispatch understand what is happening on the ground.',
                style: ResqType.caption(color: Resq.inkMuted),
              ),
              const SizedBox(height: Resq.space4),
              for (final reason in kDeclineReasons)
                Padding(
                  padding: const EdgeInsets.only(bottom: Resq.space2),
                  child: DriverCard(
                    padding: const EdgeInsets.all(Resq.space3),
                    onTap: () => Navigator.of(sheetCtx).pop(reason.key),
                    child: Row(
                      children: [
                        Icon(reason.icon, size: 20, color: Resq.inkMuted),
                        const SizedBox(width: Resq.space3),
                        Expanded(
                          child: Text(
                            reason.label,
                            style: ResqType.body(color: Resq.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.of(sheetCtx).pop(),
                child: Text('Skip', style: ResqType.button(color: Resq.inkMuted)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final seconds = (_remainingMs / 1000).ceil().clamp(0, 99);
    final progress =
        r.timeoutMs > 0 ? (_remainingMs / r.timeoutMs).clamp(0.0, 1.0) : 0.0;
    // Runs out red: the last few seconds are the ones a driver needs to feel.
    final ringColor = progress > 0.4 ? Resq.ready : (progress > 0.2 ? Resq.decision : Resq.critical);

    return Theme(
      data: ResqTheme.light,
      child: Scaffold(
        backgroundColor: Resq.canvas,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Resq.space4),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Resq.space3,
                        vertical: Resq.space2,
                      ),
                      decoration: BoxDecoration(
                        color: Resq.critical,
                        borderRadius: BorderRadius.circular(Resq.radiusPill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.emergency_rounded, color: Colors.white, size: 15),
                          const SizedBox(width: 6),
                          Text('EMERGENCY', style: ResqType.micro(color: Colors.white)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(r.caseNumber, style: ResqType.caption(color: Resq.inkMuted)),
                  ],
                ),
                const SizedBox(height: Resq.space4),

                Text(
                  r.distanceText,
                  style: ResqType.display(color: Resq.ink).copyWith(fontSize: 40),
                ),
                Text(
                  'away · ${r.patientName} needs an ambulance',
                  textAlign: TextAlign.center,
                  style: ResqType.body(color: Resq.inkMuted),
                ),
                const SizedBox(height: Resq.space4),

                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Resq.radiusCard),
                    child: AbsorbPointer(
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(r.patientLat, r.patientLng),
                          initialZoom: 15,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.none,
                          ),
                        ),
                        children: [
                          const ResQPKTileLayer(light: true),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(r.patientLat, r.patientLng),
                                width: MapSpec.touchTarget,
                                height: MapSpec.touchTarget,
                                child: const UserLocationDot(
                                  color: Resq.critical,
                                  showPulse: true,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Resq.space4),

                SizedBox(
                  width: 92,
                  height: 92,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 92,
                        height: 92,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: progress, end: progress),
                          duration: const Duration(milliseconds: 120),
                          builder: (_, value, __) => CircularProgressIndicator(
                            value: value,
                            strokeWidth: 6,
                            color: ringColor,
                            backgroundColor: Resq.surfaceAlt,
                          ),
                        ),
                      ),
                      Text(
                        '$seconds',
                        style: ResqType.display(color: Resq.ink).copyWith(fontSize: 32),
                      ),
                    ],
                  ),
                ),
                Text('seconds to answer', style: ResqType.caption(color: Resq.inkMuted)),
                const SizedBox(height: Resq.space4),

                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 60,
                        child: OutlinedButton(
                          onPressed: _busy ? null : _decline,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Resq.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(Resq.radiusControl),
                            ),
                          ),
                          child: Text(
                            'Decline',
                            style: ResqType.button(color: Resq.inkMuted),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: Resq.space3),
                    Expanded(
                      flex: 2,
                      child: DriverButton(
                        label: 'Accept',
                        icon: Icons.check_rounded,
                        height: 60,
                        busy: _busy,
                        onPressed: () => _respondAndPop('accepted', 'accepted'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
