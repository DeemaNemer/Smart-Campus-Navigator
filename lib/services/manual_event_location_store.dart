import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/event.dart';

class ManualEventLocationStore {
  static const _key = 'manual_event_locations';

  const ManualEventLocationStore._();

  static Future<void> save(int eventId, String locationText) async {
    final cleanText = locationText.trim();
    if (cleanText.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final locations = await _readAll(prefs);
    locations[eventId.toString()] = cleanText;
    await prefs.setString(_key, jsonEncode(locations));
  }

  static Future<void> remove(int eventId) async {
    final prefs = await SharedPreferences.getInstance();
    final locations = await _readAll(prefs);
    locations.remove(eventId.toString());
    await prefs.setString(_key, jsonEncode(locations));
  }

  static Future<List<Event>> apply(List<Event> events) async {
    final prefs = await SharedPreferences.getInstance();
    final locations = await _readAll(prefs);

    return events.map((event) {
      final manualLocation = locations[event.id.toString()];
      if (manualLocation == null || manualLocation.trim().isEmpty) {
        return event;
      }

      return event.copyWith(locationText: manualLocation);
    }).toList();
  }

  static Future<Map<String, String>> _readAll(SharedPreferences prefs) async {
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};

      return decoded.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } catch (_) {
      return {};
    }
  }
}
