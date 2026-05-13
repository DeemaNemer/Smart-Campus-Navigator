// Represents a professor/staff member
class Professor {
  final int id;
  final String nameEn;
  final String nameAr;
  final String? department;
  final String? email;
  final int? officeRoomId;
  final String? officeHours;
  final String? photoUrl;

  // Office location info (flat fields from server)
  final String? roomNumber;
  final int? floor;
  final double? x;
  final double? y;

  Professor({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    this.department,
    this.email,
    this.officeRoomId,
    this.officeHours,
    this.photoUrl,
    this.roomNumber,
    this.floor,
    this.x,
    this.y,
  });

  factory Professor.fromJson(Map<String, dynamic> json) {
    return Professor(
      id: json['id'] as int,
      nameEn: json['name_en'] as String? ?? '',
      nameAr: json['name_ar'] as String? ?? '',
      department: json['department'] as String?,
      email: json['email'] as String?,
      officeRoomId: json['office_room_id'] as int?,
      officeHours: json['office_hours'] as String?,
      photoUrl: json['photo_url'] as String?,
      roomNumber: json['room_number'] as String?,
      floor: json['floor'] as int?,
      x: (json['x'] as num?)?.toDouble(),
      y: (json['y'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name_en': nameEn,
      'name_ar': nameAr,
      'department': department,
      'email': email,
      'office_room_id': officeRoomId,
      'office_hours': officeHours,
      'photo_url': photoUrl,
      'room_number': roomNumber,
      'floor': floor,
      'x': x,
      'y': y,
    };
  }

  // Display name - prefer English; fallback to Arabic
  String get displayName {
    if (nameEn.isNotEmpty) return nameEn;
    return nameAr;
  }

  // Friendly office display: "Office 314 • Floor 2"
  String get officeDisplay {
    if (roomNumber == null) return 'Office not set';
    if (floor != null) {
      return 'Office $roomNumber • Floor $floor';
    }
    return 'Office $roomNumber';
  }
}
