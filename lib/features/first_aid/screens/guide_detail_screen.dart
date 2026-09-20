import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/step_slider.dart';
import '../../sos/providers/sos_provider.dart';
import '../data/models/first_aid_guide_model.dart';
import '../providers/first_aid_provider.dart';

/// One guide, one step at a time, with 1122 pinned to the bottom.
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

  Future<void> _dial(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(firstAidProvider).selectedLanguage;
    final ur = lang == 'ur';
    final hasActiveCase = ref.watch(sosProvider).activeCaseId != null;
    final g = widget.guide;
    final steps = g.getSteps(lang);

    return AppScaffold(
      title: g.getTitle(lang),
      padding: const EdgeInsets.fromLTRB(Resq.space4, 0, Resq.space4, Resq.space3),
      actions: [
        _LangPill(
          label: 'EN',
          active: !ur,
          onTap: () => ref.read(firstAidProvider.notifier).setLanguage('en'),
        ),
        const SizedBox(width: Resq.space2),
        _LangPill(
          label: 'اردو',
          active: ur,
          onTap: () => ref.read(firstAidProvider.notifier).setLanguage('ur'),
        ),
        IconButton(
          tooltip: 'Share',
          onPressed: () => Share.share(
            '${g.getTitle(lang)} — first aid steps in the ResQPK app.',
          ),
          icon: const Icon(Icons.share_rounded, size: 20, color: Resq.inkSoft),
        ),
      ],
      bottomBar: EmergencyCallBar(
        onCall1122: () => _dial('1122'),
        trailing: hasActiveCase
            ? ElevatedButton(
                onPressed: () => context.go(Routes.tracking),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Resq.critical,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(Resq.tapTarget),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Resq.radiusControl),
                  ),
                ),
                child: Text('Back to ambulance', style: ResqType.button()),
              )
            : ElevatedButton(
                onPressed: () => context.go(Routes.home),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Resq.brandInk,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(Resq.tapTarget),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Resq.radiusControl),
                  ),
                ),
                child: Text('Open SOS', style: ResqType.button()),
              ),
      ),
      body: StepSlider(
        rtl: ur,
        steps: [
          for (var i = 0; i < steps.length; i++)
            StepSliderItem(
              number: steps[i].step,
              title: steps[i].title,
              instruction: steps[i].instruction,
              // Artwork is matched by slug, and only five guides have it so
              // far; the rest fall back to a numbered card.
              image: FirstAidArt.step(g.slug, i + 1),
            ),
        ],
      ),
    );
  }
}

class _LangPill extends StatelessWidget {
  const _LangPill({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Resq.space3, vertical: 7),
        decoration: BoxDecoration(
          color: active ? Resq.brandInk : Resq.surfaceAlt,
          borderRadius: BorderRadius.circular(Resq.radiusPill),
        ),
        child: Text(
          label,
          style: ResqType.caption(color: active ? Colors.white : Resq.inkSoft),
        ),
      ),
    );
  }
}
