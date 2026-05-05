// Represents an event/announcement
class Event {
  final int id;
  final String title;
  final String? description;
  final String date; // "2026-04-25"
  final String time; // "14:00"
  final int? locationRoomId;
  final String? posterUrl;
  final bool isActive;

  // Location info (flat fields from server)
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
    this.posterUrl,
    required this.isActive,
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
      posterUrl: json['poster_url'] as String?,
      // Server returns 1/0 instead of true/false
      isActive: (json['is_active'] as int? ?? 0) == 1,
      roomNumber: json['room_number'] as String?,
      floor: json['floor'] as int?,
      x: (json['x'] as num?)?.toDouble(),
      y: (json['y'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date,
      'time': time,
      'location_room_id': locationRoomId,
      'poster_url': posterUrl,
      'is_active': isActive ? 1 : 0,
      'room_number': roomNumber,
      'floor': floor,
      'x': x,
      'y': y,
    };
  }

  // Friendly location display
  String get locationDisplay {
    if (roomNumber == null) return 'Location TBA';
    if (floor != null) {
      return 'Room $roomNumber • Floor $floor';
    }
    return 'Room $roomNumber';
  }

  // Friendly date+time display
  String get dateTimeDisplay {
    return '$date • $time';
  }
}