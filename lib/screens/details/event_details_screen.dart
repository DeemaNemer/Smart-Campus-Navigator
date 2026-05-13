import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../models/event.dart';
import '../../models/room.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/events_provider.dart';
import '../../services/api_service.dart';

class EventDetailsScreen extends ConsumerWidget {
  final Event event;

  const EventDetailsScreen({super.key, required this.event});

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('EEEE, MMMM d, yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final dt = DateTime(0, 0, 0, hour, minute);
      return DateFormat('h:mm a').format(dt);
    } catch (_) {
      return timeStr;
    }
  }

  bool get _isUpcoming {
    try {
      final eventDate = DateTime.parse(event.date);
      return !eventDate.isBefore(DateTime.now());
    } catch (_) {
      return true;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  _buildStatusBadge(),
                  if (!_isUpcoming) ...[
                    const SizedBox(height: 16),
                    _buildPastEventNote(),
                  ],
                  const SizedBox(height: 16),
                  _buildInfoCard(),
                  if (event.description != null &&
                      event.description!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildDescriptionCard(),
                  ],
                  if (event.roomNumber != null) ...[
                    const SizedBox(height: 16),
                    _buildLocationCard(),
                  ],
                  const SizedBox(height: 32),
                  // Show admin actions if user is admin AND event is pending
                  if (_shouldShowAdminActions(ref))
                    _buildAdminActions(context, ref),
                  if (_shouldShowAdminActions(ref)) const SizedBox(height: 16),
                  if (event.roomNumber != null) _buildNavigateButton(context),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: AppColors.accent,
      foregroundColor: AppColors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: event.posterUrl != null
            ? _buildPosterImage()
            : _buildDefaultHeader(),
      ),
    );
  }

  Widget _buildPosterImage() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          event.posterUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildDefaultHeader(),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.6),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: Text(
            event.title,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultHeader() {
    return Container(
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
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event, size: 60, color: AppColors.white),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                event.title,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _isUpcoming
            ? AppColors.success.withValues(alpha: 0.15)
            : AppColors.textLight.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isUpcoming ? Icons.upcoming : Icons.history,
            size: 14,
            color: _isUpcoming ? AppColors.success : AppColors.textLight,
          ),
          const SizedBox(width: 6),
          Text(
            _isUpcoming ? 'Upcoming Event' : 'Past Event',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _isUpcoming ? AppColors.success : AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Event Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InfoRow(
            icon: Icons.calendar_today_outlined,
            label: 'Date',
            value: _formatDate(event.date),
          ),
          const Divider(height: 20),
          _InfoRow(
            icon: Icons.access_time,
            label: 'Time',
            value: _formatTime(event.time),
          ),
          if (event.roomNumber != null) ...[
            const Divider(height: 20),
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: 'Location',
              value: event.locationDisplay,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.description_outlined,
                  color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'About This Event',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            event.description!,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.6,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.map_outlined, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Venue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _InfoRow(
            icon: Icons.business_outlined,
            label: 'Building',
            value: 'IT Building',
          ),
          if (event.floor != null) ...[
            const Divider(height: 20),
            _InfoRow(
              icon: Icons.layers_outlined,
              label: 'Floor',
              value: 'Floor ${event.floor}',
            ),
          ],
          if (event.roomNumber != null) ...[
            const Divider(height: 20),
            _InfoRow(
              icon: Icons.meeting_room_outlined,
              label: 'Room',
              value: event.roomNumber!,
            ),
          ],
        ],
      ),
    );
  }

  bool _shouldShowAdminActions(WidgetRef ref) {
    final user = ref.read(authProvider).user;
    if (user == null || !user.isAdmin) return false;
    return event.status == EventStatus.pending;
  }

  Widget _buildAdminActions(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.admin_panel_settings,
                  color: AppColors.warning, size: 20),
              SizedBox(width: 8),
              Text(
                'Admin Actions',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _handleReject(context, ref),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _handleApprove(context, ref),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleApprove(BuildContext context, WidgetRef ref) async {
    final notes = await _showNotesDialog(
      context,
      title: 'Approve Event',
      hint: 'Optional notes for the creator',
      confirmLabel: 'Approve',
      confirmColor: AppColors.success,
    );

    if (notes == null) return;

    final auth = ref.read(authProvider);
    if (auth.token == null) return;

    try {
      await ApiService().approveEvent(
        token: auth.token!,
        eventId: event.id,
        adminNotes: notes.isEmpty ? null : notes,
      );

      ref.invalidate(pendingEventsProvider);
      ref.invalidate(eventsStatsProvider);
      ref.invalidate(eventsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event approved!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop(); // Close details screen
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleReject(BuildContext context, WidgetRef ref) async {
    final notes = await _showNotesDialog(
      context,
      title: 'Reject Event',
      hint: 'Reason for rejection (recommended)',
      confirmLabel: 'Reject',
      confirmColor: AppColors.error,
    );

    if (notes == null) return;

    final auth = ref.read(authProvider);
    if (auth.token == null) return;

    try {
      await ApiService().rejectEvent(
        token: auth.token!,
        eventId: event.id,
        adminNotes: notes.isEmpty ? null : notes,
      );

      ref.invalidate(pendingEventsProvider);
      ref.invalidate(eventsStatsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event rejected'),
            backgroundColor: AppColors.error,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<String?> _showNotesDialog(
    BuildContext context, {
    required String title,
    required String hint,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(
              confirmLabel,
              style: TextStyle(color: confirmColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigateButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          // نبني Room مؤقت من معلومات الحدث
          final eventRoom = Room(
            id: event.locationRoomId ?? 0,
            name: 'Event: ${event.title}',
            roomNumber: event.roomNumber,
            x: event.x!,
            y: event.y!,
            floor: event.floor!,
            type: 'classroom',
            description: 'Event location',
          );
          context.push('/navigate', extra: eventRoom);
        },
        icon: const Icon(Icons.navigation),
        label: const Text(
          'Get Directions to Event',
          style: TextStyle(fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  Widget _buildPastEventNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.textLight.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.info, color: AppColors.textLight, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'This event has already taken place.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
