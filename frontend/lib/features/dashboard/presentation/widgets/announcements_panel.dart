import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/task_provider.dart';

class AnnouncementsPanel extends ConsumerWidget {
  const AnnouncementsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Announcements',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.getHeadingColor(context),
              ),
            ),
            IconButton(
              icon: Icon(FeatherIcons.edit, size: 18, color: AppColors.getBodyColor(context)),
              onPressed: () {},
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildAnnouncementItem(
          context,
          title: 'Final Exam Schedule',
          sender: 'Dr. Sarah Mitchell',
          time: '2 hours ago',
          color: Colors.blue,
        ),
        const SizedBox(height: 12),
        _buildAnnouncementItem(
          context,
          title: 'New Lab Material Posted',
          sender: 'Prof. James Wilson',
          time: '5 hours ago',
          color: Colors.purple,
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Chat',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.getHeadingColor(context),
              ),
            ),
             Icon(FeatherIcons.users, size: 18, color: AppColors.getBodyColor(context)),
          ],
        ),
        const SizedBox(height: 16),
        _buildChatItem(
          context,
          ref,
          name: 'Class Group Chat',
          message: 'Hey, has anyone finished Lab 4?',
          time: '12:45 PM',
          isUnread: true,
        ),
        const SizedBox(height: 12),
        _buildChatItem(
          context,
          ref,
          name: 'Jane Cooper',
          message: 'Can you share the notes for...',
          time: '10:30 AM',
          isUnread: false,
        ),
        const SizedBox(height: 12),
        _buildChatItem(
          context,
          ref,
          name: 'Guy Hawkins',
          message: 'The deadline is tonight!',
          time: 'Yesterday',
          isUnread: false,
        ),
      ],
    );
  }

  Widget _buildAnnouncementItem(
    BuildContext context, {
    required String title,
    required String sender,
    required String time,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorderColor(context), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(FeatherIcons.bell, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getHeadingColor(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sender,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.getBodyColor(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                 time,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.getBodyColor(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatItem(
    BuildContext context,
    WidgetRef ref, {
    required String name,
    required String message,
    required String time,
    required bool isUnread,
  }) {
    return InkWell(
      onTap: () {
        ref.read(navigationProvider.notifier).navigateTo(5); // Switch to Messages
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.getBorderColor(context), width: 1),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.getBorderColor(context),
              child: Text(name[0], style: TextStyle(fontSize: 12, color: AppColors.getHeadingColor(context))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getHeadingColor(context),
                        ),
                      ),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.getBodyColor(context),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 12,
                      color: isUnread ? AppColors.getHeadingColor(context) : AppColors.getBodyColor(context),
                      fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
