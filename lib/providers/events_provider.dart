import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import '../services/manual_event_location_store.dart';
import 'auth_provider.dart';

// ============================================
// Public events (filtered by user type)
// ============================================
final eventsProvider = FutureProvider<List<Event>>((ref) async {
  final api = ApiService();
  final auth = ref.watch(authProvider);

  // Filter events based on user type
  String? target;
  if (auth.user != null) {
    final type = auth.user!.userType;
    if (type == 'student') target = 'students';
    if (type == 'employee') target = 'employees';
  }

  final events = await ManualEventLocationStore.apply(
    await api.getEvents(target: target),
  );
  return events
      .where((event) => event.status == EventStatus.approved && event.isActive)
      .toList();
});

// ============================================
// My events (current user's created events)
// ============================================
final myEventsProvider = FutureProvider<List<Event>>((ref) async {
  final api = ApiService();
  final auth = ref.watch(authProvider);

  if (auth.token == null) return [];
  return ManualEventLocationStore.apply(await api.getMyEvents(auth.token!));
});

// ============================================
// Pending events (admin only)
// ============================================
final pendingEventsProvider = FutureProvider<List<Event>>((ref) async {
  final api = ApiService();
  final auth = ref.watch(authProvider);

  if (auth.token == null || !(auth.user?.isAdmin ?? false)) {
    return [];
  }
  return ManualEventLocationStore.apply(await api.getPendingEvents(auth.token!));
});

// ============================================
// Event stats (admin only)
// ============================================
final eventsStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final api = ApiService();
  final auth = ref.watch(authProvider);

  if (auth.token == null || !(auth.user?.isAdmin ?? false)) {
    return {};
  }
  return api.getEventsStats(auth.token!);
});
