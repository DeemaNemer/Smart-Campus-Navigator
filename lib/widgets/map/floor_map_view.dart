import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/floor_config.dart';
import '../../models/navigation_path.dart';

class FloorMapView extends StatefulWidget {
  final FloorConfig floorConfig;

  // Navigation overlays (optional)
  final List<PathPoint>? pathPoints;
  final double? userX;
  final double? userY;
  final double? destX;
  final double? destY;
  final String? userRoomNumber;
  final String? destRoomNumber;

  const FloorMapView({
    super.key,
    required this.floorConfig,
    this.pathPoints,
    this.userX,
    this.userY,
    this.destX,
    this.destY,
    this.userRoomNumber,
    this.destRoomNumber,
  });

  @override
  State<FloorMapView> createState() => _FloorMapViewState();
}

class _FloorMapViewState extends State<FloorMapView> {
  final TransformationController _transformController =
      TransformationController();

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _transformController,
      minScale: 1.0,
      maxScale: 8.0,
      boundaryMargin: const EdgeInsets.all(120),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return _MapWithOverlay(
            floorConfig: widget.floorConfig,
            pathPoints: widget.pathPoints,
            userX: widget.userX,
            userY: widget.userY,
            destX: widget.destX,
            destY: widget.destY,
            userRoomNumber: widget.userRoomNumber,
            destRoomNumber: widget.destRoomNumber,
            availableSize: Size(constraints.maxWidth, constraints.maxHeight),
          );
        },
      ),
    );
  }
}

// =============================================
// The map image + overlays (path + markers)
// =============================================
class _MapWithOverlay extends StatelessWidget {
  final FloorConfig floorConfig;
  final List<PathPoint>? pathPoints;
  final double? userX;
  final double? userY;
  final double? destX;
  final double? destY;
  final String? userRoomNumber;
  final String? destRoomNumber;
  final Size availableSize;

  const _MapWithOverlay({
    required this.floorConfig,
    required this.pathPoints,
    required this.userX,
    required this.userY,
    required this.destX,
    required this.destY,
    required this.userRoomNumber,
    required this.destRoomNumber,
    required this.availableSize,
  });

  // Convert data (x, y) → pixel position
  Offset _dataToPixel(double dataX, double dataY) {
    final calibrated = _CoordinateTransform.anchor(
      floorConfig.floor,
      dataX,
      dataY,
    );
    if (calibrated != null) return _normalizedImageToPixel(calibrated);

    final containerRatio = availableSize.width / availableSize.height;
    final imageRatio = floorConfig.imageWidth / floorConfig.imageHeight;
    final imageWidth = containerRatio > imageRatio
        ? availableSize.height * imageRatio
        : availableSize.width;
    final imageHeight = containerRatio > imageRatio
        ? availableSize.height
        : availableSize.width / imageRatio;
    final imageLeft = (availableSize.width - imageWidth) / 2;
    final imageTop = (availableSize.height - imageHeight) / 2;

    final mapLeft = imageLeft + imageWidth * floorConfig.paddingLeftRatio;
    final mapTop = imageTop + imageHeight * floorConfig.paddingTopRatio;
    final mapWidth = imageWidth *
        (1.0 - floorConfig.paddingLeftRatio - floorConfig.paddingRightRatio);
    final mapHeight = imageHeight *
        (1.0 - floorConfig.paddingTopRatio - floorConfig.paddingBottomRatio);

    final dataWidth = floorConfig.maxX - floorConfig.minX;
    final dataHeight = floorConfig.maxY - floorConfig.minY;

    final normalizedX =
        ((dataX - floorConfig.minX) / dataWidth).clamp(0.0, 1.0);
    final normalizedY =
        ((dataY - floorConfig.minY) / dataHeight).clamp(0.0, 1.0);

    final pixelX = mapLeft + (1.0 - normalizedX) * mapWidth;
    final pixelY = mapTop + (1.0 - normalizedY) * mapHeight;

    return Offset(pixelX, pixelY);
  }

  Offset _roomToPixel(String? roomNumber) {
    final anchor = _RoomAnchors.anchor(floorConfig.floor, roomNumber);
    if (anchor == null) return Offset.zero;
    return _normalizedImageToPixel(anchor);
  }

  Offset _normalizedImageToPixel(Offset normalized) {
    final containerRatio = availableSize.width / availableSize.height;
    final imageRatio = floorConfig.imageWidth / floorConfig.imageHeight;
    final imageWidth = containerRatio > imageRatio
        ? availableSize.height * imageRatio
        : availableSize.width;
    final imageHeight = containerRatio > imageRatio
        ? availableSize.height
        : availableSize.width / imageRatio;
    final imageLeft = (availableSize.width - imageWidth) / 2;
    final imageTop = (availableSize.height - imageHeight) / 2;
    return Offset(
      imageLeft + normalized.dx * imageWidth,
      imageTop + normalized.dy * imageHeight,
    );
  }

  Offset _pathPointToPixel(PathPoint point) {
    final room = _roomNumberFromLocation(point.location);
    final anchor = _RoomDoorAnchors.anchor(point.floor, room) ??
        _RoomAnchors.anchor(point.floor, room);
    if (anchor != null) return _normalizedImageToPixel(anchor);
    final featureAnchor = _FeatureAnchors.anchor(point.floor, point);
    if (featureAnchor != null) return _normalizedImageToPixel(featureAnchor);

    final calibrated =
        _CoordinateTransform.anchor(point.floor, point.x, point.y);
    if (calibrated != null) {
      final type = point.type?.toLowerCase() ?? '';
      final location = point.location?.toLowerCase() ?? '';
      final shouldSnap = type.contains('corridor') ||
          type.contains('central') ||
          type.contains('walk') ||
          location.startsWith('cc_') ||
          location.startsWith('central_');
      final snapped = shouldSnap
          ? _CorridorRails.snap(point.floor, calibrated)
          : calibrated;
      return _normalizedImageToPixel(snapped);
    }

    return _dataToPixel(point.x, point.y);
  }

  String? _roomNumberFromLocation(String? value) {
    if (value == null || value.isEmpty) return null;
    return _normalizeRoomNumber(value);
  }

  List<Offset> _displayPathPixels(List<PathPoint> pointsOnThisFloor) {
    final hasRoute = pathPoints != null && pathPoints!.isNotEmpty;
    if (!hasRoute) return const [];

    if (pointsOnThisFloor.length >= 2) {
      final points = pointsOnThisFloor.map(_pathPointToPixel).toList();
      final cleaned = <Offset>[];
      for (final point in points) {
        if (cleaned.isEmpty || (cleaned.last - point).distance > 3) {
          cleaned.add(point);
        }
      }
      return cleaned;
    }

    final userAnchor =
        _RoomDoorAnchors.anchor(floorConfig.floor, userRoomNumber) ??
            _RoomAnchors.anchor(floorConfig.floor, userRoomNumber);
    final destAnchor =
        _RoomDoorAnchors.anchor(floorConfig.floor, destRoomNumber) ??
            _RoomAnchors.anchor(floorConfig.floor, destRoomNumber);
    final hasUserOnFloor = userX != null && userY != null;
    final hasDestOnFloor = destX != null && destY != null;

    final userPos = userAnchor != null
        ? _normalizedImageToPixel(userAnchor)
        : hasUserOnFloor
            ? _dataToPixel(userX!, userY!)
            : null;
    final destPos = destAnchor != null
        ? _normalizedImageToPixel(destAnchor)
        : hasDestOnFloor
            ? _dataToPixel(destX!, destY!)
            : null;

    if (userPos != null && destPos != null) {
      return _roomPath(userRoomNumber, destRoomNumber, userPos, destPos);
    }

    final connector = _normalizedImageToPixel(
      _FloorConnector.anchor(floorConfig.floor),
    );
    if (userPos != null) {
      return _roomPath(userRoomNumber, null, userPos, connector);
    }
    if (destPos != null) {
      return _roomPath(null, destRoomNumber, connector, destPos);
    }

    if (pointsOnThisFloor.isEmpty) return const [];

    return _directPath(_pathPointToPixel(pointsOnThisFloor.first), connector);
  }

  List<Offset> _directPath(Offset start, Offset end) {
    final dx = (start.dx - end.dx).abs();
    final dy = (start.dy - end.dy).abs();
    if (dx < 18 || dy < 18) return [start, end];

    final middleX = start.dx + (end.dx - start.dx) * 0.5;
    return [
      start,
      Offset(middleX, start.dy),
      Offset(middleX, end.dy),
      end,
    ];
  }

  List<Offset> _roomPath(
    String? startRoom,
    String? endRoom,
    Offset start,
    Offset end,
  ) {
    final startDoorAnchor = _roomDoorAnchor(startRoom);
    final endDoorAnchor = _roomDoorAnchor(endRoom);
    final startDoor = startDoorAnchor != null
        ? _normalizedImageToPixel(startDoorAnchor)
        : null;
    final endDoor =
        endDoorAnchor != null ? _normalizedImageToPixel(endDoorAnchor) : null;
    final middle = <Offset>[];

    if (startDoorAnchor != null || endDoorAnchor != null) {
      final startRail = startDoorAnchor != null
          ? _CorridorRails.project(floorConfig.floor, startDoorAnchor)
          : null;
      final endRail = endDoorAnchor != null
          ? _CorridorRails.project(floorConfig.floor, endDoorAnchor)
          : null;

      if (startRail != null) middle.add(_normalizedImageToPixel(startRail));
      if (startRail != null && endRail != null) {
        final railTurn = _corridorTurn(startRail, endRail);
        if ((railTurn - startRail).distance > 0.01 &&
            (railTurn - endRail).distance > 0.01) {
          middle.add(_normalizedImageToPixel(railTurn));
        }
      }
      if (endRail != null) middle.add(_normalizedImageToPixel(endRail));
    } else if (startDoor != null && endDoor != null) {
      middle.add(Offset(startDoor.dx, endDoor.dy));
    } else if (startDoor != null) {
      middle.add(Offset(startDoor.dx, end.dy));
    } else if (endDoor != null) {
      middle.add(Offset(endDoor.dx, start.dy));
    }

    final points = <Offset>[
      start,
      if (startDoor != null) startDoor,
      ...middle,
      if (endDoor != null) endDoor,
      end,
    ];

    final cleaned = <Offset>[];
    for (final point in points) {
      if (cleaned.isEmpty || (cleaned.last - point).distance > 3) {
        cleaned.add(point);
      }
    }
    return cleaned.length >= 2 ? cleaned : _directPath(start, end);
  }

  Offset _corridorTurn(Offset startRail, Offset endRail) {
    if ((startRail.dx - endRail.dx).abs() < 0.015 ||
        (startRail.dy - endRail.dy).abs() < 0.015) {
      return endRail;
    }

    final horizontalFirst = Offset(endRail.dx, startRail.dy);
    final verticalFirst = Offset(startRail.dx, endRail.dy);
    final snappedHorizontal =
        _CorridorRails.project(floorConfig.floor, horizontalFirst);
    final snappedVertical =
        _CorridorRails.project(floorConfig.floor, verticalFirst);

    final horizontalCost = (snappedHorizontal - horizontalFirst).distance;
    final verticalCost = (snappedVertical - verticalFirst).distance;
    return horizontalCost <= verticalCost ? snappedHorizontal : snappedVertical;
  }

  Offset? _roomDoorAnchor(String? roomNumber) {
    final explicitDoor = _RoomDoorAnchors.anchor(floorConfig.floor, roomNumber);
    if (explicitDoor != null) return explicitDoor;

    final center = _RoomAnchors.anchor(floorConfig.floor, roomNumber);
    if (center == null) return null;
    return _doorFromRoomCenter(center);
  }

  Offset? _roomDoorPixel(String? roomNumber) {
    final anchor = _roomDoorAnchor(roomNumber);
    if (anchor == null) return null;
    return _normalizedImageToPixel(anchor);
  }

  Offset _doorFromRoomCenter(Offset center) {
    if (center.dx > 0.70) return Offset(center.dx - 0.10, center.dy);
    if (center.dx > 0.48 && center.dy < 0.62) {
      return Offset(center.dx + 0.10, center.dy);
    }
    if (center.dy > 0.62) return Offset(center.dx, center.dy - 0.055);
    return Offset(center.dx, center.dy + 0.055);
  }

  @override
  Widget build(BuildContext context) {
    // Filter path to only points on the current floor
    final pointsOnThisFloor =
        pathPoints?.where((p) => p.floor == floorConfig.floor).toList() ?? [];
    final displayPath = _displayPathPixels(pointsOnThisFloor);

    return Stack(
      children: [
        // Background: the floor image
        Center(
          child: Image.asset(
            floorConfig.imagePath,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
          ),
        ),

        // Path line (drawn over the map)
        if (displayPath.length >= 2)
          Positioned.fill(
            child: CustomPaint(
              painter: _PathPainter(
                points: displayPath,
              ),
            ),
          ),

        // User location marker (orange dot)
        if (userX != null && userY != null) _buildUserMarker(),

        // Destination marker (orange pin)
        if (destX != null && destY != null) _buildDestMarker(),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 300,
      height: 400,
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map_outlined,
                size: 80, color: AppColors.textLight),
            const SizedBox(height: 16),
            Text(
              floorConfig.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Image not found',
              style: TextStyle(color: AppColors.textLight, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // User's current location - orange circle with white inner dot
  Widget _buildUserMarker() {
    final doorPos = _roomDoorPixel(userRoomNumber);
    final pos = doorPos ??
        (_RoomAnchors.anchor(floorConfig.floor, userRoomNumber) != null
            ? _roomToPixel(userRoomNumber)
            : _dataToPixel(userX!, userY!));
    const size = 10.0;

    return Positioned(
      left: pos.dx - size / 2,
      top: pos.dy - size / 2,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.5),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }

  // Destination - orange ring, same visual language as the prototype path.
  Widget _buildDestMarker() {
    final doorPos = _roomDoorPixel(destRoomNumber);
    final pos = doorPos ??
        (_RoomAnchors.anchor(floorConfig.floor, destRoomNumber) != null
            ? _roomToPixel(destRoomNumber)
            : _dataToPixel(destX!, destY!));
    const size = 12.0;

    return Positioned(
      left: pos.dx - size / 2,
      top: pos.dy - size / 2,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.accent, width: 3),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.28),
              blurRadius: 4,
              spreadRadius: 0.5,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================
// CustomPainter for drawing the path line
// =============================================
class _PathPainter extends CustomPainter {
  final List<Offset> points;

  _PathPainter({
    required this.points,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final paint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Dashed line effect
    final path = Path();
    final firstPos = points.first;
    path.moveTo(firstPos.dx, firstPos.dy);

    for (int i = 1; i < points.length; i++) {
      final pos = points[i];
      path.lineTo(pos.dx, pos.dy);
    }

    _drawDashedPath(canvas, path, paint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashWidth = 11.0;
    const dashGap = 7.0;

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final length = (distance + dashWidth < metric.length)
            ? dashWidth
            : metric.length - distance;
        canvas.drawPath(
          metric.extractPath(distance, distance + length),
          paint,
        );
        distance += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PathPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

String _normalizeRoomNumber(String value) {
  return value
      .trim()
      .replaceFirst(RegExp(r'^Door_'), '')
      .replaceFirst(RegExp(r'^(Room|Lab|Office)\s*'), '')
      .trim();
}

class _RoomAnchors {
  static Offset? anchor(int floor, String? roomNumber) {
    if (roomNumber == null || roomNumber.trim().isEmpty) return null;
    final n = _normalizeRoomNumber(roomNumber);
    return _anchors[floor]?[n];
  }

  static const Map<int, Map<String, Offset>> _anchors = {
    0: {
      '110': Offset(0.77, 0.30),
      '108': Offset(0.77, 0.40),
      '106': Offset(0.77, 0.49),
      '109': Offset(0.54, 0.36),
      '107': Offset(0.54, 0.50),
      '118': Offset(0.08, 0.58),
      '103': Offset(0.20, 0.58),
      '116': Offset(0.32, 0.58),
      '114': Offset(0.44, 0.58),
      '121': Offset(0.21, 0.68),
      '119': Offset(0.32, 0.68),
      '117': Offset(0.44, 0.68),
      '115': Offset(0.55, 0.68),
    },
    1: {
      '206': Offset(0.79, 0.32),
      '204': Offset(0.79, 0.43),
      '202': Offset(0.79, 0.53),
      '207': Offset(0.54, 0.35),
      '205': Offset(0.54, 0.46),
      '203': Offset(0.54, 0.57),
      '222': Offset(0.08, 0.66),
      '220': Offset(0.20, 0.66),
      '218': Offset(0.32, 0.66),
      '216': Offset(0.44, 0.66),
      '214': Offset(0.56, 0.66),
      '221': Offset(0.20, 0.74),
      '219': Offset(0.32, 0.74),
      '217': Offset(0.44, 0.74),
      '215': Offset(0.56, 0.74),
    },
    2: {
      '306': Offset(0.77, 0.28),
      '304': Offset(0.77, 0.39),
      '302': Offset(0.77, 0.49),
      '307': Offset(0.53, 0.30),
      '305': Offset(0.53, 0.41),
      '303': Offset(0.53, 0.51),
      '322': Offset(0.08, 0.54),
      '320': Offset(0.20, 0.54),
      '318': Offset(0.32, 0.54),
      '316': Offset(0.44, 0.54),
      '314': Offset(0.56, 0.54),
      '321': Offset(0.20, 0.64),
      '319': Offset(0.32, 0.64),
      '317': Offset(0.44, 0.64),
      '315': Offset(0.56, 0.64),
      '312': Offset(0.68, 0.64),
    },
    3: {
      '406': Offset(0.79, 0.29),
      '404': Offset(0.79, 0.40),
      '402': Offset(0.79, 0.51),
      '407': Offset(0.56, 0.31),
      '405': Offset(0.56, 0.42),
      '403': Offset(0.56, 0.53),
      '418': Offset(0.20, 0.57),
      '417/2': Offset(0.32, 0.66),
      '417/1': Offset(0.44, 0.66),
      '416': Offset(0.44, 0.57),
      '415': Offset(0.56, 0.66),
    },
    4: {
      '506': Offset(0.79, 0.27),
      '503': Offset(0.79, 0.39),
      '504': Offset(0.79, 0.39),
      '502': Offset(0.79, 0.49),
      '507': Offset(0.56, 0.30),
      '505': Offset(0.56, 0.41),
      '522': Offset(0.08, 0.56),
      '520': Offset(0.20, 0.56),
      '518': Offset(0.32, 0.56),
      '516': Offset(0.44, 0.56),
      '514': Offset(0.56, 0.56),
      '521': Offset(0.20, 0.65),
      '519': Offset(0.32, 0.65),
      '517': Offset(0.44, 0.65),
      '515': Offset(0.56, 0.65),
    },
  };
}

class _RoomDoorAnchors {
  static Offset? anchor(int floor, String? roomNumber) {
    if (roomNumber == null || roomNumber.trim().isEmpty) return null;
    final n = _normalizeRoomNumber(roomNumber);
    return _anchors[floor]?[n];
  }

  static const Map<int, Map<String, Offset>> _anchors = {
    0: {
      '110': Offset(0.7176, 0.2944),
      '108': Offset(0.7176, 0.3833),
      '106': Offset(0.7176, 0.4083),
      '109': Offset(0.6513, 0.3972),
      '107': Offset(0.6513, 0.4694),
      '118': Offset(0.1268, 0.5472),
      '103': Offset(0.1931, 0.5472),
      '116': Offset(0.3084, 0.5264),
      '114': Offset(0.3833, 0.5292),
      '121': Offset(0.2075, 0.5681),
      '119': Offset(0.2709, 0.5681),
      '117': Offset(0.3429, 0.5681),
      '115': Offset(0.4207, 0.5681),
    },
    1: {
      '207': Offset(0.6744, 0.3747),
      '206': Offset(0.7378, 0.3635),
      '204': Offset(0.7378, 0.4568),
      '205': Offset(0.6744, 0.4680),
      '202': Offset(0.7435, 0.4805),
      '203': Offset(0.6772, 0.5515),
      '222': Offset(0.1585, 0.6281),
      '220': Offset(0.2277, 0.6267),
      '218': Offset(0.2651, 0.6267),
      '216': Offset(0.3775, 0.6253),
      '214': Offset(0.4121, 0.6267),
      '221': Offset(0.1844, 0.6504),
      '219': Offset(0.3055, 0.6490),
      '217': Offset(0.3401, 0.6504),
      '215': Offset(0.4150, 0.6490),
    },
    2: {
      '307': Offset(0.6342, 0.3148),
      '306': Offset(0.6932, 0.2999),
      '305': Offset(0.6342, 0.3881),
      '304': Offset(0.6932, 0.3799),
      '302': Offset(0.6873, 0.4071),
      '303': Offset(0.6342, 0.4600),
      '322': Offset(0.1799, 0.5224),
      '320': Offset(0.2389, 0.5237),
      '318': Offset(0.2743, 0.5251),
      '316': Offset(0.3687, 0.5251),
      '314': Offset(0.3982, 0.5237),
      '321': Offset(0.2124, 0.5468),
      '319': Offset(0.3068, 0.5468),
      '317': Offset(0.3333, 0.5468),
      '315': Offset(0.4041, 0.5468),
    },
    3: {
      '406': Offset(0.7147, 0.3043),
      '407': Offset(0.6549, 0.3191),
      '405': Offset(0.6549, 0.4047),
      '404': Offset(0.7147, 0.4003),
      '402': Offset(0.7147, 0.4254),
      '403': Offset(0.6549, 0.4889),
      '414': Offset(0.4212, 0.5687),
      '416': Offset(0.3913, 0.5687),
      '418': Offset(0.2636, 0.5687),
      '415': Offset(0.4212, 0.5923),
      '417/1': Offset(0.3913, 0.5923),
      '417.1': Offset(0.3913, 0.5923),
      '417/2': Offset(0.2799, 0.5923),
      '417.2': Offset(0.2799, 0.5923),
    },
    4: {
      '506': Offset(0.7278, 0.2462),
      '507': Offset(0.6705, 0.2587),
      '505': Offset(0.6676, 0.3343),
      '504': Offset(0.7278, 0.3315),
      '503': Offset(0.6734, 0.4070),
      '502': Offset(0.7278, 0.3524),
      '514': Offset(0.4384, 0.4811),
      '516': Offset(0.4040, 0.4811),
      '515': Offset(0.4413, 0.4993),
      '517': Offset(0.3754, 0.4993),
      '518': Offset(0.3095, 0.4825),
      '520': Offset(0.2808, 0.4825),
      '521': Offset(0.2779, 0.4979),
      '522': Offset(0.1948, 0.4811),
    },
  };
}

class _CoordinateTransform {
  static Offset? anchor(int floor, double x, double y) {
    final transform = _transforms[floor];
    if (transform == null) return null;
    return transform.apply(x, y);
  }

  static const Map<int, _Affine> _transforms = {
    0: _Affine(-0.022011, 0.001761, 0.819583, 0.002954, -0.006578, 0.509304),
    1: _Affine(-0.023690, 0.000073, 0.895659, -0.000133, -0.011811, 0.682375),
    2: _Affine(-0.020054, 0.000523, 0.801749, -0.000103, -0.009939, 0.570772),
    3: _Affine(-0.021463, 0.000118, 0.854817, -0.000050, -0.011816, 0.623682),
    4: _Affine(-0.021382, 0.000371, 0.862836, -0.000018, -0.010346, 0.525734),
  };
}

class _Affine {
  final double ax;
  final double ay;
  final double ac;
  final double bx;
  final double by;
  final double bc;

  const _Affine(this.ax, this.ay, this.ac, this.bx, this.by, this.bc);

  Offset apply(double x, double y) {
    return Offset(
      (ax * x + ay * y + ac).clamp(0.0, 1.0),
      (bx * x + by * y + bc).clamp(0.0, 1.0),
    );
  }
}

class _CorridorRails {
  static Offset snap(int floor, Offset point) {
    final rails = _rails[floor];
    if (rails == null || rails.isEmpty) return point;

    final best = project(floor, point);
    final bestDistance = (best - point).distance;
    return bestDistance <= 0.12 ? best : point;
  }

  static Offset project(int floor, Offset point) {
    final rails = _rails[floor];
    if (rails == null || rails.isEmpty) return point;

    var best = point;
    var bestDistance = double.infinity;
    for (final rail in rails) {
      final candidate = rail.closestPoint(point);
      final distance = (candidate - point).distance;
      if (distance < bestDistance) {
        best = candidate;
        bestDistance = distance;
      }
    }

    return best;
  }

  static const Map<int, List<_RailSegment>> _rails = {
    0: [
      _RailSegment(Offset(0.6513, 0.2944), Offset(0.6513, 0.5569)),
      _RailSegment(Offset(0.0951, 0.5472), Offset(0.8444, 0.5472)),
      _RailSegment(Offset(0.0951, 0.5681), Offset(0.8444, 0.5681)),
      _RailSegment(Offset(0.7176, 0.2944), Offset(0.7176, 0.4083)),
      _RailSegment(Offset(0.7118, 0.2153), Offset(0.7118, 0.2944)),
      _RailSegment(Offset(0.7723, 0.5167), Offset(0.8444, 0.5569)),
    ],
    1: [
      _RailSegment(Offset(0.6744, 0.3635), Offset(0.6744, 0.6448)),
      _RailSegment(Offset(0.0922, 0.6267), Offset(0.8790, 0.6267)),
      _RailSegment(Offset(0.0922, 0.6490), Offset(0.8790, 0.6490)),
      _RailSegment(Offset(0.7378, 0.3635), Offset(0.7378, 0.4805)),
      _RailSegment(Offset(0.7435, 0.2772), Offset(0.7435, 0.3635)),
      _RailSegment(Offset(0.7954, 0.5961), Offset(0.8790, 0.6448)),
    ],
    2: [
      _RailSegment(Offset(0.6342, 0.2999), Offset(0.6342, 0.5468)),
      _RailSegment(Offset(0.1091, 0.5237), Offset(0.8112, 0.5237)),
      _RailSegment(Offset(0.1091, 0.5468), Offset(0.8112, 0.5468)),
      _RailSegment(Offset(0.6932, 0.2999), Offset(0.6932, 0.4071)),
      _RailSegment(Offset(0.6932, 0.2293), Offset(0.6932, 0.2999)),
      _RailSegment(Offset(0.7463, 0.4980), Offset(0.8112, 0.5468)),
    ],
    3: [
      _RailSegment(Offset(0.6549, 0.3043), Offset(0.6549, 0.5805)),
      _RailSegment(Offset(0.1386, 0.5687), Offset(0.8424, 0.5687)),
      _RailSegment(Offset(0.1386, 0.5923), Offset(0.8424, 0.5923)),
      _RailSegment(Offset(0.7147, 0.3043), Offset(0.7147, 0.4254)),
      _RailSegment(Offset(0.7147, 0.2186), Offset(0.7147, 0.3043)),
      _RailSegment(Offset(0.7690, 0.5273), Offset(0.8424, 0.5805)),
    ],
    4: [
      _RailSegment(Offset(0.6705, 0.2462), Offset(0.6705, 0.5021)),
      _RailSegment(Offset(0.1519, 0.4811), Offset(0.8510, 0.4811)),
      _RailSegment(Offset(0.1519, 0.4993), Offset(0.8510, 0.4993)),
      _RailSegment(Offset(0.7278, 0.2462), Offset(0.7278, 0.3524)),
      _RailSegment(Offset(0.7880, 0.4531), Offset(0.8510, 0.5021)),
    ],
  };
}

class _RailSegment {
  final Offset a;
  final Offset b;

  const _RailSegment(this.a, this.b);

  Offset closestPoint(Offset point) {
    final ab = b - a;
    final ap = point - a;
    final denominator = ab.dx * ab.dx + ab.dy * ab.dy;
    if (denominator == 0) return a;

    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / denominator).clamp(0.0, 1.0);
    return Offset(
      a.dx + ab.dx * t,
      a.dy + ab.dy * t,
    );
  }
}

class _FeatureAnchors {
  static Offset? anchor(int floor, PathPoint point) {
    final type = point.type?.toLowerCase() ?? '';
    final location = point.location?.toLowerCase() ?? '';

    if (type.contains('elevator') || location.contains('elevator')) {
      return _ElevatorAnchors.anchor(floor);
    }
    if (location.contains('main-stairs') || location.contains('main_f')) {
      return _mainStairs[floor];
    }
    if (location.contains('emergency')) {
      return _emergencyStairs[floor];
    }
    if (location.contains('secondary')) {
      return _secondaryStairs[floor];
    }
    if (type.contains('stair')) {
      return _mainStairs[floor] ?? _secondaryStairs[floor];
    }
    return null;
  }

  static const Map<int, Offset> _mainStairs = {
    0: Offset(0.7723, 0.5167),
    1: Offset(0.7954, 0.5961),
    2: Offset(0.7463, 0.4980),
    3: Offset(0.7690, 0.5273),
    4: Offset(0.7880, 0.4531),
  };

  static const Map<int, Offset> _emergencyStairs = {
    0: Offset(0.0951, 0.5472),
    1: Offset(0.0922, 0.6253),
    2: Offset(0.1091, 0.5237),
    3: Offset(0.1386, 0.5687),
    4: Offset(0.1519, 0.4811),
  };

  static const Map<int, Offset> _secondaryStairs = {
    0: Offset(0.7118, 0.2153),
    1: Offset(0.7435, 0.2772),
    2: Offset(0.6932, 0.2293),
    3: Offset(0.7147, 0.2186),
  };
}

class _ElevatorAnchors {
  static Offset anchor(int floor) =>
      _anchors[floor] ?? const Offset(0.88, 0.56);

  static const Map<int, Offset> _anchors = {
    0: Offset(0.8444, 0.5569),
    1: Offset(0.8790, 0.6448),
    2: Offset(0.8112, 0.5468),
    3: Offset(0.8424, 0.5805),
    4: Offset(0.8510, 0.5021),
  };
}

class _FloorConnector {
  static Offset anchor(int floor) => _ElevatorAnchors.anchor(floor);
}
