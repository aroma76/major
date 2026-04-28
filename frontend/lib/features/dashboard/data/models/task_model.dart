
enum TaskStatus { todo, inProgress, done }
enum TaskPriority { low, medium, high }

class TaskModel {
  final String id;
  final String title;
  final String description;
  final String subject;
  final TaskStatus status;
  final TaskPriority priority;
  final DateTime dueDate;
  final String? attachments;
  final String? notes;
  final String? questions;

  TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.subject,
    required this.status,
    required this.priority,
    required this.dueDate,
    this.attachments,
    this.notes,
    this.questions,
  });

  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    String? subject,
    TaskStatus? status,
    TaskPriority? priority,
    DateTime? dueDate,
    String? attachments,
    String? notes,
    String? questions,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      subject: subject ?? this.subject,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      attachments: attachments ?? this.attachments,
      notes: notes ?? this.notes,
      questions: questions ?? this.questions,
    );
  }
}
