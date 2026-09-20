import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/offline_banner.dart';

/// Page chrome for the report flow: step counter, title, one job per screen.
///
/// The old report screen asked for a photo, a recording, typed notes and a
/// language all at once, with a submit button under the lot. Split into steps,
/// each screen can be understood without reading it — which is the only way
/// anything gets used while an ambulance is on its way.
class ReportFlowScaffold extends StatelessWidget {
  const ReportFlowScaffold({
    super.key,
    required this.step,
    required this.title,
    required this.body,
    this.subtitle,
    this.bottomBar,
    this.onBack,
    this.totalSteps = 3,
  });

  /// 1-based; 0 hides the counter (used by the generating and result screens,
  /// where there is nothing left to do).
  final int step;
  final int totalSteps;
  final String title;
  final String? subtitle;
  final Widget body;
  final Widget? bottomBar;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Resq.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const OfflineBanner(
              message: 'No internet. The report will not send until you are back online.',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Resq.space2,
                Resq.space2,
                Resq.space4,
                Resq.space2,
              ),
              child: Row(
                children: [
                  if (onBack != null)
                    IconButton(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back_rounded, color: Resq.ink),
                      constraints: const BoxConstraints(
                        minWidth: Resq.tapTarget,
                        minHeight: Resq.tapTarget,
                      ),
                    )
                  else
                    const SizedBox(width: Resq.space3),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ResqType.title(),
                    ),
                  ),
                  if (step > 0)
                    Text('Step $step of $totalSteps', style: ResqType.caption()),
                ],
              ),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Resq.space5,
                  0,
                  Resq.space5,
                  Resq.space3,
                ),
                child: Text(subtitle!, style: ResqType.body(color: Resq.inkSoft)),
              ),
            if (step > 0) _StepBar(step: step, total: totalSteps),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Resq.space4,
                  Resq.space3,
                  Resq.space4,
                  Resq.space3,
                ),
                child: body,
              ),
            ),
            if (bottomBar != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Resq.space4,
                  0,
                  Resq.space4,
                  Resq.space4,
                ),
                child: bottomBar!,
              ),
          ],
        ),
      ),
    );
  }
}

class _StepBar extends StatelessWidget {
  const _StepBar({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Resq.space4),
      child: Row(
        children: [
          for (var i = 1; i <= total; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 4,
                decoration: BoxDecoration(
                  color: i <= step ? Resq.brandInk : Resq.border,
                  borderRadius: BorderRadius.circular(Resq.radiusPill),
                ),
              ),
            ),
            if (i < total) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}
