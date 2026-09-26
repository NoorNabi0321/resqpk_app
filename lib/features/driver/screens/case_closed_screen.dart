import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';

/// Why the navigation screen went away, held for three seconds.
///
/// A case can end without the driver doing anything — the patient cancels, or
/// another driver takes over. Dropping straight back to the dashboard leaves
/// someone who was driving to an address wondering whether the app crashed or
/// they missed a step. This says what happened, thanks them, and gets out of
/// the way on its own.
class CaseClosedScreen extends StatefulWidget {
  const CaseClosedScreen({super.key, this.reason});

  /// Free text from the server, when it gave one.
  final String? reason;

  @override
  State<CaseClosedScreen> createState() => _CaseClosedScreenState();
}

class _CaseClosedScreenState extends State<CaseClosedScreen> {
  static const _hold = Duration(seconds: 3);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    _timer = Timer(_hold, _leave);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _leave() {
    if (!mounted) return;
    _timer?.cancel();
    context.go(Routes.driverHome);
  }

  @override
  Widget build(BuildContext context) {
    final falseAlarm = widget.reason == 'false_alarm';

    return Scaffold(
      backgroundColor: Resq.canvas,
      body: SafeArea(
        // Tappable, so a driver who has read it does not have to wait out the
        // three seconds.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _leave,
          child: Padding(
            padding: const EdgeInsets.all(Resq.space6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                    color: Resq.decisionTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.do_not_disturb_on_outlined,
                    size: 46,
                    color: Resq.decision,
                  ),
                )
                    .animate()
                    .scale(
                      duration: 320.ms,
                      begin: const Offset(0.82, 0.82),
                      end: const Offset(1, 1),
                      curve: Curves.easeOutBack,
                    )
                    .fadeIn(duration: 220.ms),
                const SizedBox(height: Resq.space5),
                Text(
                  'The patient cancelled',
                  textAlign: TextAlign.center,
                  style: ResqType.title(),
                ),
                const SizedBox(height: Resq.space3),
                Text(
                  falseAlarm
                      ? 'It turned out to be a false alarm. Sorry for the trip — '
                          'thank you for answering.'
                      : 'The emergency was called off. Sorry for the trip — thank '
                          'you for answering.',
                  textAlign: TextAlign.center,
                  style: ResqType.body(color: Resq.inkSoft),
                ),
                const SizedBox(height: Resq.space6),
                Text(
                  'You are back on duty',
                  style: ResqType.bodyStrong(color: Resq.ready),
                ),
                const SizedBox(height: Resq.space4),
                // Drains over the hold, so the wait is visibly finite rather
                // than a spinner that could mean anything.
                SizedBox(
                  width: 120,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Resq.radiusPill),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 1, end: 0),
                      duration: _hold,
                      builder: (_, value, __) => LinearProgressIndicator(
                        value: value,
                        minHeight: 4,
                        backgroundColor: Resq.border,
                        valueColor: const AlwaysStoppedAnimation(Resq.brand),
                      ),
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
}
