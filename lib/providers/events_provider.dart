import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event.dart';
import '../services/api_service.dart';

// FutureProvider auto-handles loading/error/data states
final eventsProvider = FutureProvider<List<Event>>((ref) async {
  final api = ApiService();
  return api.getEvents();
});