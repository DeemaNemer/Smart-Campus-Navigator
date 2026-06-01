// screens/navigation/navigation_screen.dart
//
// Navigation screen — Live/Manual mode
// - Manual: المستخدم يختار موقعه يدوياً (للاختبار في البيت)
// - Live: WiFi scan تلقائي كل 3 ثواني

import 'package:flutter/material.dart' hide NavigationMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_colors.dart';
import '../../config/floor_config.dart';
import '../../models/room.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/rooms_provider.dart';
import '../../widgets/common/system_message.dart';
import '../../widgets/map/floor_map_view.dart';

class NavigationScreen extends ConsumerStatefulWidget {
  final Room destination;

  const NavigationScreen({super.key, required this.destination});

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen> {
  int _displayedFloor = 0;
  late final NavigationNotifier _navigationNotifier;

  @override
  void initState() {
    super.initState();
    _navigationNotifier = ref.read(navigationProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _navigationNotifier.startNavigationTo(widget.destination);
      setState(() => _displayedFloor = widget.destination.floor);
    });
  }

  @override
  void dispose() {
    _navigationNotifier.stopLiveUpdates();
    super.dispose();
  }

  Future<void> _onStartNavigation() async {
    final state = ref.read(navigationProvider);

    if (!state.hasLocation) {
      showSystemMessage(
        context,
        message: 'Please set your current location first.',
        icon: Icons.error_outline,
        color: AppColors.error,
      );
      return;
    }
    await _navigationNotifier.calculatePath();
    if (!mounted) return;
    // بعد ما يحسب المسار، خلي الخريطة تعرض طابق الـ source
    final newState = ref.read(navigationProvider);
    if (newState.path != null && newState.path!.path.isNotEmpty) {
      setState(() => _displayedFloor = newState.path!.path.first.floor);
    }
  }

  Future<void> _onStartLive() async {
    final ok = await _navigationNotifier.startLiveMode();
    if (!ok && mounted) {
      showSystemMessage(
        context,
        message: 'Could not start WiFi scanning. Check permissions.',
        icon: Icons.error_outline,
        color: AppColors.error,
      );
    }
  }

  Future<void> _onPickManualLocation() async {
    final picked = await _showRoomPicker();
    if (!mounted || picked == null) return;
    _navigationNotifier.setUserLocation(picked);
    setState(() => _displayedFloor = picked.floor);
  }

  Future<Room?> _showRoomPicker() async {
    return showModalBottomSheet<Room>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollCtrl) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.my_location, color: AppColors.accent),
                      const SizedBox(width: 8),
                      const Text(
                        'I am at...',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildRoomList(scrollCtrl, ctx)),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRoomList(ScrollController ctrl, BuildContext ctx) {
    return FutureBuilder<List<Room>>(
      future: _loadAllRooms(ref),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError || !snap.hasData) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        final allRooms = snap.data!;
        return ListView.builder(
          controller: ctrl,
          itemCount: allRooms.length,
          itemBuilder: (_, i) {
            final r = allRooms[i];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  'F${r.floor}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              title: Text(r.roomNumber ?? r.name),
              subtitle: Text(r.roomNumber == null ? r.type : r.name),
              onTap: () => Navigator.pop(ctx, r),
            );
          },
        );
      },
    );
  }

  Future<List<Room>> _loadAllRooms(WidgetRef ref) async {
    final all = <Room>[];
    for (int f = 0; f < 5; f++) {
      try {
        final rooms = await ref.read(roomsByFloorProvider(f).future);
        all.addAll(rooms);
      } catch (_) {}
    }
    all.sort((a, b) {
      final c = a.floor.compareTo(b.floor);
      if (c != 0) return c;
      return (a.roomNumber ?? a.name).compareTo(b.roomNumber ?? b.name);
    });
    return all;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(navigationProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.destination.roomNumber ?? widget.destination.name),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        toolbarHeight: 48,
      ),
      body: Column(
        children: [
          // ─── Mode Toggle (مدمج مع status) ───
          _buildTopBar(state),

          // ─── Floor Tabs ───
          if (state.path != null && state.path!.path.isNotEmpty)
            _buildFloorTabs(state),

          // ─── Map (الجزء الأكبر) ───
          Expanded(child: _buildMap(state)),

          // ─── Bottom Action Bar ───
          _buildBottomBar(state),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // Top bar: mode toggle + status (compact)
  // ═══════════════════════════════════════════════════
  Widget _buildTopBar(NavigationState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: AppColors.background,
      child: Column(
        children: [
          // Mode toggle
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _modeButton(
                    label: 'Manual',
                    icon: Icons.touch_app,
                    selected: state.mode == NavigationMode.manual,
                    onTap: () => ref
                        .read(navigationProvider.notifier)
                        .setMode(NavigationMode.manual),
                  ),
                ),
                Expanded(
                  child: _modeButton(
                    label: 'Live (WiFi)',
                    icon: Icons.wifi,
                    selected: state.mode == NavigationMode.live,
                    onTap: () {
                      ref
                          .read(navigationProvider.notifier)
                          .setMode(NavigationMode.live);
                      _onStartLive();
                    },
                  ),
                ),
              ],
            ),
          ),
          // Status row (مختصرة)
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.my_location,
                  color: AppColors.accent, size: 16),
              const SizedBox(width: 4),
              Expanded(child: _currentLocationText(state)),
              const Icon(Icons.location_on,
                  color: AppColors.error, size: 16),
              const SizedBox(width: 4),
              Text(
                widget.destination.roomNumber ?? widget.destination.name,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        state.error!,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _modeButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: selected ? AppColors.white : AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.white : AppColors.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _currentLocationText(NavigationState state) {
    if (state.mode == NavigationMode.manual) {
      if (state.userLocation == null) {
        return GestureDetector(
          onTap: _onPickManualLocation,
          child: const Text(
            'Tap to set your location',
            style: TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        );
      }
      return GestureDetector(
        onTap: _onPickManualLocation,
        child: Text(
          '${state.userLocation!.roomNumber} (F${state.userLocation!.floor})',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      );
    } else {
      if (state.liveX == null) {
        return Text(
          state.scanStatus ?? 'Scanning...',
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 12),
        );
      }
      final smoothedIcon = state.liveSmoothed ? ' 🛡️' : '';
      return Text(
        '${state.liveZone} (F${state.liveFloor}) '
        '${((state.liveConfidence ?? 0) * 100).toInt()}%$smoothedIcon',
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════
  // Floor tabs
  // ═══════════════════════════════════════════════════
  Widget _buildFloorTabs(NavigationState state) {
    final floorsInRoute =
        state.path!.path.map((p) => p.floor).toSet().toList()..sort();
    if (floorsInRoute.length < 2) return const SizedBox.shrink();

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: floorsInRoute.length,
        itemBuilder: (_, i) {
          final fl = floorsInRoute[i];
          final selected = fl == _displayedFloor;
          return Padding(
            padding: const EdgeInsets.only(right: 6, top: 4),
            child: ChoiceChip(
              label: Text('F$fl', style: const TextStyle(fontSize: 12)),
              selected: selected,
              onSelected: (_) => setState(() => _displayedFloor = fl),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: selected ? AppColors.white : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // Map — يأخذ كل المساحة المتاحة
  // ═══════════════════════════════════════════════════
  Widget _buildMap(NavigationState state) {
    final cfg = FloorConfigs.forFloor(_displayedFloor);

    double? userX, userY;
    double? destX, destY;

    // ─── Source marker: nearest corridor node (first path point on user's floor) ───
    // When a pixel-accurate path exists, the first point on the user's starting floor
    // is a corridor node — exactly where the marker should appear.
    final userFloor = state.currentFloor;
    if (state.path != null &&
        state.path!.path.isNotEmpty &&
        userFloor == _displayedFloor) {
      final firstOnFloor = state.path!.path
          .where((p) => p.floor == _displayedFloor)
          .toList();
      if (firstOnFloor.isNotEmpty) {
        userX = firstOnFloor.first.x;
        userY = firstOnFloor.first.y;
      }
    }
    // Fallback when no path yet: show at room door from RoomPixels
    if (userX == null) {
      if (state.userLocation != null &&
          state.userLocation!.floor == _displayedFloor) {
        final rn = state.userLocation!.roomNumber;
        if (rn != null) {
          final p = RoomPixels.get(_displayedFloor, rn);
          if (p != null) { userX = p.$1; userY = p.$2; }
        }
      } else if (state.mode == NavigationMode.live &&
          state.liveZone != null &&
          state.liveFloor == _displayedFloor) {
        final num = state.liveZone!.replaceAll(RegExp(r'[a-zA-Z_]'), '');
        if (num.isNotEmpty) {
          final p = RoomPixels.get(_displayedFloor, num);
          if (p != null) { userX = p.$1; userY = p.$2; }
        }
      }
    }

    // ─── Destination marker: always on the room door ───
    if (widget.destination.floor == _displayedFloor) {
      final roomNumber = widget.destination.roomNumber;
      if (roomNumber != null) {
        final p = RoomPixels.get(_displayedFloor, roomNumber);
        if (p != null) {
          destX = p.$1;
          destY = p.$2;
        }
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: FloorMapView(
        floorConfig: cfg,
        pathPoints: state.path?.path,
        userX: userX,
        userY: userY,
        destX: destX,
        destY: destY,
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // Bottom bar: action button + distance info
  // ═══════════════════════════════════════════════════
  Widget _buildBottomBar(NavigationState state) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.textLight.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.path != null && state.path!.success) ...[
            Row(
              children: [
                const Icon(Icons.straighten,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  '${state.path!.distance.toStringAsFixed(0)}m',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.directions_walk,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  '${state.path!.steps} pts',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                if (state.path!.instructions.isNotEmpty)
                  Flexible(
                    child: Text(
                      state.path!.instructions.first.text,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          _buildActionButton(state),
        ],
      ),
    );
  }

  Widget _buildActionButton(NavigationState state) {
    if (state.isCalculating) {
      return const SizedBox(
        height: 40,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.mode == NavigationMode.manual && state.userLocation == null) {
      return SizedBox(
        height: 40,
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _onPickManualLocation,
          icon: const Icon(Icons.my_location, size: 18),
          label: const Text('Set My Location'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
          ),
        ),
      );
    }

    return SizedBox(
      height: 40,
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: state.hasLocation ? _onStartNavigation : null,
        icon: const Icon(Icons.navigation, size: 18),
        label: Text(
          state.path != null ? 'Recalculate' : 'Start Navigation',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }
}
