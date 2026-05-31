import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_colors.dart';
import '../../../models/event.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/events_provider.dart';
import '../../../services/api_service.dart';
import '../../../widgets/common/birzeit_logo_mark.dart';

class MyEventsScreen extends ConsumerWidget {
  const MyEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(myEventsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Smart Campus Navigator'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 10),
            child: BirzeitLogoMark(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/events/create'),
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.add),
        label: const Text('Create Event'),
      ),
      body: eventsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => _buildError(context, ref, err.toString()),
        data: (events) => _buildList(context, ref, events),
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, List<Event> events) {
    if (events.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note, size: 80, color: AppColors.textLight),
            SizedBox(height: 16),
            Text(
              'No events yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            Text(
              'Events you create will appear here.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => ref.invalidate(myEventsProvider),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: events.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _MyEventCard(event: events[i], ref: ref),
      ),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: AppColors.error),
            const SizedBox(height: 16),
            const Text('Failed to load events'),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(myEventsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyEventCard extends StatelessWidget {
  final Event event;
  final WidgetRef ref;

  const _MyEventCard({required this.event, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/event', extra: event),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status badge
              Row(
                children: [
                  _buildStatusBadge(event.status),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.error, size: 20),
                    onPressed: () => _confirmDelete(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Title
              Text(
                event.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              // Date + Location
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 12, color: AppColors.textLight),
                  const SizedBox(width: 4),
                  Text(
                    event.dateTimeDisplay,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 12, color: AppColors.textLight),
                  const SizedBox(width: 4),
                  Text(
                    event.locationDisplay,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
              // Admin notes (if rejected)
              if (event.adminNotes != null && event.adminNotes!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: event.status == EventStatus.rejected
                        ? AppColors.error.withValues(alpha: 0.08)
                        : AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        event.status == EventStatus.rejected
                            ? Icons.warning_amber_outlined
                            : Icons.info_outline,
                        size: 14,
                        color: event.status == EventStatus.rejected
                            ? AppColors.error
                            : AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Admin: ${event.adminNotes}',
                          style: TextStyle(
                            fontSize: 11,
                            color: event.status == EventStatus.rejected
                                ? AppColors.error
                                : AppColors.primary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(EventStatus status) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case EventStatus.pending:
        color = AppColors.warning;
        icon = Icons.hourglass_empty;
        label = 'Pending';
        break;
      case EventStatus.approved:
        color = AppColors.success;
        icon = Icons.check_circle_outline;
        label = 'Approved';
        break;
      case EventStatus.rejected:
        color = AppColors.error;
        icon = Icons.cancel_outlined;
        label = 'Rejected';
        break;
      case EventStatus.unknown:
        color = AppColors.textLight;
        icon = Icons.help_outline;
        label = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Are you sure you want to delete "${event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final auth = ref.read(authProvider);
    if (auth.token == null) return;

    try {
      await ApiService().deleteEvent(auth.token!, event.id);
      ref.invalidate(myEventsProvider);
      ref.invalidate(eventsProvider);

      if (context.mounted) {
        _showSystemMessage(context, 'Event deleted');
      }
    } catch (e) {
      if (context.mounted) {
        _showSystemMessage(context, 'Failed to delete: $e', isError: true);
      }
    }
  }

  Future<void> _showSystemMessage(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    isError ? Icons.error_outline : Icons.info_outline,
                    color: isError ? AppColors.error : AppColors.info,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
