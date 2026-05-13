import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_colors.dart';
import '../../config/app_constants.dart';
import '../../config/floor_config.dart';
import '../../models/room.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/rooms_provider.dart';
import '../../widgets/map/floor_map_view.dart';

class NavigationScreen extends ConsumerStatefulWidget {
  final Room destination;

  const NavigationScreen({super.key, required this.destination});

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen> {
  late int _displayedFloor;

  @override
  void initState() {
    super.initState();
    _displayedFloor = widget.destination.floor;

    // Set the destination once when the screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(navigationProvider.notifier).setDestination(widget.destination);
    });
  }

  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(navigationProvider);
    final config = FloorConfigs.forFloor(_displayedFloor);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildBuildingBar(),
          Expanded(child: _buildMap(navState, config)),
          _buildBottomPanel(navState),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Smart Campus Navigator',
        style: TextStyle(
          color: AppColors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildBuildingBar() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(Icons.business, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 10),
          const Text(
            '${AppConstants.buildingName} (IT)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          // Floor display (changeable)
          GestureDetector(
            onTap: _showFloorPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primaryLight, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Floor $_displayedFloor',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right,
                      color: AppColors.primary, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(NavigationState navState, FloorConfig config) {
    return FloorMapView(
      floorConfig: config,
      pathPoints: navState.path?.path,
      // User marker only if user location is on the displayed floor
      userX: (navState.userLocation?.floor == _displayedFloor)
          ? navState.userLocation?.x
          : null,
      userY: (navState.userLocation?.floor == _displayedFloor)
          ? navState.userLocation?.y
          : null,
      // Destination marker only if destination is on the displayed floor
      destX: (widget.destination.floor == _displayedFloor)
          ? widget.destination.x
          : null,
      destY: (widget.destination.floor == _displayedFloor)
          ? widget.destination.y
          : null,
    );
  }

  // ===== Bottom panel with location cards + start button =====
  Widget _buildBottomPanel(NavigationState navState) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // "You Are Here" card
          _LocationCard(
            label: 'You Are Here',
            value: navState.userLocation?.name ?? 'Tap to set your location',
            isPlaceholder: navState.userLocation == null,
            onTap: _showLocationPicker,
          ),
          const SizedBox(height: 10),
          // "Your destination is" card
          _LocationCard(
            label: 'Your destination is',
            value: widget.destination.name,
            isPlaceholder: false,
            onTap: null,
          ),
          const SizedBox(height: 16),
          // Start Navigation button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: navState.isCalculating || !navState.isReady
                  ? null
                  : () {
                      ref.read(navigationProvider.notifier).calculatePath();
                    },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                disabledBackgroundColor:
                    AppColors.accent.withValues(alpha: 0.4),
              ),
              child: navState.isCalculating
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        color: AppColors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      navState.path != null
                          ? 'Recalculate'
                          : 'Start Navigation',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          // Error message
          if (navState.error != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      navState.error!,
                      style:
                          const TextStyle(color: AppColors.error, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Path info (distance + steps)
          if (navState.path != null && navState.path!.success) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _InfoChip(
                  icon: Icons.straighten,
                  label: '${navState.path!.distance.toStringAsFixed(1)}m',
                ),
                const SizedBox(width: 12),
                _InfoChip(
                  icon: Icons.directions_walk,
                  label: '${navState.path!.steps} steps',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ===== Floor picker bottom sheet =====
  void _showFloorPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Floor to View',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...FloorConfigs.all.map((floor) {
              final isSelected = floor.floor == _displayedFloor;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      isSelected ? AppColors.primary : AppColors.cardBg,
                  child: Text(
                    '${floor.floor}',
                    style: TextStyle(
                      color: isSelected ? AppColors.white : AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(floor.name),
                trailing: isSelected
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _displayedFloor = floor.floor);
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ===== Location picker bottom sheet =====
  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _LocationPickerSheet(
          scrollController: scrollController,
          onSelected: (room) {
            ref.read(navigationProvider.notifier).setUserLocation(room);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}

// =============================================
// Location card widget
// =============================================
class _LocationCard extends StatelessWidget {
  final String label;
  final String value;
  final bool isPlaceholder;
  final VoidCallback? onTap;

  const _LocationCard({
    required this.label,
    required this.value,
    required this.isPlaceholder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        color: isPlaceholder
                            ? AppColors.textLight
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        fontStyle:
                            isPlaceholder ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ),
                  if (onTap != null)
                    const Icon(Icons.edit,
                        color: AppColors.textLight, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================
// Info chip (distance, steps)
// =============================================
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================
// Location picker - bottom sheet to choose "I am here"
// =============================================
class _LocationPickerSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  final void Function(Room) onSelected;

  const _LocationPickerSheet({
    required this.scrollController,
    required this.onSelected,
  });

  @override
  ConsumerState<_LocationPickerSheet> createState() =>
      _LocationPickerSheetState();
}

class _LocationPickerSheetState extends ConsumerState<_LocationPickerSheet> {
  int _selectedFloor = 0;

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(roomsByFloorProvider(_selectedFloor));

    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Where Are You?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Pick the room closest to your location',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 16),
        // Floor tabs
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: FloorConfigs.all.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final floor = FloorConfigs.all[i];
              final isSelected = floor.floor == _selectedFloor;
              return GestureDetector(
                onTap: () => setState(() => _selectedFloor = floor.floor),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.cardBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Floor ${floor.floor}',
                    style: TextStyle(
                      color: isSelected ? AppColors.white : AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Room list
        Expanded(
          child: roomsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (err, _) => Center(
              child: Text('Error: $err',
                  style: const TextStyle(color: AppColors.error)),
            ),
            data: (rooms) => ListView.separated(
              controller: widget.scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: rooms.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final room = rooms[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: Icon(
                      _getIconForType(room.type),
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    room.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(room.typeLabel),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppColors.textLight),
                  onTap: () => widget.onSelected(room),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'office':
        return Icons.business_center;
      case 'lab':
        return Icons.science;
      case 'classroom':
        return Icons.school;
      case 'bathroom':
        return Icons.wc;
      default:
        return Icons.meeting_room;
    }
  }
}
