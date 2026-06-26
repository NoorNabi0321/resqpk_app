import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_router.dart';
import '../../sos/providers/sos_provider.dart';
import '../data/models/first_aid_guide_model.dart';
import '../providers/first_aid_provider.dart';
import 'first_aid_screen.dart' show kCategoryEmoji;

class GuideDetailScreen extends ConsumerStatefulWidget {
  const GuideDetailScreen({super.key, required this.guide});
  final FirstAidGuideModel guide;

  @override
  ConsumerState<GuideDetailScreen> createState() => _GuideDetailScreenState();
}

class _GuideDetailScreenState extends ConsumerState<GuideDetailScreen> {
  late final Set<int> _expanded;

  @override
  void initState() {
    super.initState();
    // Auto-expand all steps on first view (staggered entrance animation below).
    _expanded = Set<int>.from(List.generate(widget.guide.stepsEn.length, (i) => i));
    _incrementGuidesRead();
  }

  Future<void> _incrementGuidesRead() async {
    final box = Hive.isBoxOpen('app_stats') ? Hive.box('app_stats') : await Hive.openBox('app_stats');
    await box.put('guides_read', ((box.get('guides_read') as int?) ?? 0) + 1);
  }

  Future<void> _dial(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Color _stepColor(int index, int total) {
    if (index == 0) return AppColors.sosRed;
    if (index == total - 1) return AppColors.confirmedGreen;
    return AppColors.infoBlue;
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(firstAidProvider).selectedLanguage;
    final ur = lang == 'ur';
    final hasActiveCase = ref.watch(sosProvider).activeCaseId != null;
    final g = widget.guide;
    final steps = g.getSteps(lang);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Custom app bar
            Container(
              color: AppColors.surfaceOne,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Text(
                      g.getTitle(lang),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(color: Colors.white),
                    ),
                  ),
                  _langPill('EN', !ur, () => ref.read(firstAidProvider.notifier).setLanguage('en')),
                  const SizedBox(width: 6),
                  _langPill('اردو', ur, () => ref.read(firstAidProvider.notifier).setLanguage('ur')),
                  IconButton(
                    icon: const Icon(Icons.share, color: AppColors.textSecondary, size: 20),
                    onPressed: () => Share.share(
                      '${g.getTitle(lang)} — Download ResQPK for the full first aid guide.',
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  // Hero header
                  Container(
                    height: 200,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.surfaceTwo, AppColors.background],
                      ),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(kCategoryEmoji[g.category] ?? '🩹', style: const TextStyle(fontSize: 64)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.infoBlue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(g.category,
                              style: AppTextStyles.caption.copyWith(color: AppColors.infoBlue)),
                        ),
                        const SizedBox(height: 8),
                        Text(g.getTitle(lang),
                            textAlign: TextAlign.center,
                            style: AppTextStyles.title.copyWith(color: Colors.white)),
                        const SizedBox(height: 2),
                        Text('${steps.length} steps • Tap each step to expand',
                            style: AppTextStyles.caption),
                      ],
                    ),
                  ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1),

                  // Steps
                  ...List.generate(steps.length, (i) {
                    final step = steps[i];
                    final open = _expanded.contains(i);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceTwo,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () => setState(() {
                              if (open) {
                                _expanded.remove(i);
                              } else {
                                _expanded.add(i);
                              }
                            }),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 30,
                                    height: 30,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: _stepColor(i, steps.length),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text('${step.step}',
                                        style: AppTextStyles.caption
                                            .copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(step.title,
                                        style: AppTextStyles.body.copyWith(color: Colors.white)),
                                  ),
                                  Icon(open ? Icons.expand_less : Icons.expand_more,
                                      color: AppColors.textSecondary),
                                ],
                              ),
                            ),
                          ),
                          AnimatedCrossFade(
                            duration: const Duration(milliseconds: 200),
                            crossFadeState:
                                open ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                            firstChild: Padding(
                              padding: const EdgeInsets.fromLTRB(54, 0, 14, 14),
                              child: Directionality(
                                textDirection: ur ? TextDirection.rtl : TextDirection.ltr,
                                child: Text(
                                  step.instruction,
                                  style: AppTextStyles.body.copyWith(height: 1.6, fontSize: 15),
                                ),
                              ),
                            ),
                            secondChild: const SizedBox(width: double.infinity),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: (300 + i * 150).ms).slideY(begin: 0.08);
                  }),
                ],
              ),
            ),

            // Sticky CTA
            Container(
              height: 72,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.surfaceOne,
                border: Border(top: BorderSide(color: AppColors.surfaceTwo)),
              ),
              child: hasActiveCase
                  ? ElevatedButton(
                      onPressed: () => context.go(Routes.tracking),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.sosRed,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('← Back to Emergency'),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _dial('1122'),
                            child: const Text('📞 Call 1122'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => context.go(Routes.home),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.sosRed),
                            child: const Text('🆘 Open SOS', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _langPill(String label, bool active, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active ? AppColors.infoBlue : AppColors.surfaceTwo,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: AppTextStyles.caption
                  .copyWith(color: active ? Colors.white : AppColors.textSecondary)),
        ),
      );
}
