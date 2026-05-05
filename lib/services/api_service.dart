import 'package:dio/dio.dart';
import '../config/app_constants.dart';
import '../models/room.dart';
import '../models/professor.dart';
import '../models/search_result.dart';
import '../models/event.dart';
import '../models/navigation_path.dart';

class ApiService {
  late final Dio _dio;

  // Singleton
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: Duration(seconds: AppConstants.connectTimeout),
        receiveTimeout: Duration(seconds: AppConstants.receiveTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => print('[API] $obj'),
      ),
    );
  }

  // ============================================
  // Health Check
  // ============================================
  Future<bool> ping() async {
    try {
      final response = await _dio.get('/');
      return response.statusCode == 200;
    } catch (e) {
      print('[API] Ping failed: $e');
      return false;
    }
  }

  // ============================================
  // Search rooms and professors
  // Server returns: { "query": "...", "count": N, "results": [...] }
  // Each item has "type": "lab" | "classroom" | "office" | "bathroom" | "professor"
  // ============================================
  Future<List<SearchResult>> search(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final response = await _dio.get(
        '/search',
        queryParameters: {'q': query.trim()},
      );

      final data = response.data as Map<String, dynamic>;
      final results = <SearchResult>[];
      final List<dynamic> items = data['results'] ?? [];

      for (final item in items) {
        final json = item as Map<String, dynamic>;
        final type = json['type'] as String?;

        if (type == 'professor') {
          results.add(SearchResult.professor(Professor.fromJson(json)));
        } else {
          // lab, classroom, office, bathroom → all rooms
          results.add(SearchResult.room(Room.fromJson(json)));
        }
      }

      return results;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ============================================
  // Get all rooms (optionally by floor)
  // Server may return either a list directly, or { "count": N, "rooms": [...] }
  // ============================================
  Future<List<Room>> getRooms({int? floor}) async {
    try {
      final response = await _dio.get(
        '/rooms',
        queryParameters: floor != null ? {'floor': floor} : null,
      );

      final data = response.data;
      final List<dynamic> items = _extractList(data, 'rooms');

      return items
          .map((json) => Room.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ============================================
  // Get a single room by ID
  // ============================================
  Future<Room> getRoomById(int id) async {
    try {
      final response = await _dio.get('/rooms/$id');
      return Room.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ============================================
  // Get all professors
  // Server returns: { "count": 35, "professors": [...] }
  // ============================================
  Future<List<Professor>> getProfessors() async {
    try {
      final response = await _dio.get('/professors');
      final data = response.data;
      final List<dynamic> items = _extractList(data, 'professors');

      return items
          .map((json) => Professor.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ============================================
  // Get all events
  // Server returns: { "count": 3, "events": [...] }
  // ============================================
 // ============================================
  // Get all events
  // Server returns: { "count": 3, "events": [...] }
  // ============================================
  Future<List<Event>> getEvents() async {
    try {
      final response = await _dio.get('/events');
      final data = response.data;
      final List<dynamic> items = _extractList(data, 'events');

      return items
          .map((json) => Event.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
// ============================================
  // Calculate navigation path
  // POST /navigate with body:
  // {
  //   "user_x": 5, "user_y": 10, "user_floor": 0,
  //   "dest_name": "Lab505"
  // }
  // ============================================
// ============================================
  // Calculate navigation path
  // Server expects:
  // {
  //   "user_x": 5, "user_y": 10, "user_floor": 0,
  //   "dest_room_id": 46, "dest_x": 9, "dest_y": 18, "dest_floor": 4
  // }
  // ============================================
  Future<NavigationPath> navigate({
    required double userX,
    required double userY,
    required int userFloor,
    required int destRoomId,
    required double destX,
    required double destY,
    required int destFloor,
  }) async {
    try {
      final response = await _dio.post(
        '/navigate',
        data: {
          'user_x': userX,
          'user_y': userY,
          'user_floor': userFloor,
          'dest_room_id': destRoomId,
          'dest_x': destX,
          'dest_y': destY,
          'dest_floor': destFloor,
        },
      );

      return NavigationPath.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      // For 400/404 errors, show the actual error message from the server
      if (e.response != null) {
        final errorData = e.response!.data;
        if (errorData is Map && errorData.containsKey('detail')) {
          throw 'Navigation error: ${errorData['detail']}';
        }
      }
      throw _handleError(e);
    }
  }
  // ============================================
  // Helper: extract list from response
  // Handles both: a raw list, or { "key": [...] } wrapper
  // ============================================
  List<dynamic> _extractList(dynamic data, String key) {
    if (data is List) return data;
    if (data is Map<String, dynamic>) {
      final value = data[key];
      if (value is List) return value;
    }
    return [];
  }

  // ============================================
  // Error handling
  // ============================================
  String _handleError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timeout. Check your network.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Cannot connect to server. Make sure server is running.';
    }
    if (e.response != null) {
      return 'Server error: ${e.response!.statusCode}';
    }
    return 'Network error: ${e.message}';
  }
}
