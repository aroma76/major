class AssignmentModel {
  final int id;
  final int channelId;
  final String title;
  final String? description;
  final DateTime dueDate;
  final int maxMarks;
  final String? createdByName;
  final String? submissionStatus; // null = not submitted
  final int? marks;
  final String? feedback;

  AssignmentModel({
    required this.id,
    required this.channelId,
    required this.title,
    this.description,
    required this.dueDate,
    required this.maxMarks,
    this.createdByName,
    this.submissionStatus,
    this.marks,
    this.feedback,
  });

  bool get isSubmitted => submissionStatus != null;
  bool get isOverdue => !isSubmitted && dueDate.isBefore(DateTime.now());

  factory AssignmentModel.fromJson(Map<String, dynamic> json) {
    return AssignmentModel(
      id: json['id'] as int,
      channelId: json['channel_id'] as int,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      dueDate: DateTime.tryParse(json['due_date'] as String? ?? '') ??
          DateTime.now(),
      maxMarks: json['max_marks'] as int? ?? 100,
      createdByName: json['created_by_name'] as String?,
      submissionStatus: json['submission_status'] as String?,
      marks: json['marks'] as int?,
      feedback: json['feedback'] as String?,
    );
  }
}
