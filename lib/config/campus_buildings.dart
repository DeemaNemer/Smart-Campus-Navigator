import 'package:latlong2/latlong.dart';
import '../models/campus_building.dart';

/// Approximate coordinates of Birzeit University buildings.
/// IMPORTANT: These are approximate. Refine each one by:
/// 1. Going to https://www.openstreetmap.org
/// 2. Searching "Birzeit University"
/// 3. Right-clicking on the actual building location
/// 4. Choosing "Show address" to copy the lat/lng
class CampusBuildings {
  static const LatLng campusCenter = LatLng(31.9617, 35.1846);

  static const List<CampusBuilding> all = [
    CampusBuilding(
      id: 'masri',
      nameEn: 'Masri Building (IT)',
      nameAr: 'مبنى المصري (تكنولوجيا المعلومات)',
      location: LatLng(31.9617, 35.1843),
      description: 'Information Technology Faculty',
    ),
    CampusBuilding(
      id: 'bamieh',
      nameEn: 'Bamieh Building (Education)',
      nameAr: 'مبنى البامية (كلية التربية)',
      location: LatLng(31.9608, 35.1850),
      description: 'Education Faculty',
    ),
    CampusBuilding(
      id: 'aggad',
      nameEn: 'Aggad Building',
      nameAr: 'مبنى العقاد',
      location: LatLng(31.9615, 35.1838),
      description: 'Business and Economics',
    ),
    CampusBuilding(
      id: 'kamal_nasser',
      nameEn: 'Kamal Nasser Hall',
      nameAr: 'قاعة كمال ناصر',
      location: LatLng(31.9622, 35.1844),
    ),
    CampusBuilding(
      id: 'library',
      nameEn: 'Main Library',
      nameAr: 'المكتبة الرئيسية',
      location: LatLng(31.9614, 35.1841),
    ),
    CampusBuilding(
      id: 'najjad_zani',
      nameEn: 'Najjad Zani Center',
      nameAr: 'مركز نجاد زعني',
      location: LatLng(31.9611, 35.1840),
    ),
    CampusBuilding(
      id: 'masrouji_media',
      nameEn: 'Mohammad Masrouji Media Building',
      nameAr: 'مبنى محمد مصروجي للإعلام',
      location: LatLng(31.9619, 35.1837),
    ),
  ];

  static CampusBuilding byId(String id) =>
      all.firstWhere((b) => b.id == id);
}