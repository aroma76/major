import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
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
import '../providers/saved_files_provider.dart';

class MessagesViewWidget extends ConsumerStatefulWidget {
  const MessagesViewWidget({super.key});

  @override
  ConsumerState<MessagesViewWidget> createState() => _MessagesViewWidgetState();
}

class _MessagesViewWidgetState extends ConsumerState<MessagesViewWidget> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  List<PlatformFile> _pendingFiles = []; // multi-file queue
  bool _isSending = false;
  String? _typingUser;
  ApiMessageModel? _replyingTo;
  bool _isDragging = false;

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
      final chanId = (data['channel_id'] as num?)?.toInt();
      final selected = ref.read(selectedChannelProvider)?.id;
      if (chanId == null) return;

      // If this message was sent by the current user, skip appending it
      // because an optimistic copy was already added in _send().
      final myId = AuthService().currentUser?['id']?.toString();
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
    if (text.isEmpty && _pendingFiles.isEmpty) return;

    final parentId = _replyingTo?.id;

    if (_pendingFiles.isNotEmpty) {
      await _uploadFiles(channel.id, text, parentId);
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

  Future<void> _uploadFiles(
      int channelId, String caption, int? parentId) async {
    if (_pendingFiles.isEmpty) return;
    setState(() => _isSending = true);
    final files = List<PlatformFile>.from(_pendingFiles);
    setState(() => _pendingFiles = []);
    _inputCtrl.clear();
    _clearReply();
    try {
      for (final file in files) {
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) continue;
        final ext = file.extension?.toLowerCase() ?? '';
        final mime = _mimeFromExt(ext);
        final parts = mime.split('/');
        final formData = FormData.fromMap({
          'content': caption.isNotEmpty ? caption : file.name,
          'file': MultipartFile.fromBytes(
            bytes,
            filename: file.name,
            contentType: MediaType(
                parts[0], parts.length > 1 ? parts[1] : 'octet-stream'),
          ),
          if (parentId != null) 'parent_id': parentId,
        });
        final response = await ApiService().sendMessage(channelId, formData);
        final saved = (response.data as Map<String, dynamic>)['message']
            as Map<String, dynamic>?;
        if (saved != null && mounted) {
          final msg = ApiMessageModel.fromJson(saved);
          ref.read(messagesNotifierProvider(channelId).notifier).append(msg);
          _scrollToBottom();
        }
        caption = ''; // only add caption to first file
      }
    } catch (e) {
      if (mounted) {
        final msg = e is DioException
            ? (e.response?.data?['message'] as String? ??
                e.message ??
                'Upload failed')
            : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Upload failed: $msg'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  /// Returns a MIME type string for a given file extension.
  static String _mimeFromExt(String ext) {
    const map = {
      // Images
      'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png',
      'gif': 'image/gif', 'webp': 'image/webp', 'bmp': 'image/bmp',
      'svg': 'image/svg+xml',
      // Documents
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt': 'application/vnd.ms-powerpoint',
      'pptx':
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      // Text & code
      'txt': 'text/plain',
      'md': 'text/markdown',
      'py': 'text/x-python',
      'js': 'text/javascript',
      'ts': 'text/typescript',
      'dart': 'text/plain',
      'java': 'text/plain',
      'c': 'text/plain',
      'cpp': 'text/plain',
      'cs': 'text/plain',
      'go': 'text/plain',
      'rb': 'text/plain',
      'sh': 'text/plain',
      // Data
      'json': 'application/json',
      'xml': 'application/xml',
      'csv': 'text/csv',
      'yaml': 'text/yaml',
      'yml': 'text/yaml',
      // Archives
      'zip': 'application/zip',
      'rar': 'application/x-rar-compressed',
      '7z': 'application/x-7z-compressed',
    };
    return map[ext] ?? 'application/octet-stream';
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
      allowMultiple: true, // WhatsApp-style: pick many at once
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _pendingFiles = [..._pendingFiles, ...result.files]);
    }
  }

  void _clearFile(int index) => setState(() => _pendingFiles.removeAt(index));
  void _clearAllFiles() => setState(() => _pendingFiles = []);

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(channelsProvider);
    final selectedChannel = ref.watch(selectedChannelProvider);
    final isMobile = MediaQuery.of(context).size.width < 700;

    // ── Mobile: single-panel — channel list OR chat ──────────────────────────
    if (isMobile) {
      if (selectedChannel != null) {
        return _buildDropTarget(
          selectedChannel,
          _ChatArea(
            channel: selectedChannel,
            inputCtrl: _inputCtrl,
            scrollCtrl: _scrollCtrl,
            pendingFiles: _pendingFiles,
            isSending: _isSending,
            isDragging: _isDragging,
            typingUser: _typingUser,
            replyingTo: _replyingTo,
            onSend: _send,
            onPickFile: _pickFile,
            onClearFile: _clearFile,
            onClearAllFiles: _clearAllFiles,
            onTyping: _emitTyping,
            onReply: _setReply,
            onClearReply: _clearReply,
            showBackButton: true,
            onBack: () {
              SocketService().leaveChannel(selectedChannel.id);
              ref.read(selectedChannelProvider.notifier).select(null);
            },
          ),
        );
      }

      // No channel selected → full-screen channel list
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              children: [
                Text('Messages',
                    style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getHeadingColor(context))),
                const Spacer(),
                Icon(FeatherIcons.hash, color: AppColors.accent, size: 18),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.getBorderColor(context)),
          Expanded(
            child: channelsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  const Center(child: Text('Error loading channels')),
              data: (channels) {
                if (channels.isEmpty)
                  return const Center(child: Text('No channels.'));
                return ListView.builder(
                  itemCount: channels.length,
                  itemBuilder: (_, i) => _ChannelTile(
                    channel: channels[i],
                    isSelected: false,
                    onTap: () => _selectChannel(channels[i]),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    // ── Desktop: two-panel layout ────────────────────────────────────────────
    return LayoutBuilder(
      builder: (context, constraints) {
        final panelWidth = (constraints.maxWidth * 0.28).clamp(240.0, 340.0);
        return Row(
          children: [
            Container(
              width: panelWidth,
              decoration: BoxDecoration(
                  border: Border(
                      right: BorderSide(
                          color: AppColors.getBorderColor(context)))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Row(
                      children: [
                        Text('Messages',
                            style: GoogleFonts.outfit(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.getHeadingColor(context))),
                        const Spacer(),
                        Icon(FeatherIcons.hash,
                            color: AppColors.accent, size: 18),
                      ],
                    ),
                  ),
                  Expanded(
                    child: channelsAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) =>
                          const Center(child: Text('Error loading channels')),
                      data: (channels) {
                        if (channels.isEmpty)
                          return const Center(child: Text('No channels.'));
                        return ListView.builder(
                          itemCount: channels.length,
                          itemBuilder: (_, i) => _ChannelTile(
                            channel: channels[i],
                            isSelected: selectedChannel?.id == channels[i].id,
                            onTap: () => _selectChannel(channels[i]),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: selectedChannel == null
                  ? _EmptyState()
                  : _buildDropTarget(
                      selectedChannel,
                      _ChatArea(
                        channel: selectedChannel,
                        inputCtrl: _inputCtrl,
                        scrollCtrl: _scrollCtrl,
                        pendingFiles: _pendingFiles,
                        isSending: _isSending,
                        isDragging: _isDragging,
                        typingUser: _typingUser,
                        replyingTo: _replyingTo,
                        onSend: _send,
                        onPickFile: _pickFile,
                        onClearFile: _clearFile,
                        onClearAllFiles: _clearAllFiles,
                        onTyping: _emitTyping,
                        onReply: _setReply,
                        onClearReply: _clearReply,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  /// Wraps [child] in a [DropTarget] that accepts OS-level file drags.
  Widget _buildDropTarget(ChannelModel channel, Widget child) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) async {
        setState(() => _isDragging = false);
        final dropped = <PlatformFile>[];
        for (final f in details.files) {
          final bytes = await f.readAsBytes();
          final name = f.name;
          dropped.add(PlatformFile(
            name: name,
            size: bytes.length,
            bytes: bytes,
            readStream: null,
          ));
        }
        if (dropped.isNotEmpty)
          setState(() => _pendingFiles = [..._pendingFiles, ...dropped]);
      },
      child: Stack(
        children: [
          child,
          if (_isDragging)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  border: Border.all(color: AppColors.accent, width: 2),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FeatherIcons.uploadCloud,
                          size: 48, color: AppColors.accent),
                      const SizedBox(height: 12),
                      Text('Drop files to send',
                          style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accent)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _ChannelTile extends StatelessWidget {
  final ChannelModel channel;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChannelTile(
      {required this.channel, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        color: isSelected
            ? AppColors.accent.withValues(alpha: 0.09)
            : Colors.transparent,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accent
                      : AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(FeatherIcons.hash,
                  size: 18,
                  color: isSelected ? Colors.white : AppColors.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(channel.subjectName,
                      style: GoogleFonts.outfit(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: 14,
                          color: isSelected
                              ? AppColors.accent
                              : AppColors.getHeadingColor(context)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (channel.teacherName != null)
                    Text(channel.teacherName!,
                        style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: AppColors.getBodyColor(context))),
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
          Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.07),
                  shape: BoxShape.circle),
              child: Icon(FeatherIcons.messageSquare,
                  size: 56, color: AppColors.accent.withValues(alpha: 0.3))),
          const SizedBox(height: 20),
          Text('Select a channel to start chatting',
              style: GoogleFonts.outfit(
                  fontSize: 15, color: AppColors.getBodyColor(context))),
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
  final List<PlatformFile> pendingFiles;
  final bool isSending;
  final bool isDragging;
  final String? typingUser;
  final ApiMessageModel? replyingTo;
  final Future<void> Function() onSend;
  final Future<void> Function() onPickFile;
  final void Function(int) onClearFile;
  final VoidCallback onClearAllFiles;
  final VoidCallback onTyping;
  final void Function(ApiMessageModel) onReply;
  final VoidCallback onClearReply;

  final bool showBackButton;
  final VoidCallback? onBack;

  const _ChatArea({
    required this.channel,
    required this.inputCtrl,
    required this.scrollCtrl,
    required this.pendingFiles,
    required this.isSending,
    required this.isDragging,
    required this.typingUser,
    required this.replyingTo,
    required this.onSend,
    required this.onPickFile,
    required this.onClearFile,
    required this.onClearAllFiles,
    required this.onTyping,
    required this.onReply,
    required this.onClearReply,
    this.showBackButton = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesState = ref.watch(messagesNotifierProvider(channel.id));
    final myId = AuthService().currentUser?['id']?.toString();

    return Column(
      children: [
        // ── Header ────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
              border: Border(
                  bottom:
                      BorderSide(color: AppColors.getBorderColor(context)))),
          child: Row(
            children: [
              if (showBackButton) ...[
                InkWell(
                  onTap: onBack,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(FeatherIcons.arrowLeft,
                        color: AppColors.accent, size: 20),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(FeatherIcons.hash,
                      color: AppColors.accent, size: 16)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(channel.subjectName,
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.getHeadingColor(context)),
                        overflow: TextOverflow.ellipsis),
                    if (channel.teacherName != null)
                      Text('Teacher: ${channel.teacherName}',
                          style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: AppColors.getBodyColor(context))),
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
                      if (messages.isEmpty)
                        return Center(
                            child: Text('No messages yet',
                                style: GoogleFonts.outfit(
                                    color: AppColors.getBodyColor(context))));
                      return NotificationListener<ScrollNotification>(
                        onNotification: (ScrollNotification scrollInfo) {
                          if (scrollInfo.metrics.pixels <= 200) {
                            ref
                                .read(messagesNotifierProvider(channel.id)
                                    .notifier)
                                .loadMore();
                          }
                          return false;
                        },
                        child: ListView.builder(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 20),
                          itemCount: messages.length,
                          itemBuilder: (_, i) {
                            final msg = messages[i];
                            final isMe = msg.senderId.toString() == myId;
                            return InkWell(
                              onLongPress: () => onReply(msg),
                              hoverColor: AppColors.getBorderColor(context)
                                  .withValues(alpha: 0.1),
                              child: _MessageBubble(
                                msg: msg,
                                isMe: isMe,
                                channel: channel,
                              ),
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
            child: Align(
                alignment: Alignment.centerLeft,
                child: Text('$typingUser is typing...',
                    style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: AppColors.getBodyColor(context)))),
          ),

        // ── Input Bar ─────────────────────────────────────────────────────
        _InputBar(
          inputCtrl: inputCtrl,
          pendingFiles: pendingFiles,
          isSending: isSending,
          replyingTo: replyingTo,
          onSend: onSend,
          onPickFile: onPickFile,
          onClearFile: onClearFile,
          onClearAllFiles: onClearAllFiles,
          onTyping: onTyping,
          onClearReply: onClearReply,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MessageBubble now extends ConsumerStatefulWidget so it can access providers
class _MessageBubble extends ConsumerStatefulWidget {
  final ApiMessageModel msg;
  final bool isMe;
  final ChannelModel channel;

  const _MessageBubble({
    required this.msg,
    required this.isMe,
    required this.channel,
  });

  @override
  ConsumerState<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<_MessageBubble> {
  static const _emojis = ['👍', '❤️', '😂', '🔥', '👀'];
  final Map<String, int> _reactions = {};
  String? _myReaction;
  bool _showPicker = false;

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
    const images = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'];
    const code = [
      'py',
      'js',
      'ts',
      'dart',
      'java',
      'c',
      'cpp',
      'cs',
      'go',
      'rb',
      'sh',
      'json',
      'xml',
      'yaml',
      'yml',
      'ipynb'
    ];
    const sheets = ['xls', 'xlsx', 'csv'];
    const slides = ['ppt', 'pptx'];
    const docs = ['doc', 'docx'];
    const arch = ['zip', 'rar', '7z'];
    if (images.contains(ext)) return FeatherIcons.image;
    if (ext == 'pdf') return FeatherIcons.fileText;
    if (docs.contains(ext)) return FeatherIcons.file;
    if (sheets.contains(ext)) return FeatherIcons.grid;
    if (slides.contains(ext)) return FeatherIcons.monitor;
    if (code.contains(ext)) return FeatherIcons.code;
    if (['txt', 'md'].contains(ext)) return FeatherIcons.alignLeft;
    if (arch.contains(ext)) return FeatherIcons.archive;
    return FeatherIcons.paperclip;
  }

  void _showFileViewer(
      BuildContext context, String url, String? fileName) async {
    final ext = fileName?.split('.').last.toLowerCase() ?? '';
    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
    final isPdf = ext == 'pdf';
    final isMobile = MediaQuery.of(context).size.width < 700;

    if (isImage) {
      // ── Image: full-screen zoomable overlay ────────────────────────────────
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
                    child: Text('Failed to load image',
                        style: GoogleFonts.outfit(color: Colors.red)),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: const Icon(FeatherIcons.xCircle,
                      color: Colors.white, size: 36),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (isMobile) {
      // ── Mobile: show an in-app bottom sheet with open / download ───────────
      // Opening new tabs is blocked on mobile browsers, so we show a sheet
      // with explicit "Open" (externalApplication) and "Download" buttons.
      final isDark = Theme.of(context).brightness == Brightness.dark;
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (sheetCtx) => Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.secondaryBackground
                : AppColors.lightSecondaryBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // drag handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.getBorderColor(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Icon(
                isPdf ? FeatherIcons.fileText : FeatherIcons.file,
                size: 48,
                color: AppColors.accent,
              ),
              const SizedBox(height: 12),
              Text(
                fileName ?? 'Attachment',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getHeadingColor(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        _downloadFile(url);
                      },
                      icon: const Icon(FeatherIcons.download, size: 16),
                      label: const Text('Download'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(sheetCtx);
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(FeatherIcons.externalLink, size: 16),
                      label: const Text('Open'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } else if (isPdf) {
      // ── Desktop PDF: open in new browser tab ──────────────────────────────
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, webOnlyWindowName: '_blank');
      }
    } else {
      // ── Desktop other files: open in new tab ──────────────────────────────
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        launchUrl(uri, webOnlyWindowName: '_blank');
      }
    }
  }

  void _downloadFile(String url) async {
    // For Cloudinary URLs, insert fl_attachment as a path transformation
    // so the browser downloads the file instead of rendering it inline.
    // e.g. .../upload/v123/... → .../upload/fl_attachment/v123/...
    String downloadUrl =
        url.split('?').first; // strip any existing query params
    if (downloadUrl.contains('cloudinary.com')) {
      // Insert the fl_attachment flag right after "/upload/"
      downloadUrl =
          downloadUrl.replaceFirst('/upload/', '/upload/fl_attachment/');
    }
    final uri = Uri.parse(downloadUrl);
    if (await canLaunchUrl(uri)) {
      launchUrl(uri, webOnlyWindowName: '_blank');
    }
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.msg;
    final isMe = widget.isMe;
    final bubbleColor = isMe
        ? AppColors.accent
        : AppColors.getBorderColor(context).withValues(alpha: 0.15);
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
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width < 700
              ? MediaQuery.of(context).size.width * 0.82
              : MediaQuery.of(context).size.width * 0.55,
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(msg.senderName,
                        style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color:
                                isFaculty ? Colors.orange : AppColors.accent)),
                    if (isFaculty) ...[
                      const SizedBox(width: 5),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4)),
                          child: const Text('Teacher',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold))),
                    ],
                  ],
                ),
              ),

            // Parent Message Thread
            if (msg.parentContent != null || msg.parentSenderName != null)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color:
                      AppColors.getBorderColor(context).withValues(alpha: 0.2),
                  border: Border(
                      left: BorderSide(color: AppColors.accent, width: 3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(msg.parentSenderName ?? 'Someone',
                        style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accent)),
                    Text(msg.parentContent ?? 'Attachment',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: AppColors.getBodyColor(context))),
                  ],
                ),
              ),

            // Long press for reactions
            GestureDetector(
              onLongPress: _togglePicker,
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // File or Text Content
                  if (msg.fileUrl != null && msg.fileUrl!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                          color: bubbleColor, borderRadius: radius),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Tap area: view file ──
                          GestureDetector(
                            onTap: () => _showFileViewer(
                                context, msg.fileUrl!, msg.fileName),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_fileIcon(msg.fileName),
                                    color: textColor, size: 22),
                                const SizedBox(width: 10),
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 140),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(msg.fileName ?? 'attachment',
                                          style: GoogleFonts.outfit(
                                              color: textColor,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 2),
                                      Text('Tap to view',
                                          style: GoogleFonts.outfit(
                                              color: textColor.withValues(
                                                  alpha: 0.7),
                                              fontSize: 10)),
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
                                child: Icon(FeatherIcons.download,
                                    color: textColor, size: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // ── Save as Note ──
                          _SaveFileBtn(
                            msg: msg,
                            channel: widget.channel,
                            fileType: SavedFileType.note,
                            tooltip: 'Save as Note',
                            icon: FeatherIcons.bookOpen,
                            activeColor: const Color(0xFF58A6FF),
                            textColor: textColor,
                          ),
                          const SizedBox(width: 6),
                          // ── Save as Question Paper ──
                          _SaveFileBtn(
                            msg: msg,
                            channel: widget.channel,
                            fileType: SavedFileType.questionPaper,
                            tooltip: 'Save as Question Paper',
                            icon: FeatherIcons.fileMinus,
                            activeColor: const Color(0xFF238636),
                            textColor: textColor,
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                          color: bubbleColor, borderRadius: radius),
                      child: Text(msg.content ?? '',
                          style: GoogleFonts.outfit(
                              color: textColor, fontSize: 14)),
                    ),

                  // Emoji Picker popup
                  if (_showPicker)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.getSurfaceColor(context),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.getBorderColor(context)),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 4)),
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
                                color: isSelected
                                    ? AppColors.accent.withValues(alpha: 0.15)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child:
                                  Text(e, style: const TextStyle(fontSize: 18)),
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
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
                                  Text(entry.key,
                                      style: const TextStyle(fontSize: 12)),
                                  const SizedBox(width: 4),
                                  Text('${entry.value}',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: isSelected
                                              ? AppColors.accent
                                              : AppColors.getBodyColor(context),
                                          fontWeight: FontWeight.w600)),
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
                if (isMe)
                  Icon(Icons.done_all,
                      size: 12, color: AppColors.accent.withValues(alpha: 0.8)),
                if (isMe) const SizedBox(width: 3),
                Text(time,
                    style: GoogleFonts.outfit(
                        fontSize: 10, color: AppColors.getBodyColor(context))),
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
  final List<PlatformFile> pendingFiles;
  final bool isSending;
  final ApiMessageModel? replyingTo;
  final Future<void> Function() onSend;
  final Future<void> Function() onPickFile;
  final void Function(int) onClearFile;
  final VoidCallback onClearAllFiles;
  final VoidCallback onTyping;
  final VoidCallback onClearReply;

  const _InputBar({
    required this.inputCtrl,
    required this.pendingFiles,
    required this.isSending,
    required this.replyingTo,
    required this.onSend,
    required this.onPickFile,
    required this.onClearFile,
    required this.onClearAllFiles,
    required this.onTyping,
    required this.onClearReply,
  });

  static IconData _fileChipIcon(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    const images = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'];
    const docs = ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx'];
    const code = [
      'py',
      'js',
      'ts',
      'dart',
      'java',
      'c',
      'cpp',
      'cs',
      'go',
      'rb',
      'sh',
      'json',
      'xml',
      'yaml',
      'yml',
      'ipynb'
    ];
    const text = ['txt', 'md', 'csv'];
    const arch = ['zip', 'rar', '7z'];
    if (images.contains(ext)) return FeatherIcons.image;
    if (ext == 'pdf') return FeatherIcons.fileText;
    if (docs.contains(ext)) return FeatherIcons.file;
    if (code.contains(ext)) return FeatherIcons.code;
    if (text.contains(ext)) return FeatherIcons.alignLeft;
    if (arch.contains(ext)) return FeatherIcons.archive;
    return FeatherIcons.paperclip;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    return Container(
      padding: EdgeInsets.fromLTRB(
          isMobile ? 12 : 20, 0, isMobile ? 12 : 20, isMobile ? 12 : 20),
      child: Column(
        children: [
          // ── Replying-to chip ─────────────────────────────────────────
          if (replyingTo != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.getBorderColor(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border(left: BorderSide(color: AppColors.accent, width: 4)),
              ),
              child: Row(
                children: [
                  Icon(FeatherIcons.cornerUpLeft,
                      color: AppColors.accent, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Replying to ${replyingTo!.senderName}',
                            style: GoogleFonts.outfit(
                                color: AppColors.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                        Text(replyingTo!.content ?? 'Attachment',
                            style: GoogleFonts.outfit(
                                color: AppColors.getBodyColor(context),
                                fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1),
                      ],
                    ),
                  ),
                  GestureDetector(
                      onTap: onClearReply,
                      child: Icon(Icons.close,
                          size: 16, color: AppColors.getBodyColor(context))),
                ],
              ),
            ),

          // ── Pending files — horizontal scrolling chips ────────────────────
          if (pendingFiles.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: pendingFiles.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (context, i) {
                          final f = pendingFiles[i];
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.getSurfaceColor(context),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color:
                                      AppColors.accent.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_fileChipIcon(f.name),
                                    size: 13, color: AppColors.accent),
                                const SizedBox(width: 5),
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 100),
                                  child: Text(f.name,
                                      style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          color: AppColors.getHeadingColor(
                                              context),
                                          fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => onClearFile(i),
                                  child: Icon(Icons.close,
                                      size: 12,
                                      color: AppColors.getBodyColor(context)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // Clear all
                  GestureDetector(
                    onTap: onClearAllFiles,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text('Clear all',
                          style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: AppColors.getBodyColor(context))),
                    ),
                  ),
                ],
              ),
            ),

          // ── Main input row ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.getSurfaceColor(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.getBorderColor(context)),
            ),
            child: Row(
              children: [
                Tooltip(
                  message: 'Attach files (multiple allowed)',
                  child: IconButton(
                    icon: Icon(FeatherIcons.paperclip,
                        color: pendingFiles.isNotEmpty
                            ? AppColors.accent
                            : AppColors.getBodyColor(context),
                        size: 20),
                    onPressed: isSending ? null : onPickFile,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: inputCtrl,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    onChanged: (_) => onTyping(),
                    onSubmitted: (_) => onSend(),
                    decoration: InputDecoration(
                      hintText: pendingFiles.isEmpty
                          ? 'Type a message or drop files here…'
                          : '${pendingFiles.length} file(s) ready — add a caption (optional)',
                      hintStyle: GoogleFonts.outfit(
                          color: AppColors.getBodyColor(context), fontSize: 14),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    style: GoogleFonts.outfit(
                        color: AppColors.getHeadingColor(context),
                        fontSize: 14),
                  ),
                ),
                isSending
                    ? const SizedBox(
                        width: 36,
                        height: 36,
                        child: Center(
                            child: SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))))
                    : GestureDetector(
                        onTap: onSend,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              gradient: AppColors.accentGradient,
                              borderRadius: BorderRadius.circular(12)),
                          child: const Icon(FeatherIcons.send,
                              color: Colors.white, size: 18),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
/// Button inside a file bubble to save/unsave the file to Notes or Q-Papers.
class _SaveFileBtn extends ConsumerWidget {
  final ApiMessageModel msg;
  final ChannelModel channel;
  final SavedFileType fileType;
  final String tooltip;
  final IconData icon;
  final Color activeColor;
  final Color textColor;

  const _SaveFileBtn({
    required this.msg,
    required this.channel,
    required this.fileType,
    required this.tooltip,
    required this.icon,
    required this.activeColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(savedFilesProvider.notifier);
    ref.watch(savedFilesProvider); // rebuild on state change
    final saved = notifier.isSaved(msg.id.toString(), fileType);

    return Tooltip(
      message: saved ? 'Remove from $tooltip' : tooltip,
      child: InkWell(
        onTap: () {
          if (saved) {
            notifier.remove('${msg.id}_${fileType.name}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Removed from ${fileType == SavedFileType.note ? 'Notes' : 'Question Papers'}'),
                backgroundColor: Colors.red.shade700,
                duration: const Duration(seconds: 2),
              ),
            );
          } else {
            notifier.save(
              msgId: msg.id.toString(),
              channelId: channel.id,
              subjectName: channel.subjectName.isNotEmpty
                  ? channel.subjectName
                  : channel.channelName,
              fileName: msg.fileName ?? 'attachment',
              fileUrl: msg.fileUrl ?? '',
              type: fileType,
              sharedBy: msg.senderName,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Saved to ${fileType == SavedFileType.note ? 'Notes' : 'Question Papers'} — ${channel.subjectName}'),
                backgroundColor: activeColor,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: saved
                ? activeColor.withValues(alpha: 0.25)
                : textColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: saved ? activeColor : textColor),
        ),
      ),
    );
  }
}
