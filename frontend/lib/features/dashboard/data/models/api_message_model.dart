class ApiMessageModel {
  final int id;
  final int channelId;
  final int senderId;
  final String senderName;
  final String senderRole;
  final String? senderAvatar;
  final String? content;
  final String? fileUrl;
  final String? fileName;
  final bool isPinned;
  final DateTime createdAt;
  final int? parentId;
  final String? parentContent;
  final String? parentSenderName;

  ApiMessageModel({
    required this.id,
    required this.channelId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    this.senderAvatar,
    this.content,
    this.fileUrl,
    this.fileName,
    required this.isPinned,
    required this.createdAt,
    this.parentId,
    this.parentContent,
    this.parentSenderName,
  });

  factory ApiMessageModel.fromJson(Map<String, dynamic> json) {
    return ApiMessageModel(
      id: json['id'] as int,
      channelId: json['channel_id'] as int,
      senderId: json['sender_id'] as int,
      senderName: json['sender_name'] as String? ?? 'Unknown',
      senderRole: json['sender_role'] as String? ?? 'student',
      senderAvatar: json['sender_avatar'] as String?,
      content: json['content'] as String?,
      fileUrl: json['file_url'] as String?,
      fileName: json['file_name'] as String?,
      isPinned: json['is_pinned'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      parentId: json['parent_id'] as int?,
      parentContent: json['parent_content'] as String?,
      parentSenderName: json['parent_sender_name'] as String?,
    );
  }
}
