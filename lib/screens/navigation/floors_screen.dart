import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_colors.dart';
import '../../config/app_constants.dart';
import '../../config/floor_config.dart';
import '../../widgets/map/floor_map_view.dart';

class FloorsScreen extends ConsumerStatefulWidget {
  const FloorsScreen({super.key});

  @override
  ConsumerState<FloorsScreen> createState() => _FloorsScreenState();
}

class _FloorsScreenState extends ConsumerState<FloorsScreen> {
  int _currentFloor = 0;

  @override
  Widget build(BuildContext context) {
    final config = FloorConfigs.forFloor(_currentFloor);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildBuildingBar(),
          Expanded(
            child: FloorMapView(floorConfig: config),
          ),
        ],
      ),
    );
  }

  // ===== Top green AppBar (like prototype) =====
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () {
          // Drawer/menu - implement later
        },
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
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: CircleAvatar(
            backgroundColor: AppColors.white.withOpacity(0.2),
            radius: 18,
            child: const Icon(
              Icons.park,
              color: AppColors.white,
              size: 20,
            ),
          ),
        ),
      ],
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
              color: AppColors.primary.withOpacity(0.15),
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
                      color: isSelected
                          ? AppColors.white
                          : AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  floor.name,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textPrimary,
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