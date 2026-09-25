import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../providers/ai_report_provider.dart';
import 'report_flow_chrome.dart';

/// Step 2: how do you want to say what happened.
///
/// Two choices, both enormous. Speaking is first because it is faster and
/// works for someone whose hands are occupied or who cannot type in Urdu.
class ReportMethodScreen extends ConsumerWidget {
  const ReportMethodScreen({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = ref.watch(aiReportProvider).selectedImages.firstOrNull;

    return ReportFlowScaffold(
      step: 2,
      title: 'Tell us what happened',
      subtitle: 'Speak or type — whichever is quicker right now. Both reach the '
          'hospital the same way.',
      onBack: () => context.pop(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (photo != null) _PhotoStrip(path: photo),
          const SizedBox(height: Resq.space4),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _MethodButton(
                    icon: Icons.mic_rounded,
                    label: 'Speak',
                    hint: 'Say it out loud in Urdu, Sindhi or English',
                    color: Resq.critical,
                    tint: Resq.criticalTint,
                    solidIcon: false,
                    waveform: true,
                    onTap: () => context.push(Routes.reportVoice, extra: caseId),
                  ),
                ),
                const SizedBox(height: Resq.space4),
                Expanded(
                  child: _MethodButton(
                    icon: Icons.keyboard_rounded,
                    label: 'Type',
                    hint: 'Write it in English, Urdu or Roman Urdu',
                    color: Resq.ready,
                    tint: Resq.readyTint,
                    solidIcon: true,
                    onTap: () => context.push(Routes.reportText, extra: caseId),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Resq.radiusControl),
          child: Image.file(File(path), width: 56, height: 56, fit: BoxFit.cover),
        ),
        const SizedBox(width: Resq.space3),
        Expanded(
          child: Text(
            'Photo attached — it goes with the report.',
            style: ResqType.caption(color: Resq.inkSoft),
          ),
        ),
      ],
    );
  }
}

/// A target you could hit without looking: full width, half the screen tall.
class _MethodButton extends StatelessWidget {
  const _MethodButton({
    required this.icon,
    required this.label,
    required this.hint,
    required this.color,
    required this.tint,
    required this.onTap,
    this.solidIcon = false,
    this.waveform = false,
  });

  final IconData icon;
  final String label;
  final String hint;
  final Color color;
  final Color tint;
  final VoidCallback onTap;

  /// White glyph on a filled disc, rather than a coloured glyph on a tinted one.
  final bool solidIcon;

  /// Bars either side of the microphone — the one thing on the screen that
  /// says "this listens" before a word of the label is read.
  final bool waveform;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tint,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // A soft swell in the bottom corner. It keeps a large flat card
              // from reading as an empty panel.
              Positioned(
                right: -56,
                bottom: -64,
                child: Container(
                  width: 210,
                  height: 190,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(110),
                  ),
                ),
              ),
              Positioned(
                right: -90,
                bottom: -40,
                child: Container(
                  width: 190,
                  height: 150,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(Resq.space5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (waveform) _Waveform(color: color, mirrored: false),
                        _IconDisc(icon: icon, color: color, solid: solidIcon),
                        if (waveform) _Waveform(color: color, mirrored: true),
                      ],
                    ),
                    const SizedBox(height: Resq.space3),
                    Text(
                      label,
                      // Darkened against its own tint. The green at full
                      // strength is only 2.8:1 on the mint, which is under the
                      // 3:1 large text needs — and the reference sets it in a
                      // deeper green for exactly that reason.
                      style: ResqType.display(
                        color: Color.lerp(color, const Color(0xFF1C1917), 0.28)!,
                      ).copyWith(fontSize: 30),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hint,
                      textAlign: TextAlign.center,
                      style: ResqType.body(color: Resq.inkSoft).copyWith(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The glyph, on a disc, inside a halo — so the eye lands there first.
class _IconDisc extends StatelessWidget {
  const _IconDisc({required this.icon, required this.color, required this.solid});

  final IconData icon;
  final Color color;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      height: 108,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      child: Container(
        width: 74,
        height: 74,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: solid ? color : color.withValues(alpha: 0.22),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 34, color: solid ? Colors.white : color),
      ),
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform({required this.color, required this.mirrored});

  final Color color;
  final bool mirrored;

  static const _heights = [14.0, 30.0, 20.0];

  @override
  Widget build(BuildContext context) {
    final bars = mirrored ? _heights.reversed.toList() : _heights;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Resq.space2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < bars.length; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            Container(
              width: 5,
              height: bars[i],
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(Resq.radiusPill),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
