import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/room.dart';
import '../models/navigation_path.dart';
import '../services/api_service.dart';

// State for navigation
class NavigationState {
  final Room? userLocation; // المستخدم اختارها كـ "أنا هنا"
  final Room? destination; // الوجهة
  final NavigationPath? path; // المسار المحسوب
  final bool isCalculating;
  final String? error;

  NavigationState({
    this.userLocation,
    this.destination,
    this.path,
    this.isCalculating = false,
    this.error,
  });

  NavigationState copyWith({
    Room? userLocation,
    Room? destination,
    NavigationPath? path,
    bool? isCalculating,
    String? error,
    bool clearError = false,
    bool clearPath = false,
    bool clearUserLocation = false,
  }) {
    return NavigationState(
      userLocation:
          clearUserLocation ? null : (userLocation ?? this.userLocation),
      destination: destination ?? this.destination,
      path: clearPath ? null : (path ?? this.path),
      isCalculating: isCalculating ?? this.isCalculating,
      error: clearError ? null : (error ?? this.error),
    );
  }

  bool get isReady => userLocation != null && destination != null;
}

// Notifier
class NavigationNotifier extends StateNotifier<NavigationState> {
  final ApiService _api;

  NavigationNotifier(this._api) : super(NavigationState());

  // Set the destination (called when user clicks Get Directions)
  void setDestination(Room dest) {
    state = NavigationState(destination: dest);
  }

  // Set user's current location
  void setUserLocation(Room location) {
    state = state.copyWith(
      userLocation: location,
      clearPath: true,
      clearError: true,
    );
  }

  // Calculate the path
  Future<void> calculatePath() async {
    if (!state.isReady) return;

    state =
        state.copyWith(isCalculating: true, clearError: true, clearPath: true);

    try {
      final path = await _api.navigate(
        userX: state.userLocation!.x,
        userY: state.userLocation!.y,
        userFloor: state.userLocation!.floor,
        destRoomId: state.destination!.id,
        destX: state.destination!.x,
        destY: state.destination!.y,
        destFloor: state.destination!.floor,
      );

      state = state.copyWith(
        path: path,
        isCalculating: false,
        error: path.success ? null : (path.error ?? 'Failed to calculate path'),
      );
    } catch (e) {
      state = state.copyWith(
        isCalculating: false,
        error: e.toString(),
      );
    }
  }

  // Clear and start over
  void reset() {
    state = NavigationState();
  }
}

// The provider
final navigationProvider =
    StateNotifierProvider<NavigationNotifier, NavigationState>((ref) {
  return NavigationNotifier(ApiService());
});
