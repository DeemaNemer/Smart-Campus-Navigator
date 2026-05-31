// screens/navigation/floors_screen.dart
//
// شاشة الـ Floors مع:
//   - Search bar في الأعلى (للوجهة)
//   - Floor selector tabs
//   - الخريطة في معظم الشاشة
//   - Bottom action button (Start) لما تختار وجهة
//
// ⚠️ هذا لا يحذف Search screen الموجود — كلاهما يعملوا

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_colors.dart';
import '../../config/floor_config.dart';
import '../../models/room.dart';
import '../../models/professor.dart';
import '../../models/search_result.dart';
import '../../services/api_service.dart';
import '../../widgets/map/floor_map_view.dart';

class FloorsScreen extends ConsumerStatefulWidget {
  const FloorsScreen({super.key});

  @override
  ConsumerState<FloorsScreen> createState() => _FloorsScreenState();
}

class _FloorsScreenState extends ConsumerState<FloorsScreen> {
  int _selectedFloor = 0;
  final _searchController = TextEditingController();
  List<SearchResult> _searchResults = [];
  Room? _selectedDestination;
  bool _isSearching = false;
  bool _showResultsList = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _showResultsList = false;
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _showResultsList = true;
    });
    try {
      final results = await ApiService().search(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _selectDestination(Room room) {
    setState(() {
      _selectedDestination = room;
      _selectedFloor = room.floor;
      _searchController.text = _roomLabel(room);
      _showResultsList = false;
      _searchResults = [];
    });
    FocusScope.of(context).unfocus();
  }

  void _selectProfessor(Professor prof) {
    if (prof.officeRoomId == null ||
        prof.x == null ||
        prof.y == null ||
        prof.floor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Professor office not available')),
      );
      return;
    }
    // نبني Room من الـ professor
    final room = Room(
      id: prof.officeRoomId!,
      roomNumber: prof.roomNumber,
      name: prof.displayName,
      type: 'office',
      x: prof.x!,
      y: prof.y!,
      floor: prof.floor!,
    );
    _selectDestination(room);
  }

  void _onStart() {
    if (_selectedDestination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a destination first'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    context.push('/navigate', extra: _selectedDestination!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ─── Search bar ───
            _buildSearchBar(),

            // ─── Results list (if searching) ───
            if (_showResultsList) Expanded(child: _buildResultsList()),

            // ─── Map area (when not searching) ───
            if (!_showResultsList) ...[
              _buildFloorTabs(),
              Expanded(child: _buildMap()),
              if (_selectedDestination != null) _buildStartBar(),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // Search Bar (top)
  // ═══════════════════════════════════════════════════
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      color: AppColors.background,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 16),
              child:
                  Icon(Icons.search, color: AppColors.textSecondary, size: 22),
            ),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: _onSearch,
                onTap: () {
                  if (_searchController.text.isNotEmpty) {
                    setState(() => _showResultsList = true);
                  }
                },
                decoration: const InputDecoration(
                  hintText: 'Search destination (room, professor)...',
                  hintStyle:
                      TextStyle(color: AppColors.textLight, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close,
                    color: AppColors.textSecondary, size: 20),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchResults = [];
                    _showResultsList = false;
                    _selectedDestination = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // Search Results (when typing)
  // ═══════════════════════════════════════════════════
  Widget _buildResultsList() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchResults.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No results. Try different keywords.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final r = _searchResults[i];
        if (r.type == SearchResultType.room) {
          final room = r.room!;
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: Text('F${room.floor}',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
            title: Text(_roomLabel(room)),
            subtitle: Text(room.name),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _selectDestination(room),
          );
        } else if (r.type == SearchResultType.professor) {
          final prof = r.professor!;
          return ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.accent,
              child: Icon(Icons.person, color: AppColors.white, size: 20),
            ),
            title: Text(prof.nameEn),
            subtitle: Text(prof.department ?? 'Professor'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _selectProfessor(prof),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  String _roomLabel(Room room) {
    return room.roomNumber ?? room.name;
  }

  // ═══════════════════════════════════════════════════
  // Floor tabs
  // ═══════════════════════════════════════════════════
  Widget _buildFloorTabs() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        itemBuilder: (_, i) {
          final selected = i == _selectedFloor;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                'Floor $i',
                style: const TextStyle(fontSize: 13),
              ),
              selected: selected,
              onSelected: (_) => setState(() => _selectedFloor = i),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: selected ? AppColors.white : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // Map area
  // ═══════════════════════════════════════════════════
  Widget _buildMap() {
    final cfg = FloorConfigs.forFloor(_selectedFloor);

    // إذا في destination محدّدة، نعرض pin عليها (لو على نفس الطابق)
    double? destX, destY;
    if (_selectedDestination != null &&
        _selectedDestination!.floor == _selectedFloor) {
      destX = _selectedDestination!.x;
      destY = _selectedDestination!.y;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: FloorMapView(
        floorConfig: cfg,
        destX: destX,
        destY: destY,
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // Bottom: Start Navigation
  // ═══════════════════════════════════════════════════
  Widget _buildStartBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: AppColors.accent, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _roomLabel(_selectedDestination!),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${_selectedDestination!.name} • Floor ${_selectedDestination!.floor}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _onStart,
            icon: const Icon(Icons.navigation, size: 18),
            label: const Text('Start'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
