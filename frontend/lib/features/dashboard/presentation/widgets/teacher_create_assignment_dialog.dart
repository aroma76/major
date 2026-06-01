import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../providers/api_providers.dart';
import '../../data/models/channel_model.dart';

class TeacherCreateAssignmentDialog extends ConsumerStatefulWidget {
  const TeacherCreateAssignmentDialog({super.key});

  @override
  ConsumerState<TeacherCreateAssignmentDialog> createState() =>
      _TeacherCreateAssignmentDialogState();
}

class _TeacherCreateAssignmentDialogState
    extends ConsumerState<TeacherCreateAssignmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _marksCtrl = TextEditingController(text: '100');

  ChannelModel? _selectedChannel;
  DateTime? _dueDate;
  String _priority = 'medium';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _marksCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: isDark
              ? ColorScheme.dark(
                  primary: AppColors.accent,
                  onPrimary: Colors.white,
                  surface: AppColors.surface,
                  onSurface: Colors.white,
                )
              : ColorScheme.light(
                  primary: AppColors.accent,
                  onPrimary: Colors.white,
                  onSurface: Colors.black87,
                ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedChannel == null) {
      setState(() => _error = 'Please select a subject');
      return;
    }
    if (_dueDate == null) {
      setState(() => _error = 'Please select a due date');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ApiService();
      await api.dio.post(
        '/channels/${_selectedChannel!.id}/assignments',
        data: {
          'title': _titleCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'due_date': _dueDate!.toIso8601String(),
          'max_marks': int.tryParse(_marksCtrl.text.trim()) ?? 100,
          'priority': _priority,
        },
      );
      // Invalidate so the assignments view refreshes
      ref.invalidate(channelAssignmentsProvider(_selectedChannel!.id));
      ref.invalidate(allAssignmentsProvider);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _error = 'Failed to create assignment. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(channelsProvider);

    return Dialog(
      backgroundColor: AppColors.getSurfaceColor(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(FeatherIcons.plusSquare,
                          color: AppColors.accent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Create Assignment',
                          style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getHeadingColor(context))),
                    ),
                    IconButton(
                      icon: const Icon(FeatherIcons.x, size: 18),
                      color: AppColors.getBodyColor(context),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Subject picker
                _fieldLabel('Subject *'),
                const SizedBox(height: 6),
                channelsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Could not load subjects',
                      style: TextStyle(color: AppColors.getBodyColor(context))),
                  data: (channels) => _styledDropdown<ChannelModel?>(
                    context: context,
                    value: _selectedChannel,
                    hint: 'Select a subject',
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Select a subject')),
                      ...channels.map((ch) => DropdownMenuItem(
                            value: ch,
                            child: Text(ch.subjectName.isNotEmpty
                                ? ch.subjectName
                                : ch.channelName),
                          )),
                    ],
                    onChanged: (v) => setState(() => _selectedChannel = v),
                  ),
                ),
                const SizedBox(height: 14),

                // Title
                _fieldLabel('Assignment Title *'),
                const SizedBox(height: 6),
                _styledField(
                  controller: _titleCtrl,
                  hint: 'e.g. Lab 3: Linked List Implementation',
                  context: context,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Title is required'
                      : null,
                ),
                const SizedBox(height: 14),

                // Description
                _fieldLabel('Description'),
                const SizedBox(height: 6),
                _styledField(
                  controller: _descCtrl,
                  hint: 'Instructions, requirements...',
                  context: context,
                  maxLines: 3,
                ),
                const SizedBox(height: 14),

                // Due date + Max marks
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('Due Date *'),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: _pickDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 13),
                              decoration: BoxDecoration(
                                color: AppColors.getBackgroundColor(context),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: AppColors.getBorderColor(context)),
                              ),
                              child: Row(
                                children: [
                                  Icon(FeatherIcons.calendar,
                                      size: 16,
                                      color: AppColors.getBodyColor(context)),
                                  const SizedBox(width: 8),
                                  Text(
                                    _dueDate == null
                                        ? 'Pick a date'
                                        : '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      color: _dueDate == null
                                          ? AppColors.getBodyColor(context)
                                          : AppColors.getHeadingColor(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('Max Marks'),
                          const SizedBox(height: 6),
                          _styledField(
                            controller: _marksCtrl,
                            hint: '100',
                            context: context,
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Priority
                _fieldLabel('Priority'),
                const SizedBox(height: 6),
                _styledDropdown<String>(
                  context: context,
                  value: _priority,
                  hint: 'Priority',
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                  ],
                  onChanged: (v) => setState(() => _priority = v ?? 'medium'),
                ),
                const SizedBox(height: 20),

                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: Colors.red.withValues(alpha: 0.4)),
                    ),
                    child: Text(_error!,
                        style:
                            const TextStyle(color: Colors.red, fontSize: 13)),
                  ),
                  const SizedBox(height: 12),
                ],

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: AppColors.getBorderColor(context)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Cancel',
                            style: TextStyle(
                                color: AppColors.getBodyColor(context))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text('Create Assignment',
                                style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(text,
      style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.getBodyColor(context)));

  Widget _styledField({
    required TextEditingController controller,
    required String hint,
    required BuildContext context,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) =>
      TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: GoogleFonts.outfit(
            fontSize: 13, color: AppColors.getHeadingColor(context)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.outfit(
              fontSize: 13, color: AppColors.getBodyColor(context)),
          filled: true,
          fillColor: AppColors.getBackgroundColor(context),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.getBorderColor(context))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.getBorderColor(context))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.accent, width: 1.5)),
        ),
      );

  Widget _styledDropdown<T>({
    required BuildContext context,
    required T value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.getBackgroundColor(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.getBorderColor(context)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            items: items,
            onChanged: onChanged,
            dropdownColor: AppColors.getSurfaceColor(context),
            style: GoogleFonts.outfit(
                fontSize: 13, color: AppColors.getHeadingColor(context)),
            icon: Icon(Icons.keyboard_arrow_down,
                size: 16, color: AppColors.getBodyColor(context)),
            borderRadius: BorderRadius.circular(12),
            isExpanded: true,
          ),
        ),
      );
}
