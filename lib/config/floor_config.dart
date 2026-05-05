// Configuration for each floor's map
class FloorConfig {
  final int floor;
  final String name;
  final String imagePath;

  // Data bounds - the actual coordinate range in your data
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;

  // Padding RATIOS (0.0 to 1.0) - how much of the image is empty margin
  final double paddingLeftRatio;
  final double paddingTopRatio;
  final double paddingRightRatio;
  final double paddingBottomRatio;

  const FloorConfig({
    required this.floor,
    required this.name,
    required this.imagePath,
    this.minX = 0,
    required this.maxX,
    this.minY = 0,
    required this.maxY,
    this.paddingLeftRatio = 0.0,
    this.paddingTopRatio = 0.0,
    this.paddingRightRatio = 0.0,
    this.paddingBottomRatio = 0.0,
  });
}

class FloorConfigs {
  FloorConfigs._();

  // ✅ Verified bounds based on actual server data
  // Data ranges across all floors:
  //   Floor 0: X(7-33),  Y(3-27)  | 11 rooms
  //   Floor 1: X(7-9),   Y(11-27) | 6 rooms (only labs/classrooms)
  //   Floor 2: X(6-31),  Y(3-27)  | 14 rooms
  //   Floor 3: X(7-28),  Y(3-27)  | 11 rooms
  //   Floor 4: X(7-32),  Y(3-27)  | 14 rooms
  //
  // We use unified bounds (6-33, 3-27) since all floors share
  // the same physical building layout
  static const double _unifiedMinX = 6;
  static const double _unifiedMaxX = 33;
  static const double _unifiedMinY = 3;
  static const double _unifiedMaxY = 27;

  // 🎨 Padding ratios: based on the floor map image
  // Looking at your screenshot, the actual map content is mostly
  // in the upper-right portion. ADJUST after testing.
  static const double _paddingLeft = 0.10;
  static const double _paddingTop = 0.05;
  static const double _paddingRight = 0.10;
  static const double _paddingBottom = 0.30;

  static const List<FloorConfig> all = [
    FloorConfig(
      floor: 0,
      name: 'Ground Floor',
      imagePath: 'assets/maps/floor_0.png',
      minX: _unifiedMinX,
      maxX: _unifiedMaxX,
      minY: _unifiedMinY,
      maxY: _unifiedMaxY,
      paddingLeftRatio: _paddingLeft,
      paddingTopRatio: _paddingTop,
      paddingRightRatio: _paddingRight,
      paddingBottomRatio: _paddingBottom,
    ),
    FloorConfig(
      floor: 1,
      name: 'First Floor',
      imagePath: 'assets/maps/floor_1.png',
      minX: _unifiedMinX,
      maxX: _unifiedMaxX,
      minY: _unifiedMinY,
      maxY: _unifiedMaxY,
      paddingLeftRatio: _paddingLeft,
      paddingTopRatio: _paddingTop,
      paddingRightRatio: _paddingRight,
      paddingBottomRatio: _paddingBottom,
    ),
    FloorConfig(
      floor: 2,
      name: 'Second Floor',
      imagePath: 'assets/maps/floor_2.png',
      minX: _unifiedMinX,
      maxX: _unifiedMaxX,
      minY: _unifiedMinY,
      maxY: _unifiedMaxY,
      paddingLeftRatio: _paddingLeft,
      paddingTopRatio: _paddingTop,
      paddingRightRatio: _paddingRight,
      paddingBottomRatio: _paddingBottom,
    ),
    FloorConfig(
      floor: 3,
      name: 'Third Floor',
      imagePath: 'assets/maps/floor_3.png',
      minX: _unifiedMinX,
      maxX: _unifiedMaxX,
      minY: _unifiedMinY,
      maxY: _unifiedMaxY,
      paddingLeftRatio: _paddingLeft,
      paddingTopRatio: _paddingTop,
      paddingRightRatio: _paddingRight,
      paddingBottomRatio: _paddingBottom,
    ),
    FloorConfig(
      floor: 4,
      name: 'Fourth Floor',
      imagePath: 'assets/maps/floor_4.png',
      minX: _unifiedMinX,
      maxX: _unifiedMaxX,
      minY: _unifiedMinY,
      maxY: _unifiedMaxY,
      paddingLeftRatio: _paddingLeft,
      paddingTopRatio: _paddingTop,
      paddingRightRatio: _paddingRight,
      paddingBottomRatio: _paddingBottom,
    ),
  ];

  static FloorConfig forFloor(int floor) {
    return all.firstWhere(
      (f) => f.floor == floor,
      orElse: () => all.first,
    );
  }
}