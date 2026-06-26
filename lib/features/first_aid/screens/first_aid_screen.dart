import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/router/app_router.dart';
import '../data/models/first_aid_guide_model.dart';
import '../providers/first_aid_provider.dart';

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
    final showFeatured = state.searchQuery.isEmpty && state.selectedCategory == null;
    final featured = state.guides.where((g) => g.isFeatured).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header + language toggle
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                    onPressed: () => context.pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text('First Aid Library', style: AppTextStyles.title)),
                  _langPill('EN', !ur, () => notifier.setLanguage('en')),
                  const SizedBox(width: 6),
                  _langPill('اردو', ur, () => notifier.setLanguage('ur')),
                ],
              ),
              const SizedBox(height: 12),

              // Search
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: AppTextStyles.body,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                  hintText: ur ? 'رہنمائی تلاش کریں...' : 'Search guides...',
                  hintStyle: AppTextStyles.caption,
                  filled: true,
                  fillColor: AppColors.surfaceTwo,
                  suffixIcon: state.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            notifier.search('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              // Status banners
              if (state.isOfflineCacheAvailable && !isOnline)
                _banner('📥 Offline — Using saved guides', AppColors.confirmedGreen),
              if (isOnline && state.isSyncing) _banner('Syncing…', AppColors.infoBlue),

              const SizedBox(height: 12),

              // Category filter
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _categoryPill('All', state.selectedCategory == null,
                        () => notifier.filterByCategory(null)),
                    ...kCategories.map((c) => _categoryPill(
                          c,
                          state.selectedCategory == c,
                          () => notifier.filterByCategory(c),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Expanded(child: _body(state, notifier, showFeatured, featured)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(
    FirstAidState state,
    FirstAidNotifier notifier,
    bool showFeatured,
    List<FirstAidGuideModel> featured,
  ) {
    if (state.isLoading && state.guides.isEmpty) return _shimmerGrid();

    if (state.error != null && state.guides.isEmpty) {
      return _centered([
        Text('Could not load guides', style: AppTextStyles.body),
        if (state.isOfflineCacheAvailable)
          Text('Using offline cache', style: AppTextStyles.caption),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () => notifier.loadGuides(forceRefresh: true),
          child: const Text('Retry'),
        ),
      ]);
    }

    if (state.filteredGuides.isEmpty) {
      return _centered([
        const Text('🔍', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 8),
        Text(
          state.searchQuery.isNotEmpty
              ? 'No guides found for "${state.searchQuery}"'
              : 'No guides found',
          style: AppTextStyles.body,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            _searchController.clear();
            notifier.search('');
            notifier.filterByCategory(null);
          },
          child: const Text('Clear Search'),
        ),
      ]);
    }

    return RefreshIndicator(
      onRefresh: () => notifier.loadGuides(forceRefresh: true),
      color: AppColors.sosRed,
      child: CustomScrollView(
        slivers: [
          if (showFeatured && featured.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Essential Guides',
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 124,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: featured.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => _featuredCard(featured[i], state.selectedLanguage),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
          SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.92,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, i) => _GuideCard(
                guide: state.filteredGuides[i],
                language: state.selectedLanguage,
                onTap: () => context.push(Routes.guideDetail, extra: state.filteredGuides[i]),
              ),
              childCount: state.filteredGuides.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }

  Widget _centered(List<Widget> children) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      );

  Widget _langPill(String label, bool active, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? AppColors.infoBlue : AppColors.surfaceTwo,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: AppTextStyles.caption
                  .copyWith(color: active ? Colors.white : AppColors.textSecondary)),
        ),
      );

  Widget _categoryPill(String label, bool active, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: active ? AppColors.infoBlue : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: active ? AppColors.infoBlue : AppColors.borderGlass),
            ),
            child: Text(label,
                style: AppTextStyles.caption
                    .copyWith(color: active ? Colors.white : AppColors.textSecondary)),
          ),
        ),
      );

  Widget _banner(String text, Color color) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, style: AppTextStyles.caption.copyWith(color: color)),
            ],
          ),
        ),
      );

  Widget _featuredCard(FirstAidGuideModel g, String lang) => GestureDetector(
        onTap: () => context.push(Routes.guideDetail, extra: g),
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.sosRed.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.sosRed.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(kCategoryEmoji[g.category] ?? '🩹', style: const TextStyle(fontSize: 26)),
              const Spacer(),
              Text(g.getTitle(lang),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(color: Colors.white)),
              const SizedBox(height: 2),
              Text('${g.getSteps(lang).length} steps', style: AppTextStyles.caption),
            ],
          ),
        ),
      );

  Widget _shimmerGrid() => GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.92,
        children: List.generate(
          4,
          (_) => Shimmer.fromColors(
            baseColor: AppColors.surfaceTwo,
            highlightColor: AppColors.surfaceOne,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceTwo,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      );
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.guide, required this.language, required this.onTap});
  final FirstAidGuideModel guide;
  final String language;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceTwo,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(kCategoryEmoji[guide.category] ?? '🩹', style: const TextStyle(fontSize: 30)),
            const Spacer(),
            Text(
              guide.getTitle(language),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('${guide.getSteps(language).length} steps', style: AppTextStyles.caption),
                const Spacer(),
                if (guide.isFeatured)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warningAmber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('⭐',
                        style: AppTextStyles.caption.copyWith(fontSize: 9)),
                  ),
              ],
            ),
          ],
        ),
      ),
    ).animate().scale(begin: const Offset(0.96, 0.96), end: const Offset(1, 1), duration: 150.ms);
  }
}
