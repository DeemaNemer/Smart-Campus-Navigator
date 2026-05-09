import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';

// Authentication state
enum AuthStatus {
  initial,        // App just opened, checking storage
  unauthenticated, // No user logged in
  authenticated,   // User logged in
}

class AuthState {
  final AuthStatus status;
  final AppUser? user;
  final String? token;
  final String? error;
  final bool isLoading;

  AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.token,
    this.error,
    this.isLoading = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    String? token,
    String? error,
    bool? isLoading,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      token: token ?? this.token,
      error: clearError ? null : (error ?? this.error),
      isLoading: isLoading ?? this.isLoading,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(AuthState()) {
    // Check for existing session on app start
    _checkExistingSession();
  }

  // Check if there's a saved token and try to restore the session
  Future<void> _checkExistingSession() async {
    try {
      final token = await _authService.getStoredToken();
      if (token == null) {
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return;
      }

      // Validate token with server
      final user = await _authService.getCurrentUser(token);
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
        token: token,
      );
    } catch (e) {
      // Token invalid or expired
      await _authService.clearSession();
      state = AuthState(status: AuthStatus.unauthenticated);
    }
  }

  // Login
  Future<bool> login(String usernameOrEmail, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final result = await _authService.login(
        usernameOrEmail: usernameOrEmail,
        password: password,
      );

      // Save to local storage
      await _authService.saveSession(result.accessToken, result.user);

      state = AuthState(
        status: AuthStatus.authenticated,
        user: result.user,
        token: result.accessToken,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  // Register
  Future<Map<String, dynamic>?> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
    String? studentId,
    required String userType,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final result = await _authService.register(
        username: username,
        email: email,
        password: password,
        fullName: fullName,
        studentId: studentId,
        userType: userType,
      );
      state = state.copyWith(isLoading: false);
      return result;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return null;
    }
  }

  // Verify Email (after register)
  Future<bool> verifyEmail(String email, String code) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final result = await _authService.verifyEmail(
        email: email,
        code: code,
      );

      await _authService.saveSession(result.accessToken, result.user);

      state = AuthState(
        status: AuthStatus.authenticated,
        user: result.user,
        token: result.accessToken,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  // Resend verification code
  Future<Map<String, dynamic>?> resendVerification(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _authService.resendVerification(email);
      state = state.copyWith(isLoading: false);
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  // Forgot Password
  Future<Map<String, dynamic>?> forgotPassword(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _authService.forgotPassword(email);
      state = state.copyWith(isLoading: false);
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  // Reset Password
  Future<bool> resetPassword(String token, String newPassword) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _authService.resetPassword(
        token: token,
        newPassword: newPassword,
      );
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    await _authService.clearSession();
    state = AuthState(status: AuthStatus.unauthenticated);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(AuthService());
});