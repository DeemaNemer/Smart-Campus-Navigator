import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../config/app_constants.dart';
import '../models/app_user.dart';
import 'package:google_sign_in/google_sign_in.dart';
class AuthResult {
  final String accessToken;
  final AppUser user;

  AuthResult({required this.accessToken, required this.user});
}

class AuthService {
  late final Dio _dio;
// Google Sign-In instance
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: AppConstants.googleWebClientId,
    scopes: ['email', 'profile'],
  );
  // Singleton
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  AuthService._internal() {
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
        logPrint: (obj) => print('[AUTH] $obj'),
      ),
    );
  }

  // ============================================
  // 1. Register
  // ============================================
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
    String? studentId,
    required String userType,
  }) async {
    try {
      final response = await _dio.post(
        '/register',
        data: {
          'username': username,
          'email': email,
          'password': password,
          'full_name': fullName,
          'student_id': studentId,
          'user_type': userType,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // ============================================
  // 2. Verify Email
  // ============================================
  Future<AuthResult> verifyEmail({
    required String email,
    required String code,
  }) async {
    try {
      final response = await _dio.post(
        '/verify-email',
        data: {
          'email': email,
          'code': code,
        },
      );

      final data = response.data as Map<String, dynamic>;
      return AuthResult(
        accessToken: data['access_token'] as String,
        user: AppUser.fromJson(data['user'] as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // ============================================
  // 3. Resend Verification Code
  // ============================================
  Future<Map<String, dynamic>> resendVerification(String email) async {
    try {
      final response = await _dio.post(
        '/resend-verification',
        data: {'email': email},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // ============================================
  // 4. Login
  // ============================================
  Future<AuthResult> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/login',
        data: {
          'username_or_email': usernameOrEmail,
          'password': password,
        },
      );

      final data = response.data as Map<String, dynamic>;
      return AuthResult(
        accessToken: data['access_token'] as String,
        user: AppUser.fromJson(data['user'] as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // ============================================
  // 5. Forgot Password
  // ============================================
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await _dio.post(
        '/forgot-password',
        data: {'email': email},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // ============================================
  // 6. Reset Password
  // ============================================
  Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      final response = await _dio.post(
        '/reset-password',
        data: {
          'token': token,
          'new_password': newPassword,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // ============================================
  // 7. Get Current User (with token)
  // ============================================
  Future<AppUser> getCurrentUser(String token) async {
    try {
      final response = await _dio.get(
        '/me',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return AppUser.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleAuthError(e);
    }
  }
  // ============================================
  // Google Sign-In
  // ============================================
  Future<AuthResult?> signInWithGoogle({String userType = 'guest'}) async {
    try {
      // Step 1: Show Google sign-in dialog
      final GoogleSignInAccount? account = await _googleSignIn.signIn();

      if (account == null) {
        // User cancelled
        return null;
      }

      // Step 2: Get authentication tokens
      final GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;

      if (idToken == null) {
        throw 'Failed to get Google ID token. Check your Web Client ID.';
      }

      // Step 3: Send token to our backend
      final response = await _dio.post(
        '/google-login',
        data: {
          'id_token': idToken,
          'user_type': userType,
        },
      );

      final data = response.data as Map<String, dynamic>;
      return AuthResult(
        accessToken: data['access_token'] as String,
        user: AppUser.fromJson(data['user'] as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      // Sign out from Google on any error
      await _googleSignIn.signOut();
      rethrow;
    }
  }

  Future<void> signOutGoogle() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignore errors
    }
  }

  // ============================================
  // Local storage helpers
  // ============================================
  Future<void> saveSession(String token, AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
    await prefs.setString(AppConstants.userKey, jsonEncode(user.toJson()));
  }

  Future<String?> getStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.tokenKey);
  }

  Future<AppUser?> getStoredUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(AppConstants.userKey);
    if (userJson == null) return null;
    try {
      return AppUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.userKey);
    // Also sign out from Google
    await signOutGoogle();
  }

  // ============================================
  // Error handling
  // ============================================
  String _handleAuthError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timeout. Check your network.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Cannot connect to server. Make sure server is running.';
    }
    if (e.response != null) {
      final data = e.response!.data;
      if (data is Map && data.containsKey('detail')) {
        return data['detail'].toString();
      }
      return 'Error: ${e.response!.statusCode}';
    }
    return 'Network error: ${e.message}';
  }
}