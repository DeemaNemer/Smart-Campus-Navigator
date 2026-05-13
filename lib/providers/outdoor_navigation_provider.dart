import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/campus_building.dart';
import '../services/osrm_service.dart';

final osrmServiceProvider = Provider<OsrmService>((ref) => OsrmService());

class OutdoorRouteRequest {
  final CampusBuilding from;
  final CampusBuilding to;
  const OutdoorRouteRequest({required this.from, required this.to});
}

/// Fetches the route when both from and to buildings are selected.
final outdoorRouteProvider =
    FutureProvider.family<OsrmRoute, OutdoorRouteRequest>(
  (ref, request) async {
    final service = ref.watch(osrmServiceProvider);
    return service.getRoute(
      from: request.from.location,
      to: request.to.location,
    );
  },
);