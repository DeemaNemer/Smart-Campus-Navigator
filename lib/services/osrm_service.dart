import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

/// Calls OSRM public server to get walking routes between two points.
/// Free for development. For production, host your own OSRM instance.
class OsrmService {
  static const String _baseUrl = 'http://router.project-osrm.org/route/v1/foot';
  static const Distance _distance = Distance();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  Future<OsrmRoute> getRoute({
    required LatLng from,
    required LatLng to,
    LatLng? displayFrom,
    LatLng? displayTo,
  }) async {
    // OSRM uses lng,lat order (not lat,lng)
    final coords =
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}';
    final url = '$_baseUrl/$coords?overview=full&geometries=geojson&steps=true'
        '&alternatives=false&continue_straight=false';

    final response = await _dio.get(url);
    final data = response.data as Map<String, dynamic>;

    if (data['code'] != 'Ok' ||
        data['routes'] == null ||
        (data['routes'] as List).isEmpty) {
      throw Exception('No route found between buildings');
    }

    final route = (data['routes'] as List).first as Map<String, dynamic>;

    // Decode polyline geometry (GeoJSON: [lng, lat])
    final coordinates = (route['geometry']['coordinates'] as List).cast<List>();
    final routePolyline = coordinates
        .map((c) => LatLng(
              (c[1] as num).toDouble(),
              (c[0] as num).toDouble(),
            ))
        .toList();
    final origin = displayFrom ?? from;
    final destination = displayTo ?? to;
    final polyline = _connectRouteToMarkers(
      routePolyline,
      origin: origin,
      destination: destination,
    );

    // Parse turn-by-turn steps from legs
    final legs = (route['legs'] as List).cast<Map<String, dynamic>>();
    final steps = <RouteStep>[];
    if (routePolyline.isNotEmpty) {
      final connectorDistance = _metersBetween(origin, routePolyline.first);
      if (connectorDistance > 2) {
        steps.add(
          RouteStep(
            instruction: 'Walk to the nearest campus path',
            distance: connectorDistance,
            location: origin,
          ),
        );
      }
    }
    for (final leg in legs) {
      for (final stepData
          in (leg['steps'] as List).cast<Map<String, dynamic>>()) {
        final maneuver = stepData['maneuver'] as Map<String, dynamic>;
        final loc = maneuver['location'] as List;
        steps.add(
          RouteStep(
            instruction: _buildInstruction(maneuver, stepData),
            distance: (stepData['distance'] as num).toDouble(),
            location: LatLng(
              (loc[1] as num).toDouble(),
              (loc[0] as num).toDouble(),
            ),
          ),
        );
      }
    }
    if (routePolyline.isNotEmpty) {
      final connectorDistance = _metersBetween(routePolyline.last, destination);
      if (connectorDistance > 2) {
        steps.add(
          RouteStep(
            instruction: 'Continue to the destination building',
            distance: connectorDistance,
            location: routePolyline.last,
          ),
        );
      }
    }

    return OsrmRoute(
      polyline: polyline,
      distanceMeters: _totalDistance(
        routeDistance: (route['distance'] as num).toDouble(),
        routePolyline: routePolyline,
        origin: origin,
        destination: destination,
      ),
      durationSeconds: (route['duration'] as num).toDouble(),
      steps: steps,
    );
  }

  List<LatLng> _connectRouteToMarkers(
    List<LatLng> routePolyline, {
    required LatLng origin,
    required LatLng destination,
  }) {
    if (routePolyline.isEmpty) {
      return [origin, destination];
    }

    return [
      if (_metersBetween(origin, routePolyline.first) > 2) origin,
      ...routePolyline,
      if (_metersBetween(routePolyline.last, destination) > 2) destination,
    ];
  }

  double _totalDistance({
    required double routeDistance,
    required List<LatLng> routePolyline,
    required LatLng origin,
    required LatLng destination,
  }) {
    if (routePolyline.isEmpty) {
      return _metersBetween(origin, destination);
    }
    return routeDistance +
        _metersBetween(origin, routePolyline.first) +
        _metersBetween(routePolyline.last, destination);
  }

  double _metersBetween(LatLng a, LatLng b) => _distance(a, b);

  String _buildInstruction(
    Map<String, dynamic> maneuver,
    Map<String, dynamic> step,
  ) {
    final type = maneuver['type'] as String? ?? '';
    final modifier = maneuver['modifier'] as String? ?? '';
    final name = step['name'] as String? ?? '';

    String suffix = name.isNotEmpty ? ' onto $name' : '';

    switch (type) {
      case 'depart':
        return 'Start walking${name.isNotEmpty ? " on $name" : ""}';
      case 'arrive':
        return 'Arrive at destination';
      case 'turn':
        return 'Turn $modifier$suffix';
      case 'new name':
        return 'Continue${name.isNotEmpty ? " on $name" : ""}';
      case 'continue':
        return 'Continue ${modifier.isNotEmpty ? modifier : "straight"}';
      case 'roundabout':
      case 'rotary':
        return 'Enter the roundabout';
      case 'exit roundabout':
      case 'exit rotary':
        return 'Exit the roundabout';
      case 'fork':
        return 'Keep $modifier at the fork';
      case 'merge':
        return 'Merge $modifier$suffix';
      case 'end of road':
        return 'Turn $modifier at the end of the road$suffix';
      default:
        return 'Continue ${modifier.isNotEmpty ? modifier : "straight"}';
    }
  }
}

class OsrmRoute {
  final List<LatLng> polyline;
  final double distanceMeters;
  final double durationSeconds;
  final List<RouteStep> steps;

  OsrmRoute({
    required this.polyline,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.steps,
  });

  String get distanceLabel {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(2)} km';
  }

  String get durationLabel {
    final minutes = (durationSeconds / 60).round();
    return '$minutes min';
  }
}

class RouteStep {
  final String instruction;
  final double distance;
  final LatLng location;

  RouteStep({
    required this.instruction,
    required this.distance,
    required this.location,
  });

  String get distanceLabel {
    if (distance < 1000) return '${distance.round()} m';
    return '${(distance / 1000).toStringAsFixed(2)} km';
  }
}
