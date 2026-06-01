import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/search_result.dart';
import '../services/api_service.dart';

// Holds the current search state
class SearchState {
  final String query;
  final String? category;
  final List<SearchResult> results;
  final bool isLoading;
  final String? error;

  SearchState({
    this.query = '',
    this.category,
    this.results = const [],
    this.isLoading = false,
    this.error,
  });

  SearchState copyWith({
    String? query,
    String? category,
    List<SearchResult>? results,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearCategory = false,
  }) {
    return SearchState(
      query: query ?? this.query,
      category: clearCategory ? null : (category ?? this.category),
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// The notifier that manages search state
class SearchNotifier extends StateNotifier<SearchState> {
  final ApiService _api;

  SearchNotifier(this._api) : super(SearchState());

  Future<void> search(String query, {String? category}) async {
    final selectedCategory = category ?? state.category;
    final cleanQuery = query.trim();

    if (cleanQuery.isEmpty &&
        (selectedCategory == null || selectedCategory.isEmpty)) {
      state = state.copyWith(
        query: query,
        results: [],
        isLoading: false,
        clearError: true,
      );
      return;
    }

    state = state.copyWith(
      query: query,
      category: selectedCategory,
      isLoading: true,
      clearError: true,
    );

    try {
      final results = cleanQuery.isEmpty && selectedCategory != null
          ? await _loadCategoryResults(selectedCategory)
          : _filterByCategory(
              await _api.search(
                cleanQuery,
                category: selectedCategory,
              ),
              selectedCategory,
            );
      state = state.copyWith(
        results: results,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        results: [],
      );
    }
  }

  void clear() {
    state = SearchState();
  }

  void selectCategory(String? category) {
    state = state.copyWith(
      category: category,
      results: [],
      clearError: true,
      clearCategory: category == null,
    );
  }

  Future<List<SearchResult>> _loadCategoryResults(String category) async {
    if (category == 'professor') {
      final professors = await _api.getProfessors();
      return professors.map(SearchResult.professor).toList();
    }

    final rooms = await _api.getRooms();
    return rooms
        .where((room) => room.type == category)
        .map(SearchResult.room)
        .toList();
  }

  List<SearchResult> _filterByCategory(
    List<SearchResult> results,
    String? category,
  ) {
    if (category == null || category.isEmpty) return results;

    return results.where((result) {
      if (category == 'professor') {
        return result.type == SearchResultType.professor;
      }

      return result.type == SearchResultType.room &&
          result.room?.type == category;
    }).toList();
  }
}

// The actual provider - this is what we use in UI
final searchProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ApiService());
});
