import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_colors.dart';
import '../../../config/floor_config.dart';
import '../../../models/room.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/events_provider.dart';
import '../../../providers/rooms_provider.dart';
import '../../../services/api_service.dart';
import '../../../widgets/common/birzeit_logo_mark.dart';

class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _customLocationController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  Room? _selectedRoom;
  String _targetAudience = 'all'; // students/employees/all

  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _customLocationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _pickRoom() async {
    final result = await showModalBottomSheet<Room>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) =>
            _RoomPickerSheet(scrollController: scrollController),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedRoom = result;
        // Selecting a room means we use DB location, so clear manual location.
        _customLocationController.clear();
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null) {
      setState(() => _error = 'Please pick a date');
      return;
    }
    if (_selectedTime == null) {
      setState(() => _error = 'Please pick a time');
      return;
    }
    if (_selectedRoom == null && _customLocationController.text.trim().isEmpty) {
      setState(() => _error = 'Please pick a location');
      return;
    }

    final auth = ref.read(authProvider);
    if (auth.token == null) {
      setState(() => _error = 'Please sign in first');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final api = ApiService();

      final dateStr =
          '${_selectedDate!.year.toString().padLeft(4, '0')}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';
      final timeStr =
          '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';

      final result = await api.createEvent(
        token: auth.token!,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        date: dateStr,
        time: timeStr,
        locationRoomId: _selectedRoom?.id,
        locationText: _customLocationController.text.trim().isEmpty
            ? null
            : _customLocationController.text.trim(),
        targetAudience: _targetAudience,
      );

      // Refresh events list
      ref.invalidate(myEventsProvider);
      ref.invalidate(eventsProvider);

      if (!mounted) return;

      // Show success and pop
      final message = result['message'] as String? ?? 'Event created';
      await _showSubmissionMessage(message);
      if (!mounted) return;
      context.pop();
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _showSubmissionMessage(String message) async {
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.info_outline,
                        color: AppColors.info, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
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

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(authProvider).user?.isAdmin ?? false;

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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isAdmin) _buildInfoBanner(),
                const SizedBox(height: 16),
                _buildTitleField(),
                const SizedBox(height: 14),
                _buildDescriptionField(),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _buildDateField()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTimeField()),
                  ],
                ),
                const SizedBox(height: 14),
                _buildRoomField(),
                const SizedBox(height: 12),
                _buildCustomLocationField(),
                const SizedBox(height: 20),
                _buildAudienceSelector(),
                const SizedBox(height: 20),
                if (_error != null) _buildError(_error!),
                const SizedBox(height: 16),
                _buildSubmitButton(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.info, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Your event will be reviewed by an admin before publishing',
              style: TextStyle(color: AppColors.info, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
      decoration: const InputDecoration(
        labelText: 'Event Title',
        hintText: 'e.g., AI Workshop',
        prefixIcon: Icon(Icons.title, color: AppColors.primary),
      ),
      validator: (v) {
        if (v == null || v.trim().length < 3) {
          return 'Title must be at least 3 characters';
        }
        return null;
      },
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      maxLines: 3,
      decoration: const InputDecoration(
        labelText: 'Description (optional)',
        hintText: 'Tell people what your event is about...',
        prefixIcon: Icon(Icons.description_outlined, color: AppColors.primary),
        alignLabelWithHint: true,
      ),
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today,
                color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Text(
              _selectedDate == null
                  ? 'Date'
                  : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
              style: TextStyle(
                color: _selectedDate == null
                    ? AppColors.textLight
                    : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeField() {
    return InkWell(
      onTap: _pickTime,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Text(
              _selectedTime == null ? 'Time' : _selectedTime!.format(context),
              style: TextStyle(
                color: _selectedTime == null
                    ? AppColors.textLight
                    : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomField() {
    return InkWell(
      onTap: _pickRoom,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined,
                color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _selectedRoom == null
                    ? 'Location (pick a room)'
                    : '${_selectedRoom!.name} • Floor ${_selectedRoom!.floor}',
                style: TextStyle(
                  color: _selectedRoom == null
                      ? AppColors.textLight
                      : AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomLocationField() {
    return TextFormField(
      controller: _customLocationController,
      maxLines: 2,
      decoration: const InputDecoration(
        labelText: 'Or write custom location',
        hintText: 'e.g., Main Courtyard, Library Entrance',
        prefixIcon: Icon(Icons.edit_location_alt_outlined,
            color: AppColors.primary),
      ),
      onChanged: (value) {
        setState(() {
          // If user starts typing custom location, use it and clear room pick.
          if (value.trim().isNotEmpty) {
            _selectedRoom = null;
          }
        });
      },
    );
  }

  Widget _buildAudienceSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            'Who can see this event?',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Row(
          children: [
            _audienceOption('all', 'Everyone', Icons.public),
            const SizedBox(width: 8),
            _audienceOption('students', 'Students', Icons.school_outlined),
            const SizedBox(width: 8),
            _audienceOption('employees', 'Employees', Icons.work_outline),
          ],
        ),
      ],
    );
  }

  Widget _audienceOption(String value, String label, IconData icon) {
    final isSelected = _targetAudience == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _targetAudience = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.textLight,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color:
                      isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError(String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isSubmitting ? null : _handleSubmit,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 18),
      ),
      child: _isSubmitting
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            )
          : const Text(
              'Submit Event',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
    );
  }
}

// ============================================
// Room Picker Bottom Sheet
// ============================================
class _RoomPickerSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;

  const _RoomPickerSheet({required this.scrollController});

  @override
  ConsumerState<_RoomPickerSheet> createState() => _RoomPickerSheetState();
}

class _RoomPickerSheetState extends ConsumerState<_RoomPickerSheet> {
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
          'Pick a Location',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
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
        Expanded(
          child: roomsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (err, _) => Center(
              child: Text('Error: $err',
                  style: const TextStyle(color: AppColors.error)),
            ),
            data: (rooms) {
              // Filter out bathrooms - usually not used for events
              final eventRooms =
                  rooms.where((r) => r.type != 'bathroom').toList();

              return ListView.separated(
                controller: widget.scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: eventRooms.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final room = eventRooms[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.15),
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
                    onTap: () => Navigator.of(context).pop(room),
                  );
                },
              );
            },
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
        return Icons.computer_outlined;
      case 'classroom':
        return Icons.school;
      case 'bathroom':
        return Icons.wc;
      default:
        return Icons.meeting_room;
    }
  }
}
