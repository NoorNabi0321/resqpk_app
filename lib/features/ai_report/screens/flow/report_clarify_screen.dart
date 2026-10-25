import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/back_guard.dart';
import '../../data/models/clarification_model.dart';
import '../../providers/ai_report_provider.dart';
import 'report_flow_chrome.dart';
import 'report_progress.dart';

/// The questions, asked before the report is written.
///
/// Nothing has reached the hospital yet, and that is deliberate. A report
/// written from the description alone fills its gaps with inference, and a PDF
/// is read as a clinical record whether or not it carries a caveat — so the
/// questions come first and the record is written once, from the answers.
///
/// The cost of that choice is the seconds spent here, which is why Skip is a
/// plain visible button on every question rather than a greyed-out
/// afterthought: one tap and the hospital has its report. Leaving by any route
/// is a legitimate ending, and the server closes the sequence by itself if the
/// phone never comes back.
class ReportClarifyScreen extends ConsumerStatefulWidget {
  const ReportClarifyScreen({super.key, required this.caseId});

  final String caseId;

  @override
  ConsumerState<ReportClarifyScreen> createState() => _ReportClarifyScreenState();
}

class _ReportClarifyScreenState extends ConsumerState<ReportClarifyScreen> {
  static const List<ReportStage> _writingStages = [
    (icon: Icons.psychology_rounded, label: 'Writing the report from your answers'),
    (icon: Icons.picture_as_pdf_rounded, label: 'Preparing the document'),
    (icon: Icons.local_hospital_rounded, label: 'Sending it to the hospital'),
  ];

  /// The questions this screen started with, captured once. Held as an index
  /// into a fixed list rather than always showing the first unanswered
  /// question, so a failed answer does not look like progress.
  late List<ClarificationModel> _questions;
  int _index = 0;
  String? _pending;
  bool _resuming = false;

  @override
  void initState() {
    super.initState();
    _questions = ref.read(aiReportProvider).openClarifications;
    if (_questions.isEmpty) Future.microtask(_recover);
  }

  /// Reached this screen with no questions in memory — the app was killed part
  /// way through, or someone came back from tracking. Ask the server what is
  /// still open.
  Future<void> _recover() async {
    setState(() => _resuming = true);
    final resumed =
        await ref.read(aiReportProvider.notifier).resumeClarification(widget.caseId);
    if (!mounted) return;
    if (!resumed) {
      // Nothing outstanding: either the record is written or the sequence timed
      // out and the server wrote it without us.
      _toResult();
      return;
    }
    setState(() {
      _questions = ref.read(aiReportProvider).openClarifications;
      _index = 0;
      _resuming = false;
    });
  }

  void _toResult() {
    if (!mounted) return;
    context.pushReplacement(Routes.reportResult, extra: widget.caseId);
  }

  /// Skip: close the sequence and have the report written now.
  ///
  /// Not an abandonment path — it is the designed escape, and the one that
  /// keeps the blocking sequence honest. Answers already given still count.
  Future<void> _skip() async {
    final ok = await ref.read(aiReportProvider.notifier).skipClarifications(widget.caseId);
    if (!mounted) return;
    if (!ok) {
      _complain('The report could not be sent. Try again.');
      return;
    }
    _toResult();
  }

  Future<void> _answer(ClarificationModel question, String option) async {
    setState(() => _pending = option);
    final ok = await ref.read(aiReportProvider.notifier).answerClarification(
          widget.caseId,
          questionId: question.id,
          answer: option,
        );
    if (!mounted) return;
    setState(() => _pending = null);

    if (!ok) {
      _complain('That answer did not get through. Nothing is lost — try again.');
      return;
    }

    // The last answer writes the record, so the notifier now holds the report.
    if (ref.read(aiReportProvider).report != null) {
      _toResult();
      return;
    }

    if (_index + 1 >= _questions.length) {
      // Answered everything this screen knew about but the server still has
      // something open — ask it what.
      await _recover();
      return;
    }
    setState(() => _index += 1);
  }

  /// Urdu script needs a different face and direction. Detected from the text
  /// rather than from the stored language code, because the code says what was
  /// asked for and this has to match what actually came back.
  bool _urdu(ClarificationModel q) =>
      RegExp(r'[؀-ۿ]').hasMatch(q.displayQuestion());

  void _complain(String fallback) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ref.read(aiReportProvider).error ?? fallback)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiReportProvider);

    // The record is being written: the one wait in this flow the hospital is
    // actually at the end of.
    if (state.isFinalising) {
      return const _Writing(stages: _writingStages);
    }

    if (_resuming || _questions.isEmpty) {
      return const ReportFlowScaffold(
        step: 0,
        title: 'One moment',
        body: Center(child: CircularProgressIndicator(color: Resq.brandInk)),
      );
    }

    final question = _questions[_index];
    final busy = state.isAnswering;

    return BackTo(
      // Back means "stop asking and send it", not back through the flow that
      // made the recording. There is no report to go back to yet.
      onBack: _skip,
      child: ReportFlowScaffold(
        step: _index + 1,
        totalSteps: _questions.length,
        title: 'Before we send it',
        subtitle: 'The hospital has not been sent anything yet. These answers go '
            'into the report — you can send it without them at any time.',
        onBack: _skip,
        bottomBar: TextButton(
          onPressed: busy ? null : _skip,
          child: Text(
            _index == 0 ? 'Skip and send the report now' : 'That is all I know — send it',
            style: ResqType.button(color: Resq.brandInk),
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Shown in the language they gave the description in. Urdu needs
            // its own face and right-to-left, or it renders as a wall of
            // mis-shaped glyphs — the same reason the typed screen switches.
            Directionality(
              textDirection: _urdu(question) ? TextDirection.rtl : TextDirection.ltr,
              child: Text(
                question.displayQuestion(),
                style: _urdu(question)
                    ? ResqType.nastaliq(size: 25)
                    : ResqType.display(color: Resq.ink)
                        .copyWith(fontSize: 26, height: 1.25),
              ),
            ).animate(key: ValueKey('q${question.id}')).fadeIn(duration: 220.ms),
            const SizedBox(height: Resq.space5),
            Expanded(
              child: ListView.separated(
                itemCount: question.options.length,
                separatorBuilder: (_, __) => const SizedBox(height: Resq.space3),
                itemBuilder: (_, i) {
                  // Read in their language, recorded in English. The tap is
                  // resolved by position, so the two never have to be matched.
                  final shown = question.displayOptions()[i];
                  final recorded = question.answerFor(i);
                  return _OptionButton(
                    label: shown,
                    urdu: _urdu(question),
                    busy: busy && _pending == recorded,
                    enabled: !busy,
                    onTap: () => _answer(question, recorded),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The second wait. No back button: the record is being written and sent, and
/// there is nothing useful to go back to mid-write.
class _Writing extends StatefulWidget {
  const _Writing({required this.stages});

  final List<ReportStage> stages;

  @override
  State<_Writing> createState() => _WritingState();
}

class _WritingState extends State<_Writing> {
  int _stage = 0;

  @override
  void initState() {
    super.initState();
    _advance();
  }

  Future<void> _advance() async {
    // Walks forward on time, because the server reports no progress. Stops on
    // the last stage rather than looping, so it never claims to be finished.
    while (mounted && _stage < widget.stages.length - 1) {
      await Future<void>.delayed(const Duration(milliseconds: 2600));
      if (!mounted) return;
      setState(() => _stage += 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Back is blocked outright here, not redirected. The record is being
    // written and sent on the strength of answers already given; walking out
    // mid-write would land on the recording screens with no way to tell
    // whether the hospital got anything. It resolves either way in seconds.
    return PopScope(
      canPop: false,
      child: ReportFlowScaffold(
        step: 0,
        title: 'Sending your report',
        body: ReportProgress(
          stage: _stage,
          stages: widget.stages,
          footnote: 'The hospital will have this before the ambulance arrives.',
        ),
      ),
    );
  }
}

/// Full width, tall, and the only thing to do on the row. One tap from someone
/// who may be holding the phone in the hand they are not using to keep a
/// casualty still.
class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.label,
    required this.busy,
    required this.enabled,
    required this.onTap,
    this.urdu = false,
  });

  final String label;
  final bool busy;
  final bool enabled;
  final bool urdu;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Resq.surface,
      borderRadius: BorderRadius.circular(Resq.radiusCard),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(Resq.radiusCard),
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.symmetric(
            horizontal: Resq.space4,
            vertical: Resq.space3,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Resq.radiusCard),
            border: Border.all(color: busy ? Resq.brandInk : Resq.border),
          ),
          child: Row(
            textDirection: urdu ? TextDirection.rtl : TextDirection.ltr,
            children: [
              Expanded(
                child: Text(
                  label,
                  textAlign: urdu ? TextAlign.right : TextAlign.left,
                  style: urdu
                      ? ResqType.nastaliq(
                          size: 18,
                          color: enabled || busy ? Resq.ink : Resq.inkFaint,
                        )
                      : ResqType.bodyStrong(
                          color: enabled || busy ? Resq.ink : Resq.inkFaint,
                        ).copyWith(fontSize: 17),
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Resq.brandInk),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: enabled ? Resq.inkFaint : Resq.surfaceAlt,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
