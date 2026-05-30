import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../config/app_colors.dart';
import '../../config/campus_buildings.dart';
import '../../models/campus_building.dart';
import '../../providers/outdoor_navigation_provider.dart';
import '../../services/osrm_service.dart';
import '../../widgets/common/birzeit_logo_mark.dart';

class OutdoorNavigationScreen extends ConsumerStatefulWidget {
  final String? fromId;
  final String? toId;

  const OutdoorNavigationScreen({super.key, this.fromId, this.toId});

  @override
  ConsumerState<OutdoorNavigationScreen> createState() =>
      _OutdoorNavigationScreenState();
}

class _OutdoorNavigationScreenState
    extends ConsumerState<OutdoorNavigationScreen> {
  CampusBuilding? _from;
  CampusBuilding? _to;
  String? _lastFittedRouteKey;
  StreamSubscription<Position>? _positionSubscription;
  Position? _currentPosition;
  bool _isLiveNavigation = false;
  String? _locationError;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    if (widget.fromId != null) {
      _from =
          CampusBuildings.all.where((b) => b.id == widget.fromId).firstOrNull;
    }
    if (widget.toId != null) {
      _to = CampusBuildings.all.where((b) => b.id == widget.toId).firstOrNull;
    }
  }

  Future<void> _pickBuilding({required bool isFrom}) async {
    final selected = await showModalBottomSheet<CampusBuilding>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _BuildingPickerSheet(
        title: isFrom ? 'Select Starting Point' : 'Select Destination',
        excludeId: isFrom ? _to?.id : _from?.id,
      ),
    );
    if (selected != null) {
      setState(() {
        if (isFrom) {
          _from = selected;
        } else {
          _to = selected;
        }
      });
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _toggleLiveNavigation() async {
    if (_isLiveNavigation) {
      await _positionSubscription?.cancel();
      if (!mounted) return;
      setState(() {
        _isLiveNavigation = false;
        _locationError = null;
      });
      return;
    }

    final permissionGranted = await _ensureLocationPermission();
    if (!permissionGranted) return;

    final initialPosition = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
      ),
    );

    await _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 3,
      ),
    ).listen(
      (position) {
        if (!mounted) return;
        setState(() {
          _currentPosition = position;
          _locationError = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() => _locationError = error.toString());
      },
    );

    if (!mounted) return;
    setState(() {
      _currentPosition = initialPosition;
      _isLiveNavigation = true;
      _locationError = null;
    });

    _mapController.move(
      LatLng(initialPosition.latitude, initialPosition.longitude),
      18,
    );
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() => _locationError = 'Location services are disabled.');
      }
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(
          () => _locationError =
              'Location permission is required for live navigation.',
        );
      }
      return false;
    }

    return true;
  }

  LatLng? get _currentLatLng {
    final position = _currentPosition;
    if (position == null) return null;
    return LatLng(position.latitude, position.longitude);
  }

  void _fitRoute(OsrmRoute route) {
    if (route.polyline.isEmpty) return;
    final routeKey = '${_from?.id}->${_to?.id}';
    if (_lastFittedRouteKey == routeKey) return;
    _lastFittedRouteKey = routeKey;

    final bounds = LatLngBounds.fromPoints(route.polyline);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(60),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bothSelected = _from != null && _to != null;
    final routeAsync = bothSelected
        ? ref.watch(
            outdoorRouteProvider(
              OutdoorRouteRequest(from: _from!, to: _to!),
            ),
          )
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: CampusBuildings.campusCenter,
              initialZoom: 17,
              minZoom: 14,
              maxZoom: 19,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'edu.birzeit.smart_campus_app',
              ),
              if (routeAsync?.valueOrNull != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routeAsync!.value!.polyline,
                      color: AppColors.accent,
                      strokeWidth: 5,
                      pattern: StrokePattern.dashed(
                        segments: const [10, 8],
                        patternFit: PatternFit.none,
                      ),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (_currentLatLng != null)
                    Marker(
                      point: _currentLatLng!,
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.fromBorderSide(
                              BorderSide(color: Colors.white, width: 3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_from != null)
                    Marker(
                      point: _from!.location,
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: const _MapPin(
                        icon: Icons.trip_origin,
                        color: AppColors.accent,
                      ),
                    ),
                  if (_to != null)
                    Marker(
                      point: _to!.location,
                      width: 44,
                      height: 44,
                      alignment: Alignment.topCenter,
                      child: const _MapPin(
                        icon: Icons.location_on,
                        color: AppColors.error,
                      ),
                    ),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  _CircleButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Outdoor Navigation',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const BirzeitLogoMark(),
                ],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            top: MediaQuery.paddingOf(context).top + 58,
            child: _buildRouteSelector(),
          ),
          if (routeAsync != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _RouteInfoPanel(
                routeAsync: routeAsync,
                onRouteReady: _fitRoute,
                currentLocation: _currentLatLng,
                isLiveNavigation: _isLiveNavigation,
                locationError: _locationError,
                onToggleLiveNavigation: _toggleLiveNavigation,
              ),
            ),
          if (routeAsync == null && _locationError != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 20,
              child: _MapMessage(text: _locationError!),
            ),
        ],
      ),
    );
  }

  Widget _buildRouteSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildingCard(
                  label: 'Source',
                  building: _from,
                  icon: Icons.trip_origin,
                  color: AppColors.accent,
                  onTap: () => _pickBuilding(isFrom: true),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: IconButton.filledTonal(
                  tooltip: 'Swap',
                  onPressed: _from == null && _to == null
                      ? null
                      : () => setState(() {
                            final oldFrom = _from;
                            _from = _to;
                            _to = oldFrom;
                            _lastFittedRouteKey = null;
                          }),
                  icon: const Icon(Icons.swap_horiz),
                ),
              ),
              Expanded(
                child: _buildingCard(
                  label: 'Destination',
                  building: _to,
                  icon: Icons.location_on,
                  color: AppColors.error,
                  onTap: () => _pickBuilding(isFrom: false),
                ),
              ),
            ],
          ),
          if (_from == null || _to == null) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(
                  Icons.touch_app_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Choose a source and destination to calculate the shortest campus route.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildingCard({
    required String label,
    required CampusBuilding? building,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 76),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              building?.nameEn ?? 'Select',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.15,
                fontWeight:
                    building == null ? FontWeight.w600 : FontWeight.w800,
                color: building == null
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _MapPin({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 28),
    );
  }
}

class _RouteInfoPanel extends StatelessWidget {
  final AsyncValue<OsrmRoute> routeAsync;
  final void Function(OsrmRoute) onRouteReady;
  final LatLng? currentLocation;
  final bool isLiveNavigation;
  final String? locationError;
  final VoidCallback onToggleLiveNavigation;
  static const Distance _distance = Distance();

  const _RouteInfoPanel({
    required this.routeAsync,
    required this.onRouteReady,
    required this.currentLocation,
    required this.isLiveNavigation,
    required this.locationError,
    required this.onToggleLiveNavigation,
  });

  @override
  Widget build(BuildContext context) {
    return routeAsync.when(
      loading: () => _panel(
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Calculating route...'),
            ],
          ),
        ),
      ),
      error: (e, _) => _panel(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Failed to load route: $e',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
      data: (route) {
        // Fit map to route after first build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onRouteReady(route);
        });

        final progress = currentLocation == null
            ? null
            : _RouteProgress.from(route, currentLocation!);

        return _panel(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.directions_walk, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Text(
                      progress?.durationLabel ?? route.durationLabel,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '(${progress?.distanceLabel ?? route.distanceLabel})',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (locationError != null) ...[
                  _StatusText(
                    icon: Icons.warning_amber_rounded,
                    text: locationError!,
                    color: AppColors.warning,
                  ),
                  const SizedBox(height: 8),
                ],
                if (progress != null) ...[
                  _StatusText(
                    icon: progress.isOffRoute
                        ? Icons.near_me_disabled_outlined
                        : Icons.navigation_outlined,
                    text: progress.guidanceText,
                    color: progress.isOffRoute
                        ? AppColors.warning
                        : AppColors.primary,
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onToggleLiveNavigation,
                    icon: Icon(
                      isLiveNavigation
                          ? Icons.stop_circle_outlined
                          : Icons.my_location,
                    ),
                    label: Text(
                      isLiveNavigation
                          ? 'Stop Live Navigation'
                          : 'Start Live Navigation',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: route.steps.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final step = route.steps[i];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.directions,
                          color: AppColors.primary,
                        ),
                        title: Text(step.instruction),
                        trailing: Text(step.distanceLabel),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _RouteProgress {
  final double remainingMeters;
  final double offRouteMeters;
  final RouteStep? nextStep;

  const _RouteProgress({
    required this.remainingMeters,
    required this.offRouteMeters,
    required this.nextStep,
  });

  bool get isOffRoute => offRouteMeters > 35;

  String get distanceLabel {
    if (remainingMeters < 1000) return '${remainingMeters.round()} m left';
    return '${(remainingMeters / 1000).toStringAsFixed(2)} km left';
  }

  String get durationLabel {
    final minutes =
        (OsrmService.estimateWalkingSeconds(remainingMeters) / 60).ceil();
    return minutes <= 1 ? '<1 min left' : '$minutes min left';
  }

  String get guidanceText {
    if (isOffRoute) {
      return 'You are ${offRouteMeters.round()} m away from the route. Move back to the highlighted path.';
    }
    if (remainingMeters < 12) return 'You have arrived at the destination.';
    final instruction =
        nextStep?.instruction ?? 'Continue on the highlighted path';
    return '$instruction • $distanceLabel';
  }

  static _RouteProgress from(OsrmRoute route, LatLng currentLocation) {
    if (route.polyline.isEmpty) {
      return const _RouteProgress(
        remainingMeters: 0,
        offRouteMeters: 0,
        nextStep: null,
      );
    }

    var nearestIndex = 0;
    var nearestDistance = double.infinity;
    for (var i = 0; i < route.polyline.length; i++) {
      final distance = _RouteInfoPanel._distance(
        currentLocation,
        route.polyline[i],
      );
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = i;
      }
    }

    var remaining = nearestDistance;
    for (var i = nearestIndex; i < route.polyline.length - 1; i++) {
      remaining += _RouteInfoPanel._distance(
        route.polyline[i],
        route.polyline[i + 1],
      );
    }

    RouteStep? nextStep;
    var bestStepDistance = double.infinity;
    for (final step in route.steps) {
      final distance =
          _RouteInfoPanel._distance(currentLocation, step.location);
      if (distance < bestStepDistance) {
        bestStepDistance = distance;
        nextStep = step;
      }
    }

    return _RouteProgress(
      remainingMeters: remaining,
      offRouteMeters: nearestDistance,
      nextStep: nextStep,
    );
  }
}

class _StatusText extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _StatusText({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _MapMessage extends StatelessWidget {
  final String text;

  const _MapMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
          ),
        ],
      ),
      child: _StatusText(
        icon: Icons.warning_amber_rounded,
        text: text,
        color: AppColors.warning,
      ),
    );
  }
}

class _BuildingPickerSheet extends StatelessWidget {
  final String title;
  final String? excludeId;

  const _BuildingPickerSheet({required this.title, this.excludeId});

  @override
  Widget build(BuildContext context) {
    final items = CampusBuildings.all.where((b) => b.id != excludeId).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final b = items[i];
                  return ListTile(
                    leading: const Icon(
                      Icons.location_city,
                      color: AppColors.primary,
                    ),
                    title: Text(b.nameEn),
                    subtitle: Text(b.nameAr),
                    onTap: () => Navigator.pop(context, b),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
