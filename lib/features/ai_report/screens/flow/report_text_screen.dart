import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../providers/ai_report_provider.dart';
import 'report_flow_chrome.dart';

/// Step 3, typed. English, Urdu or Roman Urdu — all three reach the same
/// model, and the language only tells it what to expect.
class ReportTextScreen extends ConsumerStatefulWidget {
  const ReportTextScreen({super.key, required this.caseId});

  final String caseId;

  @override
  ConsumerState<ReportTextScreen> createState() => _ReportTextScreenState();
}

class _ReportTextScreenState extends ConsumerState<ReportTextScreen> {
  late final TextEditingController _controller;

  static const _languages = [
    (key: 'en', label: 'English', sample: 'He fell from a ladder and cannot move his leg.'),
    (key: 'ur', label: 'اردو', sample: 'وہ سیڑھی سے گر گیا ہے اور ٹانگ ہلا نہیں سکتا۔'),
    (key: 'roman_ur', label: 'Roman Urdu', sample: 'Wo seerhi se gir gaya hai, taang nahi hila raha.'),
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(aiReportProvider).textInput);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _generate() {
    ref.read(aiReportProvider.notifier).setTextInput(_controller.text.trim());
    context.push(Routes.reportGenerating, extra: widget.caseId);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiReportProvider);
    // 'auto' is the default and means nothing was picked yet; the typed screen
    // always names a language, so the model is not left guessing script.
    final language = state.selectedLanguage == 'auto' ? 'en' : state.selectedLanguage;
    final urdu = language == 'ur';
    final sample = _languages.firstWhere((l) => l.key == language).sample;

    return ReportFlowScaffold(
      step: 3,
      title: 'What happened?',
      subtitle: 'Anything you can see: what happened, what hurts, whether they '
          'are awake, any medicine they take.',
      onBack: () => context.pop(),
      bottomBar: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _controller,
        builder: (_, value, __) => ElevatedButton(
          onPressed: value.text.trim().isEmpty ? null : _generate,
          style: ElevatedButton.styleFrom(
            backgroundColor: Resq.critical,
            disabledBackgroundColor: Resq.surfaceAlt,
            elevation: 0,
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Resq.radiusControl),
            ),
          ),
          child: Text(
            'Generate report',
            style: ResqType.button(
              color: value.text.trim().isEmpty ? Resq.inkFaint : Colors.white,
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final l in _languages)
                  Padding(
                    padding: const EdgeInsets.only(right: Resq.space2),
                    child: _LanguageChip(
                      label: l.label,
                      active: l.key == language,
                      onTap: () => ref.read(aiReportProvider.notifier).setLanguage(l.key),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Resq.space4),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Resq.surface,
                borderRadius: BorderRadius.circular(Resq.radiusCard),
                border: Border.all(color: Resq.border),
              ),
              padding: const EdgeInsets.all(Resq.space4),
              child: Directionality(
                textDirection: urdu ? TextDirection.rtl : TextDirection.ltr,
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  keyboardType: TextInputType.multiline,
                  cursorColor: Resq.brandInk,
                  style: urdu
                      ? ResqType.nastaliq(size: 17)
                      : ResqType.body().copyWith(fontSize: 17, height: 1.5),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: sample,
                    hintStyle: urdu
                        ? ResqType.nastaliq(size: 16, color: Resq.inkFaint)
                        : ResqType.body(color: Resq.inkFaint),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: Resq.space4),
        decoration: BoxDecoration(
          color: active ? Resq.brandInk : Resq.surface,
          borderRadius: BorderRadius.circular(Resq.radiusPill),
          border: Border.all(color: active ? Resq.brandInk : Resq.border),
        ),
        child: Text(
          label,
          style: ResqType.caption(color: active ? Colors.white : Resq.inkSoft),
        ),
      ),
    );
  }
}
