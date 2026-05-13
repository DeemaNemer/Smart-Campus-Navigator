// Represents the logged-in user
class AppUser {
  final int id;
  final String username;
  final String email;
  final String? fullName;
  final String? studentId;
  final String userType; // 'student', 'employee', 'guest', 'admin'
  final bool isVerified;
  final String accountStatus; // 'pending', 'active', 'disabled'

  AppUser({
    required this.id,
    required this.username,
    required this.email,
    this.fullName,
    this.studentId,
    required this.userType,
    required this.isVerified,
    required this.accountStatus,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      username: json['username'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      studentId: json['student_id'] as String?,
      userType: json['user_type'] as String? ?? 'guest',
      isVerified: json['is_verified'] as bool? ?? false,
      accountStatus: json['account_status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'full_name': fullName,
      'student_id': studentId,
      'user_type': userType,
      'is_verified': isVerified,
      'account_status': accountStatus,
    };
  }

  // User type label for display
  String get userTypeLabel {
    switch (userType) {
      case 'student':
        return 'Student';
      case 'employee':
        return 'Employee';
      case 'admin':
        return 'Administrator';
      case 'guest':
      default:
        return 'Guest';
    }
  }

  // Check if user can create events (only registered users, not guests)
  bool get canCreateEvents =>
      userType == 'student' || userType == 'employee' || userType == 'admin';

  bool get isAdmin => userType == 'admin';
}
