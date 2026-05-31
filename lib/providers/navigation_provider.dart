import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/room.dart';
import '../models/navigation_path.dart';
import '../services/api_service.dart';
import '../services/wifi_localization_service.dart';

// ═══════════════════════════════════════════════════
// State
// ═══════════════════════════════════════════════════
enum NavigationMode {
  manual,  // المستخدم يختار "أنا هنا" يدوياً (للاختبار في البيت)
  live,    // WiFi scan تلقائي (في الجامعة)
}

class NavigationState {
  // Mode
  final NavigationMode mode;

  // الموقع الحالي للمستخدم (في Manual: من اختيار يدوي، في Live: من WiFi)
  final Room? userLocation;
  final double? liveX;          // في Live mode: x من الـ WiFi
  final double? liveY;
  final int? liveFloor;
  final String? liveZone;       // في Live mode: zone name من الـ V4
  final double? liveConfidence;
  final bool liveSmoothed;      // هل SmartDecider صحح؟

  // الوجهة
  final Room? destination;

  // المسار
  final NavigationPath? path;

  // الحالة
  final bool isCalculating;
  final bool isScanning;        // في Live mode: scan جاري
  final String? error;
  final int scanCount;          // عدد الـ scans (للـ debugging)
  final String? scanStatus;     // رسالة الحالة (مثل "Scanning..." أو "✓ Room108")

  NavigationState({
    this.mode = NavigationMode.manual,
    this.userLocation,
    this.liveX,
    this.liveY,
    this.liveFloor,
    this.liveZone,
    this.liveConfidence,
    this.liveSmoothed = false,
    this.destination,
    this.path,
    this.isCalculating = false,
    this.isScanning = false,
    this.error,
    this.scanCount = 0,
    this.scanStatus,
  });

  NavigationState copyWith({
    NavigationMode? mode,
    Room? userLocation,
    double? liveX,
    double? liveY,
    int? liveFloor,
    String? liveZone,
    double? liveConfidence,
    bool? liveSmoothed,
    Room? destination,
    NavigationPath? path,
    bool? isCalculating,
    bool? isScanning,
    String? error,
    int? scanCount,
    String? scanStatus,
    bool clearError = false,
    bool clearPath = false,
    bool clearUserLocation = false,
    bool clearLive = false,
  }) {
    return NavigationState(
      mode: mode ?? this.mode,
      userLocation:
          clearUserLocation ? null : (userLocation ?? this.userLocation),
      liveX: clearLive ? null : (liveX ?? this.liveX),
      liveY: clearLive ? null : (liveY ?? this.liveY),
      liveFloor: clearLive ? null : (liveFloor ?? this.liveFloor),
      liveZone: clearLive ? null : (liveZone ?? this.liveZone),
      liveConfidence:
          clearLive ? null : (liveConfidence ?? this.liveConfidence),
      liveSmoothed: liveSmoothed ?? this.liveSmoothed,
      destination: destination ?? this.destination,
      path: clearPath ? null : (path ?? this.path),
      isCalculating: isCalculating ?? this.isCalculating,
      isScanning: isScanning ?? this.isScanning,
      error: clearError ? null : (error ?? this.error),
      scanCount: scanCount ?? this.scanCount,
      scanStatus: scanStatus ?? this.scanStatus,
    );
  }

  /// هل عندنا موقع حالي صالح؟
  bool get hasLocation {
    if (mode == NavigationMode.manual) {
      return userLocation != null;
    } else {
      return liveX != null && liveY != null && liveFloor != null;
    }
  }

  bool get isReady => hasLocation && destination != null;

  /// الإحداثيات الحالية (للرسم على الـ map)
  double? get currentX =>
      mode == NavigationMode.manual ? userLocation?.x : liveX;
  double? get currentY =>
      mode == NavigationMode.manual ? userLocation?.y : liveY;
  int? get currentFloor =>
      mode == NavigationMode.manual ? userLocation?.floor : liveFloor;
}

// ═══════════════════════════════════════════════════
// Notifier
// ═══════════════════════════════════════════════════
class NavigationNotifier extends StateNotifier<NavigationState> {
  final ApiService _api;
  final WifiLocalizationService _wifi;
  Timer? _liveTimer;

  // ⏱️ كل كم ثانية نعمل scan جديد
  static const Duration _scanInterval = Duration(seconds: 3);

  // 🔄 لو الـ user تحرّك أكثر من هاد، نعيد حساب المسار
  static const double _rerouteDistanceM = 8.0;

  NavigationNotifier(this._api, this._wifi) : super(NavigationState());

  // ═══════════════════════════════════════════════════
  // Mode switching
  // ═══════════════════════════════════════════════════
  void setMode(NavigationMode mode) {
    if (state.mode == mode) return;
    _stopLiveLoop();
    state = state.copyWith(
      mode: mode,
      clearError: true,
      clearPath: true,
      clearUserLocation: true,
      clearLive: true,
      scanStatus: null,
      scanCount: 0,
    );
  }

  // ═══════════════════════════════════════════════════
  // Destination (نفس القديم — الـ Flutter يكمل يستخدم Room)
  // ═══════════════════════════════════════════════════
  void setDestination(Room dest) {
    state = state.copyWith(
      destination: dest,
      clearError: true,
      clearPath: true,
    );
  }

  // ═══════════════════════════════════════════════════
  // Manual mode (نفس القديم)
  // ═══════════════════════════════════════════════════
  void setUserLocation(Room location) {
    state = state.copyWith(
      mode: NavigationMode.manual,
      userLocation: location,
      clearPath: true,
      clearError: true,
      clearLive: true,
    );
    _stopLiveLoop();
  }

  // ═══════════════════════════════════════════════════
  // Live mode — WiFi scanning loop
  // ═══════════════════════════════════════════════════
  Future<bool> startLiveMode() async {
    // 1) طلب صلاحيات
    state = state.copyWith(
      mode: NavigationMode.live,
      isScanning: true,
      scanStatus: 'Requesting permissions...',
      clearError: true,
      clearLive: true,
    );

    final hasPerms = await _wifi.requestPermissions();
    if (!hasPerms) {
      state = state.copyWith(
        isScanning: false,
        error: 'Location permission denied. Cannot scan WiFi.',
        scanStatus: null,
      );
      return false;
    }

    // 2) Reset session في الـ backend (نبدأ SmartDecider من جديد)
    _wifi.newSession();

    // 3) أول scan
    state = state.copyWith(scanStatus: 'First WiFi scan...');
    final firstOk = await _doSingleScan(isFirst: true);
    if (!firstOk) {
      state = state.copyWith(isScanning: false);
      return false;
    }

    // 4) ابدأ loop دوري
    _liveTimer?.cancel();
    _liveTimer = Timer.periodic(_scanInterval, (_) async {
      if (state.mode != NavigationMode.live) {
        _stopLiveLoop();
        return;
      }
      await _doSingleScan(isFirst: false);
    });

    state = state.copyWith(isScanning: false);
    return true;
  }

  Future<bool> _doSingleScan({required bool isFirst}) async {
    try {
      state = state.copyWith(
        scanStatus: 'Scanning... (#${state.scanCount + 1})',
      );
      final result = await _wifi.scanAndLocalize();

      state = state.copyWith(
        liveX: result.x,
        liveY: result.y,
        liveFloor: result.floor,
        liveZone: result.location,
        liveConfidence: result.confidence,
        liveSmoothed: result.smoothed,
        scanCount: state.scanCount + 1,
        scanStatus:
            '✓ ${result.location} (${(result.confidence * 100).toInt()}%)',
        clearError: true,
      );

      // إذا في destination، احسب/أعد حساب المسار
      if (state.destination != null) {
        if (isFirst) {
          await calculatePath();
        } else if (_shouldReroute(result.x, result.y, result.floor)) {
          await calculatePath();
        }
      }
      return true;
    } catch (e) {
      debugPrint('[Live] Scan failed: $e');
      state = state.copyWith(
        scanStatus: '⚠️ Scan failed: ${e.toString().split("\n").first}',
        error: isFirst ? e.toString() : null,
      );
      return false;
    }
  }

  bool _shouldReroute(double newX, double newY, int newFloor) {
    if (state.path == null) return false;
    // لو الطابق تغير → reroute
    if (state.liveFloor != null && state.liveFloor != newFloor) return true;
    // لو الـ user بعد عن أقرب نقطة على المسار > 8m → reroute
    double minDist = double.infinity;
    for (final p in state.path!.path) {
      if (p.floor != newFloor) continue;
      final dx = p.x - newX;
      final dy = p.y - newY;
      final d = dx * dx + dy * dy;
      if (d < minDist) minDist = d;
    }
    return minDist > (_rerouteDistanceM * _rerouteDistanceM);
  }

  void _stopLiveLoop() {
    _liveTimer?.cancel();
    _liveTimer = null;
  }

  // ═══════════════════════════════════════════════════
  // Calculate path (يشتغل لكلا الـ modes)
  // ═══════════════════════════════════════════════════
  Future<void> calculatePath() async {
    if (!state.isReady) return;

    final ux = state.currentX!;
    final uy = state.currentY!;
    final uf = state.currentFloor!;

    // Build zone hints so backend can use pixel-accurate navigation
    String? sourceZone;
    if (state.mode == NavigationMode.manual && state.userLocation != null) {
      final rn = state.userLocation!.roomNumber;
      if (rn != null) sourceZone = 'Room$rn';
    } else if (state.mode == NavigationMode.live && state.liveZone != null) {
      sourceZone = state.liveZone;
    }
    final destRn = state.destination!.roomNumber;
    final destZone = destRn != null ? 'Room$destRn' : null;

    state = state.copyWith(
      isCalculating: true,
      clearError: true,
      clearPath: true,
    );

    try {
      final path = await _api.navigate(
        userX: ux,
        userY: uy,
        userFloor: uf,
        destRoomId: state.destination!.id,
        destX: state.destination!.x,
        destY: state.destination!.y,
        destFloor: state.destination!.floor,
        sourceZone: sourceZone,
        destZone: destZone,
      );

      state = state.copyWith(
        path: path,
        isCalculating: false,
        error: path.success
            ? null
            : (path.error ?? 'Failed to calculate path'),
      );
    } catch (e) {
      state = state.copyWith(
        isCalculating: false,
        error: e.toString(),
      );
    }
  }

  // ═══════════════════════════════════════════════════
  // Reset
  // ═══════════════════════════════════════════════════
  void reset() {
    _stopLiveLoop();
    state = NavigationState();
  }

  @override
  void dispose() {
    _stopLiveLoop();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════
// Provider
// ═══════════════════════════════════════════════════
final navigationProvider =
    StateNotifierProvider<NavigationNotifier, NavigationState>((ref) {
  return NavigationNotifier(ApiService(), WifiLocalizationService());
});