import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/campus_building.dart';
import '../services/osrm_service.dart';

final osrmServiceProvider = Provider<OsrmService>((ref) => OsrmService());

class OutdoorRouteRequest {
  final CampusBuilding from;
  final CampusBuilding to;

  const OutdoorRouteRequest({required this.from, required this.to});

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is OutdoorRouteRequest &&
            other.from.id == from.id &&
            other.to.id == to.id;
  }

  @override
  int get hashCode => Object.hash(from.id, to.id);
}

/// Fetches the route when both from and to buildings are selected.
final outdoorRouteProvider =
    FutureProvider.family<OsrmRoute, OutdoorRouteRequest>(
  (ref, request) async {
    final service = ref.watch(osrmServiceProvider);
    return service.getRoute(
      from: request.from.routePoint,
      to: request.to.routePoint,
      displayFrom: request.from.location,
      displayTo: request.to.location,
    );
  },
);
