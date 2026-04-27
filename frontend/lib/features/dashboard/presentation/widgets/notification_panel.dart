import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/api_service.dart';
import 'package:intl/intl.dart';
import '../providers/api_providers.dart';

class NotificationPanel extends ConsumerWidget {
  const NotificationPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsApiProvider);

    return Container(
      width: 360,
      constraints: const BoxConstraints(maxHeight: 520),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(color: AppColors.getBorderColor(context), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 8, 12),
            child: Row(
              children: [
                Icon(FeatherIcons.bell, size: 18, color: AppColors.accent),
                const SizedBox(width: 10),
                Text(
                  'Notifications',
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getHeadingColor(context),
                  ),
                ),
                const Spacer(),
                // Refresh
                IconButton(
                  icon: Icon(FeatherIcons.refreshCw,
                      size: 15, color: AppColors.getBodyColor(context)),
                  tooltip: 'Refresh',
                  onPressed: () => ref.invalidate(notificationsApiProvider),
                  splashRadius: 18,
                ),
                // Mark all read
                notificationsAsync.whenOrNull(
                  data: (list) => list.isNotEmpty
                      ? TextButton(
                          onPressed: () async {
                            await ApiService().dio.patch('/notifications/read-all');
                            ref.invalidate(notificationsApiProvider);
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: Text('Mark all read',
                              style: GoogleFonts.outfit(
                                  fontSize: 11, color: AppColors.accent)),
                        )
                      : null,
                ) ?? const SizedBox.shrink(),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.getBorderColor(context)),

          // ── Body ──────────────────────────────────────────────────────────
          Flexible(
            child: notificationsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(FeatherIcons.alertCircle, size: 36, color: Colors.red.shade400),
                      const SizedBox(height: 12),
                      Text('Could not load notifications',
                          style: GoogleFonts.outfit(
                              color: AppColors.getBodyColor(context), fontSize: 13)),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: () => ref.invalidate(notificationsApiProvider),
                        icon: const Icon(FeatherIcons.refreshCw, size: 14),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            textStyle: GoogleFonts.outfit()),
                      ),
                    ],
                  ),
                ),
              ),
              data: (notifications) {
                if (notifications.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(FeatherIcons.bellOff,
                              size: 44,
                              color: AppColors.getBodyColor(context).withValues(alpha: 0.4)),
                          const SizedBox(height: 14),
                          Text('All caught up!',
                              style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.getHeadingColor(context))),
                          const SizedBox(height: 4),
                          Text('No new notifications',
                              style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: AppColors.getBodyColor(context))),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: AppColors.getBorderColor(context)),
                  itemBuilder: (context, index) {
                    final n = notifications[index];
                    final isRead = n['is_read'] as bool? ?? false;
                    final title = n['title'] as String? ?? 'Notification';
                    final message = n['message'] as String? ?? '';
                    final createdAt = n['created_at'] as String?;
                    final id = (n['id'] as num?)?.toInt();
                    final timestamp = createdAt != null
                        ? DateTime.tryParse(createdAt) ?? DateTime.now()
                        : DateTime.now();

                    return Container(
                      color: isRead
                          ? Colors.transparent
                          : AppColors.accent.withValues(alpha: 0.04),
                      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon dot
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: isRead
                                  ? AppColors.getBorderColor(context).withValues(alpha: 0.2)
                                  : AppColors.accent.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              FeatherIcons.bell,
                              size: 14,
                              color: isRead
                                  ? AppColors.getBodyColor(context)
                                  : AppColors.accent,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Text
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: isRead
                                              ? FontWeight.w500
                                              : FontWeight.bold,
                                          color: AppColors.getHeadingColor(context),
                                        ),
                                      ),
                                    ),
                                    if (!isRead)
                                      Container(
                                        width: 7,
                                        height: 7,
                                        margin: const EdgeInsets.only(left: 6),
                                        decoration: const BoxDecoration(
                                          color: AppColors.accent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  message,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: AppColors.getBodyColor(context),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  DateFormat('MMM d, h:mm a').format(timestamp),
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    color: AppColors.getBodyColor(context).withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Mark read / dismiss
                          if (id != null)
                            Column(
                              children: [
                                if (!isRead)
                                  IconButton(
                                    icon: Icon(FeatherIcons.check,
                                        size: 14,
                                        color: AppColors.getBodyColor(context).withValues(alpha: 0.6)),
                                    tooltip: 'Mark as read',
                                    splashRadius: 16,
                                    onPressed: () async {
                                      await ApiService().markNotificationRead(id);
                                      ref.invalidate(notificationsApiProvider);
                                    },
                                  ),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
