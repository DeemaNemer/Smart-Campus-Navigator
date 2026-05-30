// Event status from server
enum EventStatus { pending, approved, rejected, unknown }

EventStatus parseEventStatus(String? value) {
  switch (value) {
    case 'pending':
      return EventStatus.pending;
    case 'approved':
      return EventStatus.approved;
    case 'rejected':
      return EventStatus.rejected;
    default:
      return EventStatus.unknown;
  }
}

// Target audience
enum EventAudience { students, employees, all }

EventAudience parseAudience(String? value) {
  switch (value) {
    case 'students':
      return EventAudience.students;
    case 'employees':
      return EventAudience.employees;
    default:
      return EventAudience.all;
  }
}

class Event {
  final int id;
  final String title;
  final String? description;
  final String date;
  final String time;
  final int? locationRoomId;
  final String? locationText;
  final String? posterUrl;
  final bool isActive;

  // New fields
  final EventStatus status;
  final EventAudience targetAudience;
  final int? createdByUserId;
  final String? adminNotes;
  final String? createdAt;
  final String? reviewedAt;

  // Creator info (when admin sees pending events)
  final String? creatorUsername;
  final String? creatorName;
  final String? creatorEmail;

  // Location info (flat from server)
  final String? roomNumber;
  final int? floor;
  final double? x;
  final double? y;

  Event({
    required this.id,
    required this.title,
    this.description,
    required this.date,
    required this.time,
    this.locationRoomId,
    this.locationText,
    this.posterUrl,
    required this.isActive,
    this.status = EventStatus.approved,
    this.targetAudience = EventAudience.all,
    this.createdByUserId,
    this.adminNotes,
    this.createdAt,
    this.reviewedAt,
    this.creatorUsername,
    this.creatorName,
    this.creatorEmail,
    this.roomNumber,
    this.floor,
    this.x,
    this.y,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      date: json['date'] as String? ?? '',
      time: json['time'] as String? ?? '',
      locationRoomId: json['location_room_id'] as int?,
      locationText: json['location_text'] as String?,
      posterUrl: json['poster_url'] as String?,
      isActive: (json['is_active'] as int? ?? 0) == 1,
      status: parseEventStatus(json['status'] as String?),
      targetAudience: parseAudience(json['target_audience'] as String?),
      createdByUserId: json['created_by_user_id'] as int?,
      adminNotes: json['admin_notes'] as String?,
      createdAt: json['created_at'] as String?,
      reviewedAt: json['reviewed_at'] as String?,
      creatorUsername: json['creator_username'] as String?,
      creatorName: json['creator_name'] as String?,
      creatorEmail: json['creator_email'] as String?,
      roomNumber: json['room_number'] as String?,
      floor: json['floor'] as int?,
      x: (json['x'] as num?)?.toDouble(),
      y: (json['y'] as num?)?.toDouble(),
    );
  }

  String get locationDisplay {
    if (locationText != null && locationText!.trim().isNotEmpty) {
      return locationText!;
    }
    if (roomNumber == null) return 'Location TBA';
    if (floor != null) return 'Room $roomNumber • Floor $floor';
    return 'Room $roomNumber';
  }

  String get dateTimeDisplay => '$date • $time';

  String get statusLabel {
    switch (status) {
      case EventStatus.pending:
        return 'Pending';
      case EventStatus.approved:
        return 'Approved';
      case EventStatus.rejected:
        return 'Rejected';
      case EventStatus.unknown:
        return 'Unknown';
    }
  }

  String get audienceLabel {
    switch (targetAudience) {
      case EventAudience.students:
        return 'Students';
      case EventAudience.employees:
        return 'Employees';
      case EventAudience.all:
        return 'Everyone';
    }
  }
}
