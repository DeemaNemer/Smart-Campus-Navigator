import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event.dart';
import '../services/api_service.dart';

// Provider لجلب الأحداث
final eventsProvider = FutureProvider<List<Event>>((ref) async {
  final api = ApiService();
  return api.getEvents();
});

// State للإنشاء
class CreateEventState {
  final bool isLoading;
  final String? error;
  final bool success;

  CreateEventState({
    this.isLoading = false,
    this.error,
    this.success = false,
  });

  CreateEventState copyWith({
    bool? isLoading,
    String? error,
    bool? success,
    bool clearError = false,
  }) {
    return CreateEventState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      success: success ?? this.success,
    );
  }
}

class CreateEventNotifier extends StateNotifier<CreateEventState> {
  final ApiService _api;
  final Ref _ref;

  CreateEventNotifier(this._api, this._ref) : super(CreateEventState());

  Future<void> createEvent({
    required String title,
    required String description,
    required String date,
    required String time,
    int? locationRoomId,
    required String targetCategory,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _api.createEvent(
        title: title,
        description: description,
        date: date,
        time: time,
        locationRoomId: locationRoomId,
        targetCategory: targetCategory,
      );
      // Refresh the events list
      _ref.invalidate(eventsProvider);
      state = state.copyWith(isLoading: false, success: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void reset() {
    state = CreateEventState();
  }
}

final createEventProvider =
    StateNotifierProvider<CreateEventNotifier, CreateEventState>((ref) {
  return CreateEventNotifier(ApiService(), ref);
});