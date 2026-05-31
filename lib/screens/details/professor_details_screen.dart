import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../models/professor.dart';
import 'package:go_router/go_router.dart';
import '../../models/room.dart';

class ProfessorDetailsScreen extends StatelessWidget {
  final Professor professor;

  const ProfessorDetailsScreen({super.key, required this.professor});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildHeader(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildContactCard(),
                  const SizedBox(height: 16),
                  if (professor.roomNumber != null) _buildOfficeCard(),
                  const SizedBox(height: 32),
                  if (professor.roomNumber != null)
                    _buildNavigateButton(context),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== Header with avatar =====
  Widget _buildHeader(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      backgroundColor: AppColors.accent,
      foregroundColor: AppColors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () => Navigator.of(context).pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.accent, AppColors.accentDark],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 30),
                // Avatar circle
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(
                    _getInitials(professor.displayName),
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  professor.displayName,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===== Contact info card =====
  Widget _buildContactCard() {
    final hasArabicName =
        professor.nameAr.isNotEmpty && professor.nameAr != professor.nameEn;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Information',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (hasArabicName)
            _IconRow(
              icon: Icons.translate_outlined,
              label: 'Arabic Name',
              value: professor.nameAr,
            ),
          if (professor.email != null)
            _IconRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: professor.email!,
            ),
        ],
      ),
    );
  }

  // ===== Office location card =====
  Widget _buildOfficeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on_outlined,
                  color: AppColors.accent, size: 22),
              SizedBox(width: 8),
              Text(
                'Office Location',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DetailRow(label: 'Office', value: professor.roomNumber ?? '-'),
          const SizedBox(height: 8),
          _DetailRow(
            label: 'Floor',
            value: professor.floor?.toString() ?? '-',
          ),
          const SizedBox(height: 8),
          const _DetailRow(label: 'Building', value: 'IT Building'),
        ],
      ),
    );
  }

  Widget _buildNavigateButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          // Build a temporary Room representing the professor's office
          final officeRoom = Room(
            id: professor.officeRoomId ?? 0,
            name: 'Office ${professor.roomNumber}',
            roomNumber: professor.roomNumber,
            x: professor.x ?? 0,
            y: professor.y ?? 0,
            floor: professor.floor ?? 0,
            type: 'office',
          );
          context.push('/navigate', extra: officeRoom);
        },
        icon: const Icon(Icons.navigation),
        label: const Text(
          'Navigate to Office',
          style: TextStyle(fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

// ===== Icon row helper =====
class _IconRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _IconRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textLight, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===== Detail row helper =====
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
