import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_colors.dart';
import '../../config/app_constants.dart';
import '../../config/floor_config.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/rooms_provider.dart';
import '../../widgets/map/floor_map_view.dart';

class FloorsScreen extends ConsumerStatefulWidget {
  const FloorsScreen({super.key});

  @override
  ConsumerState<FloorsScreen> createState() => _FloorsScreenState();
}

class _FloorsScreenState extends ConsumerState<FloorsScreen> {
  int _currentFloor = 0;
  String? _lastShownError;

  @override
  Widget build(BuildContext context) {
    final config = FloorConfigs.forFloor(_currentFloor);
    final navState = ref.watch(navigationProvider);
    final userLocation = navState.userLocation;
    final destination = navState.destination;

    ref.listen<NavigationState>(navigationProvider, (previous, next) {
      final error = next.error;
      if (error == null || error == _lastShownError) return;
      _lastShownError = error;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(error),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
      Future<void>.delayed(const Duration(seconds: 4), () {
        if (mounted && ref.read(navigationProvider).error == error) {
          ref.read(navigationProvider.notifier).clearError();
        }
      });
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildBuildingBar(),
          Expanded(
            child: FloorMapView(
              floorConfig: config,
              pathPoints: navState.path?.path,
              userX:
                  userLocation?.floor == _currentFloor ? userLocation?.x : null,
              userY:
                  userLocation?.floor == _currentFloor ? userLocation?.y : null,
              userRoomNumber: userLocation?.roomNumber ?? userLocation?.name,
              destX:
                  destination?.floor == _currentFloor ? destination?.x : null,
              destY:
                  destination?.floor == _currentFloor ? destination?.y : null,
              destRoomNumber: destination?.roomNumber ?? destination?.name,
            ),
          ),
          _buildNavigationPanel(navState),
        ],
      ),
    );
  }

  Widget _buildNavigationPanel(NavigationState navState) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRoomPicker(selectSource: true),
                    icon: const Icon(Icons.my_location),
                    label: Text(
                      navState.userLocation == null
                          ? 'Set Source'
                          : navState.userLocation!.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRoomPicker(selectSource: false),
                    icon: const Icon(Icons.place),
                    label: Text(
                      navState.destination == null
                          ? 'Set Destination'
                          : navState.destination!.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: navState.isLocating
                    ? null
                    : () async {
                        await ref
                            .read(navigationProvider.notifier)
                            .locateFromWifi();
                        final location =
                            ref.read(navigationProvider).userLocation;
                        if (mounted && location != null) {
                          setState(() => _currentFloor = location.floor);
                        }
                      },
                icon: navState.isLocating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_tethering),
                label: Text(navState.isLocating
                    ? 'Locating...'
                    : 'Use Live Indoor Location'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: navState.isCalculating || !navState.isReady
                    ? null
                    : () async {
                        await ref
                            .read(navigationProvider.notifier)
                            .calculatePath();
                        final location =
                            ref.read(navigationProvider).userLocation;
                        if (mounted && location != null) {
                          setState(() => _currentFloor = location.floor);
                        }
                      },
                icon: navState.isCalculating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Icon(Icons.alt_route),
                label: Text(navState.isCalculating
                    ? 'Calculating...'
                    : 'Start Navigation'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRoomPicker({required bool selectSource}) async {
    final rooms = await ref.read(roomsByFloorProvider(_currentFloor).future);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                selectSource ? 'Choose Source' : 'Choose Destination',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ...rooms.map((room) => ListTile(
                  leading: Icon(
                    selectSource ? Icons.my_location : Icons.place,
                    color: AppColors.primary,
                  ),
                  title: Text(room.name),
                  subtitle: Text('${room.typeLabel} - Floor ${room.floor}'),
                  onTap: () {
                    final notifier = ref.read(navigationProvider.notifier);
                    if (selectSource) {
                      notifier.setUserLocation(room);
                    } else {
                      notifier.setDestination(room);
                    }
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }

  // ===== Building name + floor selector =====
  Widget _buildBuildingBar() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Building icon + name
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.business,
              color: AppColors.primary,
              size: 20,
            ),
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
          // Floor selector pill
          _buildFloorSelector(),
        ],
      ),
    );
  }

  Widget _buildFloorSelector() {
    return GestureDetector(
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
              'Floor $_currentFloor',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              color: AppColors.primary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  // Bottom sheet to pick a floor
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
              'Select Floor',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...FloorConfigs.all.map((floor) {
              final isSelected = floor.floor == _currentFloor;
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
                title: Text(
                  floor.name,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color:
                        isSelected ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _currentFloor = floor.floor);
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
}
