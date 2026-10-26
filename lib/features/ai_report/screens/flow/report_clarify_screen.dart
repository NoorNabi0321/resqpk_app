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
/// Nothing has reached the hospital yet, and that is deliberate: a report
/// written from the description alone fills its gaps with inference, and a PDF
/// is read as a clinical record whether or not it carries a caveat.
///
/// The screen is one question and its answers, and nothing else. It used to
/// carry three lines explaining the design above the question, which is text
/// nobody standing over a casualty is going to read and which pushed the first
/// answer towards the middle of the screen. What is actually needed is the
/// question, the things you can tap, and a way out.
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
  /// Not an abandonment path — it is the designed escape, and the thing that
  /// bounds the delay asking first imposes. Answers already given still count.
  Future<void> _skip() async {
    final ok = await ref.read(aiReportProvider.notifier).skipClarifications(widget.caseId);
    if (!mounted) return;
    // Closed under us, or sent: either way the report exists.
    if (ok || ref.read(aiReportProvider).clarificationClosed) {
      _toResult();
      return;
    }
    _complain('The report could not be sent. Try again.');
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

    // The sequence closed while this screen was open — the deadline passed, or
    // a tap landed first. The report exists, so show it instead of telling
    // someone their answer was refused.
    if (ref.read(aiReportProvider).clarificationClosed) {
      _toResult();
      return;
    }

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
    final urdu = _urdu(question);
    final options = question.displayOptions();

    return BackTo(
      // Back means "stop asking and send it", not back through the flow that
      // made the recording. There is no report to go back to yet.
      onBack: _skip,
      child: Scaffold(
        backgroundColor: Resq.canvas,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                index: _index,
                total: _questions.length,
                onBack: busy ? null : _skip,
              ),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    Resq.space5,
                    Resq.space4,
                    Resq.space5,
                    Resq.space4,
                  ),
                  children: [
                    Directionality(
                      textDirection: urdu ? TextDirection.rtl : TextDirection.ltr,
                      child: Text(
                        question.displayQuestion(),
                        style: urdu
                            ? ResqType.nastaliq(size: 27)
                            : ResqType.display(color: Resq.ink)
                                .copyWith(fontSize: 29, height: 1.2, letterSpacing: -0.4),
                      ),
                    )
                        .animate(key: ValueKey('q${question.id}'))
                        .fadeIn(duration: 260.ms)
                        .slideY(begin: 0.12, end: 0, curve: Curves.easeOutCubic),
                    const SizedBox(height: Resq.space6),
                    for (var i = 0; i < options.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Resq.space3),
                        child: _OptionCard(
                          label: options[i],
                          position: i,
                          urdu: urdu,
                          busy: busy && _pending == question.answerFor(i),
                          enabled: !busy,
                          onTap: () => _answer(question, question.answerFor(i)),
                        )
                            .animate(key: ValueKey('q${question.id}o$i'))
                            .fadeIn(delay: (70 * i + 110).ms, duration: 240.ms)
                            .slideY(begin: 0.16, end: 0, curve: Curves.easeOutCubic),
                      ),
                  ],
                ),
              ),
              _SkipBar(onSkip: busy ? null : _skip),
            ],
          ),
        ),
      ),
    );
  }
}

/// Back, and how far through you are. No title: the question below is the
/// title, and a heading above it would only compete with it.
class _Header extends StatelessWidget {
  const _Header({required this.index, required this.total, required this.onBack});

  final int index;
  final int total;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Resq.space2, Resq.space2, Resq.space5, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, color: Resq.ink),
            constraints: const BoxConstraints(
              minWidth: Resq.tapTarget,
              minHeight: Resq.tapTarget,
            ),
          ),
          const Spacer(),
          // Dots rather than a bar. Two or three questions is a short enough
          // sequence to count at a glance, and a bar that moves in halves reads
          // as a download rather than as progress through a conversation.
          for (var i = 0; i < total; i++)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                width: i == index ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i <= index ? Resq.critical : Resq.border,
                  borderRadius: BorderRadius.circular(Resq.radiusPill),
                ),
              ),
            ),
          const SizedBox(width: Resq.space3),
          Text(
            '${index + 1}/$total',
            style: ResqType.caption(color: Resq.inkMuted),
          ),
        ],
      ),
    );
  }
}

/// One answer. Full width, tall, and the only thing to do on its row — one tap
/// from someone who may be holding the phone in the hand they are not using to
/// keep a casualty still.
class _OptionCard extends StatefulWidget {
  const _OptionCard({
    required this.label,
    required this.position,
    required this.urdu,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final int position;
  final bool urdu;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<_OptionCard> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.busy;
    final dim = !widget.enabled && !widget.busy;

    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: widget.enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: widget.enabled ? () => setState(() => _down = false) : null,
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedScale(
        // Presses back under the thumb. On a screen where every control looks
        // the same, the feel of the press is what confirms the tap landed.
        scale: _down ? 0.975 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 78),
          padding: const EdgeInsets.symmetric(
            horizontal: Resq.space4,
            vertical: Resq.space4,
          ),
          decoration: BoxDecoration(
            color: active ? Resq.criticalTint : Resq.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? Resq.critical : Resq.border,
              width: active ? 2 : 1.4,
            ),
            boxShadow: _down || dim
                ? null
                : [
                    BoxShadow(
                      color: Resq.ink.withValues(alpha: 0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            textDirection: widget.urdu ? TextDirection.rtl : TextDirection.ltr,
            children: [
              _Badge(position: widget.position, active: active, dim: dim),
              const SizedBox(width: Resq.space4),
              Expanded(
                child: Text(
                  widget.label,
                  textAlign: widget.urdu ? TextAlign.right : TextAlign.left,
                  style: widget.urdu
                      ? ResqType.nastaliq(size: 19, color: dim ? Resq.inkFaint : Resq.ink)
                      : ResqType.bodyStrong(color: dim ? Resq.inkFaint : Resq.ink)
                          .copyWith(fontSize: 18, height: 1.3),
                ),
              ),
              const SizedBox(width: Resq.space2),
              SizedBox(
                width: 22,
                height: 22,
                child: active
                    ? const CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Resq.critical,
                      )
                    : Icon(
                        widget.urdu
                            ? Icons.chevron_left_rounded
                            : Icons.chevron_right_rounded,
                        color: dim ? Resq.surfaceAlt : Resq.inkFaint,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A, B, C down the left. Gives the eye somewhere to land and makes the options
/// countable without reading them.
class _Badge extends StatelessWidget {
  const _Badge({required this.position, required this.active, required this.dim});

  final int position;
  final bool active;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? Resq.critical : Resq.surfaceAlt,
        shape: BoxShape.circle,
      ),
      child: Text(
        String.fromCharCode(65 + position),
        style: ResqType.bodyStrong(
          color: active ? Colors.white : (dim ? Resq.inkFaint : Resq.inkSoft),
        ).copyWith(fontSize: 15),
      ),
    );
  }
}

/// The way out, on every question.
///
/// Visible and plainly worded rather than greyed into a corner: it is what
/// bounds the delay that asking before sending imposes, and someone who cannot
/// answer — because they are doing compressions, because they genuinely do not
/// know — needs it to be the easiest thing on the screen to find.
class _SkipBar extends StatelessWidget {
  const _SkipBar({required this.onSkip});

  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Resq.space5, 0, Resq.space5, Resq.space4),
      child: TextButton(
        onPressed: onSkip,
        style: TextButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Resq.radiusControl),
          ),
        ),
        child: Text(
          'Skip and send the report',
          style: ResqType.button(color: Resq.inkSoft),
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
