import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../providers/ai_report_provider.dart';
import 'report_actions.dart';
import 'report_flow_chrome.dart';

/// The wait.
///
/// Transcription, analysis and the PDF take a few seconds each, and a bare
/// spinner for that long reads as a hang. So the screen names the stage it is
/// on. The stages are honest about what the server does, even though it does
/// not report progress: they advance on time, and the bar never fills until
/// the answer actually arrives.
class ReportGeneratingScreen extends ConsumerStatefulWidget {
  const ReportGeneratingScreen({super.key, required this.caseId});

  final String caseId;

  @override
  ConsumerState<ReportGeneratingScreen> createState() => _ReportGeneratingScreenState();
}

class _ReportGeneratingScreenState extends ConsumerState<ReportGeneratingScreen> {
  static const _stages = [
    (icon: Icons.upload_rounded, label: 'Sending what you gave us'),
    (icon: Icons.graphic_eq_rounded, label: 'Listening and reading'),
    (icon: Icons.psychology_rounded, label: 'Working out what the hospital needs'),
    (icon: Icons.picture_as_pdf_rounded, label: 'Writing the report'),
  ];

  int _stage = 0;
  Timer? _ticker;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Submit once, on the way in. Riverpod keeps the notifier alive, so the
    // upload survives this screen being rebuilt.
    Future.microtask(() => ref.read(aiReportProvider.notifier).submitReport(widget.caseId));

    _ticker = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      if (!mounted) return;
      setState(() => _stage = (_stage + 1).clamp(0, _stages.length - 1));
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiReportProvider);

    // Done — or failed. Either way, stop pretending to work.
    ref.listen(aiReportProvider, (_, next) {
      if (_navigated || !mounted) return;
      if (next.report?.isComplete == true) {
        _navigated = true;
        context.pushReplacement(Routes.reportResult, extra: widget.caseId);
      }
    });

    final failed = state.error != null && !state.isSubmitting;

    return ReportFlowScaffold(
      step: 0,
      title: failed ? 'That did not work' : 'Building the report',
      onBack: failed ? () => context.pop() : null,
      bottomBar: failed
          ? ReportActions(
              actions: [
                ReportAction(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back to tracking',
                  onPressed: () => context.go(Routes.tracking),
                ),
                ReportAction(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Try again',
                  onPressed: () =>
                      ref.read(aiReportProvider.notifier).submitReport(widget.caseId),
                  filled: true,
                ),
              ],
            )
          : null,
      body: failed ? _Failure(message: state.error!) : _Working(stage: _stage, stages: _stages),
    );
  }
}

class _Working extends StatelessWidget {
  const _Working({required this.stage, required this.stages});

  final int stage;
  final List<({IconData icon, String label})> stages;

  @override
  Widget build(BuildContext context) {
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
                      stages[stage].icon,
                      key: ValueKey(stage),
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
                  i < stage
                      ? Icons.check_circle_rounded
                      : (i == stage ? Icons.adjust_rounded : Icons.circle_outlined),
                  size: 18,
                  color: i <= stage ? Resq.ready : Resq.inkFaint,
                ),
                const SizedBox(width: Resq.space3),
                Expanded(
                  child: Text(
                    stages[i].label,
                    style: i == stage
                        ? ResqType.bodyStrong()
                        : ResqType.body(color: i < stage ? Resq.inkSoft : Resq.inkFaint),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: Resq.space4),
        Text(
          'This usually takes about ten seconds.',
          textAlign: TextAlign.center,
          style: ResqType.caption(),
        ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeIn(duration: 1200.ms),
      ],
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(color: Resq.criticalTint, shape: BoxShape.circle),
            child: const Icon(Icons.error_outline_rounded, size: 52, color: Resq.critical),
          ),
          const SizedBox(height: Resq.space5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: ResqType.body(color: Resq.inkSoft),
          ),
          const SizedBox(height: Resq.space3),
          Text(
            'Nothing you recorded is lost — the ambulance is still coming either way.',
            textAlign: TextAlign.center,
            style: ResqType.caption(),
          ),
        ],
      ),
    );
  }
}
