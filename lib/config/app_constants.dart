class AppConstants {
  AppConstants._();

  static const String baseUrl = 'http://192.168.1.10:8000';
  // University
  static const String universityName = 'Birzeit University';
  static const String buildingName = 'IT Building';

  // Floors
  static const int totalFloors = 5;

  // Network timeouts
  static const int connectTimeout = 10;
  static const int receiveTimeout = 15;

  // Storage keys (for SharedPreferences)
  static const String tokenKey = 'auth_token';
  static const String userKey = 'auth_user';
  static const String googleWebClientId =
      '744973934182-2qfptgei76dr16krec5vv9pmvm4mlgt3.apps.googleusercontent.com';
}
