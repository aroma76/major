import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/task_model.dart';
import '../providers/task_provider.dart';
import 'package:intl/intl.dart';
import 'task_details_dialog.dart';

class KanbanBoardWidget extends ConsumerWidget {
  const KanbanBoardWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(filteredTasksProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        // responsive columns: repeat(auto-fit, minmax(280px, 1fr))
        double minWidth = 280;
        int crossAxisCount = (constraints.maxWidth / (minWidth + 20)).floor();
        if (crossAxisCount < 1) crossAxisCount = 1;
        if (crossAxisCount > 3) crossAxisCount = 3;
        
        final double itemWidth = crossAxisCount == 1 
            ? constraints.maxWidth 
            : (constraints.maxWidth - (20 * (crossAxisCount - 1))) / crossAxisCount;

        return Wrap(
          spacing: 20,
          runSpacing: 32,
          children: [
            _buildKanbanColumn(
              context,
              ref,
              'To Do',
              tasks.where((t) => t.status == TaskStatus.todo).toList(),
              TaskStatus.todo,
              AppColors.todoColor,
              width: itemWidth,
            ),
            _buildKanbanColumn(
              context,
              ref,
              'In Progress',
              tasks.where((t) => t.status == TaskStatus.inProgress).toList(),
              TaskStatus.inProgress,
              AppColors.inProgressColor,
              width: itemWidth,
            ),
            _buildKanbanColumn(
              context,
              ref,
              'Done',
              tasks.where((t) => t.status == TaskStatus.done).toList(),
              TaskStatus.done,
              AppColors.doneColor,
              width: itemWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildKanbanColumn(
    BuildContext context,
    WidgetRef ref,
    String title,
    List<TaskModel> columnTasks,
    TaskStatus status,
    Color accentColor, {
    required double width,
  }) {
    return Container(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getHeadingColor(context),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.getSurfaceColor(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.getBorderColor(context), width: 1),
                  ),
                  child: Text(
                    '${columnTasks.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getBodyColor(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          DragTarget<TaskModel>(
            onAcceptWithDetails: (details) {
              final task = details.data;
              ref.read(taskProvider.notifier).updateTaskStatus(task.id, status);
            },
            builder: (context, candidateData, rejectedData) {
              return Container(
                decoration: BoxDecoration(
                  color: candidateData.isNotEmpty 
                    ? AppColors.accent.withOpacity(0.05) 
                    : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: columnTasks.length,
                  itemBuilder: (context, index) {
                    final task = columnTasks[index];
                    return _buildTaskCard(context, ref, task);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, WidgetRef ref, TaskModel task) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LongPressDraggable<TaskModel>(
        data: task,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: 330,
            child: _buildCardContent(context, task, isDragging: true),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.3,
          child: _buildCardContent(context, task),
        ),
        child: InkWell(
          onTap: () {
             showDialog(
               context: context,
               builder: (context) => TaskDetailsDialog(task: task),
             );
          },
          borderRadius: BorderRadius.circular(16),
          child: _buildCardContent(context, task),
        ),
      ),
    );
  }

  Widget _buildCardContent(BuildContext context, TaskModel task, {bool isDragging = false}) {
    Color priorityColor;
    switch (task.priority) {
      case TaskPriority.high: priorityColor = AppColors.priorityHigh; break;
      case TaskPriority.medium: priorityColor = AppColors.priorityMedium; break;
      case TaskPriority.low: priorityColor = AppColors.priorityLow; break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDragging ? AppColors.accent : AppColors.getBorderColor(context),
          width: 1,
        ),
        boxShadow: isDragging ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  task.priority.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: priorityColor,
                  ),
                ),
              ),
              Icon(Icons.more_horiz, color: AppColors.getBodyColor(context), size: 18),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            task.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.getHeadingColor(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            task.description,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.getBodyColor(context),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_month, size: 14, color: AppColors.getBodyColor(context)),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MMM d').format(task.dueDate),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.getBodyColor(context),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                   const CircleAvatar(radius: 10, backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=11')),
                   const SizedBox(width: 4),
                   Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.getBorderColor(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                       children: [
                          Icon(Icons.link, size: 14, color: AppColors.getBodyColor(context)),
                          const SizedBox(width: 4),
                          Text('2', style: TextStyle(fontSize: 10, color: AppColors.getBodyColor(context))),
                       ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
