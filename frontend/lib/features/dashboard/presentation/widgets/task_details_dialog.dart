import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/models/task_model.dart';
import '../providers/task_provider.dart';
import '../../../../core/theme/app_colors.dart';

class TaskDetailsDialog extends ConsumerWidget {
  final TaskModel task;

  const TaskDetailsDialog({super.key, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final priorityColor = _priorityColor(task.priority);

    return Dialog(
      backgroundColor: isDark
          ? AppColors.secondaryBackground
          : AppColors.lightSecondaryBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.12),
                    AppColors.accent.withValues(alpha: 0.03),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  bottom: BorderSide(color: AppColors.getBorderColor(context)),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(FeatherIcons.checkSquare,
                        color: priorityColor, size: 18),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getHeadingColor(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _PillBadge(
                              label: task.subject,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 6),
                            _PillBadge(
                              label: task.priority.name.toUpperCase(),
                              color: priorityColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close,
                        color: AppColors.getBodyColor(context), size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // ── Body ─────────────────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Meta row
                    Row(
                      children: [
                        Expanded(
                          child: _MetaCard(
                            icon: FeatherIcons.calendar,
                            label: 'Deadline',
                            value: DateFormat('MMM d, y • h:mm a')
                                .format(task.dueDate),
                            iconColor: const Color(0xFF58A6FF),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetaCard(
                            icon: FeatherIcons.activity,
                            label: 'Status',
                            value: _statusLabel(task.status),
                            iconColor: _statusColor(task.status),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Description
                    if (task.description.isNotEmpty) ...[
                      _DetailSection(
                        icon: FeatherIcons.alignLeft,
                        title: 'Description',
                        content: task.description,
                        accentColor: AppColors.accent,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Notes
                    if (task.notes != null && task.notes!.isNotEmpty) ...[
                      _DetailSection(
                        icon: FeatherIcons.edit3,
                        title: 'Notes',
                        content: task.notes!,
                        accentColor: const Color(0xFF3FB950),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Questions
                    if (task.questions != null &&
                        task.questions!.isNotEmpty) ...[
                      _DetailSection(
                        icon: FeatherIcons.helpCircle,
                        title: 'Questions to Ask',
                        content: task.questions!,
                        accentColor: const Color(0xFFD29922),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),

            // ── Actions ──────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(color: AppColors.getBorderColor(context))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    icon: const Icon(FeatherIcons.trash2,
                        size: 16, color: Colors.red),
                    label: const Text('Delete',
                        style: TextStyle(color: Colors.red)),
                    onPressed: () {
                      ref.read(taskProvider.notifier).removeTask(task.id);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Task "${task.title}" deleted',
                              style: GoogleFonts.outfit()),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 12),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text('Close',
                        style: GoogleFonts.outfit(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
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

  Color _statusColor(TaskStatus s) {
    switch (s) {
      case TaskStatus.todo:
        return AppColors.todoColor;
      case TaskStatus.inProgress:
        return AppColors.inProgressColor;
      case TaskStatus.done:
        return AppColors.doneColor;
    }
  }

  String _statusLabel(TaskStatus s) {
    switch (s) {
      case TaskStatus.todo:
        return 'To Do';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.done:
        return 'Done';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PillBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _PillBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _MetaCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  const _MetaCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.getBorderColor(context)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    color: AppColors.getBodyColor(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getHeadingColor(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  final Color accentColor;

  const _DetailSection({
    required this.icon,
    required this.title,
    required this.content,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: accentColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.getBodyColor(context),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
