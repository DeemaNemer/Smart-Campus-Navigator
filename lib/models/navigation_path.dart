// Represents a single point on the navigation path
class PathPoint {
  final double x;
  final double y;
  final int floor;
  final String? type;
  final String? label;

  PathPoint({
    required this.x,
    required this.y,
    required this.floor,
    this.type,
    this.label,
  });

  factory PathPoint.fromJson(Map<String, dynamic> json) {
    return PathPoint(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      floor: (json['floor'] as num).toInt(),
      type: json['type'] as String?,
      label: json['location'] as String? ?? json['label'] as String?,
    );
  }
}

class NavigationStep {
  final String type;
  final String text;

  NavigationStep({required this.type, required this.text});

  factory NavigationStep.fromJson(Map<String, dynamic> json) {
    return NavigationStep(
      type: json['type'] as String? ?? 'walk',
      text: json['text'] as String? ?? '',
    );
  }
}

class NavigationPath {
  final bool success;
  final List<PathPoint> path;
  final double distance;
  final int steps;
  final List<NavigationStep> instructions;
  final String? error;

  NavigationPath({
    required this.success,
    required this.path,
    required this.distance,
    required this.steps,
    required this.instructions,
    this.error,
  });

  factory NavigationPath.fromJson(Map<String, dynamic> json) {
    final pathList = json['path'] as List? ?? [];
    final instructionsList = json['instructions'] as List? ?? [];

    return NavigationPath(
      success: json['success'] as bool? ?? false,
      path: pathList
          .map((p) => PathPoint.fromJson(p as Map<String, dynamic>))
          .toList(),
      distance: (json['distance'] as num?)?.toDouble() ?? 0,
      steps: (json['steps'] as num?)?.toInt() ?? 0,
      instructions: instructionsList
          .map((i) => NavigationStep.fromJson(i as Map<String, dynamic>))
          .toList(),
      error: json['error'] as String?,
    );
  }

  PathPoint? get startPoint => path.isNotEmpty ? path.first : null;
  PathPoint? get endPoint => path.isNotEmpty ? path.last : null;

  Map<int, List<PathPoint>> get pathByFloor {
    final result = <int, List<PathPoint>>{};
    for (final point in path) {
      result.putIfAbsent(point.floor, () => []).add(point);
    }
    return result;
  }
}