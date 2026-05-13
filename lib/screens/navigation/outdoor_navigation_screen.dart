import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../config/app_colors.dart';
import '../../config/campus_buildings.dart';
import '../../models/campus_building.dart';
import '../../providers/outdoor_navigation_provider.dart';
import '../../services/osrm_service.dart';

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
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    if (widget.fromId != null) {
      _from = CampusBuildings.all
          .where((b) => b.id == widget.fromId)
          .firstOrNull;
    }
    if (widget.toId != null) {
      _to = CampusBuildings.all
          .where((b) => b.id == widget.toId)
          .firstOrNull;
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

  void _fitRoute(OsrmRoute route) {
    if (route.polyline.isEmpty) return;
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
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text(
          'Outdoor Navigation',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          _buildBuildingCards(),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: CampusBuildings.campusCenter,
                    initialZoom: 17,
                    minZoom: 14,
                    maxZoom: 19,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName:
                          'edu.birzeit.smart_campus_app',
                    ),
                    if (routeAsync?.valueOrNull != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: routeAsync!.value!.polyline,
                            color: AppColors.accent,
                            strokeWidth: 5,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        if (_from != null)
                          Marker(
                            point: _from!.location,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.trip_origin,
                              color: AppColors.accent,
                              size: 36,
                            ),
                          ),
                        if (_to != null)
                          Marker(
                            point: _to!.location,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_on,
                              color: AppColors.accent,
                              size: 40,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                if (routeAsync != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _RouteInfoPanel(
                      routeAsync: routeAsync,
                      onRouteReady: _fitRoute,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuildingCards() {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _buildingCard(
            label: 'From',
            building: _from,
            icon: Icons.trip_origin,
            onTap: () => _pickBuilding(isFrom: true),
          ),
          const SizedBox(height: 8),
          _buildingCard(
            label: 'To',
            building: _to,
            icon: Icons.location_on,
            onTap: () => _pickBuilding(isFrom: false),
          ),
        ],
      ),
    );
  }

  Widget _buildingCard({
    required String label,
    required CampusBuilding? building,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    building?.nameEn ?? 'Tap to select',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _RouteInfoPanel extends StatelessWidget {
  final AsyncValue<OsrmRoute> routeAsync;
  final void Function(OsrmRoute) onRouteReady;

  const _RouteInfoPanel({
    required this.routeAsync,
    required this.onRouteReady,
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

        return _panel(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.directions_walk,
                        color: AppColors.accent),
                    const SizedBox(width: 8),
                    Text(
                      route.durationLabel,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '(${route.distanceLabel})',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: route.steps.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1),
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
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _BuildingPickerSheet extends StatelessWidget {
  final String title;
  final String? excludeId;

  const _BuildingPickerSheet({required this.title, this.excludeId});

  @override
  Widget build(BuildContext context) {
    final items = CampusBuildings.all
        .where((b) => b.id != excludeId)
        .toList();

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