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
  List<Map<String, dynamic>> _members = []; // {id, name}
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
      final projectData = data['project'] as Map<String, dynamic>? ?? data;
      final tasks = (projectData['tasks'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final members = (projectData['members'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .where((m) => m['id'] != null && m['name'] != null)
          .toList();
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _members = members;
          _loadingTasks = false;
        });
      }
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
    Map<String, dynamic>? assignedMember; // {id, name}

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
                    const SizedBox(height: 16),

                    // ── Assign to ──────────────────────────────────────────
                    if (_members.isNotEmpty) ...[
                      Text('Assign to',
                          style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getHeadingColor(ctx))),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: assignedMember != null
                                  ? AppColors.accent
                                  : AppColors.getBorderColor(ctx)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<Map<String, dynamic>?>(
                            value: assignedMember,
                            isExpanded: true,
                            dropdownColor: AppColors.getSurfaceColor(ctx),
                            style: GoogleFonts.outfit(
                                color: AppColors.getHeadingColor(ctx),
                                fontSize: 14),
                            hint: Text('Unassigned',
                                style: GoogleFonts.outfit(
                                    color: AppColors.getBodyColor(ctx),
                                    fontSize: 14)),
                            items: [
                              // Unassigned option
                              DropdownMenuItem<Map<String, dynamic>?>(
                                value: null,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: AppColors
                                          .getBorderColor(ctx)
                                          .withValues(alpha: 0.3),
                                      child: Icon(FeatherIcons.user,
                                          size: 12,
                                          color:
                                              AppColors.getBodyColor(ctx)),
                                    ),
                                    const SizedBox(width: 10),
                                    Text('Unassigned',
                                        style: GoogleFonts.outfit(
                                            color:
                                                AppColors.getBodyColor(ctx))),
                                  ],
                                ),
                              ),
                              // Project members
                              ..._members.map((member) =>
                                  DropdownMenuItem<Map<String, dynamic>?>(
                                    value: member,
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 12,
                                          backgroundColor: AppColors.accent
                                              .withValues(alpha: 0.18),
                                          child: Text(
                                            (member['name'] as String)
                                                .trim()[0]
                                                .toUpperCase(),
                                            style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.accent),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(member['name'] as String,
                                            style: GoogleFonts.outfit(
                                                color: AppColors
                                                    .getHeadingColor(ctx))),
                                      ],
                                    ),
                                  )),
                            ],
                            onChanged: (val) =>
                                setS(() => assignedMember = val),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

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
        if (assignedMember != null)
          'assigned_to': (assignedMember!['id'] as num).toInt(),
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

  /// Cycles status: todo → in_progress → done → todo
  String _nextStatus(String current) {
    if (current == 'todo') return 'in_progress';
    if (current == 'in_progress') return 'done';
    return 'todo';
  }

  Future<void> _changeTaskStatus(
      Map<String, dynamic> task, String newStatus) async {
    final projectId = int.tryParse(widget.project.id);
    final taskId = (task['id'] as num?)?.toInt();
    if (projectId == null || taskId == null) return;
    try {
      await _projectRepo.updateTaskStatus(projectId, taskId, newStatus);
      await _fetchTasks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _deleteTask(Map<String, dynamic> task) async {
    final projectId = int.tryParse(widget.project.id);
    final taskId = (task['id'] as num?)?.toInt();
    if (projectId == null || taskId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getSurfaceColor(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Task?',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: AppColors.getHeadingColor(ctx))),
        content: Text(
            'Are you sure you want to delete "${task['title']}"? This cannot be undone.',
            style: GoogleFonts.outfit(color: AppColors.getBodyColor(ctx))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: AppColors.getBodyColor(ctx))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await _projectRepo.deleteTask(projectId, taskId);
      await _fetchTasks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Task deleted'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to delete task: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Widget _buildTaskItem(BuildContext context, Map<String, dynamic> task) {
    final status        = task['status'] as String? ?? 'todo';
    final title         = task['title'] as String? ?? 'Untitled';
    final priority      = task['priority'] as String? ?? 'medium';
    final assigneeName  = task['assigned_to_name'] as String?;
    final dueDateRaw    = task['due_date'] as String?;
    final dueDate       = dueDateRaw != null ? DateTime.tryParse(dueDateRaw) : null;
    final isDone        = status == 'done';
    final isInProgress  = status == 'in_progress';

    Color statusColor;
    IconData statusIcon;
    String statusLabel;
    if (isDone) {
      statusColor = AppColors.doneColor;
      statusIcon  = Icons.check_circle;
      statusLabel = 'Done';
    } else if (isInProgress) {
      statusColor = AppColors.inProgressColor;
      statusIcon  = Icons.pending_actions;
      statusLabel = 'In Progress';
    } else {
      statusColor = AppColors.todoColor;
      statusIcon  = Icons.radio_button_unchecked;
      statusLabel = 'To Do';
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
          border: Border.all(
              color: isDone
                  ? AppColors.doneColor.withValues(alpha: 0.3)
                  : AppColors.getBorderColor(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // ── Tappable status icon ──────────────────────────────────
                Tooltip(
                  message: 'Tap to mark as: ${_nextStatus(status).replaceAll('_', ' ')}',
                  child: GestureDetector(
                    onTap: () => _changeTaskStatus(task, _nextStatus(status)),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(statusIcon,
                          key: ValueKey(status),
                          color: statusColor,
                          size: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // ── Title ─────────────────────────────────────────────────
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.outfit(
                      color: isDone
                          ? AppColors.getBodyColor(context)
                          : AppColors.getHeadingColor(context),
                      fontWeight: FontWeight.w600,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      decorationColor: AppColors.getBodyColor(context),
                    ),
                  ),
                ),

                // ── Priority badge ────────────────────────────────────────
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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

                // ── Delete button ─────────────────────────────────────────
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Delete task',
                  child: GestureDetector(
                    onTap: () => _deleteTask(task),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(FeatherIcons.trash2,
                          size: 13, color: Colors.red.shade400),
                    ),
                  ),
                ),
              ],
            ),

            // ── Sub-row: status label · assignee · due date ───────────────
            Padding(
              padding: const EdgeInsets.only(left: 34, top: 6),
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  // Status label
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            color: statusColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 5),
                      Text(statusLabel,
                          style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: statusColor,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),

                  // Assignee
                  if (assigneeName != null && assigneeName.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 8,
                          backgroundColor:
                              AppColors.accent.withValues(alpha: 0.18),
                          child: Text(
                            assigneeName.trim().isNotEmpty
                                ? assigneeName.trim()[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accent),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(assigneeName,
                            style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: AppColors.getBodyColor(context))),
                      ],
                    ),

                  // Due date
                  if (dueDate != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FeatherIcons.calendar,
                            size: 11,
                            color: dueDate.isBefore(DateTime.now()) && !isDone
                                ? Colors.red.shade400
                                : AppColors.getBodyColor(context)),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM d, y').format(dueDate),
                          style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: dueDate.isBefore(DateTime.now()) && !isDone
                                  ? Colors.red.shade400
                                  : AppColors.getBodyColor(context)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
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
