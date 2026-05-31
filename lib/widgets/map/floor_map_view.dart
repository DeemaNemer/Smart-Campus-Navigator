import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/floor_config.dart';
import '../../models/navigation_path.dart';

class FloorMapView extends StatefulWidget {
  final FloorConfig floorConfig;

  // Navigation overlays
  final List<PathPoint>? pathPoints;
  // ⭐ userX/userY = pixel positions in the floor plan image
  // (caller looks them up from RoomPixels.get(floor, roomNumber))
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

  // ⭐ Convert image pixel → widget pixel
  // Image is shown with BoxFit.contain — we replicate the same scaling.
  Offset _imgPxToWidget(double imgX, double imgY) {
    final imgW = floorConfig.imageWidth;
    final imgH = floorConfig.imageHeight;
    final widgetW = availableSize.width;
    final widgetH = availableSize.height;

    final scaleX = widgetW / imgW;
    final scaleY = widgetH / imgH;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final displayedW = imgW * scale;
    final displayedH = imgH * scale;
    final offsetX = (widgetW - displayedW) / 2;
    final offsetY = (widgetH - displayedH) / 2;

    return Offset(offsetX + imgX * scale, offsetY + imgY * scale);
  }

  @override
  Widget build(BuildContext context) {
    final pointsOnThisFloor =
        pathPoints?.where((p) => p.floor == floorConfig.floor).toList() ?? [];

    return Stack(
      children: [
        // Background floor plan image
        Center(
          child: Image.asset(
            floorConfig.imagePath,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _buildPlaceholder(),
          ),
        ),
        // Path line (drawn over the map)
        if (pointsOnThisFloor.length >= 2)
          Positioned.fill(
            child: CustomPaint(
              painter: _PathPainter(
                points: pointsOnThisFloor,
                imgPxToWidget: _imgPxToWidget,
              ),
            ),
          ),
        // User marker (orange dot)
        if (userX != null && userY != null) _buildUserMarker(),
        // Destination marker (orange pin)
        if (destX != null && destY != null) _buildDestMarker(),
      ],
    );
  }

  Widget _buildPlaceholder() => Container(
        width: 300,
        height: 400,
        decoration: BoxDecoration(
          color: AppColors.cardBg.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            '${floorConfig.name}\nImage not found',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );

  Widget _buildUserMarker() {
    final pos = _imgPxToWidget(userX!, userY!);
    const size = 16.0;
    return Positioned(
      left: pos.dx - size / 2,
      top: pos.dy - size / 2,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.45),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestMarker() {
    final pos = _imgPxToWidget(destX!, destY!);
    const size = 24.0;
    return Positioned(
      left: pos.dx - size / 2,
      top: pos.dy - size,
      child: Icon(
        Icons.location_on,
        color: AppColors.accent,
        size: size,
        shadows: [
          Shadow(color: AppColors.accent.withValues(alpha: 0.45), blurRadius: 6),
        ],
      ),
    );
  }
}

class _PathPainter extends CustomPainter {
  final List<PathPoint> points;
  final Offset Function(double, double) imgPxToWidget;

  _PathPainter({required this.points, required this.imgPxToWidget});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    // Shadow / glow underneath
    final shadowPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.2)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final linePaint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final first = imgPxToWidget(points.first.x, points.first.y);
    path.moveTo(first.dx, first.dy);
    for (int i = 1; i < points.length; i++) {
      final p = imgPxToWidget(points[i].x, points[i].y);
      path.lineTo(p.dx, p.dy);
    }

    // Draw glow first, then dashes on top
    _drawDashedPath(canvas, path, shadowPaint, dashWidth: 8, dashGap: 5);
    _drawDashedPath(canvas, path, linePaint, dashWidth: 8, dashGap: 5);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint,
      {double dashWidth = 8.0, double dashGap = 5.0}) {
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final length = (distance + dashWidth < metric.length)
            ? dashWidth
            : metric.length - distance;
        canvas.drawPath(
            metric.extractPath(distance, distance + length), paint);
        distance += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PathPainter old) => old.points != points;
}