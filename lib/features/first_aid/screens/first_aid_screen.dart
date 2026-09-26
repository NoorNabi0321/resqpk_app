import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/state_views.dart';
import '../providers/first_aid_provider.dart';
import '../widgets/guide_card.dart';

/// Kept for the AI report screen, which labels its suggested guides with these.
/// Kept for the AI report screen, which labels its suggested guides with these.
const Map<String, String> kCategoryEmoji = {
  'CPR': '❤️',
  'Choking': '🫁',
  'Bleeding': '🩸',
  'Burns': '🔥',
  'Snake Bite': '🐍',
  'Fracture': '🦴',
  'Heatstroke': '🌡️',
  'Eye Injury': '👁️',
};

/// The eight the library carries, in the order the guides are ordered.
///
/// Road Accident, Drowning and Cardiac Arrest were dropped: none had step
/// artwork, and a first-aid step without a picture is the one people stop
/// reading. Their emergency types were folded into the guides that remain —
/// cardiac arrest and drowning both end in CPR, and a road accident is
/// bleeding and broken bones — so the AI report still resolves a guide for
/// every emergency it can detect.
const List<String> kCategories = [
  'CPR',
  'Choking',
  'Bleeding',
  'Burns',
  'Snake Bite',
  'Fracture',
  'Heatstroke',
  'Eye Injury',
];

/// The guide library.
///
/// One row per guide: what it covers, when to use it, and the picture. The
/// category chips that used to sit under the search bar are gone — with eight
/// guides they filtered a list you could already see, and they pushed the
/// guides themselves below the fold. Category now lives in the filter sheet,
/// where it belongs with sorting.
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
    final urdu = state.selectedLanguage == 'ur';

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Resq.space4, Resq.space4, Resq.space4, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(urdu ? 'ابتدائی طبی امداد' : 'First aid', style: ResqType.display()),
                ),
                // One button, both directions: it always names the language you
                // would be switching TO, so it reads as an action rather than
                // a label for the state you are already in.
                _LanguageButton(
                  label: urdu ? 'English' : 'اردو',
                  onTap: notifier.toggleLanguage,
                ),
              ],
            ),
            const SizedBox(height: Resq.space3),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: ResqType.body(),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded, color: Resq.inkMuted),
                      hintText: urdu ? 'رہنمائی تلاش کریں' : 'Search guides',
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
                ),
                const SizedBox(width: Resq.space3),
                _FilterButton(
                  count: state.activeFilterCount,
                  onTap: () => _openFilters(context, state),
                ),
              ],
            ),

            if (!isOnline && state.isOfflineCacheAvailable)
              const _Note(
                icon: Icons.offline_pin_rounded,
                text: 'Offline — these guides are saved on your phone',
                color: Resq.ready,
              ),
            if (isOnline && state.isSyncing)
              const _Note(icon: Icons.sync_rounded, text: 'Updating guides…', color: Resq.info),
            if (state.activeFilterCount > 0) _ActiveFilters(state: state, notifier: notifier),

            const SizedBox(height: Resq.space4),
            Expanded(child: _body(state, notifier)),
          ],
        ),
      ),
    );
  }

  Widget _body(FirstAidState state, FirstAidNotifier notifier) {
    if (state.isLoading && state.guides.isEmpty) {
      return const LoadingSkeleton(lines: 4, height: 112);
    }

    if (state.error != null && state.guides.isEmpty) {
      return ErrorState(
        illustration: AppAssets.stateOffline,
        title: 'Could not load the guides',
        message: 'They are saved on your phone once you have been online once.',
        onRetry: () => notifier.loadGuides(forceRefresh: true),
      );
    }

    if (state.filteredGuides.isEmpty) {
      return EmptyState(
        illustration: AppAssets.stateError,
        title: state.searchQuery.isNotEmpty
            ? 'Nothing matches "${state.searchQuery}"'
            : 'No guides match these filters',
        actionLabel: 'Show all guides',
        onAction: () {
          _searchController.clear();
          notifier.search('');
          notifier.clearFilters();
        },
      );
    }

    // Keyed on the result set, so narrowing a search animates rather than
    // swapping silently. Without it the list changed between two frames and a
    // reader could not tell whether their typing had done anything.
    final resultKey = state.filteredGuides.map((g) => g.slug).join(',');

    return RefreshIndicator(
      onRefresh: () => notifier.loadGuides(forceRefresh: true),
      color: Resq.brandInk,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        // The outgoing list must not push the incoming one around while both
        // are alive, so they are stacked rather than laid out together.
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [...previous, if (current != null) current],
        ),
        child: ListView.builder(
          key: ValueKey(resultKey),
          padding: const EdgeInsets.only(bottom: Resq.space6),
          itemCount: state.filteredGuides.length,
          itemBuilder: (_, i) {
            final guide = state.filteredGuides[i];
            return GuideCard(
              guide: guide,
              language: state.selectedLanguage,
              onTap: () => context.push(Routes.guideDetail, extra: guide),
            )
                // Staggered, but only just — eight cards at 28ms apart reads
                // as the list settling, not as a queue forming.
                .animate()
                .fadeIn(
                  duration: 220.ms,
                  delay: Duration(milliseconds: 28 * (i < 6 ? i : 6)),
                )
                .slideY(begin: 0.06, end: 0, duration: 260.ms, curve: Curves.easeOutCubic);
          },
        ),
      ),
    );
  }

  Future<void> _openFilters(BuildContext context, FirstAidState state) async {
    final notifier = ref.read(firstAidProvider.notifier);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Resq.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Resq.radiusCard)),
      ),
      builder: (sheetCtx) => Consumer(
        builder: (_, sheetRef, __) {
          final live = sheetRef.watch(firstAidProvider);
          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Resq.space5,
                  Resq.space4,
                  Resq.space5,
                  Resq.space5,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Resq.border,
                          borderRadius: BorderRadius.circular(Resq.radiusPill),
                        ),
                      ),
                    ),
                    const SizedBox(height: Resq.space4),
                    Row(
                      children: [
                        Expanded(child: Text('Sort and filter', style: ResqType.title())),
                        if (live.activeFilterCount > 0)
                          TextButton(
                            onPressed: notifier.clearFilters,
                            child: Text('Reset', style: ResqType.button(color: Resq.brandInk)),
                          ),
                      ],
                    ),
                    const SizedBox(height: Resq.space4),

                    Text('Order', style: ResqType.caption(color: Resq.inkSoft)),
                    const SizedBox(height: Resq.space2),
                    for (final sort in GuideSort.values)
                      _SortRow(
                        sort: sort,
                        selected: live.sort == sort,
                        onTap: () => notifier.setSort(sort),
                      ),

                    const SizedBox(height: Resq.space4),
                    Text('Kind of emergency', style: ResqType.caption(color: Resq.inkSoft)),
                    const SizedBox(height: Resq.space2),
                    Wrap(
                      spacing: Resq.space2,
                      runSpacing: Resq.space2,
                      children: [
                        _Chip(
                          label: 'All',
                          active: live.selectedCategory == null,
                          onTap: () => notifier.filterByCategory(null),
                        ),
                        for (final c in kCategories)
                          _Chip(
                            label: c,
                            active: live.selectedCategory == c,
                            onTap: () => notifier.filterByCategory(
                              live.selectedCategory == c ? null : c,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: Resq.space4),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: live.illustratedOnly,
                      onChanged: notifier.setIllustratedOnly,
                      activeThumbColor: Resq.brandInk,
                      title: Text('Only guides with pictures', style: ResqType.bodyStrong()),
                      subtitle: Text(
                        'Faster to follow when your hands are busy',
                        style: ResqType.caption(),
                      ),
                    ),

                    const SizedBox(height: Resq.space3),
                    SizedBox(
                      height: Resq.tapTarget,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(sheetCtx).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Resq.brandInk,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Resq.radiusControl),
                          ),
                        ),
                        child: Text(
                          'Show ${live.filteredGuides.length} '
                          '${live.filteredGuides.length == 1 ? 'guide' : 'guides'}',
                          style: ResqType.button(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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
          constraints: const BoxConstraints(minHeight: Resq.tapTarget, minWidth: 92),
          padding: const EdgeInsets.symmetric(horizontal: Resq.space4),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.translate_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(label, style: ResqType.bodyStrong(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = count > 0;

    return Material(
      color: active ? Resq.brandInk : Resq.surface,
      borderRadius: BorderRadius.circular(Resq.radiusControl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Resq.radiusControl),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Resq.radiusControl),
            border: Border.all(color: active ? Resq.brandInk : Resq.border),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.tune_rounded,
                size: 22,
                color: active ? Colors.white : Resq.inkSoft,
              ),
              if (active)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Resq.critical, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$count',
                      textAlign: TextAlign.center,
                      style: ResqType.micro(color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What is currently filtering the list, and a way out of it.
class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({required this.state, required this.notifier});

  final FirstAidState state;
  final FirstAidNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Resq.space3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              [
                if (state.selectedCategory != null) state.selectedCategory!,
                if (state.illustratedOnly) 'with pictures',
                if (state.sort != GuideSort.recommended) state.sort.label.toLowerCase(),
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ResqType.caption(color: Resq.brandInk),
            ),
          ),
          GestureDetector(
            onTap: notifier.clearFilters,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Resq.space2, vertical: 4),
              child: Text('Clear', style: ResqType.caption(color: Resq.inkMuted)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SortRow extends StatelessWidget {
  const _SortRow({required this.sort, required this.selected, required this.onTap});

  final GuideSort sort;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Resq.radiusControl),
      child: Container(
        constraints: const BoxConstraints(minHeight: Resq.tapTarget),
        padding: const EdgeInsets.symmetric(horizontal: Resq.space2, vertical: Resq.space2),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              size: 20,
              color: selected ? Resq.brandInk : Resq.inkFaint,
            ),
            const SizedBox(width: Resq.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sort.label, style: ResqType.bodyStrong()),
                  Text(sort.hint, style: ResqType.caption()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Resq.space4, vertical: 10),
        decoration: BoxDecoration(
          color: active ? Resq.brandInk : Resq.surfaceAlt,
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

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Resq.space3),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: Resq.space2),
          Expanded(child: Text(text, style: ResqType.caption(color: color))),
        ],
      ),
    );
  }
}
