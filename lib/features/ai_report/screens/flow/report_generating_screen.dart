import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../providers/ai_report_provider.dart';
import 'report_actions.dart';
import 'report_flow_chrome.dart';
import 'report_progress.dart';

/// The first wait: working out what still needs asking.
///
/// This screen does not produce a report. It sends the recording, the photo and
/// the text, and the server comes back with the two to four questions it needs
/// answered before it will write a clinical record. Nothing has reached the
/// hospital when this finishes, and the screen says so — someone standing over
/// a casualty is owed the truth about whether help has been told anything yet.
class ReportGeneratingScreen extends ConsumerStatefulWidget {
  const ReportGeneratingScreen({super.key, required this.caseId});

  final String caseId;

  @override
  ConsumerState<ReportGeneratingScreen> createState() => _ReportGeneratingScreenState();
}

class _ReportGeneratingScreenState extends ConsumerState<ReportGeneratingScreen> {
  static const List<ReportStage> _stages = [
    (icon: Icons.upload_rounded, label: 'Sending what you gave us'),
    (icon: Icons.graphic_eq_rounded, label: 'Listening and reading'),
    (icon: Icons.psychology_rounded, label: 'Working out what is missing'),
  ];

  int _stage = 0;
  Timer? _ticker;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Submit once, on the way in. Riverpod keeps the notifier alive, so the
    // upload survives this screen being rebuilt.
    Future.microtask(_start);

    _ticker = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      if (!mounted) return;
      setState(() => _stage = (_stage + 1).clamp(0, _stages.length - 1));
    });
  }

  Future<void> _start() async {
    final hasQuestions = await ref.read(aiReportProvider.notifier).submitReport(widget.caseId);
    if (!mounted || _navigated) return;
    if (ref.read(aiReportProvider).error != null) return; // the failure UI below

    _navigated = true;
    // Questions first. Only when there were none worth asking does the record
    // get written straight away, and then the document is already waiting.
    context.pushReplacement(
      hasQuestions ? Routes.reportClarify : Routes.reportResult,
      extra: widget.caseId,
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiReportProvider);
    final failed = state.error != null && !state.isSubmitting;

    return ReportFlowScaffold(
      step: 0,
      title: failed ? 'That did not work' : 'Reading what you told us',
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
                  onPressed: _start,
                  filled: true,
                ),
              ],
            )
          : null,
      body: failed
          ? _Failure(message: state.error!)
          : ReportProgress(
              stage: _stage,
              stages: _stages,
              footnote: 'A few quick questions next, then the hospital gets the report.',
            ),
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
