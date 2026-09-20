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
                    onTap: () => context.push(Routes.reportVoice, extra: caseId),
                  ),
                ),
                const SizedBox(height: Resq.space4),
                Expanded(
                  child: _MethodButton(
                    icon: Icons.keyboard_rounded,
                    label: 'Type',
                    hint: 'Write it in English, Urdu or Roman Urdu',
                    color: Resq.info,
                    tint: Resq.infoTint,
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
  });

  final IconData icon;
  final String label;
  final String hint;
  final Color color;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tint,
      borderRadius: BorderRadius.circular(Resq.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Resq.radiusCard),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Resq.radiusCard),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          padding: const EdgeInsets.all(Resq.space5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 30, color: color),
              ),
              const SizedBox(height: Resq.space3),
              Text(label, style: ResqType.title(color: color)),
              const SizedBox(height: 4),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: ResqType.caption(color: Resq.inkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
