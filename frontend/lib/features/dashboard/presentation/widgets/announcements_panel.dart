import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/socket_service.dart';
import '../../../../features/auth/auth_provider.dart';
import '../../data/repositories/announcement_repository.dart';
import '../providers/api_providers.dart';

class AnnouncementsPanel extends ConsumerStatefulWidget {
  const AnnouncementsPanel({super.key});

  @override
  ConsumerState<AnnouncementsPanel> createState() => _AnnouncementsPanelState();
}

class _AnnouncementsPanelState extends ConsumerState<AnnouncementsPanel> {
  @override
  void initState() {
    super.initState();

    // Re-fetch on mount. Using whenData ensures we only invalidate once auth
    // is confirmed — prevents the race condition where isFaculty defaults to
    // false during auth loading, invalidating the wrong provider variant.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(authProvider).whenData((auth) {
        ref.invalidate(dashboardRecentActivityProvider(auth.isFaculty));
      });
    });

    // Listen for real-time announcement broadcasts from the backend.
    // When a teacher posts, the backend emits 'announcement:new' to all
    // channel members so they see it without refreshing.
    SocketService().onNewAnnouncement((_) {
      if (!mounted) return;
      final isFaculty = ref.read(authProvider).value?.isFaculty ?? false;
      ref.invalidate(dashboardRecentActivityProvider(isFaculty));
    });
  }

  @override
  void dispose() {
    SocketService().off('announcement:new');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFaculty = ref.watch(authProvider).value?.isFaculty ?? false;
    final activityAsync = ref.watch(dashboardRecentActivityProvider(isFaculty));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Announcements',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.getHeadingColor(context),
              ),
            ),
            Icon(FeatherIcons.bell,
                size: 18, color: AppColors.getBodyColor(context)),
          ],
        ),
        const SizedBox(height: 16),

        // ── Body ────────────────────────────────────────────────────────────
        activityAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) {
            debugPrint('AnnouncementsPanel error: $e');
            return _ErrorState(
              onRetry: () =>
                  ref.invalidate(dashboardRecentActivityProvider(isFaculty)),
            );
          },
          data: (activity) {
            final announcements =
                (activity['announcements'] as List<Map<String, dynamic>>?) ??
                    [];

            if (announcements.isEmpty) {
              return _EmptyAnnouncements(isFaculty: isFaculty);
            }

            return Column(
              children: announcements
                  .map((ann) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _AnnouncementItem(
                          data: ann,
                          isFaculty: isFaculty,
                          onDeleted: () => ref.invalidate(
                              dashboardRecentActivityProvider(isFaculty)),
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

// ── Announcement Item ──────────────────────────────────────────────────────────
class _AnnouncementItem extends ConsumerWidget {
  final Map<String, dynamic> data;
  final bool isFaculty;
  final VoidCallback onDeleted;

  const _AnnouncementItem({
    required this.data,
    required this.isFaculty,
    required this.onDeleted,
  });

  static final _announcementRepo = AnnouncementRepository();

  static const _colors = [
    Color(0xFF58A6FF),
    Color(0xFFA475F9),
    Color(0xFF3FB950),
    Color(0xFFD29922),
    Color(0xFFFF6B6B),
  ];

  Future<void> _confirmDelete(BuildContext context) async {
    final annId = (data['id'] as num?)?.toInt();
    final channelId = (data['channel_id'] as num?)?.toInt();
    if (annId == null || channelId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getSurfaceColor(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Announcement?',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: AppColors.getHeadingColor(ctx))),
        content: Text(
            'This announcement will be permanently removed for all students.',
            style: GoogleFonts.outfit(color: AppColors.getBodyColor(ctx))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: AppColors.getBodyColor(ctx))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: GoogleFonts.outfit(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _announcementRepo.deleteAnnouncement(channelId, annId);
      onDeleted();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Announcement deleted'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to delete: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = data['title'] as String? ?? '';
    final content = data['content'] as String? ?? '';
    final sender = data['created_by_name'] as String? ?? 'Teacher';
    final subject = data['subject_name'] as String? ?? '';
    final isImportant = data['is_important'] as bool? ?? false;
    final rawDate = data['created_at'] as String?;
    final timeAgo =
        rawDate != null ? _formatTimeAgo(DateTime.parse(rawDate)) : '';
    final colorIndex =
        sender.isNotEmpty ? sender.codeUnitAt(0) % _colors.length : 0;
    final color = isImportant ? Colors.orange : _colors[colorIndex];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isImportant
              ? Colors.orange.withValues(alpha: 0.4)
              : AppColors.getBorderColor(context),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isImportant ? FeatherIcons.alertCircle : FeatherIcons.bell,
              size: 15,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getHeadingColor(context),
                    ),
                  ),
                if (content.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.getBodyColor(context),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      sender,
                      style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.w600),
                    ),
                    if (subject.isNotEmpty) ...[
                      Text(' · ',
                          style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: AppColors.getBodyColor(context))),
                      Expanded(
                        child: Text(
                          subject,
                          style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: AppColors.getBodyColor(context)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      timeAgo,
                      style: GoogleFonts.outfit(
                          fontSize: 10, color: AppColors.getBodyColor(context)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // ── Delete button (faculty only) ─────────────────────────────────
          if (isFaculty) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: 'Delete announcement',
              child: GestureDetector(
                onTap: () => _confirmDelete(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(FeatherIcons.trash2,
                      size: 13, color: Colors.red.shade400),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt.toLocal());
  }
}

// ── Empty State ────────────────────────────────────────────────────────────────
class _EmptyAnnouncements extends StatelessWidget {
  final bool isFaculty;
  const _EmptyAnnouncements({required this.isFaculty});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.getBorderColor(context),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FeatherIcons.bell,
            size: 36,
            color: AppColors.getBodyColor(context).withValues(alpha: 0.25),
          ),
          const SizedBox(height: 12),
          Text(
            'No announcements yet',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.getHeadingColor(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isFaculty
                ? 'Post an announcement to notify your students.'
                : 'Your teachers haven\'t posted anything yet.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.getBodyColor(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error State ────────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorderColor(context)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FeatherIcons.wifiOff,
              size: 28,
              color: AppColors.getBodyColor(context).withValues(alpha: 0.35)),
          const SizedBox(height: 10),
          Text(
            'Could not load announcements',
            style: GoogleFonts.outfit(
                fontSize: 13, color: AppColors.getHeadingColor(context)),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            icon: const Icon(FeatherIcons.refreshCw, size: 14),
            label: Text('Retry', style: GoogleFonts.outfit(fontSize: 13)),
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
