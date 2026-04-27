import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/socket_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/api_service.dart';
import '../../data/models/channel_model.dart';
import '../../data/models/api_message_model.dart';
import '../providers/api_providers.dart';
import '../providers/messages_notifier.dart';

class MessagesViewWidget extends ConsumerStatefulWidget {
  const MessagesViewWidget({super.key});

  @override
  ConsumerState<MessagesViewWidget> createState() => _MessagesViewWidgetState();
}

class _MessagesViewWidgetState extends ConsumerState<MessagesViewWidget> {
  final TextEditingController _inputCtrl    = TextEditingController();
  final ScrollController       _scrollCtrl  = ScrollController();

  PlatformFile?    _pendingFile;
  bool             _isSending  = false;
  String?          _typingUser;
  ApiMessageModel? _replyingTo;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initSocketListeners();
  }

  void _initSocketListeners() {
    final socket = SocketService();
    socket.onNewMessage((data) {
      if (!mounted) return;
      final chanId   = (data['channel_id'] as num?)?.toInt();
      final selected = ref.read(selectedChannelProvider)?.id;
      if (chanId == null) return;

      // If this message was sent by the current user, skip appending it
      // because an optimistic copy was already added in _send().
      final myId     = AuthService().currentUser?['id']?.toString();
      final senderId = (data['sender_id'] as num?)?.toInt().toString();
      if (senderId != null && senderId == myId) return;

      final msg = ApiMessageModel.fromJson(data);
      ref.read(messagesNotifierProvider(chanId).notifier).append(msg);

      if (chanId == selected) _scrollToBottom();
    });

    socket.onTypingStart((name) {
      if (mounted) setState(() => _typingUser = name);
    });
    socket.onTypingStop(() {
      if (mounted) setState(() => _typingUser = null);
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    SocketService().off('message:new');
    SocketService().off('typing:start');
    SocketService().off('typing:stop');
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _selectChannel(ChannelModel ch) {
    final prev = ref.read(selectedChannelProvider);
    if (prev != null) SocketService().leaveChannel(prev.id);
    ref.read(selectedChannelProvider.notifier).select(ch);
    setState(() => _replyingTo = null);
    SocketService().joinChannel(ch.id);
  }

  void _emitTyping() {
    final channel = ref.read(selectedChannelProvider);
    if (channel == null) return;
    final name = AuthService().currentUser?['name']?.toString() ?? 'Someone';
    SocketService().emitTypingStart(channel.id, name);
    Future.delayed(const Duration(seconds: 2),
        () => SocketService().emitTypingStop(channel.id));
  }

  void _setReply(ApiMessageModel msg) {
    setState(() => _replyingTo = msg);
  }
  void _clearReply() {
    setState(() => _replyingTo = null);
  }

  // ── Send ──────────────────────────────────────────────────────────────────
  Future<void> _send() async {
    final channel = ref.read(selectedChannelProvider);
    if (channel == null) return;

    final text = _inputCtrl.text.trim();
    if (text.isEmpty && _pendingFile == null) return;

    final parentId = _replyingTo?.id;

    if (_pendingFile != null) {
      await _uploadFile(channel.id, text, parentId);
    } else {
      // Optimistically append the message so the sender sees it immediately
      final currentUser = AuthService().currentUser;
      final tempMsg = ApiMessageModel(
        id: DateTime.now().millisecondsSinceEpoch,
        channelId: channel.id,
        senderId: int.tryParse(currentUser?['id']?.toString() ?? '0') ?? 0,
        senderName: currentUser?['name']?.toString() ?? 'You',
        senderRole: currentUser?['role']?.toString() ?? 'student',
        content: text,
        isPinned: false,
        createdAt: DateTime.now(),
        parentId: parentId,
      );
      ref.read(messagesNotifierProvider(channel.id).notifier).append(tempMsg);

      SocketService().sendMessage(
        channelId: channel.id,
        content: text,
        parentId: parentId,
      );
      _inputCtrl.clear();
      _clearReply();
      _scrollToBottom();
    }
  }

  Future<void> _uploadFile(int channelId, String caption, int? parentId) async {
    final file = _pendingFile!;

    // Guard: bytes must exist (Flutter Web requires withData: true in picker)
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not read file data. Please try picking the file again.'),
          backgroundColor: Colors.orange,
        ));
      }
      setState(() => _pendingFile = null);
      return;
    }

    setState(() => _isSending = true);
    try {
      // Derive MIME type from extension so Cloudinary resource_type:auto works correctly
      final ext  = file.extension?.toLowerCase() ?? '';
      final mime = _mimeFromExt(ext);
      final parts = mime.split('/');

      final formData = FormData.fromMap({
        'content': caption.isNotEmpty ? caption : file.name,
        'file': MultipartFile.fromBytes(
          bytes,
          filename: file.name,
          contentType: MediaType(parts[0], parts.length > 1 ? parts[1] : 'octet-stream'),
        ),
        if (parentId != null) 'parent_id': parentId,
      });

      final response = await ApiService().sendMessage(channelId, formData);
      final saved = (response.data as Map<String, dynamic>)['message']
          as Map<String, dynamic>?;

      // Optimistically show the file in chat for the sender
      // (the socket broadcast is suppressed for self-sent messages)
      if (saved != null && mounted) {
        final msg = ApiMessageModel.fromJson(saved);
        ref.read(messagesNotifierProvider(channelId).notifier).append(msg);
        _scrollToBottom();
      }

      setState(() {
        _pendingFile = null;
        _inputCtrl.clear();
      });
      _clearReply();
    } catch (e) {
      if (mounted) {
        final msg = e is DioException
            ? (e.response?.data?['message'] as String? ?? e.message ?? 'Upload failed')
            : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $msg'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  /// Returns a MIME type string for a given file extension.
  static String _mimeFromExt(String ext) {
    const map = {
      'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png',
      'gif': 'image/gif',  'webp': 'image/webp', 'bmp': 'image/bmp',
      'svg': 'image/svg+xml',
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt': 'application/vnd.ms-powerpoint',
      'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'txt': 'text/plain',
      'zip': 'application/zip',
      'mp4': 'video/mp4',  'mov': 'video/quicktime',
      'mp3': 'audio/mpeg', 'wav': 'audio/wav',
    };
    return map[ext] ?? 'application/octet-stream';
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
    if (result != null && result.files.isNotEmpty) {
      setState(() => _pendingFile = result.files.first);
    }
  }
  void _clearFile() => setState(() => _pendingFile = null);

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final channelsAsync    = ref.watch(channelsProvider);
    final selectedChannel  = ref.watch(selectedChannelProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final panelWidth = (constraints.maxWidth * 0.28).clamp(240.0, 340.0);
        return Row(
      children: [
        // ── Left: Channel List ───────────────────────────────────────────
        Container(
          width: panelWidth,

          decoration: BoxDecoration(border: Border(right: BorderSide(color: AppColors.getBorderColor(context)))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Row(
                  children: [
                    Text('Messages', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.getHeadingColor(context))),
                    const Spacer(),
                    Icon(FeatherIcons.hash, color: AppColors.accent, size: 18),
                  ],
                ),
              ),
              Expanded(
                child: channelsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error loading channels')),
                  data: (channels) {
                    if (channels.isEmpty) return const Center(child: Text('No channels.'));
                    return ListView.builder(
                      itemCount: channels.length,
                      itemBuilder: (_, i) => _ChannelTile(
                        channel   : channels[i],
                        isSelected: selectedChannel?.id == channels[i].id,
                        onTap     : () => _selectChannel(channels[i]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // ── Right: Chat Area ─────────────────────────────────────────────
        Expanded(
          child: selectedChannel == null
              ? _EmptyState()
              : _ChatArea(
                  channel    : selectedChannel,
                  inputCtrl  : _inputCtrl,
                  scrollCtrl : _scrollCtrl,
                  pendingFile: _pendingFile,
                  isSending  : _isSending,
                  typingUser : _typingUser,
                  replyingTo : _replyingTo,
                  onSend     : _send,
                  onPickFile : _pickFile,
                  onClearFile: _clearFile,
                  onTyping   : _emitTyping,
                  onReply    : _setReply,
                  onClearReply: _clearReply,
                ),
        ),
      ],
    );
      },
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
class _ChannelTile extends StatelessWidget {
  final ChannelModel channel;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChannelTile({required this.channel, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        color: isSelected ? AppColors.accent.withValues(alpha: 0.09) : Colors.transparent,
        child: Row(
          children: [
            Container(
              width: 40, height: 40, alignment: Alignment.center,
              decoration: BoxDecoration(color: isSelected ? AppColors.accent : AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(FeatherIcons.hash, size: 18, color: isSelected ? Colors.white : AppColors.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(channel.subjectName, style: GoogleFonts.outfit(fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, fontSize: 14, color: isSelected ? AppColors.accent : AppColors.getHeadingColor(context)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (channel.teacherName != null) Text(channel.teacherName!, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.getBodyColor(context))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(padding: const EdgeInsets.all(28), decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.07), shape: BoxShape.circle), child: Icon(FeatherIcons.messageSquare, size: 56, color: AppColors.accent.withValues(alpha: 0.3))),
          const SizedBox(height: 20),
          Text('Select a channel to start chatting', style: GoogleFonts.outfit(fontSize: 15, color: AppColors.getBodyColor(context))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _ChatArea extends ConsumerWidget {
  final ChannelModel channel;
  final TextEditingController inputCtrl;
  final ScrollController scrollCtrl;
  final PlatformFile? pendingFile;
  final bool isSending;
  final String? typingUser;
  final ApiMessageModel? replyingTo;
  final Future<void> Function() onSend;
  final Future<void> Function() onPickFile;
  final VoidCallback onClearFile;
  final VoidCallback onTyping;
  final void Function(ApiMessageModel) onReply;
  final VoidCallback onClearReply;

  const _ChatArea({
    required this.channel, required this.inputCtrl, required this.scrollCtrl, required this.pendingFile,
    required this.isSending, required this.typingUser, required this.replyingTo,
    required this.onSend, required this.onPickFile, required this.onClearFile,
    required this.onTyping, required this.onReply, required this.onClearReply,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesState = ref.watch(messagesNotifierProvider(channel.id));
    final myId = AuthService().currentUser?['id']?.toString();

    return Column(
      children: [
        // ── Header ────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.getBorderColor(context)))),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(FeatherIcons.hash, color: AppColors.accent, size: 16)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(channel.subjectName, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.getHeadingColor(context))),
                    if (channel.teacherName != null) Text('Teacher: ${channel.teacherName}', style: GoogleFonts.outfit(fontSize: 11, color: AppColors.getBodyColor(context))),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Messages List ──────────────────────────────────────────────────
        Expanded(
          child: messagesState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : messagesState.error != null && messagesState.messages.isEmpty
                  ? Center(child: Text('Failed to load messages'))
                  : () {
                      final messages = messagesState.messages;
                      if (messages.isEmpty) return Center(child: Text('No messages yet', style: GoogleFonts.outfit(color: AppColors.getBodyColor(context))));
                      return NotificationListener<ScrollNotification>(
                        onNotification: (ScrollNotification scrollInfo) {
                          if (scrollInfo.metrics.pixels <= 200) {
                             ref.read(messagesNotifierProvider(channel.id).notifier).loadMore();
                          }
                          return false;
                        },
                        child: ListView.builder(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                          itemCount: messages.length,
                          itemBuilder: (_, i) {
                            final msg = messages[i];
                            final isMe = msg.senderId.toString() == myId;
                            return InkWell(
                              onLongPress: () => onReply(msg),
                              hoverColor: AppColors.getBorderColor(context).withValues(alpha: 0.1),
                              child: _MessageBubble(msg: msg, isMe: isMe),
                            );
                          },
                        ),
                      );
                    }(),
        ),

        // ── Typing Indicator ──────────────────────────────────────────────
        if (typingUser != null)
          Padding(
            padding: const EdgeInsets.only(left: 28, bottom: 4),
            child: Align(alignment: Alignment.centerLeft, child: Text('$typingUser is typing...', style: GoogleFonts.outfit(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.getBodyColor(context)))),
          ),

        // ── Input Bar ─────────────────────────────────────────────────────
        _InputBar(
          inputCtrl: inputCtrl, pendingFile: pendingFile, isSending: isSending, replyingTo: replyingTo,
          onSend: onSend, onPickFile: onPickFile, onClearFile: onClearFile, onTyping: onTyping, onClearReply: onClearReply,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _MessageBubble extends StatefulWidget {
  final ApiMessageModel msg;
  final bool isMe;

  const _MessageBubble({required this.msg, required this.isMe});

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  static const _emojis = ['👍', '❤️', '😂', '🔥', '👀'];
  final Map<String, int> _reactions = {};
  String? _myReaction;
  bool _showPicker = false;
  bool _isStarred = false;

  void _togglePicker() => setState(() => _showPicker = !_showPicker);

  void _react(String emoji) {
    setState(() {
      if (_myReaction == emoji) {
        _reactions[emoji] = (_reactions[emoji] ?? 1) - 1;
        if (_reactions[emoji]! <= 0) _reactions.remove(emoji);
        _myReaction = null;
      } else {
        if (_myReaction != null) {
          _reactions[_myReaction!] = (_reactions[_myReaction!] ?? 1) - 1;
          if (_reactions[_myReaction!]! <= 0) _reactions.remove(_myReaction!);
        }
        _myReaction = emoji;
        _reactions[emoji] = (_reactions[emoji] ?? 0) + 1;
      }
      _showPicker = false;
    });
  }

  static IconData _fileIcon(String? name) {
    final ext = name?.split('.').last.toLowerCase() ?? '';
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) return FeatherIcons.image;
    if (ext == 'pdf') return FeatherIcons.fileText;
    return FeatherIcons.paperclip;
  }

  void _showFileViewer(BuildContext context, String url, String? fileName) async {
    final ext = fileName?.split('.').last.toLowerCase() ?? '';
    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);

    if (isImage) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.all(20),
          child: Stack(
            alignment: Alignment.center,
            children: [
              InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.getSurfaceColor(context),
                    padding: const EdgeInsets.all(20),
                    child: Text('Failed to load image', style: GoogleFonts.outfit(color: Colors.red)),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: const Icon(FeatherIcons.xCircle, color: Colors.white, size: 36),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        launchUrl(uri, webOnlyWindowName: '_blank');
      }
    }
  }

  void _downloadFile(String url) async {
    // Force download via Cloudinary's fl_attachment flag; works for any file type
    final downloadUrl = url.contains('cloudinary.com')
        ? '${url.split('?').first}?fl_attachment=true'
        : url;
    final uri = Uri.parse(downloadUrl);
    if (await canLaunchUrl(uri)) {
      launchUrl(uri, webOnlyWindowName: '_blank');
    }
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.msg;
    final isMe = widget.isMe;
    final bubbleColor = isMe ? AppColors.accent : AppColors.getBorderColor(context).withValues(alpha: 0.15);
    final textColor = isMe ? Colors.white : AppColors.getHeadingColor(context);
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isMe ? 16 : 0),
      bottomRight: Radius.circular(isMe ? 0 : 16),
    );
    final time = DateFormat('h:mm a').format(msg.createdAt.toLocal());
    final isFaculty = msg.senderRole == 'faculty';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.55),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(msg.senderName, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: isFaculty ? Colors.orange : AppColors.accent)),
                    if (isFaculty) ...[
                      const SizedBox(width: 5),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)), child: const Text('Teacher', style: TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.bold))),
                    ],
                  ],
                ),
              ),

            // Parent Message Thread
            if (msg.parentContent != null || msg.parentSenderName != null)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.getBorderColor(context).withValues(alpha: 0.2),
                  border: Border(left: BorderSide(color: AppColors.accent, width: 3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(msg.parentSenderName ?? 'Someone', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.accent)),
                    Text(msg.parentContent ?? 'Attachment', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.getBodyColor(context))),
                  ],
                ),
              ),

            // Long press for reactions
            GestureDetector(
              onLongPress: _togglePicker,
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // File or Text Content
                  if (msg.fileUrl != null && msg.fileUrl!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: bubbleColor, borderRadius: radius),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Tap area: view file ──
                          GestureDetector(
                            onTap: () => _showFileViewer(context, msg.fileUrl!, msg.fileName),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_fileIcon(msg.fileName), color: textColor, size: 22),
                                const SizedBox(width: 10),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 160),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(msg.fileName ?? 'attachment', style: GoogleFonts.outfit(color: textColor, fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 2),
                                      Text('Tap to view', style: GoogleFonts.outfit(color: textColor.withValues(alpha: 0.7), fontSize: 10)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // ── Download button ──
                          Tooltip(
                            message: 'Download',
                            child: InkWell(
                              onTap: () => _downloadFile(msg.fileUrl!),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: textColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(FeatherIcons.download, color: textColor, size: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // ── Star / Mark button ──
                          Tooltip(
                            message: _isStarred ? 'Unmark' : 'Mark as important',
                            child: InkWell(
                              onTap: () => setState(() => _isStarred = !_isStarred),
                              borderRadius: BorderRadius.circular(8),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: _isStarred
                                      ? Colors.amber.withValues(alpha: 0.25)
                                      : textColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                                  color: _isStarred ? Colors.amber : textColor,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: bubbleColor, borderRadius: radius),
                      child: Text(msg.content ?? '', style: GoogleFonts.outfit(color: textColor, fontSize: 14)),
                    ),

                  // Emoji Picker popup
                  if (_showPicker)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.getSurfaceColor(context),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.getBorderColor(context)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: _emojis.map((e) {
                          final isSelected = _myReaction == e;
                          return GestureDetector(
                            onTap: () => _react(e),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.accent.withValues(alpha: 0.15) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(e, style: const TextStyle(fontSize: 18)),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  // Reaction pills
                  if (_reactions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 4,
                        children: _reactions.entries.map((entry) {
                          final isSelected = _myReaction == entry.key;
                          return GestureDetector(
                            onTap: () => _react(entry.key),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.accent.withValues(alpha: 0.15)
                                    : AppColors.getSurfaceColor(context),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.accent.withValues(alpha: 0.4)
                                      : AppColors.getBorderColor(context),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(entry.key, style: const TextStyle(fontSize: 12)),
                                  const SizedBox(width: 4),
                                  Text('${entry.value}',
                                      style: TextStyle(fontSize: 11, color: isSelected ? AppColors.accent : AppColors.getBodyColor(context), fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isMe) Icon(Icons.done_all, size: 12, color: AppColors.accent.withValues(alpha: 0.8)),
                if (isMe) const SizedBox(width: 3),
                Text(time, style: GoogleFonts.outfit(fontSize: 10, color: AppColors.getBodyColor(context))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController inputCtrl;
  final PlatformFile? pendingFile;
  final bool isSending;
  final ApiMessageModel? replyingTo;
  final Future<void> Function() onSend;
  final Future<void> Function() onPickFile;
  final VoidCallback onClearFile;
  final VoidCallback onTyping;
  final VoidCallback onClearReply;

  const _InputBar({
    required this.inputCtrl, required this.pendingFile, required this.isSending, required this.replyingTo,
    required this.onSend, required this.onPickFile, required this.onClearFile, required this.onTyping, required this.onClearReply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          // Replying to chip
          if (replyingTo != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: AppColors.getBorderColor(context).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border(left: BorderSide(color: AppColors.accent, width: 4))),
              child: Row(
                children: [
                  Icon(FeatherIcons.cornerUpLeft, color: AppColors.accent, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Replying to ${replyingTo!.senderName}', style: GoogleFonts.outfit(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold)),
                        Text(replyingTo!.content ?? 'Attachment', style: GoogleFonts.outfit(color: AppColors.getBodyColor(context), fontSize: 12), overflow: TextOverflow.ellipsis, maxLines: 1),
                      ],
                    ),
                  ),
                  GestureDetector(onTap: onClearReply, child: Icon(Icons.close, size: 16, color: AppColors.getBodyColor(context))),
                ],
              ),
            ),

          if (pendingFile != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.accent.withValues(alpha: 0.25))),
              child: Row(
                children: [
                  Icon(FeatherIcons.paperclip, color: AppColors.accent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(pendingFile!.name, style: GoogleFonts.outfit(color: AppColors.getHeadingColor(context), fontSize: 12), overflow: TextOverflow.ellipsis)),
                  GestureDetector(onTap: onClearFile, child: Padding(padding: const EdgeInsets.only(left: 6), child: Icon(Icons.close, size: 14, color: AppColors.getBodyColor(context)))),
                ],
              ),
            ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(color: AppColors.getSurfaceColor(context), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.getBorderColor(context))),
            child: Row(
              children: [
                IconButton(icon: Icon(FeatherIcons.paperclip, color: pendingFile != null ? AppColors.accent : AppColors.getBodyColor(context), size: 20), onPressed: isSending ? null : onPickFile),
                Expanded(
                  child: TextField(
                    controller: inputCtrl, maxLines: null, keyboardType: TextInputType.multiline, onChanged: (_) => onTyping(), onSubmitted: (_) => onSend(),
                    decoration: InputDecoration(hintText: 'Type a message...', hintStyle: GoogleFonts.outfit(color: AppColors.getBodyColor(context), fontSize: 14), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 12)),
                    style: GoogleFonts.outfit(color: AppColors.getHeadingColor(context), fontSize: 14),
                  ),
                ),
                isSending
                    ? const SizedBox(width: 36, height: 36, child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))))
                    : GestureDetector(onTap: onSend, child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(gradient: AppColors.accentGradient, borderRadius: BorderRadius.circular(12)), child: const Icon(FeatherIcons.send, color: Colors.white, size: 18))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
