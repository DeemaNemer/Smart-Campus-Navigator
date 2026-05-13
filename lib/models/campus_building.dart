import 'package:latlong2/latlong.dart';

class CampusBuilding {
  final String id;
  final String nameEn;
  final String nameAr;
  final LatLng location;
  final LatLng? routingLocation;
  final String? description;

  const CampusBuilding({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.location,
    this.routingLocation,
    this.description,
  });

  LatLng get routePoint => routingLocation ?? location;
}
