import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/socket_service.dart';
import '../../../../core/services/auth_service.dart';
import '../providers/api_providers.dart';
import '../providers/task_provider.dart';

// ── Toast data model ──────────────────────────────────────────────────────────
enum _ToastType { message, announcement, notification }

class _ToastData {
  final String title;
  final String body;
  final _ToastType type;
  _ToastData({required this.title, required this.body, required this.type});
}

// ── Provider to expose toast queue globally ───────────────────────────────────
final _toastQueueProvider =
    NotifierProvider<_ToastQueueNotifier, List<_ToastData>>(
        _ToastQueueNotifier.new);

class _ToastQueueNotifier extends Notifier<List<_ToastData>> {
  @override
  List<_ToastData> build() => [];

  void push(_ToastData toast) => state = [...state, toast];
  void pop() => state = state.isEmpty ? [] : state.sublist(1);
}

// ─────────────────────────────────────────────────────────────────────────────
/// Wrap the entire dashboard body with this widget.
/// It listens for Socket.IO events (announcement, message, notification)
/// and shows a slide-in toast at the top-right of the screen.
///
/// Usage in main_dashboard_screen.dart:
///   NotificationToastOverlay(child: <rest of UI>)
class NotificationToastOverlay extends ConsumerStatefulWidget {
  final Widget child;
  const NotificationToastOverlay({super.key, required this.child});

  @override
  ConsumerState<NotificationToastOverlay> createState() =>
      _NotificationToastOverlayState();
}

class _NotificationToastOverlayState
    extends ConsumerState<NotificationToastOverlay> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bindSocketEvents());
  }

  void _bindSocketEvents() {
    final socket = SocketService();

    // ── New announcement ──────────────────────────────────────────────────
    socket.onNewAnnouncement((data) {
      if (!mounted) return;
      final title = data['title'] as String? ?? 'New Announcement';
      final content = data['content'] as String? ?? '';
      final subject = data['subject_name'] as String? ?? '';
      ref.read(_toastQueueProvider.notifier).push(_ToastData(
            title: '📢 $title',
            body: subject.isNotEmpty ? '$subject • $content' : content,
            type: _ToastType.announcement,
          ));
      // Refresh notification badge count
      ref.invalidate(notificationsApiProvider);
    });

    // ── Direct notification (grading, submission, etc.) ───────────────────
    socket.onNewNotification((data) {
      if (!mounted) return;
      final title = data['title'] as String? ?? 'Notification';
      final message = data['message'] as String? ?? '';
      ref.read(_toastQueueProvider.notifier).push(_ToastData(
            title: title,
            body: message,
            type: _ToastType.notification,
          ));
      ref.invalidate(notificationsApiProvider);
    });

    // ── New message in a background channel ───────────────────────────────
    socket.onNewMessage((data) {
      if (!mounted) return;
      // Only toast if the user is NOT currently viewing that channel
      final chanId = (data['channel_id'] as num?)?.toInt();
      final selectedChanId = ref.read(selectedChannelProvider)?.id;
      final currentNav = ref.read(navigationProvider);
      // Nav index 4 = Messages tab; suppress if the user is viewing that channel
      if (currentNav == 4 && chanId == selectedChanId) return;

      // Don't show toast for own messages
      final myId = AuthService().currentUser?['id']?.toString();
      final senderId = (data['sender_id'] as num?)?.toInt().toString();
      if (senderId != null && senderId == myId) return;

      final senderName = data['sender_name'] as String? ?? 'Someone';
      final content = data['content'] as String? ?? 'Sent a file';
      final subjectName =
          data['channel_name'] as String? ?? data['subject_name'] as String? ?? 'a channel';

      ref.read(_toastQueueProvider.notifier).push(_ToastData(
            title: '💬 $senderName',
            body: '$subjectName • $content',
            type: _ToastType.message,
          ));
    });
  }

  @override
  void dispose() {
    SocketService().off('announcement:new');
    SocketService().off('notification:new');
    // NOTE: We do NOT off('message:new') here because MessagesViewWidget
    // also listens to it — removing it would break the chat.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(_toastQueueProvider);

    return Stack(
      children: [
        widget.child,
        // Show the first toast in queue, positioned top-right
        if (queue.isNotEmpty)
          Positioned(
            top: 16,
            right: 16,
            child: _ToastCard(
              data: queue.first,
              onDismissed: () =>
                  ref.read(_toastQueueProvider.notifier).pop(),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
/// Animated slide-in toast card. Auto-dismisses after 4 seconds.
class _ToastCard extends StatefulWidget {
  final _ToastData data;
  final VoidCallback onDismissed;
  const _ToastCard({required this.data, required this.onDismissed});

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slide = Tween<Offset>(begin: const Offset(1.2, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _ctrl.forward();

    // Auto-dismiss after 4 seconds
    _autoTimer = Timer(const Duration(seconds: 4), _dismiss);
  }

  Future<void> _dismiss() async {
    _autoTimer?.cancel();
    if (!mounted) return;
    await _ctrl.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Color get _accentColor {
    switch (widget.data.type) {
      case _ToastType.announcement:
        return const Color(0xFFF78166); // orange-red
      case _ToastType.message:
        return const Color(0xFF58A6FF); // blue
      case _ToastType.notification:
        return const Color(0xFF3FB950); // green
    }
  }

  IconData get _icon {
    switch (widget.data.type) {
      case _ToastType.announcement:
        return FeatherIcons.bell;
      case _ToastType.message:
        return FeatherIcons.messageSquare;
      case _ToastType.notification:
        return FeatherIcons.zap;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF21262D) : Colors.white;
    final borderColor = _accentColor.withValues(alpha: 0.5);

    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 320,
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Icon ──
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_icon, size: 16, color: _accentColor),
                ),
                const SizedBox(width: 10),

                // ── Text ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.data.title,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.textHeading
                              : AppColors.lightTextHeading,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.data.body.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.data.body,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.textBody
                                : AppColors.lightTextBody,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // ── Dismiss button ──
                GestureDetector(
                  onTap: _dismiss,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      FeatherIcons.x,
                      size: 14,
                      color: isDark ? AppColors.textBody : AppColors.lightTextBody,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
