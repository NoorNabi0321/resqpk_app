import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_assets.dart';
import '../data/first_aid_repository.dart';
import '../data/models/first_aid_guide_model.dart';

/// How the library is ordered.
///
/// `recommended` is the order the guides were written in — the most common
/// emergencies first — and stays the default. The rest exist because someone
/// hunting for one specific thing sorts differently from someone browsing.
enum GuideSort {
  recommended,
  titleAsc,
  titleDesc,
  fewestSteps,
}

extension GuideSortLabel on GuideSort {
  String get label => switch (this) {
        GuideSort.recommended => 'Most common first',
        GuideSort.titleAsc => 'A to Z',
        GuideSort.titleDesc => 'Z to A',
        GuideSort.fewestSteps => 'Quickest to follow',
      };

  String get hint => switch (this) {
        GuideSort.recommended => 'The emergencies we are called for most',
        GuideSort.titleAsc => 'Alphabetical',
        GuideSort.titleDesc => 'Reverse alphabetical',
        GuideSort.fewestSteps => 'Fewest steps at the top',
      };
}

class FirstAidState {
  final List<FirstAidGuideModel> guides;
  final List<FirstAidGuideModel> filteredGuides;
  final FirstAidGuideModel? selectedGuide;
  final String searchQuery;
  final String selectedLanguage; // 'en' | 'ur'
  final String? selectedCategory; // null = all
  final GuideSort sort;

  /// Only guides that have step artwork. Pictures are faster to follow than
  /// text when your hands are busy, so it is worth being able to ask for them.
  final bool illustratedOnly;
  final bool isLoading;
  final bool isSyncing;
  final String? error;
  final bool isOfflineCacheAvailable;
  final DateTime? lastSyncedAt;

  const FirstAidState({
    this.guides = const [],
    this.filteredGuides = const [],
    this.selectedGuide,
    this.searchQuery = '',
    this.selectedLanguage = 'en',
    this.selectedCategory,
    this.sort = GuideSort.recommended,
    this.illustratedOnly = false,
    this.isLoading = false,
    this.isSyncing = false,
    this.error,
    this.isOfflineCacheAvailable = false,
    this.lastSyncedAt,
  });

  /// How many filters are on, for the badge on the filter button.
  int get activeFilterCount =>
      (selectedCategory != null ? 1 : 0) +
      (illustratedOnly ? 1 : 0) +
      (sort != GuideSort.recommended ? 1 : 0);

  FirstAidState copyWith({
    List<FirstAidGuideModel>? guides,
    List<FirstAidGuideModel>? filteredGuides,
    FirstAidGuideModel? selectedGuide,
    String? searchQuery,
    String? selectedLanguage,
    String? selectedCategory,
    GuideSort? sort,
    bool? illustratedOnly,
    bool? isLoading,
    bool? isSyncing,
    String? error,
    bool? isOfflineCacheAvailable,
    DateTime? lastSyncedAt,
    bool clearSelectedGuide = false,
    bool clearCategory = false,
    bool clearError = false,
  }) {
    return FirstAidState(
      guides: guides ?? this.guides,
      filteredGuides: filteredGuides ?? this.filteredGuides,
      selectedGuide: clearSelectedGuide ? null : (selectedGuide ?? this.selectedGuide),
      searchQuery: searchQuery ?? this.searchQuery,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      selectedCategory: clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      sort: sort ?? this.sort,
      illustratedOnly: illustratedOnly ?? this.illustratedOnly,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      error: clearError ? null : (error ?? this.error),
      isOfflineCacheAvailable: isOfflineCacheAvailable ?? this.isOfflineCacheAvailable,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}

class FirstAidNotifier extends StateNotifier<FirstAidState> {
  FirstAidNotifier(this._repository) : super(const FirstAidState());

  final FirstAidRepository _repository;

  Future<void> loadGuides({bool forceRefresh = false}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final cacheAvailable = await _repository.isCacheAvailable();
      final guides = await _repository.getGuides(
        language: state.selectedLanguage,
        forceRefresh: forceRefresh,
      );
      guides.sort((a, b) {
        if (a.isFeatured != b.isFeatured) return a.isFeatured ? -1 : 1;
        return a.displayOrder.compareTo(b.displayOrder);
      });
      state = state.copyWith(
        guides: guides,
        isLoading: false,
        isOfflineCacheAvailable: cacheAvailable,
        lastSyncedAt: DateTime.now(),
      );
      _applyFilters();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  List<FirstAidGuideModel> _applyCategory(List<FirstAidGuideModel> guides) {
    if (state.selectedCategory == null) return guides;
    return guides.where((g) => g.category == state.selectedCategory).toList();
  }

  List<FirstAidGuideModel> _applySort(List<FirstAidGuideModel> guides) {
    final sorted = [...guides];
    final lang = state.selectedLanguage;
    switch (state.sort) {
      case GuideSort.recommended:
        sorted.sort((a, b) {
          if (a.isFeatured != b.isFeatured) return a.isFeatured ? -1 : 1;
          return a.displayOrder.compareTo(b.displayOrder);
        });
      case GuideSort.titleAsc:
        sorted.sort((a, b) => a.getTitle(lang).compareTo(b.getTitle(lang)));
      case GuideSort.titleDesc:
        sorted.sort((a, b) => b.getTitle(lang).compareTo(a.getTitle(lang)));
      case GuideSort.fewestSteps:
        sorted.sort((a, b) => a.getSteps(lang).length.compareTo(b.getSteps(lang).length));
    }
    return sorted;
  }

  void _applyFilters() {
    var base = _applyCategory(state.guides);
    if (state.illustratedOnly) {
      base = base.where((g) => FirstAidArt.hasArt(g.slug)).toList();
    }
    final searched = state.searchQuery.isEmpty
        ? base
        : _repository.searchGuides(base, state.searchQuery, state.selectedLanguage);
    state = state.copyWith(filteredGuides: _applySort(searched));
  }

  void setSort(GuideSort sort) {
    state = state.copyWith(sort: sort);
    _applyFilters();
  }

  void setIllustratedOnly(bool value) {
    state = state.copyWith(illustratedOnly: value);
    _applyFilters();
  }

  /// Back to the plain library: no category, no picture filter, default order.
  void clearFilters() {
    state = state.copyWith(
      clearCategory: true,
      sort: GuideSort.recommended,
      illustratedOnly: false,
    );
    _applyFilters();
  }

  /// One button, two directions: English shows Urdu, Urdu shows English.
  void toggleLanguage() => setLanguage(state.selectedLanguage == 'ur' ? 'en' : 'ur');

  void search(String query) {
    state = state.copyWith(searchQuery: query);
    _applyFilters();
  }

  void filterByCategory(String? category) {
    state = category == null
        ? state.copyWith(clearCategory: true)
        : state.copyWith(selectedCategory: category);
    _applyFilters();
  }

  void setLanguage(String language) {
    state = state.copyWith(selectedLanguage: language);
    _applyFilters();
  }

  void selectGuide(FirstAidGuideModel guide) => state = state.copyWith(selectedGuide: guide);

  void clearSelection() => state = state.copyWith(clearSelectedGuide: true);

  List<FirstAidGuideModel> getRelevantGuidesForEmergency(String emergencyType) {
    return _repository.getRelevantGuides(state.guides, emergencyType);
  }

  Future<void> syncInBackground() async {
    state = state.copyWith(isSyncing: true);
    try {
      await _repository.syncInBackground();
      await loadGuides();
    } finally {
      state = state.copyWith(isSyncing: false);
    }
  }
}

final firstAidRepositoryProvider = Provider<FirstAidRepository>((ref) => FirstAidRepository());

final firstAidProvider = StateNotifierProvider<FirstAidNotifier, FirstAidState>((ref) {
  final notifier = FirstAidNotifier(ref.read(firstAidRepositoryProvider));
  notifier.loadGuides();
  return notifier;
});

final featuredGuidesProvider = Provider<List<FirstAidGuideModel>>((ref) {
  return ref.watch(firstAidProvider).guides.where((g) => g.isFeatured).toList();
});

final filteredGuidesProvider = Provider<List<FirstAidGuideModel>>((ref) {
  return ref.watch(firstAidProvider).filteredGuides;
});
