class ChatModel {
  final String id;
  final String name;
  final String lastMessage;
  final String lastMessageTime;
  final String imageUrl;
  final int unreadCount;
  final bool isOnline;

  ChatModel({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.imageUrl,
    this.unreadCount = 0,
    this.isOnline = false,
  });
}

class MessageModel {
  final String id;
  final String text;
  final DateTime timestamp;
  final String senderId;
  final bool isMe;

  MessageModel({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.senderId,
    required this.isMe,
  });
}
