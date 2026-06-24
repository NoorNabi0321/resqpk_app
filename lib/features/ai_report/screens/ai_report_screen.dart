import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../data/models/recording_state_model.dart';
import '../providers/ai_report_provider.dart';

const _languages = [
  ('auto', 'Auto'),
  ('en', 'EN'),
  ('ur', 'اردو'),
  ('sd', 'سنڌي'),
  ('roman_ur', 'Roman'),
];

const _processingMessages = [
  'Analyzing your input…',
  'Transcribing voice note…',
  'Processing with medical AI…',
  'Generating emergency report…',
  'Sending to hospital dashboard…',
];

class AIReportScreen extends ConsumerStatefulWidget {
  const AIReportScreen({super.key, required this.caseId});
  final String caseId;

  @override
  ConsumerState<AIReportScreen> createState() => _AIReportScreenState();
}

class _AIReportScreenState extends ConsumerState<AIReportScreen> {
  final Set<String> _activeMethods = {'voice'};
  final List<double> _bars = List.filled(20, 8);
  Timer? _waveTimer;
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;

  @override
  void dispose() {
    _waveTimer?.cancel();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  void _startWave() {
    _waveTimer?.cancel();
    final rnd = Random();
    _waveTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      setState(() {
        for (var i = 0; i < _bars.length; i++) {
          _bars[i] = 4 + rnd.nextDouble() * 28;
        }
      });
    });
  }

  void _stopWave() {
    _waveTimer?.cancel();
    _waveTimer = null;
  }

  void _startElapsed() {
    _elapsedSeconds = 0;
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsedSeconds++);
    });
  }

  void _stopElapsed() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiReportProvider);
    final notifier = ref.read(aiReportProvider.notifier);

    // Drive the recording waveform timer from status changes.
    ref.listen(aiReportProvider.select((s) => s.recordingStatus), (prev, next) {
      if (next == RecordingStatus.recording) {
        _startWave();
      } else {
        _stopWave();
      }
    });
    // Drive the processing elapsed timer.
    ref.listen(aiReportProvider.select((s) => s.isSubmitting), (prev, next) {
      if (next == true) {
        _startElapsed();
      } else {
        _stopElapsed();
      }
    });

    final showResult = state.report != null && state.report!.isComplete;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('AI Emergency Report'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: state.isSubmitting
            ? _buildProcessing()
            : showResult
                ? _buildResult(state, notifier)
                : _buildInput(state, notifier),
      ),
    );
  }

  // ---- PHASE 1: INPUT ------------------------------------------------------

  Widget _buildInput(AIReportState state, AIReportNotifier notifier) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.error != null) _errorCard(state, notifier),
                _methodSelector(),
                const SizedBox(height: 20),
                if (_activeMethods.contains('voice')) _voiceSection(state, notifier),
                if (_activeMethods.contains('text')) _textSection(state, notifier),
                if (_activeMethods.contains('photo')) _photoSection(state, notifier),
              ],
            ),
          ),
        ),
        _submitBar(state, notifier),
      ],
    );
  }

  Widget _methodSelector() {
    Widget pill(String key, IconData icon, String label) {
      final active = _activeMethods.contains(key);
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() {
            if (active) {
              _activeMethods.remove(key);
            } else {
              _activeMethods.add(key);
            }
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: active ? AppColors.infoBlue : AppColors.surfaceTwo,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Icon(icon, color: active ? Colors.white : AppColors.textSecondary, size: 22),
                const SizedBox(height: 4),
                Text(label,
                    style: AppTextStyles.caption.copyWith(
                        color: active ? Colors.white : AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        pill('voice', Icons.mic, 'Voice'),
        pill('text', Icons.edit_note, 'Text'),
        pill('photo', Icons.photo_camera, 'Photo'),
      ],
    );
  }

  Widget _voiceSection(AIReportState state, AIReportNotifier notifier) {
    final recording = state.recordingStatus == RecordingStatus.recording;
    final recorded = state.recordingStatus == RecordingStatus.recorded;

    return Column(
      children: [
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => recording ? notifier.stopRecording() : notifier.startRecording(),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: recording ? AppColors.sosRed : AppColors.surfaceTwo,
            ),
            child: Icon(
              recording ? Icons.stop : Icons.mic,
              color: recording ? Colors.white : AppColors.textSecondary,
              size: 34,
            ),
          ).animate(target: recording ? 1 : 0).scaleXY(end: 1.08, duration: 600.ms).then().scaleXY(end: 1 / 1.08, duration: 600.ms),
        ),
        const SizedBox(height: 12),
        if (recording) ...[
          _waveform(),
          const SizedBox(height: 8),
          Text('Recording… ${_fmt(state.recordingDuration)}',
              style: AppTextStyles.body.copyWith(color: AppColors.sosRed)),
        ] else if (recorded) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: AppColors.confirmedGreen, size: 18),
              const SizedBox(width: 6),
              Text('Voice note ready',
                  style: AppTextStyles.body.copyWith(color: AppColors.confirmedGreen)),
            ],
          ),
          TextButton(
            onPressed: () => notifier.startRecording(),
            child: const Text('Re-record'),
          ),
        ] else
          Text('Tap to start recording', style: AppTextStyles.caption),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          alignment: WrapAlignment.center,
          children: _languages.map((l) {
            final active = state.selectedLanguage == l.$1;
            return GestureDetector(
              onTap: () => notifier.setLanguage(l.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? AppColors.infoBlue : AppColors.surfaceTwo,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(l.$2,
                    style: AppTextStyles.caption.copyWith(
                        color: active ? Colors.white : AppColors.textSecondary)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _waveform() {
    return SizedBox(
      height: 36,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: _bars
            .map((h) => Container(
                  width: 4,
                  height: h,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: AppColors.sosRed,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _textSection(AIReportState state, AIReportNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TextFormField(
            initialValue: state.textInput,
            onChanged: notifier.setTextInput,
            maxLines: 5,
            style: AppTextStyles.body,
            decoration: InputDecoration(
              hintText: 'Describe the emergency… (Urdu, Sindhi, or English accepted)',
              hintStyle: AppTextStyles.caption,
              filled: true,
              fillColor: AppColors.surfaceTwo,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text('${state.textInput.length} characters', style: AppTextStyles.caption),
        ],
      ),
    );
  }

  Widget _photoSection(AIReportState state, AIReportNotifier notifier) {
    if (state.selectedImages.isEmpty) {
      return GestureDetector(
        onTap: notifier.pickImages,
        child: Container(
          height: 120,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.textSecondary, style: BorderStyle.solid),
            color: AppColors.surfaceOne,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_a_photo_outlined, color: AppColors.textSecondary, size: 28),
              const SizedBox(height: 8),
              Text('Tap to add injury photos', style: AppTextStyles.caption),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SizedBox(
        height: 88,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            ...state.selectedImages.asMap().entries.map((e) => Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      margin: const EdgeInsets.only(right: 8, top: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        image: DecorationImage(
                          image: FileImage(File(e.value)),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      top: 0,
                      child: GestureDetector(
                        onTap: () => notifier.removeImage(e.key),
                        child: const CircleAvatar(
                          radius: 11,
                          backgroundColor: Colors.black54,
                          child: Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                )),
            if (state.selectedImages.length < 4)
              GestureDetector(
                onTap: notifier.pickImages,
                child: Container(
                  width: 80,
                  height: 80,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: AppColors.surfaceTwo,
                  ),
                  child: const Icon(Icons.add, color: AppColors.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _submitBar(AIReportState state, AIReportNotifier notifier) {
    final enabled = state.hasAnyInput && !state.isSubmitting;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: enabled ? () => notifier.submitReport(widget.caseId) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.infoBlue,
            disabledBackgroundColor: AppColors.surfaceTwo,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          ),
          child: Text('Generate Report (10–15 sec)',
              style: AppTextStyles.buttonLabel.copyWith(color: Colors.white)),
        ),
      ),
    );
  }

  // ---- PHASE 2: PROCESSING -------------------------------------------------

  Widget _buildProcessing() {
    final msgIndex = (_elapsedSeconds ~/ 3) % _processingMessages.length;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              return Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                decoration: const BoxDecoration(color: AppColors.infoBlue, shape: BoxShape.circle),
              )
                  .animate(onPlay: (c) => c.repeat())
                  .fadeIn(duration: 400.ms, delay: (i * 200).ms)
                  .then()
                  .fadeOut(duration: 400.ms, delay: 400.ms);
            }),
          ),
          const SizedBox(height: 24),
          Text(_processingMessages[msgIndex],
                  key: ValueKey(msgIndex), style: AppTextStyles.subtitle)
              .animate(key: ValueKey(msgIndex))
              .fadeIn(duration: 400.ms),
          const SizedBox(height: 8),
          Text('Processing: ${_elapsedSeconds}s', style: AppTextStyles.caption),
          const SizedBox(height: 16),
          Text('Report will appear here when ready', style: AppTextStyles.caption),
        ],
      ),
    );
  }

  // ---- PHASE 3: RESULT -----------------------------------------------------

  Widget _buildResult(AIReportState state, AIReportNotifier notifier) {
    final r = state.report!;
    var delay = 0;
    Widget staggered(Widget child) {
      delay += 80;
      return child.animate().fadeIn(duration: 350.ms, delay: delay.ms).slideY(begin: 0.1);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: r.urgencyColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border(left: BorderSide(color: r.urgencyColor, width: 4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: r.urgencyColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(r.urgencyLabel,
                      style: AppTextStyles.caption.copyWith(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 10),
                Text(r.emergencyType ?? 'Emergency', style: AppTextStyles.title),
                if (r.generationTimeMs != null)
                  Text('Generated in ${(r.generationTimeMs! / 1000).toStringAsFixed(1)} seconds',
                      style: AppTextStyles.caption),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.15),
          const SizedBox(height: 12),

          staggered(_card(
            icon: Icons.remove_red_eye_outlined,
            title: 'Consciousness',
            child: Text(r.consciousnessState ?? 'Unknown', style: AppTextStyles.body),
          )),
          if (r.keyObservations.isNotEmpty)
            staggered(_card(
              icon: Icons.visibility_outlined,
              title: 'Key Observations',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: r.keyObservations
                    .map((o) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('•  ', style: TextStyle(color: AppColors.textSecondary)),
                              Expanded(child: Text(o, style: AppTextStyles.body)),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            )),
          if (r.firstAidSuggestion != null)
            staggered(Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.confirmedGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: const Border(
                    left: BorderSide(color: AppColors.confirmedGreen, width: 4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.healing, color: AppColors.confirmedGreen, size: 18),
                    const SizedBox(width: 6),
                    Text('First Aid',
                        style: AppTextStyles.body.copyWith(
                            color: AppColors.confirmedGreen, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 6),
                  Text(r.firstAidSuggestion!, style: AppTextStyles.body),
                ],
              ),
            )),
          if (r.hospitalPreparation != null)
            staggered(_card(
              icon: Icons.local_hospital_outlined,
              title: 'Hospital Preparation',
              child: Text(r.hospitalPreparation!, style: AppTextStyles.body),
            )),
          if (r.transcribedText != null && r.transcribedText!.isNotEmpty)
            staggered(_card(
              icon: Icons.record_voice_over_outlined,
              title: 'What AI heard',
              trailing: r.detectedLanguage != null
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceTwo,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(r.detectedLanguage!.toUpperCase(),
                          style: AppTextStyles.caption),
                    )
                  : null,
              child: Text(r.transcribedText!, style: AppTextStyles.body),
            )),
          if (r.possibleConditions.isNotEmpty)
            staggered(_card(
              icon: Icons.science_outlined,
              title: 'Possible Conditions',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...r.possibleConditions.map((c) => Text('• $c', style: AppTextStyles.body)),
                  const SizedBox(height: 6),
                  Text('For hospital reference only — not a diagnosis',
                      style: AppTextStyles.caption.copyWith(fontStyle: FontStyle.italic)),
                ],
              ),
            )),

          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.confirmedGreen, size: 18),
              const SizedBox(width: 6),
              Text('Report sent to hospital',
                  style: AppTextStyles.body.copyWith(color: AppColors.confirmedGreen)),
            ],
          ).animate().fadeIn(delay: 400.ms),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => context.pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.infoBlue,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
            ),
            child: Text('Back to Tracking',
                style: AppTextStyles.buttonLabel.copyWith(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => _showShareDialog(r),
            child: const Text('Download Report'),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceOne,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.textSecondary, size: 18),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(title,
                      style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold))),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  void _showShareDialog(report) {
    final text = [
      'ResQPK Emergency Report',
      'Urgency: ${report.urgencyLabel}',
      'Type: ${report.emergencyType ?? '-'}',
      'Consciousness: ${report.consciousnessState ?? '-'}',
      if (report.keyObservations.isNotEmpty)
        'Observations: ${report.keyObservations.join(', ')}',
      if (report.firstAidSuggestion != null) 'First Aid: ${report.firstAidSuggestion}',
    ].join('\n');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceOne,
        title: Text('Report Summary', style: AppTextStyles.subtitle),
        content: SingleChildScrollView(child: Text(text, style: AppTextStyles.body)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  // ---- Error ---------------------------------------------------------------

  Widget _errorCard(AIReportState state, AIReportNotifier notifier) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.sosRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: const Border(left: BorderSide(color: AppColors.sosRed, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Report generation failed',
              style: AppTextStyles.body.copyWith(color: AppColors.sosRed)),
          const SizedBox(height: 4),
          Text(state.error ?? '', style: AppTextStyles.caption),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: () => notifier.submitReport(widget.caseId),
                child: const Text('Try Again'),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _activeMethods.add('text'));
                  notifier.clearError();
                },
                child: const Text('Enter Manually'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
