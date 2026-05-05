class AppConstants {
  AppConstants._();

  // ⚠️ Replace with YOUR laptop's IP address
  // Get it by running 'ipconfig' in PowerShell
  static const String baseUrl = 'http://192.168.1.107:8000';

  // University
  static const String universityName = 'Birzeit University';
  static const String buildingName = 'IT Building';

  // Floors
  static const int totalFloors = 5;

  // Network timeouts (seconds)
  static const int connectTimeout = 10;
  static const int receiveTimeout = 15;
}