import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:intl/intl.dart';
import '../../data/models/task_model.dart';
import '../providers/task_provider.dart';
import '../providers/api_providers.dart';
import '../../../../core/theme/app_colors.dart';

class CreateTaskDialog extends ConsumerStatefulWidget {
  const CreateTaskDialog({super.key});

  @override
  ConsumerState<CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends ConsumerState<CreateTaskDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _customSubjectController = TextEditingController();
  final _notesController = TextEditingController();
  final _questionsController = TextEditingController();

  TaskPriority _priority = TaskPriority.medium;
  String? _selectedSubject; // null = custom
  bool _useCustomSubject = false;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _dueTime = const TimeOfDay(hour: 23, minute: 59);

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _customSubjectController.dispose();
    _notesController.dispose();
    _questionsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppColors.accent,
            onPrimary: Colors.white,
            surface: AppColors.surface,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppColors.accent,
            onPrimary: Colors.white,
            surface: AppColors.surface,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dueTime = picked);
  }

  void _submit(List<String> channelNames) {
    if (!_formKey.currentState!.validate()) return;

    final subject = _useCustomSubject
        ? _customSubjectController.text.trim()
        : (_selectedSubject ?? (channelNames.isNotEmpty ? channelNames.first : 'General'));

    final deadline = DateTime(
      _dueDate.year,
      _dueDate.month,
      _dueDate.day,
      _dueTime.hour,
      _dueTime.minute,
    );

    final task = TaskModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      subject: subject,
      status: TaskStatus.todo,
      priority: _priority,
      dueDate: deadline,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      questions: _questionsController.text.trim().isEmpty
          ? null
          : _questionsController.text.trim(),
    );
    ref.read(taskProvider.notifier).addTask(task);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(channelsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<String> channelNames = channelsAsync.maybeWhen(
      data: (channels) => channels
          .map((c) =>
              c.subjectName.isNotEmpty ? c.subjectName : c.channelName)
          .toList(),
      orElse: () => [],
    );

    return FadeTransition(
      opacity: _fadeAnim,
      child: Dialog(
        backgroundColor:
            isDark ? AppColors.secondaryBackground : AppColors.lightSecondaryBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ─────────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(28, 24, 20, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accent.withValues(alpha: 0.15),
                      AppColors.accent.withValues(alpha: 0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.getBorderColor(context),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(FeatherIcons.plus,
                          color: AppColors.accent, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Create New Task',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getHeadingColor(context),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close,
                          color: AppColors.getBodyColor(context)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // ── Body ───────────────────────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 8),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        _SectionLabel(
                            label: 'Task Title', icon: FeatherIcons.fileText),
                        const SizedBox(height: 8),
                        _StyledField(
                          controller: _titleController,
                          hintText: 'e.g. Complete Assignment 3',
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Title is required' : null,
                        ),
                        const SizedBox(height: 20),

                        // Subject dropdown
                        _SectionLabel(
                            label: 'Subject', icon: FeatherIcons.bookOpen),
                        const SizedBox(height: 8),
                        if (channelsAsync.isLoading)
                          const Center(
                              child: CircularProgressIndicator(strokeWidth: 2))
                        else ...[
                          if (!_useCustomSubject) ...[
                            // Dropdown from enrolled subjects
                            DropdownButtonFormField<String>(
                              initialValue: _selectedSubject ??
                                  (channelNames.isNotEmpty
                                      ? channelNames.first
                                      : null),
                              isExpanded: true,
                              decoration: _fieldDecoration(context,
                                  hintText: 'Select subject'),
                              dropdownColor: isDark
                                  ? AppColors.secondaryBackground
                                  : AppColors.lightSecondaryBackground,
                              style: GoogleFonts.outfit(
                                color: AppColors.getHeadingColor(context),
                                fontSize: 14,
                              ),
                              items: [
                                ...channelNames.map((name) => DropdownMenuItem(
                                      value: name,
                                      child: Text(name),
                                    )),
                                DropdownMenuItem(
                                  value: '__custom__',
                                  child: Row(
                                    children: [
                                      Icon(FeatherIcons.plus,
                                          size: 14,
                                          color: AppColors.accent),
                                      const SizedBox(width: 6),
                                      Text('Create my own subject',
                                          style: TextStyle(
                                              color: AppColors.accent,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == '__custom__') {
                                  setState(() => _useCustomSubject = true);
                                } else {
                                  setState(() => _selectedSubject = value);
                                }
                              },
                              validator: (_) => null,
                            ),
                          ] else ...[
                            // Custom subject text field
                            Row(
                              children: [
                                Expanded(
                                  child: _StyledField(
                                    controller: _customSubjectController,
                                    hintText: 'Enter custom subject name',
                                    validator: (v) =>
                                        v == null || v.trim().isEmpty
                                            ? 'Subject is required'
                                            : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Tooltip(
                                  message: 'Pick from enrolled subjects',
                                  child: IconButton(
                                    icon: Icon(FeatherIcons.list,
                                        color: AppColors.accent),
                                    onPressed: () => setState(
                                        () => _useCustomSubject = false),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                        const SizedBox(height: 20),

                        // Description
                        _SectionLabel(
                            label: 'Description',
                            icon: FeatherIcons.alignLeft),
                        const SizedBox(height: 8),
                        _StyledField(
                          controller: _descriptionController,
                          hintText: 'What does this task involve?',
                          maxLines: 3,
                        ),
                        const SizedBox(height: 20),

                        // Priority + Deadline row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _SectionLabel(
                                      label: 'Priority',
                                      icon: FeatherIcons.flag),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<TaskPriority>(
                                    initialValue: _priority,
                                    isExpanded: true,
                                    decoration:
                                        _fieldDecoration(context, hintText: ''),
                                    dropdownColor: isDark
                                        ? AppColors.secondaryBackground
                                        : AppColors.lightSecondaryBackground,
                                    style: GoogleFonts.outfit(
                                      color: AppColors.getHeadingColor(context),
                                      fontSize: 14,
                                    ),
                                    items: TaskPriority.values
                                        .map((p) => DropdownMenuItem(
                                              value: p,
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: _priorityColor(p),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(p.name.toUpperCase()),
                                                ],
                                              ),
                                            ))
                                        .toList(),
                                    onChanged: (value) =>
                                        setState(() => _priority = value!),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _SectionLabel(
                                      label: 'Deadline Date',
                                      icon: FeatherIcons.calendar),
                                  const SizedBox(height: 8),
                                  _DeadlineButton(
                                    icon: FeatherIcons.calendar,
                                    label: DateFormat('MMM d, yyyy')
                                        .format(_dueDate),
                                    onTap: _pickDate,
                                    context: context,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Deadline time
                        _SectionLabel(
                            label: 'Deadline Time', icon: FeatherIcons.clock),
                        const SizedBox(height: 8),
                        _DeadlineButton(
                          icon: FeatherIcons.clock,
                          label: _dueTime.format(context),
                          onTap: _pickTime,
                          context: context,
                        ),
                        const SizedBox(height: 20),

                        // Notes
                        _SectionLabel(
                            label: 'Notes',
                            icon: FeatherIcons.edit3),
                        const SizedBox(height: 4),
                        Text(
                          'Add any personal notes or reminders for this task',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: AppColors.getBodyColor(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _StyledField(
                          controller: _notesController,
                          hintText:
                              'e.g. Remember to check lecture slides first...',
                          maxLines: 3,
                        ),
                        const SizedBox(height: 20),

                        // Questions
                        _SectionLabel(
                            label: 'Questions to Ask',
                            icon: FeatherIcons.helpCircle),
                        const SizedBox(height: 4),
                        Text(
                          'Note down questions you want to clarify with your teacher',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: AppColors.getBodyColor(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _StyledField(
                          controller: _questionsController,
                          hintText:
                              'e.g. What is the expected output format?...',
                          maxLines: 3,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Actions ────────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(28, 16, 28, 20),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.getBorderColor(context)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.outfit(
                          color: AppColors.getBodyColor(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_task_rounded,
                          size: 18, color: Colors.white),
                      label: Text(
                        'Create Task',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: () => _submit(channelNames),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _priorityColor(TaskPriority p) {
    switch (p) {
      case TaskPriority.high:
        return AppColors.priorityHigh;
      case TaskPriority.medium:
        return AppColors.priorityMedium;
      case TaskPriority.low:
        return AppColors.priorityLow;
    }
  }

  InputDecoration _fieldDecoration(BuildContext context,
      {required String hintText}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.outfit(
          color: AppColors.getBodyColor(context).withValues(alpha: 0.5),
          fontSize: 13),
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.04)
          : Colors.black.withValues(alpha: 0.03),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.getBorderColor(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.getBorderColor(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: AppColors.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final int maxLines;
  final String? Function(String?)? validator;

  const _StyledField({
    required this.controller,
    required this.hintText,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: GoogleFonts.outfit(
        color: AppColors.getHeadingColor(context),
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.outfit(
            color: AppColors.getBodyColor(context).withValues(alpha: 0.5),
            fontSize: 13),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.getBorderColor(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.getBorderColor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.accent),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.getHeadingColor(context),
          ),
        ),
      ],
    );
  }
}

class _DeadlineButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final BuildContext context;

  const _DeadlineButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.context,
  });

  @override
  Widget build(BuildContext ctx) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.getBorderColor(ctx)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.accent),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppColors.getHeadingColor(ctx),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
