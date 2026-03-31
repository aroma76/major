class ChannelModel {
  final int id;
  final String subjectName;
  final String channelName;
  final int semesterNumber;
  final String? teacherName;
  final int? teacherId;

  ChannelModel({
    required this.id,
    required this.subjectName,
    required this.channelName,
    required this.semesterNumber,
    this.teacherName,
    this.teacherId,
  });

  factory ChannelModel.fromJson(Map<String, dynamic> json) {
    return ChannelModel(
      id: json['id'] as int,
      subjectName: json['subject_name'] as String? ?? '',
      channelName: json['channel_name'] as String? ?? '',
      semesterNumber: json['semester_number'] as int? ?? 0,
      teacherName: json['teacher_name'] as String?,
      teacherId: json['teacher_id'] as int?,
    );
  }
}
