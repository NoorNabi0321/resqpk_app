import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';

/// One stage of a wait, named.
typedef ReportStage = ({IconData icon, String label});

/// The staged wait, shared by both halves of the report flow.
///
/// There are two waits now and they are not the same wait. The first analyses
/// what was said so it knows what to ask; the second writes the record from the
/// answers and sends it. A bare spinner for ten seconds reads as a hang, and
/// the same spinner twice reads as a bug — so each one names the stage it is on
/// and says what is happening at the hospital end.
///
/// The stages advance on time rather than on progress, because the server does
/// not report any. The bar never claims to be finished: the last stage stays
/// lit until the answer actually arrives.
class ReportProgress extends StatelessWidget {
  const ReportProgress({
    super.key,
    required this.stage,
    required this.stages,
    required this.footnote,
  });

  final int stage;
  final List<ReportStage> stages;

  /// The honest line about where the hospital stands. Different in each phase,
  /// and the thing someone standing over a casualty actually wants to know.
  final String footnote;

  @override
  Widget build(BuildContext context) {
    final current = stage.clamp(0, stages.length - 1);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const SizedBox(
                  width: 180,
                  height: 180,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Resq.brandInk,
                    backgroundColor: Resq.surfaceAlt,
                  ),
                ),
                Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    color: Resq.brandTint,
                    shape: BoxShape.circle,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      stages[current].icon,
                      key: ValueKey(current),
                      size: 52,
                      color: Resq.brandInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Resq.space6),
        for (var i = 0; i < stages.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: Resq.space3),
            child: Row(
              children: [
                Icon(
                  i < current
                      ? Icons.check_circle_rounded
                      : (i == current ? Icons.adjust_rounded : Icons.circle_outlined),
                  size: 18,
                  color: i <= current ? Resq.ready : Resq.inkFaint,
                ),
                const SizedBox(width: Resq.space3),
                Expanded(
                  child: Text(
                    stages[i].label,
                    style: i == current
                        ? ResqType.bodyStrong()
                        : ResqType.body(color: i < current ? Resq.inkSoft : Resq.inkFaint),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: Resq.space4),
        Text(
          footnote,
          textAlign: TextAlign.center,
          style: ResqType.caption(),
        ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeIn(duration: 1200.ms),
      ],
    );
  }
}
