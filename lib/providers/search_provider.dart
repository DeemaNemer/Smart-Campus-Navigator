import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/search_result.dart';
import '../services/api_service.dart';

// Holds the current search state
class SearchState {
  final String query;
  final List<SearchResult> results;
  final bool isLoading;
  final String? error;

  SearchState({
    this.query = '',
    this.results = const [],
    this.isLoading = false,
    this.error,
  });

  SearchState copyWith({
    String? query,
    List<SearchResult>? results,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return SearchState(
      query: query ?? this.query,
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

  Future<void> search(String query) async {
    // If query is empty, clear results
    if (query.trim().isEmpty) {
      state = SearchState();
      return;
    }

    // Set loading
    state = state.copyWith(
      query: query,
      isLoading: true,
      clearError: true,
    );

    try {
      final results = await _api.search(query);
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
}

// The actual provider - this is what we use in UI
final searchProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ApiService());
});