import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/task_provider.dart';
import '../../data/models/task_model.dart';
import 'task_details_dialog.dart';

class CalendarViewWidget extends ConsumerStatefulWidget {
  const CalendarViewWidget({super.key});

  @override
  ConsumerState<CalendarViewWidget> createState() => _CalendarViewWidgetState();
}

class _CalendarViewWidgetState extends ConsumerState<CalendarViewWidget> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(taskProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Academic Calendar',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.getHeadingColor(context),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.getSurfaceColor(context),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.getBorderColor(context), width: 1),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: TableCalendar<TaskModel>(
              firstDay: DateTime.now().subtract(const Duration(days: 365)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onFormatChanged: (format) {
                setState(() => _calendarFormat = format);
              },
              eventLoader: (day) {
                return tasks.where((task) => isSameDay(task.dueDate, day)).toList();
              },
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
                selectedDecoration: const BoxDecoration(
                  gradient: AppColors.accentGradient,
                  shape: BoxShape.circle,
                ),
                markerDecoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                weekendTextStyle: const TextStyle(color: AppColors.priorityHigh),
                defaultTextStyle: TextStyle(color: AppColors.getHeadingColor(context)),
                outsideTextStyle: TextStyle(color: AppColors.getBodyColor(context).withOpacity(0.5)),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
                titleTextStyle: TextStyle(color: AppColors.getHeadingColor(context), fontSize: 18, fontWeight: FontWeight.bold),
                formatButtonTextStyle: const TextStyle(color: Colors.white),
                formatButtonDecoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
                leftChevronIcon: Icon(Icons.chevron_left, color: AppColors.getHeadingColor(context)),
                rightChevronIcon: Icon(Icons.chevron_right, color: AppColors.getHeadingColor(context)),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedDay == null ? 'Upcoming Tasks' : 'Tasks for ${DateFormat('MMM d, y').format(_selectedDay!)}',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.getHeadingColor(context)),
              ),
              if (_selectedDay != null)
                TextButton(
                  onPressed: () => setState(() => _selectedDay = null),
                  child: const Text('Show All Upcoming'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTaskList(tasks),
        ],
      ),
    );
  }

  Widget _buildTaskList(List<TaskModel> allTasks) {
    final displayTasks = _selectedDay == null 
        ? allTasks.where((t) => t.dueDate.isAfter(DateTime.now().subtract(const Duration(days: 1)))).toList()
        : allTasks.where((t) => isSameDay(t.dueDate, _selectedDay)).toList();

    if (displayTasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(Icons.event_busy, size: 48, color: AppColors.getBodyColor(context).withOpacity(0.3)),
              const SizedBox(height: 16),
              Text(
                'No tasks scheduled for this period',
                style: TextStyle(color: AppColors.getBodyColor(context)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: displayTasks.length,
      itemBuilder: (context, index) {
        final task = displayTasks[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.getBorderColor(context)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: _buildStatusIcon(task.status),
            title: Text(task.title, style: TextStyle(color: AppColors.getHeadingColor(context), fontWeight: FontWeight.bold)),
            subtitle: Text(task.subject, style: TextStyle(color: AppColors.getBodyColor(context))),
            trailing: _buildPriorityTag(task.priority),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => TaskDetailsDialog(task: task),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStatusIcon(TaskStatus status) {
    Color color;
    switch (status) {
      case TaskStatus.todo: color = AppColors.todoColor; break;
      case TaskStatus.inProgress: color = AppColors.inProgressColor; break;
      case TaskStatus.done: color = AppColors.doneColor; break;
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
      child: Icon(Icons.calendar_today, color: color, size: 18),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(
        priority.name.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
