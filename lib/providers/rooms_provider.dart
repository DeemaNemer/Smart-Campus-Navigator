import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/room.dart';
import '../services/api_service.dart';

// FutureProvider.family lets us pass a parameter (the floor number)
final roomsByFloorProvider =
    FutureProvider.family<List<Room>, int>((ref, floor) async {
  final api = ApiService();
  return api.getRooms(floor: floor);
});
