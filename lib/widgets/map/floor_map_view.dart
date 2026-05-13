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

  const FloorMapView({
    super.key,
    required this.floorConfig,
    this.pathPoints,
    this.userX,
    this.userY,
    this.destX,
    this.destY,
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
      minScale: 0.5,
      maxScale: 5.0,
      boundaryMargin: const EdgeInsets.all(80),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return _MapWithOverlay(
            floorConfig: widget.floorConfig,
            pathPoints: widget.pathPoints,
            userX: widget.userX,
            userY: widget.userY,
            destX: widget.destX,
            destY: widget.destY,
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
  final Size availableSize;

  const _MapWithOverlay({
    required this.floorConfig,
    required this.pathPoints,
    required this.userX,
    required this.userY,
    required this.destX,
    required this.destY,
    required this.availableSize,
  });

  // Convert data (x, y) → pixel position
  Offset _dataToPixel(double dataX, double dataY) {
    final width = availableSize.width;
    final height = availableSize.height;

    final mapLeft = width * floorConfig.paddingLeftRatio;
    final mapTop = height * floorConfig.paddingTopRatio;
    final mapWidth = width *
        (1.0 - floorConfig.paddingLeftRatio - floorConfig.paddingRightRatio);
    final mapHeight = height *
        (1.0 - floorConfig.paddingTopRatio - floorConfig.paddingBottomRatio);

    final dataWidth = floorConfig.maxX - floorConfig.minX;
    final dataHeight = floorConfig.maxY - floorConfig.minY;

    final pixelX =
        mapLeft + ((dataX - floorConfig.minX) / dataWidth) * mapWidth;
    final pixelY =
        mapTop + ((dataY - floorConfig.minY) / dataHeight) * mapHeight;

    return Offset(pixelX, pixelY);
  }

  @override
  Widget build(BuildContext context) {
    // Filter path to only points on the current floor
    final pointsOnThisFloor =
        pathPoints?.where((p) => p.floor == floorConfig.floor).toList() ?? [];

    return Stack(
      children: [
        // Background: the floor image
        Center(
          child: Image.asset(
            floorConfig.imagePath,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
          ),
        ),

        // Path line (drawn over the map)
        if (pointsOnThisFloor.length >= 2)
          Positioned.fill(
            child: CustomPaint(
              painter: _PathPainter(
                points: pointsOnThisFloor,
                dataToPixel: _dataToPixel,
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
    final pos = _dataToPixel(userX!, userY!);
    const size = 24.0;

    return Positioned(
      left: pos.dx - size / 2,
      top: pos.dy - size / 2,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.5),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }

  // Destination - orange location pin
  Widget _buildDestMarker() {
    final pos = _dataToPixel(destX!, destY!);
    const size = 32.0;

    return Positioned(
      left: pos.dx - size / 2,
      top: pos.dy - size,
      child: Icon(
        Icons.location_on,
        color: AppColors.accent,
        size: size,
        shadows: [
          Shadow(
            color: AppColors.accent.withValues(alpha: 0.5),
            blurRadius: 8,
          ),
        ],
      ),
    );
  }
}

// =============================================
// CustomPainter for drawing the path line
// =============================================
class _PathPainter extends CustomPainter {
  final List<PathPoint> points;
  final Offset Function(double, double) dataToPixel;

  _PathPainter({
    required this.points,
    required this.dataToPixel,
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
    final firstPos = dataToPixel(points.first.x, points.first.y);
    path.moveTo(firstPos.dx, firstPos.dy);

    for (int i = 1; i < points.length; i++) {
      final pos = dataToPixel(points[i].x, points[i].y);
      path.lineTo(pos.dx, pos.dy);
    }

    // Draw dashed path
    _drawDashedPath(canvas, path, paint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashWidth = 8.0;
    const dashGap = 6.0;

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
