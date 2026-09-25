import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../data/models/recording_state_model.dart';
import '../../providers/ai_report_provider.dart';
import 'report_actions.dart';
import 'report_flow_chrome.dart';

/// Step 3, spoken. One microphone in the middle of the screen.
///
/// Speak in Urdu, Sindhi, English or a mix — the transcription handles all of
/// them, which is the point: the person at the scene should not have to
/// translate anything while they are describing an injury.
class ReportVoiceScreen extends ConsumerWidget {
  const ReportVoiceScreen({super.key, required this.caseId});

  final String caseId;

  String _clock(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiReportProvider);
    final notifier = ref.read(aiReportProvider.notifier);
    final recording = state.recordingStatus == RecordingStatus.recording;
    final recorded = state.recordingStatus == RecordingStatus.recorded;

    return ReportFlowScaffold(
      step: 3,
      title: 'Say what happened',
      subtitle: recording
          ? 'Listening. Describe what you can see — press again when you are done.'
          : 'Press the microphone and speak in any language.',
      onBack: () async {
        if (recording) await notifier.cancelRecording();
        if (context.mounted) context.pop();
      },
      bottomBar: recorded
          ? ReportActions(
              actions: [
                ReportAction(
                  icon: Icons.replay_rounded,
                  tooltip: 'Record again',
                  onPressed: notifier.cancelRecording,
                ),
                ReportAction(
                  icon: Icons.auto_awesome_rounded,
                  tooltip: 'Generate the report',
                  onPressed: () => context.push(Routes.reportGenerating, extra: caseId),
                  filled: true,
                ),
              ],
            )
          : null,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _MicButton(
            recording: recording,
            recorded: recorded,
            onTap: () => recording ? notifier.stopRecording() : notifier.startRecording(),
          ),
          const SizedBox(height: Resq.space6),
          Text(
            recording || recorded ? _clock(state.recordingDuration) : 'Tap to start',
            style: ResqType.display(color: recording ? Resq.critical : Resq.ink),
          ),
          const SizedBox(height: Resq.space2),
          Text(
            switch (state.recordingStatus) {
              RecordingStatus.recording => 'Recording — tap the microphone to stop',
              RecordingStatus.recorded => 'Recorded. Generate the report, or record again.',
              _ => 'Urdu, Sindhi, English, or all three in one sentence',
            },
            textAlign: TextAlign.center,
            style: ResqType.body(color: Resq.inkSoft),
          ),
          if (state.error != null) ...[
            const SizedBox(height: Resq.space4),
            Container(
              padding: const EdgeInsets.all(Resq.space3),
              decoration: BoxDecoration(
                color: Resq.criticalTint,
                borderRadius: BorderRadius.circular(Resq.radiusControl),
              ),
              child: Text(
                state.error!,
                textAlign: TextAlign.center,
                style: ResqType.caption(color: Resq.critical),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The microphone, and the only moving thing on the screen.
///
/// The rings are what tells someone it is actually listening — a static icon
/// leaves them wondering whether the press registered, and they start again.
class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.recording,
    required this.recorded,
    required this.onTap,
  });

  final bool recording;
  final bool recorded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = recorded ? Resq.ready : Resq.critical;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 240,
        height: 240,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (recording) ...[
              _Ring(color: color, size: 240, delayMs: 0),
              _Ring(color: color, size: 200, delayMs: 400),
            ],
            Container(
              width: 156,
              height: 156,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                recorded ? Icons.check_rounded : (recording ? Icons.stop_rounded : Icons.mic_rounded),
                size: 64,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.color, required this.size, required this.delayMs});

  final Color color;
  final double size;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.12),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .scale(
          delay: Duration(milliseconds: delayMs),
          duration: 1400.ms,
          begin: const Offset(0.75, 0.75),
          end: const Offset(1, 1),
          curve: Curves.easeOut,
        )
        .fadeOut(delay: Duration(milliseconds: delayMs), duration: 1400.ms);
  }
}
