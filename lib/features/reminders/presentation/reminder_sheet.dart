import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pocket_tutor/app/theme/app_colors.dart';
import 'package:pocket_tutor/core/services/notification_service.dart';

void showReminderSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ReminderSheet(),
  );
}

class _ReminderSheet extends StatefulWidget {
  const _ReminderSheet();

  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  final _titleController = TextEditingController(text: 'Study Time! 📚');
  final _bodyController = TextEditingController(
    text: "Time to hit the books. Let's go!",
  );

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay(
    hour: TimeOfDay.now().hour + 1 > 23 ? 23 : TimeOfDay.now().hour + 1,
    minute: 0,
  );
  bool _repeatDaily = false;
  bool _isSaving = false;
  List<PendingNotificationRequest> _pendingReminders = [];

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    final list = await NotificationService.instance.getPendingReminders();
    if (mounted) setState(() => _pendingReminders = list);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primaryAccent,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primaryAccent,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _setReminder() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reminder title.')),
      );
      return;
    }

    final scheduledDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    if (!_repeatDaily && scheduledDate.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose a future date and time.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await NotificationService.instance.scheduleReminder(
        id: id,
        title: title,
        body: _bodyController.text.trim().isNotEmpty
            ? _bodyController.text.trim()
            : title,
        scheduledDate: scheduledDate,
        repeatDaily: _repeatDaily,
      );

      await _loadPending();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _repeatDaily
                  ? '✅ Daily reminder set for ${_selectedTime.format(context)}'
                  : '✅ Reminder set!',
            ),
            backgroundColor: AppColors.primaryAccent,
          ),
        );
        _titleController.text = 'Study Time! 📚';
        _bodyController.text = "Time to hit the books. Let's go!";
        _selectedDate = DateTime.now();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set reminder: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _cancelReminder(int id) async {
    await NotificationService.instance.cancelReminder(id);
    await _loadPending();
  }

  String _formatScheduledTime(String? body) {
    // body stores the notification body; we show it
    return body ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomPadding),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryAccent.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: AppColors.primaryAccent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Study Reminder',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Title field
            _label('Reminder Title'),
            const SizedBox(height: 8),
            _textField(
              controller: _titleController,
              hint: 'e.g. Study Physics',
              icon: Icons.title_rounded,
            ),

            const SizedBox(height: 16),

            // Body field
            _label('Message'),
            const SizedBox(height: 8),
            _textField(
              controller: _bodyController,
              hint: 'e.g. Review Chapter 3',
              icon: Icons.message_outlined,
            ),

            const SizedBox(height: 20),

            // Date & Time row
            Row(
              children: [
                Expanded(
                  child: _pickerTile(
                    icon: Icons.calendar_today_rounded,
                    label: 'Date',
                    value:
                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    onTap: _repeatDaily ? null : _pickDate,
                    muted: _repeatDaily,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _pickerTile(
                    icon: Icons.access_time_rounded,
                    label: 'Time',
                    value: _selectedTime.format(context),
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Daily repeat toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.repeat_rounded,
                    color: AppColors.primaryAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Repeat Daily',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Fire at the same time every day',
                          style: TextStyle(
                            color: AppColors.onSurfaceHint,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _repeatDaily,
                    onChanged: (v) => setState(() => _repeatDaily = v),
                    activeThumbColor: AppColors.primaryAccent,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Set Reminder button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _setReminder,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.alarm_add_rounded, color: Colors.white),
                label: Text(
                  _isSaving ? 'Setting...' : 'Set Reminder',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAccent,
                  disabledBackgroundColor: AppColors.onSurfaceMuted,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

            // Pending reminders section
            if (_pendingReminders.isNotEmpty) ...[
              const SizedBox(height: 28),
              Row(
                children: [
                  const Text(
                    'Scheduled Reminders',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      await NotificationService.instance.cancelAll();
                      await _loadPending();
                    },
                    child: const Text(
                      'Clear All',
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ..._pendingReminders.map(
                (r) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.alarm_rounded,
                        color: AppColors.primaryAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.title ?? 'Study Reminder',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            if ((r.body ?? '').isNotEmpty)
                              Text(
                                _formatScheduledTime(r.body),
                                style: const TextStyle(
                                  color: AppColors.onSurfaceHint,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.error,
                          size: 18,
                        ),
                        onPressed: () => _cancelReminder(r.id),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      color: AppColors.onSurfaceHint,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
  );

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.onSurfaceMuted),
        prefixIcon: Icon(icon, color: AppColors.primaryAccent, size: 20),
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryAccent),
        ),
      ),
    );
  }

  Widget _pickerTile({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback? onTap,
    bool muted = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: muted ? 0.4 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: muted ? AppColors.border : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primaryAccent, size: 18),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.onSurfaceHint,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
