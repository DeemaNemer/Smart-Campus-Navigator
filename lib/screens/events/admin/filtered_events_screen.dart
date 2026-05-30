import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_colors.dart';
import '../../../models/event.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/events_provider.dart';
import '../../../services/api_service.dart';
import '../../../widgets/common/birzeit_logo_mark.dart';

// Filter type for admin event listing
enum AdminFilter { pending, approved, rejected }

final adminFilteredEventsProvider =
    FutureProvider.family<List<Event>, AdminFilter>((ref, filter) async {
  final auth = ref.watch(authProvider);
  if (auth.token == null || !(auth.user?.isAdmin ?? false)) return [];

  final api = ApiService();
  return api.getEventsByStatus(auth.token!, filter.name);
});

class FilteredEventsScreen extends ConsumerWidget {
  final AdminFilter filter;

  const FilteredEventsScreen({super.key, required this.filter});

  String get _title {
    switch (filter) {
      case AdminFilter.pending:
        return 'Pending Events';
      case AdminFilter.approved:
        return 'Approved Events';
      case AdminFilter.rejected:
        return 'Rejected Events';
    }
  }

  Color get _color {
    switch (filter) {
      case AdminFilter.pending:
        return AppColors.warning;
      case AdminFilter.approved:
        return AppColors.success;
      case AdminFilter.rejected:
        return AppColors.error;
    }
  }

  IconData get _icon {
    switch (filter) {
      case AdminFilter.pending:
        return Icons.hourglass_empty;
      case AdminFilter.approved:
        return Icons.check_circle_outline;
      case AdminFilter.rejected:
        return Icons.cancel_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(adminFilteredEventsProvider(filter));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(_title),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 10),
            child: BirzeitLogoMark(),
          ),
        ],
      ),
      body: eventsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => _buildError(context, ref, err.toString()),
        data: (events) => _buildList(context, events),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<Event> events) {
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_icon, size: 80, color: AppColors.textLight),
            const SizedBox(height: 16),
            Text(
              'No ${filter.name} events',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nothing to show',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) =>
          _AdminEventCard(event: events[i], color: _color, icon: _icon, filter: filter),
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
              onPressed: () =>
                  ref.invalidate(adminFilteredEventsProvider(filter)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// Card for admin event (tappable, opens details)
class _AdminEventCard extends ConsumerWidget {
  final Event event;
  final Color color;
  final IconData icon;
  final AdminFilter filter;

  const _AdminEventCard({
    required this.event,
    required this.color,
    required this.icon,
    required this.filter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              // Status badge + audience
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 12, color: color),
                        const SizedBox(width: 4),
                        Text(
                          event.statusLabel,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Delete event',
                    icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                    onPressed: () => _handleDelete(context, ref),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      event.audienceLabel,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Title
              Text(
                event.title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              // Date / Location
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
                  const SizedBox(width: 12),
                  const Icon(Icons.location_on_outlined,
                      size: 12, color: AppColors.textLight),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      event.locationDisplay,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (event.creatorName != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 12, color: AppColors.textLight),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'By: ${event.creatorName}',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleDelete(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authProvider);
    if (auth.token == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Delete "${event.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService().deleteEvent(auth.token!, event.id);
      ref.invalidate(adminFilteredEventsProvider(filter));
      ref.invalidate(pendingEventsProvider);
      ref.invalidate(eventsStatsProvider);
      ref.invalidate(eventsProvider);
    } catch (_) {}
  }
}
