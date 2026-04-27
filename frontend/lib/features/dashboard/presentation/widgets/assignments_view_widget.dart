import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/task_provider.dart';
import '../../data/models/task_model.dart';
import 'kanban_board_widget.dart';
import 'task_details_dialog.dart';

class AssignmentsViewWidget extends ConsumerWidget {
  const AssignmentsViewWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskProvider);
    final viewType = ref.watch(assignmentViewTypeProvider);
    final selectedSubject = ref.watch(selectedSubjectFilterProvider);
    final selectedPriority = ref.watch(selectedPriorityFilterProvider);

    // Apply filters
    final filteredTasks = tasks.where((task) {
      final matchesSubject = selectedSubject == null || task.subject == selectedSubject;
      final matchesPriority = selectedPriority == null || task.priority == selectedPriority;
      return matchesSubject && matchesPriority;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header (Non-sticky part of the header)
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assignments',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getHeadingColor(context),
                    ),
                  ),
                  Text(
                    'Manage and track your academic assignments',
                    style: TextStyle(color: AppColors.getBodyColor(context), fontSize: 14),
                  ),
                ],
              ),
              _buildViewToggler(context, ref, viewType),
            ],
          ),
        ),
        
        // Sticky Filter Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          color: Theme.of(context).scaffoldBackgroundColor,
          child: _buildFilterBar(context, ref, tasks, selectedSubject, selectedPriority),
        ),
        
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: viewType == AssignmentViewType.kanban
                  ? const KanbanBoardWidget()
                  : _buildListView(context, filteredTasks),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildViewToggler(BuildContext context, WidgetRef ref, AssignmentViewType currentView) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.getBorderColor(context)),
      ),
      child: Row(
        children: [
          _buildToggleItem(
            context,
            ref,
            AssignmentViewType.list,
            'List',
            Icons.format_list_bulleted,
            currentView == AssignmentViewType.list,
          ),
          _buildToggleItem(
            context,
            ref,
            AssignmentViewType.kanban,
            'Board',
            Icons.view_column_outlined,
            currentView == AssignmentViewType.kanban,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem(BuildContext context, WidgetRef ref, AssignmentViewType type, String label, IconData icon, bool isSelected) {
    return InkWell(
      onTap: () => ref.read(assignmentViewTypeProvider.notifier).setViewType(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? AppColors.accent : AppColors.getBodyColor(context)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.accent : AppColors.getBodyColor(context),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, WidgetRef ref, List<TaskModel> allTasks, String? subject, TaskPriority? priority) {
    final subjects = allTasks.map((t) => t.subject).toSet().toList();

    return Row(
      children: [
        _buildDropdownFilter<String?>(
          context,
          hint: 'All Subjects',
          value: subject,
          items: [
            const DropdownMenuItem(value: null, child: Text('All Subjects')),
            ...subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))),
          ],
          onChanged: (val) => ref.read(selectedSubjectFilterProvider.notifier).set(val),
        ),
        const SizedBox(width: 16),
        _buildDropdownFilter<TaskPriority?>(
          context,
          hint: 'All Priorities',
          value: priority,
          items: [
            const DropdownMenuItem(value: null, child: Text('All Priorities')),
            ...TaskPriority.values.map((p) => DropdownMenuItem(value: p, child: Text(p.name.toUpperCase()))),
          ],
          onChanged: (val) => ref.read(selectedPriorityFilterProvider.notifier).set(val),
        ),
        const Spacer(),
        Text(
          'Total: ${allTasks.length}',
          style: TextStyle(color: AppColors.getBodyColor(context), fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildDropdownFilter<T>(
    BuildContext context, {
    required String hint,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.getBorderColor(context)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: (val) => onChanged(val as T),
          dropdownColor: AppColors.getSurfaceColor(context),
          style: TextStyle(color: AppColors.getHeadingColor(context), fontSize: 13),
          icon: Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.getBodyColor(context)),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildListView(BuildContext context, List<TaskModel> tasks) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_late_outlined, size: 48, color: AppColors.getBodyColor(context).withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('No assignments found matching these filters', style: TextStyle(color: AppColors.getBodyColor(context))),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: tasks.length,
      padding: const EdgeInsets.only(bottom: 24),
      itemBuilder: (context, index) {
        final task = tasks[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () {
               showDialog(
                context: context,
                builder: (context) => TaskDetailsDialog(task: task),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.getSurfaceColor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.getBorderColor(context)),
              ),
              child: Row(
                children: [
                  _buildStatusIcon(task.status),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(color: AppColors.getHeadingColor(context), fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(task.subject, style: TextStyle(color: AppColors.getBodyColor(context), fontSize: 13)),
                            const SizedBox(width: 8),
                            Container(width: 4, height: 4, decoration: BoxDecoration(color: AppColors.getBodyColor(context), shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Icon(Icons.calendar_today, size: 12, color: AppColors.getBodyColor(context)),
                            const SizedBox(width: 4),
                            Text(DateFormat('MMM d, y').format(task.dueDate), style: TextStyle(color: AppColors.getBodyColor(context), fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildPriorityTag(task.priority),
                  const SizedBox(width: 16),
                  Icon(Icons.chevron_right, color: AppColors.getBodyColor(context)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusIcon(TaskStatus status) {
    Color color;
    IconData icon;
    switch (status) {
      case TaskStatus.todo:
        color = AppColors.todoColor;
        icon = Icons.radio_button_unchecked;
        break;
      case TaskStatus.inProgress:
        color = AppColors.inProgressColor;
        icon = Icons.pending_actions;
        break;
      case TaskStatus.done:
        color = AppColors.doneColor;
        icon = Icons.check_circle_outline;
        break;
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildPriorityTag(TaskPriority priority) {
    Color color;
    switch (priority) {
      case TaskPriority.high: color = AppColors.priorityHigh; break;
      case TaskPriority.medium: color = AppColors.priorityMedium; break;
      case TaskPriority.low: color = AppColors.priorityLow; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(
        priority.name.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
