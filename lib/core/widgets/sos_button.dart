import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// What the button is doing. Drives the label and the ring.
enum SosButtonPhase { idle, holding, searching, active }

/// The SOS control — the reason this app exists.
///
/// Press and hold. The ring fills as the hold progresses, so the user can see
/// how much longer to keep pressing, and a haptic pulse confirms the press
/// registered even if they are not looking at the screen.
///
/// Deliberately a dumb widget: it renders a phase and reports gestures. All
/// timing lives in the SOS notifier, so the countdown survives a rebuild.
class SosButton extends StatelessWidget {
  const SosButton({
    super.key,
    required this.phase,
    required this.progress,
    required this.onHoldStart,
    required this.onHoldEnd,
    this.onTapWhenActive,
    this.size = 210,
  });

  final SosButtonPhase phase;

  /// 0 → 1 as the hold completes.
  final double progress;

  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;
  final VoidCallback? onTapWhenActive;
  final double size;

  String get _label => switch (phase) {
        SosButtonPhase.idle => 'SOS',
        SosButtonPhase.holding => 'KEEP\nHOLDING',
        SosButtonPhase.searching => 'FINDING\nAMBULANCE',
        SosButtonPhase.active => 'VIEW\nAMBULANCE',
      };

  String get _hint => switch (phase) {
        SosButtonPhase.idle => 'Press and hold',
        SosButtonPhase.holding => 'Release to cancel',
        SosButtonPhase.searching => 'Stay with the patient',
        SosButtonPhase.active => 'Tap to track',
      };

  @override
  Widget build(BuildContext context) {
    final busy = phase == SosButtonPhase.searching || phase == SosButtonPhase.active;

    return Semantics(
      button: true,
      label: 'Emergency SOS. $_hint',
      child: GestureDetector(
        onTap: phase == SosButtonPhase.active ? onTapWhenActive : null,
        onLongPressStart: busy
            ? null
            : (_) {
                HapticFeedback.mediumImpact();
                onHoldStart();
              },
        onLongPressEnd: busy ? null : (_) => onHoldEnd(),
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _SosRingPainter(
              progress: phase == SosButtonPhase.holding ? progress : 0,
              pulsing: phase == SosButtonPhase.searching,
            ),
            child: Center(
              child: Container(
                width: size - 34,
                height: size - 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: busy ? Resq.criticalPressed : Resq.critical,
                  boxShadow: [
                    BoxShadow(
                      color: Resq.critical.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _label,
                      textAlign: TextAlign.center,
                      style: ResqType.display(color: Colors.white).copyWith(
                        fontSize: phase == SosButtonPhase.idle ? 44 : 20,
                        height: 1.1,
                        letterSpacing: phase == SosButtonPhase.idle ? 1 : 0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _hint,
                      textAlign: TextAlign.center,
                      style: ResqType.caption(color: Colors.white.withValues(alpha: 0.9)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SosRingPainter extends CustomPainter {
  _SosRingPainter({required this.progress, required this.pulsing});

  final double progress;
  final bool pulsing;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = Resq.critical.withValues(alpha: pulsing ? 0.25 : 0.15);
    canvas.drawCircle(centre, radius, track);

    if (progress <= 0) return;

    // Starts at twelve o'clock and fills clockwise, the direction people expect
    // a timer to run.
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = Resq.critical;
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_SosRingPainter old) =>
      old.progress != progress || old.pulsing != pulsing;
}
