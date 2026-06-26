import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/first_aid_repository.dart';
import '../data/models/first_aid_guide_model.dart';

class FirstAidState {
  final List<FirstAidGuideModel> guides;
  final List<FirstAidGuideModel> filteredGuides;
  final FirstAidGuideModel? selectedGuide;
  final String searchQuery;
  final String selectedLanguage; // 'en' | 'ur'
  final String? selectedCategory; // null = all
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
    this.isLoading = false,
    this.isSyncing = false,
    this.error,
    this.isOfflineCacheAvailable = false,
    this.lastSyncedAt,
  });

  FirstAidState copyWith({
    List<FirstAidGuideModel>? guides,
    List<FirstAidGuideModel>? filteredGuides,
    FirstAidGuideModel? selectedGuide,
    String? searchQuery,
    String? selectedLanguage,
    String? selectedCategory,
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

  void _applyFilters() {
    final base = _applyCategory(state.guides);
    final filtered = state.searchQuery.isEmpty
        ? base
        : _repository.searchGuides(base, state.searchQuery, state.selectedLanguage);
    state = state.copyWith(filteredGuides: filtered);
  }

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
