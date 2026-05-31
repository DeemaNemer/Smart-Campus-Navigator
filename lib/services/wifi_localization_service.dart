// services/wifi_localization_service.dart
//
// Wi-Fi scanning + BSSID localization service
// منفصل عن api_service.dart عشان ما يكسر الكود الموجود
//
// Usage:
//   final svc = WifiLocalizationService();
//   await svc.requestPermissions();
//   final result = await svc.scanAndLocalize();
//   print('You are at: ${result.location}');

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/app_constants.dart';

// ─── Result Model ───
class LocalizationResult {
  final bool success;
  final String location; // Room108, Lab305, etc. (V4 zone name)
  final double x;
  final double y;
  final int floor;
  final double confidence;
  final String? rawZone; // قبل SmartDecider
  final bool smoothed; // هل SmartDecider صحح النتيجة؟
  final double stability; // 0-1
  final List<String> group; // مجموعة الـ confusion (لو موجودة)
  final int matchedWaps;
  final int totalBssids;

  LocalizationResult({
    required this.success,
    required this.location,
    required this.x,
    required this.y,
    required this.floor,
    required this.confidence,
    this.rawZone,
    this.smoothed = false,
    this.stability = 1.0,
    this.group = const [],
    this.matchedWaps = 0,
    this.totalBssids = 0,
  });

  factory LocalizationResult.fromJson(Map<String, dynamic> j) {
    return LocalizationResult(
      success: j['success'] as bool? ?? false,
      location: j['location'] as String? ?? '',
      x: ((j['x'] as num?) ?? 0).toDouble(),
      y: ((j['y'] as num?) ?? 0).toDouble(),
      floor: (j['floor'] as num?)?.toInt() ?? 0,
      confidence: ((j['gnn_confidence'] as num?) ?? 0).toDouble(),
      rawZone: j['raw_zone'] as String?,
      smoothed: j['smoothed'] as bool? ?? false,
      stability: ((j['stability'] as num?) ?? 1.0).toDouble(),
      group: (j['group'] as List? ?? []).map((e) => e.toString()).toList(),
      matchedWaps: (j['matched_waps'] as num?)?.toInt() ?? 0,
      totalBssids: (j['total_bssids'] as num?)?.toInt() ?? 0,
    );
  }
}

// ─── Service ───
class WifiLocalizationService {
  static final WifiLocalizationService _instance =
      WifiLocalizationService._internal();
  factory WifiLocalizationService() => _instance;

  late final Dio _dio;
  bool _permissionGranted = false;
  String _sessionId = DateTime.now().millisecondsSinceEpoch.toString();

  WifiLocalizationService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: AppConstants.connectTimeout),
      receiveTimeout: const Duration(seconds: AppConstants.receiveTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
  }

  /// يبدأ session جديد (يمسح SmartDecider history في الـ backend)
  void newSession() {
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _resetBackendSession();
  }

  Future<void> _resetBackendSession() async {
    try {
      await _dio.post(
        '/reset_session',
        queryParameters: {'session_id': _sessionId},
      );
    } catch (_) {
      // Fire-and-forget: navigation can continue even if backend reset fails.
    }
  }

  String get sessionId => _sessionId;

  // ═══════════════════════════════════════════════════
  // Permissions
  // ═══════════════════════════════════════════════════
  Future<bool> requestPermissions() async {
    if (_permissionGranted) return true;

    // Location مطلوبة للـ WiFi scan في Android
    final locationStatus = await Permission.locationWhenInUse.request();
    if (!locationStatus.isGranted) {
      debugPrint('[WiFi] Location permission denied');
      return false;
    }

    // تأكيد إمكانية الـ scan
    final canScan = await WiFiScan.instance.canStartScan();
    if (canScan != CanStartScan.yes) {
      debugPrint('[WiFi] canStartScan: $canScan');
      // مرات Android بيحدد throttling — نكمل ونأخذ آخر نتائج
    }

    _permissionGranted = true;
    return true;
  }

  Future<String> diagnose() async {
    final loc = await Permission.locationWhenInUse.status;
    final canScan = await WiFiScan.instance.canStartScan();
    final canGet = await WiFiScan.instance.canGetScannedResults();
    return 'Location: $loc | CanScan: $canScan | CanGet: $canGet';
  }

  // ═══════════════════════════════════════════════════
  // WiFi Scan
  // ═══════════════════════════════════════════════════
  /// يبدأ scan جديد ويرجع dict من BSSID → RSSI
  Future<Map<String, double>> scan() async {
    if (!_permissionGranted) {
      final ok = await requestPermissions();
      if (!ok) throw Exception('WiFi permission denied');
    }

    try {
      await WiFiScan.instance.startScan();
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('[WiFi] startScan exception (ignored): $e');
    }

    final canGet = await WiFiScan.instance.canGetScannedResults();
    if (canGet != CanGetScannedResults.yes) {
      throw Exception('Cannot get scan results: $canGet');
    }

    final results = await WiFiScan.instance.getScannedResults();
    final map = <String, double>{};
    for (final r in results) {
      final bssid = r.bssid.toLowerCase().trim();
      // نأخذ أعلى RSSI لو نفس الـ BSSID مكرر
      if (!map.containsKey(bssid) || r.level > map[bssid]!) {
        map[bssid] = r.level.toDouble();
      }
    }
    return map;
  }

  // ═══════════════════════════════════════════════════
  // Send BSSID readings to server → localize
  // ═══════════════════════════════════════════════════
  Future<LocalizationResult> localizeBssid(
      Map<String, double> bssidReadings) async {
    if (bssidReadings.isEmpty) {
      throw Exception('No WiFi readings to send');
    }

    try {
      final response = await _dio.post(
        '/localize_bssid',
        data: {
          'bssid_readings': bssidReadings,
          'session_id': _sessionId,
        },
      );
      return LocalizationResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response!.data;
        if (data is Map && data.containsKey('detail')) {
          throw 'Localization error: ${data['detail']}';
        }
      }
      throw 'Network error: ${e.message}';
    }
  }

  // ═══════════════════════════════════════════════════
  // Scan + Localize (الـ shortcut الرئيسي)
  // ═══════════════════════════════════════════════════
  Future<LocalizationResult> scanAndLocalize() async {
    final readings = await scan();
    if (readings.isEmpty) {
      throw Exception('No WiFi networks found nearby');
    }
    return await localizeBssid(readings);
  }
}
