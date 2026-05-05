// Represents a room/office/lab in the building
class Room {
  final int id;
  final String name;
  final String? roomNumber;
  final double x;
  final double y;
  final int floor;
  final String type; // 'office', 'lab', 'classroom', 'bathroom'
  final String? description;

  Room({
    required this.id,
    required this.name,
    this.roomNumber,
    required this.x,
    required this.y,
    required this.floor,
    required this.type,
    this.description,
  });

  // Convert JSON from server to Room object
  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as int,
      name: json['name'] as String,
      roomNumber: json['room_number'] as String?,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      floor: json['floor'] as int,
      type: json['type'] as String,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'room_number': roomNumber,
      'x': x,
      'y': y,
      'floor': floor,
      'type': type,
      'description': description,
    };
  }

  // Friendly type label for UI
  String get typeLabel {
    switch (type) {
      case 'office':
        return 'Office';
      case 'lab':
        return 'Lab';
      case 'classroom':
        return 'Classroom';
      case 'bathroom':
        return 'Bathroom';
      default:
        // Capitalize first letter as fallback
        if (type.isEmpty) return type;
        return type[0].toUpperCase() + type.substring(1);
    }
  }
}