import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../models/room.dart';
import '../../providers/events_provider.dart';
import '../../services/api_service.dart';

class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  Room? _selectedRoom;
  String _selectedCategory = 'All';
  List<Room> _rooms = [];
  bool _loadingRooms = false;

  final List<String> _categories = ['All', 'Students', 'Teachers', 'Others'];

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadRooms() async {
    setState(() => _loadingRooms = true);
    try {
      final rooms = await ApiService().getAllRoomsForPicker();
      setState(() {
        _rooms = rooms;
        _loadingRooms = false;
      });
    } catch (_) {
      setState(() => _loadingRooms = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
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

  void _showRoomPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RoomPickerSheet(
        rooms: _rooms,
        selectedRoom: _selectedRoom,
        onSelected: (room) {
          setState(() => _selectedRoom = room);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      _showSnack('Please select a date');
      return;
    }
    if (_selectedTime == null) {
      _showSnack('Please select a time');
      return;
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
    final timeStr =
        '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';

    await ref.read(createEventProvider.notifier).createEvent(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          date: dateStr,
          time: timeStr,
          locationRoomId: _selectedRoom?.id,
          targetCategory: _selectedCategory,
        );

    final state = ref.read(createEventProvider);
    if (state.success && mounted) {
      _showSnack('Event submitted for approval!', isSuccess: true);
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) context.pop();
    }
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createEventProvider);

    // Show error if any
    ref.listen(createEventProvider, (prev, next) {
      if (next.error != null && prev?.error != next.error) {
        _showSnack(next.error!);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Event'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildSectionLabel('Event Title *'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'e.g. AI Workshop, Guest Lecture...',
                prefixIcon: Icon(Icons.title, color: AppColors.primary),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 20),
            _buildSectionLabel('Description'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Describe the event...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            _buildSectionLabel('Date & Time *'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildDateButton()),
                const SizedBox(width: 12),
                Expanded(child: _buildTimeButton()),
              ],
            ),
            const SizedBox(height: 20),
            _buildSectionLabel('Location (Optional)'),
            const SizedBox(height: 8),
            _buildLocationButton(),
            const SizedBox(height: 20),
            _buildSectionLabel('Target Audience'),
            const SizedBox(height: 8),
            _buildCategorySelector(),
            const SizedBox(height: 12),
            _buildCategoryNote(),
            const SizedBox(height: 32),
            _buildSubmitButton(state),
            const SizedBox(height: 12),
            _buildAdminNote(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildDateButton() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today,
                color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _selectedDate == null
                    ? 'Pick Date'
                    : DateFormat('MMM d, yyyy').format(_selectedDate!),
                style: TextStyle(
                  color: _selectedDate == null
                      ? AppColors.textLight
                      : AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeButton() {
    return GestureDetector(
      onTap: _pickTime,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _selectedTime == null
                    ? 'Pick Time'
                    : _selectedTime!.format(context),
                style: TextStyle(
                  color: _selectedTime == null
                      ? AppColors.textLight
                      : AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationButton() {
    return GestureDetector(
      onTap: _loadingRooms ? null : _showRoomPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: _loadingRooms
                  ? const Text('Loading rooms...',
                      style: TextStyle(
                          color: AppColors.textLight, fontSize: 14))
                  : Text(
                      _selectedRoom == null
                          ? 'Select a room (optional)'
                          : '${_selectedRoom!.name}${_selectedRoom!.roomNumber != null ? " • Room ${_selectedRoom!.roomNumber}" : ""}',
                      style: TextStyle(
                        color: _selectedRoom == null
                            ? AppColors.textLight
                            : AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
            if (_selectedRoom != null)
              GestureDetector(
                onTap: () => setState(() => _selectedRoom = null),
                child: const Icon(Icons.clear,
                    color: AppColors.textLight, size: 18),
              )
            else
              const Icon(Icons.arrow_drop_down, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Wrap(
      spacing: 8,
      children: _categories.map((cat) {
        final isSelected = _selectedCategory == cat;
        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : AppColors.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                    isSelected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Text(
              cat,
              style: TextStyle(
                color:
                    isSelected ? AppColors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCategoryNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.info, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _selectedCategory == 'All'
                  ? 'All users will receive this announcement.'
                  : 'Only $_selectedCategory will receive this announcement.',
              style: const TextStyle(
                  color: AppColors.info, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(CreateEventState state) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: state.isLoading ? null : _submit,
        icon: state.isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: AppColors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.send),
        label: Text(
          state.isLoading ? 'Submitting...' : 'Submit for Approval',
          style: const TextStyle(fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          disabledBackgroundColor: AppColors.accent.withOpacity(0.6),
        ),
      ),
    );
  }

  Widget _buildAdminNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.pending_outlined, color: AppColors.warning, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your event will be reviewed by an administrator before it is published.',
              style: TextStyle(
                color: AppColors.warning,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Bottom sheet لاختيار الغرفة
class _RoomPickerSheet extends StatefulWidget {
  final List<Room> rooms;
  final Room? selectedRoom;
  final void Function(Room) onSelected;

  const _RoomPickerSheet({
    required this.rooms,
    required this.selectedRoom,
    required this.onSelected,
  });

  @override
  State<_RoomPickerSheet> createState() => _RoomPickerSheetState();
}

class _RoomPickerSheetState extends State<_RoomPickerSheet> {
  String _search = '';

  List<Room> get _filtered {
    if (_search.isEmpty) return widget.rooms;
    final q = _search.toLowerCase();
    return widget.rooms
        .where((r) =>
            r.name.toLowerCase().contains(q) ||
            (r.roomNumber?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
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
                'Select Room',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: const InputDecoration(
                    hintText: 'Search rooms...',
                    prefixIcon:
                        Icon(Icons.search, color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _filtered.isEmpty
                    ? const Center(
                        child: Text('No rooms found',
                            style:
                                TextStyle(color: AppColors.textSecondary)))
                    : ListView.builder(
                        controller: controller,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final room = _filtered[i];
                          final isSelected =
                              widget.selectedRoom?.id == room.id;
                          return ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            tileColor: isSelected
                                ? AppColors.primary.withOpacity(0.1)
                                : null,
                            leading: Icon(
                              _iconForType(room.type),
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textLight,
                            ),
                            title: Text(
                              room.name,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              '${room.typeLabel} • Floor ${room.floor}${room.roomNumber != null ? " • Room ${room.roomNumber}" : ""}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle,
                                    color: AppColors.primary)
                                : null,
                            onTap: () => widget.onSelected(room),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'lab':
        return Icons.science_outlined;
      case 'office':
        return Icons.business_center_outlined;
      case 'classroom':
        return Icons.school_outlined;
      default:
        return Icons.meeting_room_outlined;
    }
  }
}