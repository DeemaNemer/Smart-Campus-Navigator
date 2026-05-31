// Configuration for each floor's map
//
// ⭐ Simple pixel-based system:
// Each room has a known pixel position in its floor plan image.
// To show a marker on Room109, we lookup its pixel directly — no math.

class FloorConfig {
  final int floor;
  final String name;
  final String imagePath;
  final double imageWidth;
  final double imageHeight;

  const FloorConfig({
    required this.floor,
    required this.name,
    required this.imagePath,
    required this.imageWidth,
    required this.imageHeight,
  });
}

class FloorConfigs {
  FloorConfigs._();

  static const List<FloorConfig> all = [
    FloorConfig(
      floor: 0,
      name: 'Ground Floor',
      imagePath: 'assets/maps/floor_0.png',
      imageWidth: 347,
      imageHeight: 720,
    ),
    FloorConfig(
      floor: 1,
      name: 'First Floor',
      imagePath: 'assets/maps/floor_1.png',
      imageWidth: 347,
      imageHeight: 718,
    ),
    FloorConfig(
      floor: 2,
      name: 'Second Floor',
      imagePath: 'assets/maps/floor_2.png',
      imageWidth: 339,
      imageHeight: 737,
    ),
    FloorConfig(
      floor: 3,
      name: 'Third Floor',
      imagePath: 'assets/maps/floor_3.png',
      imageWidth: 368,
      imageHeight: 677,
    ),
    FloorConfig(
      floor: 4,
      name: 'Fourth Floor',
      imagePath: 'assets/maps/floor_4.png',
      imageWidth: 349,
      imageHeight: 715,
    ),
  ];

  static FloorConfig forFloor(int floor) {
    return all.firstWhere(
      (f) => f.floor == floor,
      orElse: () => all.first,
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ⭐ Room pixel lookup table
// Maps room number → (pixel_x, pixel_y) in its floor plan image
// These are the EXACT pixel positions the user measured.
// ═══════════════════════════════════════════════════════════
class RoomPixels {
  RoomPixels._();

  // Floor 0 — image 347×720
  static const Map<String, (double, double)> floor0 = {
    '109': (227, 234),     // الباب الأول
    '109_d2': (227, 181),  // الباب الثاني
    '110': (249, 212),
    '108': (249, 276),
    '106': (249, 294),
    '107': (226, 338),
    '115': (146, 409),
    '117': (119, 409),
    '119': (94, 409),
    '121': (72, 409),
    '114': (133, 381),
    '116': (107, 379),
    '103': (67, 394),
    '118': (44, 394),
    // Landmarks
    'SecondaryStairs': (247, 155),
    'Bathroom': (224, 167),
    'MainStairs': (268, 372),
    'Elevator': (293, 401),
    'EmergencyStairs': (33, 394),
  };

  // Floor 1 — image 347×718
  static const Map<String, (double, double)> floor1 = {
    '207': (234, 269),
    '206': (256, 261),
    '204': (256, 328),
    '205': (234, 336),
    '202': (258, 345),
    '203': (235, 396),
    '215': (144, 466),
    '214': (143, 450),
    '216': (131, 449),
    '217': (118, 467),
    '219': (106, 466),
    '218': (92, 450),
    '220': (79, 450),
    '221': (64, 467),
    '222': (55, 451),
    // Landmarks
    'SecondaryStairs': (258, 199),
    'Bathroom': (235, 213),
    'MainStairs': (276, 428),
    'Elevator': (305, 463),
    'EmergencyStairs': (32, 449),
  };

  // Floor 2 — image 339×737
  static const Map<String, (double, double)> floor2 = {
    '307': (215, 232),
    '306': (235, 221),
    '305': (215, 286),
    '304': (235, 280),
    '302': (233, 300),
    '303': (215, 339),
    '314': (135, 386),
    '316': (125, 387),
    '318': (93, 387),
    '320': (81, 386),
    '322': (61, 385),
    '321': (72, 403),
    '319': (104, 403),
    '317': (113, 403),
    '315': (137, 403),
    // Landmarks
    'SecondaryStairs': (235, 169),
    'Bathroom': (217, 178),
    'MainStairs': (253, 367),
    'Elevator': (275, 403),
    'EmergencyStairs': (37, 386),
  };

  // Floor 3 — image 368×677
  static const Map<String, (double, double)> floor3 = {
    '406': (263, 206),
    '407': (241, 216),
    '405': (241, 274),
    '404': (263, 271),
    '402': (263, 288),
    '403': (241, 331),
    '414': (155, 385),
    '416': (144, 385),
    '418': (97, 385),
    '415': (155, 401),
    '417.1': (144, 401),
    '417.2': (103, 401),
    // Landmarks
    'SecondaryStairs': (263, 148),
    'Bathroom': (241, 162),
    'MainStairs': (283, 357),
    'Elevator': (310, 393),
    'EmergencyStairs': (51, 385),
  };

  // Floor 4 — image 349×715
  static const Map<String, (double, double)> floor4 = {
    '506': (254, 176),
    '507': (234, 185),
    '505': (233, 239),
    '504': (254, 237),
    '502': (254, 252),
    '503': (235, 291),
    '514': (153, 344),
    '516': (141, 344),
    '515': (154, 357),
    '517': (131, 357),
    '518': (108, 345),
    '520': (98, 345),
    '521': (97, 356),
    '522': (68, 344),
    // Landmarks
    'WomenPrayer': (254, 120),
    'Bathroom': (234, 131),
    'MainStairs': (275, 324),
    'Elevator': (297, 359),
    'MenPrayer': (299, 398),
    'EmergencyStairs': (53, 344),
  };

  /// Get pixel position for a room on a specific floor.
  /// Returns null if room not in the lookup table.
  static (double, double)? get(int floor, String roomNumber) {
    final clean = roomNumber.trim();
    switch (floor) {
      case 0:
        return floor0[clean];
      case 1:
        return floor1[clean];
      case 2:
        return floor2[clean];
      case 3:
        return floor3[clean];
      case 4:
        return floor4[clean];
      default:
        return null;
    }
  }
}