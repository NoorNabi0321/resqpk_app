import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/step_slider.dart';
import '../data/models/first_aid_guide_model.dart';
import '../providers/first_aid_provider.dart';

/// One guide, one step at a time.
///
/// A takeover, not a tab: the tab bar is gone while you are following steps,
/// because nothing on it is what you should be doing next. Back returns to the
/// library with the tabs where they were.
class GuideDetailScreen extends ConsumerStatefulWidget {
  const GuideDetailScreen({super.key, required this.guide});

  final FirstAidGuideModel guide;

  @override
  ConsumerState<GuideDetailScreen> createState() => _GuideDetailScreenState();
}

class _GuideDetailScreenState extends ConsumerState<GuideDetailScreen> {
  @override
  void initState() {
    super.initState();
    _incrementGuidesRead();
  }

  Future<void> _incrementGuidesRead() async {
    final box =
        Hive.isBoxOpen('app_stats') ? Hive.box('app_stats') : await Hive.openBox('app_stats');
    await box.put('guides_read', ((box.get('guides_read') as int?) ?? 0) + 1);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(firstAidProvider).selectedLanguage;
    final urdu = lang == 'ur';
    final g = widget.guide;
    final steps = g.getSteps(lang);

    return Scaffold(
      backgroundColor: Resq.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              // The category, not the full title: "Choking" fits and is the
              // word someone is looking for. "First Aid for Choking" did not
              // fit, and ellipsised to "First Aid for…", which named nothing.
              title: urdu ? g.getTitle(lang) : (g.category.isNotEmpty ? g.category : g.titleEn),
              languageLabel: urdu ? 'English' : 'اردو',
              onBack: () => context.pop(),
              onToggleLanguage: ref.read(firstAidProvider.notifier).toggleLanguage,
            ),
            Expanded(
              child: StepSlider(
                rtl: urdu,
                steps: [
                  for (var i = 0; i < steps.length; i++)
                    StepSliderItem(
                      number: steps[i].step,
                      title: steps[i].title,
                      instruction: steps[i].instruction,
                      // Artwork is matched by slug, and only five guides have
                      // it so far; the rest fall back to a numbered card.
                      image: FirstAidArt.step(g.slug, i + 1),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact header: a small back button, the name, and the language switch.
///
/// Everything here is smaller than the app's standard page header — this
/// screen's job is the illustration, and the chrome should take as little of
/// it as it can while staying tappable.
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.languageLabel,
    required this.onBack,
    required this.onToggleLanguage,
  });

  final String title;
  final String languageLabel;
  final VoidCallback onBack;
  final VoidCallback onToggleLanguage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Resq.space2, Resq.space2, Resq.space4, Resq.space2),
      child: Row(
        children: [
          InkWell(
            onTap: onBack,
            customBorder: const CircleBorder(),
            child: const SizedBox(
              // 40dp of touch area around a 20dp glyph: still comfortably
              // tappable, but it no longer competes with the title.
              width: 40,
              height: 40,
              child: Icon(Icons.arrow_back_rounded, size: 20, color: Resq.ink),
            ),
          ),
          const SizedBox(width: Resq.space2),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ResqType.section(),
            ),
          ),
          const SizedBox(width: Resq.space3),
          _LanguageButton(label: languageLabel, onTap: onToggleLanguage),
        ],
      ),
    );
  }
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Resq.brandInk,
      borderRadius: BorderRadius.circular(Resq.radiusPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Resq.radiusPill),
        child: Container(
          height: 36,
          constraints: const BoxConstraints(minWidth: 76),
          padding: const EdgeInsets.symmetric(horizontal: Resq.space3),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.translate_rounded, size: 14, color: Colors.white),
              const SizedBox(width: 5),
              Text(label, style: ResqType.caption(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}
