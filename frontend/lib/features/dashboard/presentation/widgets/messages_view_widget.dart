import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/task_provider.dart';
import '../../data/models/chat_model.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';

class MessageModel {
  final String text;
  final String time;
  final bool isMe;

  MessageModel({required this.text, required this.time, required this.isMe});
}

class MessagesViewWidget extends ConsumerStatefulWidget {
  const MessagesViewWidget({super.key});

  @override
  ConsumerState<MessagesViewWidget> createState() => _MessagesViewWidgetState();
}

class _MessagesViewWidgetState extends ConsumerState<MessagesViewWidget> {
  String? selectedChatId;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final Map<String, List<MessageModel>> _chatMessages = {
    'c1': [
      MessageModel(text: "Hey, has anyone finished Lab 4?", time: "12:45 PM", isMe: false),
      MessageModel(text: "Working on it right now!", time: "12:46 PM", isMe: true),
      MessageModel(text: "I'm stuck on the buffer overflow part.", time: "12:50 PM", isMe: false),
    ],
    'c2': [
      MessageModel(text: "Hello Professor, I have a question about Assignment 3.", time: "10:30 AM", isMe: true),
      MessageModel(text: "Sure John, what's on your mind?", time: "10:32 AM", isMe: false),
      MessageModel(text: "Can you share the notes for the last lecture?", time: "10:33 AM", isMe: true),
    ],
    'c3': [
      MessageModel(text: "Let's meet at 5:00 PM for the project sync.", time: "Yesterday", isMe: false),
      MessageModel(text: "Sounds good to me.", time: "Yesterday", isMe: true),
    ],
  };

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty || selectedChatId == null) return;

    setState(() {
      _chatMessages[selectedChatId!]!.add(
        MessageModel(
          text: _messageController.text.trim(),
          time: TimeOfDay.now().format(context),
          isMe: true,
        ),
      );
      _messageController.clear();
    });

    // Auto-scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showChatSettings(ChatModel chat) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getSurfaceColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Chat Settings: ${chat.name}', style: TextStyle(color: AppColors.getHeadingColor(context))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSettingTile(context, 'Rename Chat', FeatherIcons.edit2, () {}),
            _buildSettingTile(context, 'Manage Participants', FeatherIcons.users, () {}),
            _buildSettingTile(context, 'Mute Notifications', FeatherIcons.bellOff, () {}),
            _buildSettingTile(context, 'Clear Chat', FeatherIcons.trash2, () {}, isDestructive: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildSettingTile(BuildContext context, String title, IconData icon, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : AppColors.getBodyColor(context), size: 20),
      title: Text(title, style: TextStyle(color: isDestructive ? Colors.red : AppColors.getHeadingColor(context), fontSize: 14)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chats = ref.watch(chatProvider);

    return Row(
      children: [
        // Left Column: Chat List
        Container(
          width: 350,
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: AppColors.getBorderColor(context))),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Messages',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.getHeadingColor(context)),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(FeatherIcons.edit, color: AppColors.accent, size: 20),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    final chat = chats[index];
                    final isSelected = selectedChatId == chat.id;
                    return InkWell(
                      onTap: () {
                        setState(() => selectedChatId = chat.id);
                        // Mark as read logic would go here
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        color: isSelected ? AppColors.accent.withOpacity(0.08) : Colors.transparent,
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(radius: 26, backgroundImage: NetworkImage(chat.imageUrl)),
                                if (chat.isOnline)
                                  Positioned(
                                    right: 2,
                                    bottom: 2,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppColors.getSurfaceColor(context), width: 2),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        chat.name,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: isSelected || chat.unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                                          color: isSelected ? AppColors.accent : AppColors.getHeadingColor(context),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        chat.lastMessageTime,
                                        style: TextStyle(fontSize: 10, color: AppColors.getBodyColor(context)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          chat.lastMessage,
                                          style: TextStyle(
                                            fontSize: 12, 
                                            color: chat.unreadCount > 0 ? AppColors.getHeadingColor(context) : AppColors.getBodyColor(context),
                                            fontWeight: chat.unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (chat.unreadCount > 0)
                                        Container(
                                          margin: const EdgeInsets.only(left: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
                                          child: Text(
                                            '${chat.unreadCount}',
                                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        
        // Right Column: Active Conversation
        Expanded(
          child: selectedChatId == null
              ? _buildEmptyState()
              : _buildActiveChat(chats.firstWhere((c) => c.id == selectedChatId)),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(FeatherIcons.messageSquare, size: 64, color: AppColors.accent.withOpacity(0.3)),
          ),
          const SizedBox(height: 24),
          Text(
            'Select a conversation to start messaging',
            style: TextStyle(color: AppColors.getBodyColor(context), fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveChat(ChatModel chat) {
    final messages = _chatMessages[chat.id] ?? [];

    return Column(
      children: [
        // Chat Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.getBorderColor(context))),
          ),
          child: Row(
            children: [
              CircleAvatar(radius: 20, backgroundImage: NetworkImage(chat.imageUrl)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(chat.name, style: TextStyle(color: AppColors.getHeadingColor(context), fontWeight: FontWeight.bold)),
                  if (chat.isOnline)
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        const Text('Online', style: TextStyle(color: Colors.green, fontSize: 11)),
                      ],
                    )
                  else
                    const Text('Last seen recently', style: TextStyle(color: AppColors.textBody, fontSize: 11)),
                ],
              ),
              const Spacer(),
              IconButton(icon: Icon(FeatherIcons.video, color: AppColors.getBodyColor(context), size: 20), onPressed: () {}),
              IconButton(icon: Icon(FeatherIcons.phone, color: AppColors.getBodyColor(context), size: 18), onPressed: () {}),
              IconButton(icon: Icon(FeatherIcons.moreHorizontal, color: AppColors.getBodyColor(context), size: 20), onPressed: () => _showChatSettings(chat)),
            ],
          ),
        ),
        
        // Message List
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(24),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              return _buildMessageBubble(msg.text, msg.time, msg.isMe);
            },
          ),
        ),
        
        // Message Input
        Container(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.getSurfaceColor(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.getBorderColor(context)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                IconButton(icon: Icon(FeatherIcons.plusCircle, color: AppColors.getBodyColor(context), size: 20), onPressed: () {}),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: AppColors.getBodyColor(context), fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    style: TextStyle(color: AppColors.getHeadingColor(context), fontSize: 14),
                  ),
                ),
                InkWell(
                  onTap: _sendMessage,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: AppColors.accentGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(FeatherIcons.send, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(String text, String time, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        constraints: const BoxConstraints(maxWidth: 450),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? AppColors.accent : AppColors.getBorderColor(context).withOpacity(0.1),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 0),
                  bottomRight: Radius.circular(isMe ? 0 : 16),
                ),
              ),
              child: Text(
                text,
                style: TextStyle(color: isMe ? Colors.white : AppColors.getHeadingColor(context), fontSize: 14),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isMe) Icon(Icons.done_all, size: 12, color: AppColors.accent.withOpacity(0.8)),
                if (isMe) const SizedBox(width: 4),
                Text(time, style: TextStyle(fontSize: 10, color: AppColors.getBodyColor(context))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
