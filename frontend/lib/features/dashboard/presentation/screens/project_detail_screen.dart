import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/project_model.dart';
import '../../data/repositories/project_repository.dart';

class ProjectDetailScreen extends StatefulWidget {
  final ProjectModel project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final List<PlatformFile> _uploadedFiles = [];
  bool _isPicking = false;

  // Real tasks from backend
  final _projectRepo = ProjectRepository();
  List<Map<String, dynamic>> _tasks = [];
  bool _loadingTasks = true;

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    final id = int.tryParse(widget.project.id);
    if (id == null) {
      setState(() => _loadingTasks = false);
      return;
    }
    try {
      final data = await _projectRepo.getProject(id);
      final tasks = (data['project']?['tasks'] as List<dynamic>? ??
              data['tasks'] as List<dynamic>? ??
              [])
          .cast<Map<String, dynamic>>();
      if (mounted) setState(() { _tasks = tasks; _loadingTasks = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingTasks = false);
    }
  }

  Future<void> _addTask() async {
    final projectId = int.tryParse(widget.project.id);
    if (projectId == null) return;

    final titleCtrl = TextEditingController();
    final descCtrl  = TextEditingController();
    String priority = 'medium';
    DateTime? dueDate;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return Dialog(
            backgroundColor: AppColors.getSurfaceColor(ctx),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(28),
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
                          child: const Icon(FeatherIcons.checkSquare,
                              color: AppColors.accent, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Text('Add Task',
                            style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.getHeadingColor(ctx))),
                        const Spacer(),
                        IconButton(
                          icon: Icon(FeatherIcons.x,
                              size: 18, color: AppColors.getBodyColor(ctx)),
                          onPressed: () => Navigator.pop(ctx, false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Task title
                    Text('Task Title *',
                        style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getHeadingColor(ctx))),
                    const SizedBox(height: 8),
                    TextField(
                      controller: titleCtrl,
                      style: GoogleFonts.outfit(
                          color: AppColors.getHeadingColor(ctx), fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'e.g. Design login page',
                        hintStyle: GoogleFonts.outfit(
                            color: AppColors.getBodyColor(ctx)),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.black.withValues(alpha: 0.03),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: AppColors.getBorderColor(ctx))),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: AppColors.getBorderColor(ctx))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppColors.accent, width: 2)),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Description
                    Text('Description (optional)',
                        style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getHeadingColor(ctx))),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      style: GoogleFonts.outfit(
                          color: AppColors.getHeadingColor(ctx), fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Brief description...',
                        hintStyle: GoogleFonts.outfit(
                            color: AppColors.getBodyColor(ctx)),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.black.withValues(alpha: 0.03),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: AppColors.getBorderColor(ctx))),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: AppColors.getBorderColor(ctx))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppColors.accent, width: 2)),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Priority + Due Date row
                    Row(
                      children: [
                        // Priority chips
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Priority',
                                  style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.getHeadingColor(ctx))),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: ['low', 'medium', 'high'].map((p) {
                                  final colors = {
                                    'low': AppColors.priorityLow,
                                    'medium': AppColors.priorityMedium,
                                    'high': AppColors.priorityHigh,
                                  };
                                  final c = colors[p]!;
                                  final selected = priority == p;
                                  return GestureDetector(
                                    onTap: () => setS(() => priority = p),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 150),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? c.withValues(alpha: 0.18)
                                            : Colors.transparent,
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        border: Border.all(
                                            color: selected
                                                ? c
                                                : AppColors
                                                    .getBorderColor(ctx)),
                                      ),
                                      child: Text(p.toUpperCase(),
                                          style: GoogleFonts.outfit(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: selected
                                                  ? c
                                                  : AppColors
                                                      .getBodyColor(ctx))),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Due date picker
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Due Date',
                                style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.getHeadingColor(ctx))),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: DateTime.now()
                                      .add(const Duration(days: 7)),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  setS(() => dueDate = picked);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: dueDate != null
                                      ? AppColors.accent
                                          .withValues(alpha: 0.08)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: dueDate != null
                                          ? AppColors.accent
                                          : AppColors.getBorderColor(ctx)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(FeatherIcons.calendar,
                                        size: 14,
                                        color: dueDate != null
                                            ? AppColors.accent
                                            : AppColors.getBodyColor(ctx)),
                                    const SizedBox(width: 6),
                                    Text(
                                      dueDate == null
                                          ? 'Pick date'
                                          : DateFormat('MMM d, y')
                                              .format(dueDate!),
                                      style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          color: dueDate != null
                                              ? AppColors.accent
                                              : AppColors.getBodyColor(ctx),
                                          fontWeight: dueDate != null
                                              ? FontWeight.w600
                                              : FontWeight.normal),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text('Cancel',
                              style: GoogleFonts.outfit(
                                  color: AppColors.getBodyColor(ctx))),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: const Icon(FeatherIcons.plus,
                              size: 16, color: Colors.white),
                          label: Text('Add Task',
                              style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            elevation: 0,
                          ),
                          onPressed: () {
                            if (titleCtrl.text.trim().isEmpty) return;
                            Navigator.pop(ctx, true);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (confirmed != true) return;
    if (titleCtrl.text.trim().isEmpty) return;

    try {
      await _projectRepo.createTask(projectId, {
        'title': titleCtrl.text.trim(),
        if (descCtrl.text.trim().isNotEmpty) 'description': descCtrl.text.trim(),
        'priority': priority,
        if (dueDate != null) 'due_date': dueDate!.toIso8601String(),
      });
      await _fetchTasks(); // refresh the list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Task "${titleCtrl.text.trim()}" added!'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to add task: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _pickFiles() async {
    setState(() => _isPicking = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf', 'zip', 'png', 'jpg', 'jpeg', 'doc', 'docx',
          'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'md', 'mp4', 'rar', '7z'
        ],
        withData: true,
        allowMultiple: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() => _uploadedFiles.addAll(result.files));
      }
    } finally {
      setState(() => _isPicking = false);
    }
  }

  void _removeFile(int index) => setState(() => _uploadedFiles.removeAt(index));

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  IconData _iconForExt(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'pdf':
        return FeatherIcons.fileText;
      case 'zip':
      case 'rar':
      case '7z':
        return FeatherIcons.archive;
      case 'png':
      case 'jpg':
      case 'jpeg':
        return FeatherIcons.image;
      case 'doc':
      case 'docx':
      case 'txt':
      case 'md':
        return FeatherIcons.file;
      case 'xls':
      case 'xlsx':
        return FeatherIcons.grid;
      case 'ppt':
      case 'pptx':
        return FeatherIcons.monitor;
      case 'mp4':
        return FeatherIcons.video;
      default:
        return FeatherIcons.paperclip;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(FeatherIcons.arrowLeft,
              color: AppColors.getHeadingColor(context)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.project.title,
          style: GoogleFonts.outfit(
              color: AppColors.getHeadingColor(context),
              fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProgressSection(context),
            const SizedBox(height: 32),
            _buildTeamSection(context),
            const SizedBox(height: 32),
            _buildMilestonesSection(context),
            const SizedBox(height: 32),
            _buildFilesSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.getBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Overall Progress',
                style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getHeadingColor(context)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.project.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(widget.project.progress * 100).toInt()}%',
                  style: GoogleFonts.outfit(
                      color: widget.project.color,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: widget.project.progress,
              minHeight: 10,
              backgroundColor: AppColors.getBorderColor(context),
              valueColor:
                  AlwaysStoppedAnimation<Color>(widget.project.color),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildStat(
                  context,
                  'Deadline',
                  DateFormat('MMM d, y').format(widget.project.deadline),
                  FeatherIcons.calendar),
              const SizedBox(width: 32),
              _buildStat(
                  context, 'Status', 'In Progress', FeatherIcons.activity),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(
      BuildContext context, String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: AppColors.getBodyColor(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: AppColors.getBodyColor(context)),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.outfit(
                    color: AppColors.getBodyColor(context), fontSize: 12)),
            Text(value,
                style: GoogleFonts.outfit(
                    color: AppColors.getHeadingColor(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ],
        ),
      ],
    );
  }

  Widget _buildTeamSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Team Members',
          style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.getHeadingColor(context)),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: widget.project.teamMembers
              .map((member) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.getSurfaceColor(context),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: AppColors.getBorderColor(context)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // initials avatar — no external URL needed
                        CircleAvatar(
                          radius: 12,
                          backgroundColor:
                              AppColors.accent.withValues(alpha: 0.2),
                          child: Text(
                            member.isNotEmpty
                                ? member.trim()[0].toUpperCase()
                                : '?',
                            style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accent),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(member,
                            style: GoogleFonts.outfit(
                                color: AppColors.getHeadingColor(context),
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildMilestonesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tasks',
              style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getHeadingColor(context)),
            ),
            TextButton.icon(
              onPressed: _addTask,
              icon: const Icon(FeatherIcons.plus,
                  size: 16, color: AppColors.accent),
              label: Text('Add Task',
                  style: GoogleFonts.outfit(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loadingTasks)
          const Center(child: CircularProgressIndicator(color: AppColors.accent))
        else if (_tasks.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.getSurfaceColor(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.getBorderColor(context)),
            ),
            child: Row(
              children: [
                Icon(FeatherIcons.checkSquare,
                    size: 20,
                    color: AppColors.getBodyColor(context).withValues(alpha: 0.4)),
                const SizedBox(width: 12),
                Text(
                  'No tasks yet for this project.',
                  style: GoogleFonts.outfit(
                      color: AppColors.getBodyColor(context), fontSize: 14),
                ),
              ],
            ),
          )
        else
          ..._tasks.map((task) => _buildTaskItem(context, task)),
      ],
    );
  }

  Widget _buildTaskItem(BuildContext context, Map<String, dynamic> task) {
    final status = task['status'] as String? ?? 'todo';
    final title = task['title'] as String? ?? 'Untitled';
    final priority = task['priority'] as String? ?? 'medium';
    final isDone = status == 'done';
    final isInProgress = status == 'in_progress';

    Color statusColor;
    IconData statusIcon;
    if (isDone) {
      statusColor = AppColors.doneColor;
      statusIcon = Icons.check_circle;
    } else if (isInProgress) {
      statusColor = AppColors.inProgressColor;
      statusIcon = Icons.pending_actions;
    } else {
      statusColor = AppColors.todoColor;
      statusIcon = Icons.radio_button_unchecked;
    }

    Color priorityColor;
    switch (priority) {
      case 'high': priorityColor = AppColors.priorityHigh; break;
      case 'low':  priorityColor = AppColors.priorityLow;  break;
      default:     priorityColor = AppColors.priorityMedium;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.getBorderColor(context)),
        ),
        child: Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.outfit(
                  color: isDone
                      ? AppColors.getBodyColor(context)
                      : AppColors.getHeadingColor(context),
                  fontWeight: FontWeight.w500,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                  decorationColor: AppColors.getBodyColor(context),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: priorityColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                priority.toUpperCase(),
                style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: priorityColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // kept for compile safety — no longer called
  Widget _buildMilestoneItemOld(
      BuildContext context, String title, bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            color:
                isCompleted ? AppColors.doneColor : AppColors.getBodyColor(context),
            size: 20,
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: GoogleFonts.outfit(
              color: isCompleted
                  ? AppColors.getHeadingColor(context)
                  : AppColors.getBodyColor(context),
              fontWeight:
                  isCompleted ? FontWeight.w600 : FontWeight.normal,
              decoration:
                  isCompleted ? TextDecoration.lineThrough : null,
              decorationColor: AppColors.getBodyColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ────────────────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'File Uploads',
              style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getHeadingColor(context)),
            ),
            TextButton.icon(
              onPressed: _isPicking ? null : _pickFiles,
              icon: _isPicking
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.accent))
                  : const Icon(FeatherIcons.upload, size: 16,
                      color: AppColors.accent),
              label: Text(
                _isPicking ? 'Picking...' : 'Upload',
                style: GoogleFonts.outfit(
                    color: AppColors.accent, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Drop zone / file list ─────────────────────────────────────────────
        if (_uploadedFiles.isEmpty)
          GestureDetector(
            onTap: _isPicking ? null : _pickFiles,
            child: Container(
              padding: const EdgeInsets.all(32),
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.getSurfaceColor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.getBorderColor(context)),
              ),
              child: Column(
                children: [
                  Icon(FeatherIcons.uploadCloud,
                      size: 40,
                      color: AppColors.getBodyColor(context)
                          .withValues(alpha: 0.4)),
                  const SizedBox(height: 14),
                  Text(
                    'Click "Upload" or tap here to pick files',
                    style: GoogleFonts.outfit(
                        color: AppColors.getBodyColor(context),
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'PDF, ZIP, PNG, DOC, XLSX, PPT, MP4 (Max 50MB)',
                    style: GoogleFonts.outfit(
                        color: AppColors.getBodyColor(context)
                            .withValues(alpha: 0.5),
                        fontSize: 12),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: [
              // file list
              ..._uploadedFiles.asMap().entries.map((entry) {
                final i = entry.key;
                final file = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.getSurfaceColor(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.getBorderColor(context)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              AppColors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(_iconForExt(file.extension),
                            size: 16, color: AppColors.accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.name,
                              style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      AppColors.getHeadingColor(context)),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _formatSize(file.size),
                              style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color:
                                      AppColors.getBodyColor(context)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(FeatherIcons.x,
                            size: 16,
                            color: AppColors.getBodyColor(context)),
                        onPressed: () => _removeFile(i),
                        tooltip: 'Remove',
                      ),
                    ],
                  ),
                );
              }),
              // add more button
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: _isPicking ? null : _pickFiles,
                icon: const Icon(FeatherIcons.plus,
                    size: 14, color: AppColors.accent),
                label: Text('Add More Files',
                    style: GoogleFonts.outfit(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.accent.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
