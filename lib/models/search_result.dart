import 'room.dart';
import 'professor.dart';

enum SearchResultType { room, professor }

class SearchResult {
  final SearchResultType type;
  final Room? room;
  final Professor? professor;

  SearchResult.room(this.room)
      : type = SearchResultType.room,
        professor = null;

  SearchResult.professor(this.professor)
      : type = SearchResultType.professor,
        room = null;

  String get displayTitle {
    if (type == SearchResultType.room) {
      return room!.name;
    } else {
      return professor!.displayName;
    }
  }

  String get displaySubtitle {
    if (type == SearchResultType.room) {
      final r = room!;
      // "Lab • Room 505 • Floor 4"
      final parts = <String>[r.typeLabel];
      if (r.roomNumber != null && r.roomNumber!.isNotEmpty) {
        parts.add('Room ${r.roomNumber}');
      }
      parts.add('Floor ${r.floor}');
      return parts.join(' • ');
    } else {
      final p = professor!;
      // "Computer Engineering • Office 314 • Floor 2"
      final parts = <String>[];
      if (p.roomNumber != null) {
        parts.add('Office ${p.roomNumber}');
      }
      if (p.floor != null) {
        parts.add('Floor ${p.floor}');
      }
      return parts.isEmpty ? 'Professor' : parts.join(' • ');
    }
  }
}
