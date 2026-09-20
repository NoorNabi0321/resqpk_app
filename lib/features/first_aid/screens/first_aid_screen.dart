import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/state_views.dart';
import '../data/models/first_aid_guide_model.dart';
import '../providers/first_aid_provider.dart';

/// Kept for the AI report screen, which labels its suggested guides with these.
const Map<String, String> kCategoryEmoji = {
  'CPR': '❤️',
  'Choking': '🫁',
  'Burns': '🔥',
  'Snake Bite': '🐍',
  'Road Accident': '🚗',
  'Drowning': '🌊',
  'Cardiac Arrest': '⚡',
  'Bleeding': '🩸',
};

const List<String> kCategories = [
  'CPR',
  'Cardiac Arrest',
  'Bleeding',
  'Burns',
  'Choking',
  'Snake Bite',
  'Road Accident',
  'Drowning',
];

/// The guide library — a wall of covers.
///
/// Picked over a list of titles because this screen is used in two very
/// different moods: browsing calmly, and hunting for one specific thing while
/// someone is hurt. A picture is found faster than a line of text in the second.
class FirstAidScreen extends ConsumerStatefulWidget {
  const FirstAidScreen({super.key});

  @override
  ConsumerState<FirstAidScreen> createState() => _FirstAidScreenState();
}

class _FirstAidScreenState extends ConsumerState<FirstAidScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(firstAidProvider.notifier).search(q);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(firstAidProvider);
    final notifier = ref.read(firstAidProvider.notifier);
    final isOnline = ref.watch(isOnlineProvider).value ?? true;
    final ur = state.selectedLanguage == 'ur';

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Resq.space4, Resq.space4, Resq.space4, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('First aid', style: ResqType.display())),
                _LangPill(
                  label: 'EN',
                  active: !ur,
                  onTap: () => notifier.setLanguage('en'),
                ),
                const SizedBox(width: Resq.space2),
                _LangPill(
                  label: 'اردو',
                  active: ur,
                  onTap: () => notifier.setLanguage('ur'),
                ),
              ],
            ),
            const SizedBox(height: Resq.space3),

            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: ResqType.body(),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded, color: Resq.inkMuted),
                hintText: ur ? 'رہنمائی تلاش کریں…' : 'Search guides',
                hintStyle: ResqType.body(color: Resq.inkFaint),
                filled: true,
                fillColor: Resq.surface,
                suffixIcon: state.searchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: Resq.inkMuted),
                        onPressed: () {
                          _searchController.clear();
                          notifier.search('');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Resq.radiusControl),
                  borderSide: BorderSide(color: Resq.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Resq.radiusControl),
                  borderSide: BorderSide(color: Resq.border),
                ),
              ),
            ),

            // Cached guides are the whole point of this screen offline — say so
            // rather than leaving someone wondering whether it is stale.
            if (!isOnline && state.isOfflineCacheAvailable)
              const _Note(
                icon: Icons.offline_pin_rounded,
                text: 'Offline — showing saved guides',
                color: Resq.ready,
              ),
            if (isOnline && state.isSyncing)
              const _Note(
                icon: Icons.sync_rounded,
                text: 'Updating guides…',
                color: Resq.info,
              ),

            const SizedBox(height: Resq.space3),

            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _CategoryPill(
                    label: 'All',
                    active: state.selectedCategory == null,
                    onTap: () => notifier.filterByCategory(null),
                  ),
                  for (final c in kCategories)
                    _CategoryPill(
                      label: c,
                      active: state.selectedCategory == c,
                      onTap: () => notifier.filterByCategory(c),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Resq.space4),

            Expanded(child: _body(state, notifier)),
          ],
        ),
      ),
    );
  }

  Widget _body(FirstAidState state, FirstAidNotifier notifier) {
    if (state.isLoading && state.guides.isEmpty) {
      return const LoadingSkeleton(lines: 3, height: 150);
    }

    if (state.error != null && state.guides.isEmpty) {
      return ErrorState(
        illustration: AppAssets.stateOffline,
        title: 'Could not load the guides',
        message: 'They download once and then work offline.',
        onRetry: () => notifier.loadGuides(forceRefresh: true),
      );
    }

    if (state.filteredGuides.isEmpty) {
      return EmptyState(
        illustration: AppAssets.stateError,
        title: state.searchQuery.isNotEmpty
            ? 'Nothing matches "${state.searchQuery}"'
            : 'No guides in this category yet',
        actionLabel: 'Show all guides',
        onAction: () {
          _searchController.clear();
          notifier.search('');
          notifier.filterByCategory(null);
        },
      );
    }

    return RefreshIndicator(
      onRefresh: () => notifier.loadGuides(forceRefresh: true),
      color: Resq.brandInk,
      child: GridView.builder(
        padding: const EdgeInsets.only(bottom: Resq.space6),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: Resq.space3,
          mainAxisSpacing: Resq.space3,
          childAspectRatio: 0.78,
        ),
        itemCount: state.filteredGuides.length,
        itemBuilder: (_, i) {
          final guide = state.filteredGuides[i];
          return _GuideCard(
            guide: guide,
            language: state.selectedLanguage,
            onTap: () => context.push(Routes.guideDetail, extra: guide),
          );
        },
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.guide, required this.language, required this.onTap});

  final FirstAidGuideModel guide;
  final String language;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cover = FirstAidArt.cover(guide.slug);
    final steps = guide.getSteps(language).length;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Resq.surface,
          borderRadius: BorderRadius.circular(Resq.radiusCard),
          border: Border.all(color: Resq.border),
          boxShadow: Resq.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: cover == null
                  ? _EmojiCover(category: guide.category)
                  : Image.asset(
                      cover,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _EmojiCover(category: guide.category),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Resq.space3, Resq.space3, Resq.space3, Resq.space3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guide.getTitle(language),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ResqType.bodyStrong(),
                  ),
                  const SizedBox(height: 2),
                  Text('$steps steps', style: ResqType.caption()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stand-in for the three guides still waiting on artwork.
class _EmojiCover extends StatelessWidget {
  const _EmojiCover({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Resq.brandTint,
      alignment: Alignment.center,
      child: Text(kCategoryEmoji[category] ?? '🩹', style: const TextStyle(fontSize: 44)),
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
        padding: const EdgeInsets.symmetric(horizontal: Resq.space3, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Resq.brandInk : Resq.surfaceAlt,
          borderRadius: BorderRadius.circular(Resq.radiusPill),
        ),
        child: Text(label, style: ResqType.caption(color: active ? Colors.white : Resq.inkSoft)),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: Resq.space2),
      child: GestureDetector(
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
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Resq.space2),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: Resq.space2),
          Text(text, style: ResqType.caption(color: color)),
        ],
      ),
    );
  }
}
