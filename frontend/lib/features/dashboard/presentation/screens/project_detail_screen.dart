import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
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
  final _projectRepo = ProjectRepository();

  /// Tasks fetched from backend.
  List<Map<String, dynamic>> _tasks = [];

  /// Real project members: [{id: int, name: string}]
  List<Map<String, dynamic>> _members = [];

  bool _loadingTasks = true;

  @override
  void initState() {
    super.initState();
    _fetchProjectData();
  }

  // ── Data fetching ──────────────────────────────────────────────────────────

  Future<void> _fetchProjectData() async {
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
          .cast<Map<String, dynamic>>();
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

  // ── Task helpers ───────────────────────────────────────────────────────────

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
      await _fetchProjectData();
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
                backgroundColor: Colors.red.shade600,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: GoogleFonts.outfit(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await _projectRepo.deleteTask(projectId, taskId);
      await _fetchProjectData();
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

  // ── Add / Edit task dialog ─────────────────────────────────────────────────

  Future<void> _showTaskDialog({Map<String, dynamic>? existingTask}) async {
    final projectId = int.tryParse(widget.project.id);
    if (projectId == null) return;

    final isEditing = existingTask != null;
    final titleCtrl =
        TextEditingController(text: isEditing ? (existingTask['title'] as String?) ?? '' : '');
    final descCtrl =
        TextEditingController(text: isEditing ? (existingTask['description'] as String?) ?? '' : '');
    String priority = isEditing ? (existingTask['priority'] as String?) ?? 'medium' : 'medium';
    DateTime? dueDate;
    if (isEditing && existingTask['due_date'] != null) {
      dueDate = DateTime.tryParse(existingTask['due_date'] as String);
    }

    // Pre-select existing assignee
    Map<String, dynamic>? assignedMember;
    if (isEditing && existingTask['assigned_to_name'] != null) {
      final name = existingTask['assigned_to_name'] as String;
      try {
        assignedMember = _members.firstWhere(
          (m) => (m['name'] as String) == name,
        );
      } catch (_) {
        // name not found in current members — leave unassigned
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return Dialog(
            backgroundColor: AppColors.getSurfaceColor(ctx),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
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
                          child: Icon(
                              isEditing
                                  ? FeatherIcons.edit2
                                  : FeatherIcons.checkSquare,
                              color: AppColors.accent,
                              size: 18),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isEditing ? 'Edit Task' : 'Add Task',
                          style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getHeadingColor(ctx)),
                        ),
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
                    _dialogLabel(ctx, 'Task Title *'),
                    const SizedBox(height: 8),
                    _dialogTextField(
                        ctx: ctx,
                        controller: titleCtrl,
                        hint: 'e.g. Design login page',
                        isDark: isDark),
                    const SizedBox(height: 14),

                    // Description
                    _dialogLabel(ctx, 'Description (optional)'),
                    const SizedBox(height: 8),
                    _dialogTextField(
                        ctx: ctx,
                        controller: descCtrl,
                        hint: 'Brief description...',
                        isDark: isDark,
                        maxLines: 2),
                    const SizedBox(height: 14),

                    // Priority + Due Date row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Priority chips
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _dialogLabel(ctx, 'Priority'),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children:
                                    ['low', 'medium', 'high'].map((p) {
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
                            _dialogLabel(ctx, 'Due Date'),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: dueDate ??
                                      DateTime.now()
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

                    // ── Assign to ─────────────────────────────────────────────
                    if (_members.isNotEmpty) ...[
                      _dialogLabel(ctx, 'Assign to'),
                      const SizedBox(height: 8),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
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
                              DropdownMenuItem<Map<String, dynamic>?>(
                                value: null,
                                child: Row(children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: AppColors
                                        .getBorderColor(ctx)
                                        .withValues(alpha: 0.3),
                                    child: Icon(FeatherIcons.user,
                                        size: 12,
                                        color: AppColors.getBodyColor(ctx)),
                                  ),
                                  const SizedBox(width: 10),
                                  Text('Unassigned',
                                      style: GoogleFonts.outfit(
                                          color:
                                              AppColors.getBodyColor(ctx))),
                                ]),
                              ),
                              ..._members.map((member) =>
                                  DropdownMenuItem<Map<String, dynamic>?>(
                                    value: member,
                                    child: Row(children: [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor: AppColors.accent
                                            .withValues(alpha: 0.18),
                                        child: Text(
                                          (member['name'] as String)
                                              .trim()
                                              .isNotEmpty
                                              ? (member['name'] as String)
                                                  .trim()[0]
                                                  .toUpperCase()
                                              : '?',
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
                                    ]),
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
                          icon: Icon(
                              isEditing ? FeatherIcons.save : FeatherIcons.plus,
                              size: 16,
                              color: Colors.white),
                          label: Text(
                              isEditing ? 'Save Changes' : 'Add Task',
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

    final taskData = {
      'title': titleCtrl.text.trim(),
      if (descCtrl.text.trim().isNotEmpty) 'description': descCtrl.text.trim(),
      'priority': priority,
      if (dueDate != null) 'due_date': dueDate!.toIso8601String(),
      if (assignedMember != null)
        'assigned_to_name': assignedMember!['name'] as String,
      if (assignedMember == null) 'assigned_to_name': null,
    };

    try {
      if (isEditing) {
        final taskId = (existingTask['id'] as num).toInt();
        await _projectRepo.updateTask(
            int.parse(widget.project.id), taskId, taskData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Task updated!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ));
        }
      } else {
        await _projectRepo.createTask(
            int.parse(widget.project.id), taskData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Task "${titleCtrl.text.trim()}" added!'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
      await _fetchProjectData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ── Add member from classroom picker ──────────────────────────────────────

  Future<void> _showAddMemberSheet() async {
    final projectId = int.tryParse(widget.project.id);
    if (projectId == null) return;

    // Fetch available students
    List<Map<String, dynamic>> students = [];
    bool loading = true;
    String searchQuery = '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setS) {
          if (loading) {
            // Fetch in background
            _projectRepo.getClassroomStudents(projectId).then((result) {
              setS(() {
                students = result;
                loading = false;
              });
            }).catchError((_) {
              setS(() => loading = false);
            });
          }

          final filtered = students.where((s) {
            final name = (s['name'] as String? ?? '').toLowerCase();
            final roll = (s['roll_number'] as String? ?? '').toLowerCase();
            final q = searchQuery.toLowerCase();
            return q.isEmpty || name.contains(q) || roll.contains(q);
          }).toList();

          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            builder: (_, scrollCtrl) => Container(
              decoration: BoxDecoration(
                color: AppColors.getSurfaceColor(ctx),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.getBorderColor(ctx),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(FeatherIcons.userPlus,
                              color: AppColors.accent, size: 16),
                        ),
                        const SizedBox(width: 12),
                        Text('Add Team Member',
                            style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.getHeadingColor(ctx))),
                      ],
                    ),
                  ),

                  // Search box
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    child: TextField(
                      onChanged: (v) => setS(() => searchQuery = v),
                      style: GoogleFonts.outfit(
                          color: AppColors.getHeadingColor(ctx), fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search by name or roll number...',
                        hintStyle: GoogleFonts.outfit(
                            color: AppColors.getBodyColor(ctx), fontSize: 13),
                        prefixIcon: Icon(FeatherIcons.search,
                            size: 16, color: AppColors.getBodyColor(ctx)),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.black.withValues(alpha: 0.03),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: AppColors.getBorderColor(ctx))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppColors.accent, width: 1.5)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),

                  // Student list
                  Expanded(
                    child: loading
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.accent))
                        : filtered.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(FeatherIcons.users,
                                          size: 40,
                                          color: AppColors.getBodyColor(ctx)
                                              .withValues(alpha: 0.3)),
                                      const SizedBox(height: 12),
                                      Text(
                                        students.isEmpty
                                            ? 'No students available to add.\nAll classroom students are already members.'
                                            : 'No students match your search.',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.outfit(
                                            color:
                                                AppColors.getBodyColor(ctx),
                                            fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollCtrl,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 4),
                                itemCount: filtered.length,
                                itemBuilder: (_, i) {
                                  final student = filtered[i];
                                  final name =
                                      student['name'] as String? ?? '';
                                  final roll =
                                      student['roll_number'] as String? ?? '';
                                  final initial = name.isNotEmpty
                                      ? name[0].toUpperCase()
                                      : '?';
                                  return ListTile(
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            vertical: 4),
                                    leading: CircleAvatar(
                                      backgroundColor: AppColors.accent
                                          .withValues(alpha: 0.15),
                                      child: Text(initial,
                                          style: const TextStyle(
                                              color: AppColors.accent,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                    title: Text(name,
                                        style: GoogleFonts.outfit(
                                            color: AppColors.getHeadingColor(
                                                ctx),
                                            fontWeight: FontWeight.w600)),
                                    subtitle: roll.isNotEmpty
                                        ? Text(roll,
                                            style: GoogleFonts.outfit(
                                                color: AppColors.getBodyColor(
                                                    ctx),
                                                fontSize: 12))
                                        : null,
                                    trailing: ElevatedButton(
                                      onPressed: () async {
                                        final uid =
                                            (student['id'] as num).toInt();
                                        try {
                                          final newMember =
                                              await _projectRepo.addMember(
                                                  projectId, uid);
                                          if (mounted) {
                                            setState(() {
                                              _members.add(newMember);
                                              students.removeWhere(
                                                  (s) => s['id'] == uid);
                                            });
                                            setS(() {
                                              students.removeWhere(
                                                  (s) => s['id'] == uid);
                                            });
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                              content: Text(
                                                  '$name added to project!'),
                                              backgroundColor:
                                                  Colors.green.shade700,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                            ));
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                              content: Text('Failed: $e'),
                                              backgroundColor:
                                                  Colors.red.shade700,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                            ));
                                          }
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.accent,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                      child: Text('Add',
                                          style: GoogleFonts.outfit(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13)),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    final projectId = int.tryParse(widget.project.id);
    if (projectId == null) return;
    final userId = (member['id'] as num).toInt();
    final name = member['name'] as String? ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getSurfaceColor(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove Member?',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: AppColors.getHeadingColor(ctx))),
        content: Text('Remove "$name" from this project?',
            style: GoogleFonts.outfit(color: AppColors.getBodyColor(ctx))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style:
                    GoogleFonts.outfit(color: AppColors.getBodyColor(ctx))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove',
                style: GoogleFonts.outfit(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await _projectRepo.removeMember(projectId, userId);
      setState(() =>
          _members.removeWhere((m) => (m['id'] as num).toInt() == userId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$name removed from project'),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to remove member: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
            _buildTasksSection(context),
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
                  context, 'Tasks', '${_tasks.length} total', FeatherIcons.list),
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
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Team Members',
                style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getHeadingColor(context))),
            ElevatedButton.icon(
              onPressed: _showAddMemberSheet,
              icon: const Icon(FeatherIcons.userPlus,
                  size: 14, color: Colors.white),
              label: Text('Add Member',
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Member boxes
        if (_members.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.getSurfaceColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.getBorderColor(context)),
            ),
            child: Row(children: [
              Icon(FeatherIcons.users,
                  size: 16,
                  color: AppColors.getBodyColor(context)
                      .withValues(alpha: 0.4)),
              const SizedBox(width: 10),
              Text('No team members yet. Tap "Add Member" to invite classmates.',
                  style: GoogleFonts.outfit(
                      color: AppColors.getBodyColor(context), fontSize: 13)),
            ]),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _members.map((member) {
              final name = member['name'] as String? ?? '';
              final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
              return Container(
                padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor:
                        AppColors.accent.withValues(alpha: 0.2),
                    child: Text(initial,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accent)),
                  ),
                  const SizedBox(width: 8),
                  Text(name,
                      style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getHeadingColor(context))),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _removeMember(member),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.close_rounded,
                          size: 13, color: Colors.red.shade400),
                    ),
                  ),
                ]),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildTasksSection(BuildContext context) {
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
              onPressed: () => _showTaskDialog(),
              icon: const Icon(FeatherIcons.plus,
                  size: 16, color: AppColors.accent),
              label: Text('Add Task',
                  style: GoogleFonts.outfit(
                      color: AppColors.accent, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loadingTasks)
          const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
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
                    color: AppColors.getBodyColor(context)
                        .withValues(alpha: 0.4)),
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
    final assigneeName = task['assigned_to_name'] as String?;
    final dueDateRaw = task['due_date'] as String?;
    final dueDate =
        dueDateRaw != null ? DateTime.tryParse(dueDateRaw) : null;
    final isDone = status == 'done';
    final isInProgress = status == 'in_progress';

    Color statusColor;
    IconData statusIcon;
    String statusLabel;
    if (isDone) {
      statusColor = AppColors.doneColor;
      statusIcon = Icons.check_circle;
      statusLabel = 'Done';
    } else if (isInProgress) {
      statusColor = AppColors.inProgressColor;
      statusIcon = Icons.pending_actions;
      statusLabel = 'In Progress';
    } else {
      statusColor = AppColors.todoColor;
      statusIcon = Icons.radio_button_unchecked;
      statusLabel = 'To Do';
    }

    Color priorityColor;
    switch (priority) {
      case 'high':
        priorityColor = AppColors.priorityHigh;
        break;
      case 'low':
        priorityColor = AppColors.priorityLow;
        break;
      default:
        priorityColor = AppColors.priorityMedium;
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
                // Tappable status icon
                Tooltip(
                  message:
                      'Mark as: ${_nextStatus(status).replaceAll('_', ' ')}',
                  child: GestureDetector(
                    onTap: () =>
                        _changeTaskStatus(task, _nextStatus(status)),
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

                // Title
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.outfit(
                      color: isDone
                          ? AppColors.getBodyColor(context)
                          : AppColors.getHeadingColor(context),
                      fontWeight: FontWeight.w600,
                      decoration:
                          isDone ? TextDecoration.lineThrough : null,
                      decorationColor:
                          AppColors.getBodyColor(context),
                    ),
                  ),
                ),

                // Priority badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
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

                // Edit button
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Edit task',
                  child: GestureDetector(
                    onTap: () => _showTaskDialog(existingTask: task),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(FeatherIcons.edit2,
                          size: 13, color: AppColors.accent),
                    ),
                  ),
                ),

                // Delete button
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

            // Sub-row: status · assignee · due date
            Padding(
              padding: const EdgeInsets.only(left: 34, top: 6),
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  // Status label
                  Row(mainAxisSize: MainAxisSize.min, children: [
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
                  ]),

                  // Assignee
                  if (assigneeName != null && assigneeName.isNotEmpty)
                    Row(mainAxisSize: MainAxisSize.min, children: [
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
                    ]),

                  // Due date
                  if (dueDate != null)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(FeatherIcons.calendar,
                          size: 11,
                          color: dueDate.isBefore(DateTime.now()) &&
                                  !isDone
                              ? Colors.red.shade400
                              : AppColors.getBodyColor(context)),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM d, y').format(dueDate),
                        style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: dueDate.isBefore(DateTime.now()) &&
                                    !isDone
                                ? Colors.red.shade400
                                : AppColors.getBodyColor(context)),
                      ),
                    ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Dialog helpers ─────────────────────────────────────────────────────────

  Widget _dialogLabel(BuildContext ctx, String text) => Text(text,
      style: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppColors.getHeadingColor(ctx)));

  Widget _dialogTextField({
    required BuildContext ctx,
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    int maxLines = 1,
  }) =>
      TextField(
        controller: controller,
        maxLines: maxLines,
        style:
            GoogleFonts.outfit(color: AppColors.getHeadingColor(ctx), fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              GoogleFonts.outfit(color: AppColors.getBodyColor(ctx)),
          filled: true,
          fillColor: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.03),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: AppColors.getBorderColor(ctx))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: AppColors.getBorderColor(ctx))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.accent, width: 2)),
          contentPadding: const EdgeInsets.all(14),
        ),
      );
}
