import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wifi_scan/wifi_scan.dart';
import '../models/room.dart';
import '../models/navigation_path.dart';
import '../services/api_service.dart';

// State for navigation
class NavigationState {
  final Room? userLocation; // المستخدم اختارها كـ "أنا هنا"
  final Room? destination; // الوجهة
  final NavigationPath? path; // المسار المحسوب
  final bool isCalculating;
  final bool isLocating;
  final String? error;

  NavigationState({
    this.userLocation,
    this.destination,
    this.path,
    this.isCalculating = false,
    this.isLocating = false,
    this.error,
  });

  NavigationState copyWith({
    Room? userLocation,
    Room? destination,
    NavigationPath? path,
    bool? isCalculating,
    bool? isLocating,
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
      isLocating: isLocating ?? this.isLocating,
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
    state = state.copyWith(
      destination: dest,
      clearPath: true,
      clearError: true,
    );
  }

  // Set user's current location
  void setUserLocation(Room location) {
    state = state.copyWith(
      userLocation: location,
      clearPath: true,
      clearError: true,
    );
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  // Calculate the path
  Future<void> calculatePath() async {
    if (!state.isReady) return;

    if (_samePlace(state.userLocation!, state.destination!)) {
      state = state.copyWith(
        error: 'Source and destination are the same place.',
        clearPath: true,
      );
      return;
    }

    state =
        state.copyWith(isCalculating: true, clearError: true, clearPath: true);

    try {
      final path = await _api.navigate(
        userX: state.userLocation!.x,
        userY: state.userLocation!.y,
        userFloor: state.userLocation!.floor,
        sourceRoomId:
            state.userLocation!.id > 0 ? state.userLocation!.id : null,
        sourceZone: _zoneForRoom(state.userLocation!),
        destRoomId: state.destination!.id > 0 ? state.destination!.id : null,
        destX: state.destination!.x,
        destY: state.destination!.y,
        destFloor: state.destination!.floor,
        destZone: _zoneForRoom(state.destination!),
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

  Future<void> locateFromWifi() async {
    state = state.copyWith(isLocating: true, clearError: true, clearPath: true);

    try {
      final canStart =
          await WiFiScan.instance.canStartScan(askPermissions: true);
      if (canStart != CanStartScan.yes) {
        throw 'Wi-Fi scan is not available: ${canStart.name}';
      }

      await WiFiScan.instance.startScan();
      await Future<void>.delayed(const Duration(seconds: 2));

      final canGet =
          await WiFiScan.instance.canGetScannedResults(askPermissions: true);
      if (canGet != CanGetScannedResults.yes) {
        throw 'Cannot read Wi-Fi scan results: ${canGet.name}';
      }

      final accessPoints = await WiFiScan.instance.getScannedResults();
      final readings = <String, double>{};
      for (final ap in accessPoints) {
        if (ap.bssid.isNotEmpty) {
          readings[ap.bssid.toLowerCase()] = ap.level.toDouble();
        }
      }
      if (readings.isEmpty) {
        throw 'No Wi-Fi access points found.';
      }

      final result = await _api.localizeBssid(bssidReadings: readings);
      if (result['success'] == false) {
        throw result['message'] as String? ??
            'Indoor localization is available only inside the campus building.';
      }

      final location = result['location'] as String? ?? 'Current location';
      final roomNumber =
          result['room_number'] as String? ?? _roomNumberFromZone(location);
      final room = Room(
        id: 0,
        name: location,
        roomNumber: roomNumber,
        x: (result['x'] as num).toDouble(),
        y: (result['y'] as num).toDouble(),
        floor: result['floor'] as int,
        type: 'localized',
      );

      state = state.copyWith(
        userLocation: room,
        isLocating: false,
        clearError: true,
        clearPath: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLocating: false,
        error: e.toString(),
        clearUserLocation: true,
      );
    }
  }

  String? _zoneForRoom(Room room) {
    final roomNumber = room.roomNumber?.trim();
    if (roomNumber == null || roomNumber.isEmpty) return null;
    switch (room.type) {
      case 'lab':
        return 'Lab$roomNumber';
      case 'office':
        return 'Office$roomNumber';
      case 'classroom':
        return 'Room$roomNumber';
      default:
        return 'Room$roomNumber';
    }
  }

  String? _roomNumberFromZone(String? zone) {
    if (zone == null) return null;
    return zone.replaceFirst(RegExp(r'^(Room|Lab|Office)'), '');
  }

  bool _samePlace(Room source, Room destination) {
    if (source.id > 0 && destination.id > 0 && source.id == destination.id) {
      return true;
    }

    final sourceRoom = source.roomNumber?.trim().toLowerCase();
    final destRoom = destination.roomNumber?.trim().toLowerCase();
    if (sourceRoom != null &&
        sourceRoom.isNotEmpty &&
        sourceRoom == destRoom &&
        source.floor == destination.floor) {
      return true;
    }

    return source.floor == destination.floor &&
        (source.x - destination.x).abs() < 0.01 &&
        (source.y - destination.y).abs() < 0.01;
  }
}

// The provider
final navigationProvider =
    StateNotifierProvider<NavigationNotifier, NavigationState>((ref) {
  return NavigationNotifier(ApiService());
});
