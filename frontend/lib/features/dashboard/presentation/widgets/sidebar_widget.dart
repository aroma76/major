import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/task_provider.dart';
import '../../../../features/auth/auth_provider.dart';

class SidebarWidget extends ConsumerWidget {
  const SidebarWidget({super.key});

  // ── Student nav items ─────────────────────────────────────────────────────────────────────────────
  static final List<SidebarItemModel> studentItems = [
    SidebarItemModel(icon: FeatherIcons.grid, title: 'Dashboard'),
    SidebarItemModel(icon: FeatherIcons.book, title: 'Subjects'),
    SidebarItemModel(icon: FeatherIcons.folder, title: 'Projects'),
    SidebarItemModel(icon: FeatherIcons.calendar, title: 'Calendar'),
    SidebarItemModel(icon: FeatherIcons.messageSquare, title: 'Messages'),
    SidebarItemModel(icon: FeatherIcons.bookOpen, title: 'Notes'),
    SidebarItemModel(icon: FeatherIcons.fileMinus, title: 'Question Papers'),
  ];

  // ── Faculty / Teacher nav items ───────────────────────────────────────────
  static final List<SidebarItemModel> facultyItems = [
    SidebarItemModel(icon: FeatherIcons.grid, title: 'Dashboard'),
    SidebarItemModel(icon: FeatherIcons.bookOpen, title: 'Manage Subjects'),
    SidebarItemModel(icon: FeatherIcons.folder, title: 'Student Projects'),
    SidebarItemModel(icon: FeatherIcons.calendar, title: 'Schedule'),
    SidebarItemModel(icon: FeatherIcons.messageSquare, title: 'Messages'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(navigationProvider);
    final authState = ref.watch(authProvider).value;
    final isFaculty = authState?.isFaculty ?? false;
    final items = isFaculty ? facultyItems : studentItems;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.secondaryBackground
            : AppColors.lightSecondaryBackground,
      ),
      child: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 16),

          // Header Logo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Image.asset(
              'assets/images/adtu_logo.png',
              height: 52,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
            ),
          ),

          const SizedBox(height: 8),
          Divider(color: AppColors.getBorderColor(context), height: 1),
          const SizedBox(height: 12),

          // Navigation Items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = selectedIndex == index;
                const int unreadCount = 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      ref.read(navigationProvider.notifier).navigateTo(index);
                      // Auto-close drawer when inside a Drawer (mobile)
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          vertical: 13, horizontal: 16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accent.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(
                                color: AppColors.accent.withValues(alpha: 0.3),
                                width: 1)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.icon,
                            size: 20,
                            color: isSelected
                                ? AppColors.accent
                                : AppColors.getBodyColor(context),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppColors.accent
                                    : AppColors.getBodyColor(context),
                              ),
                            ),
                          ),
                          // Unread badge for Messages
                          if (unreadCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$unreadCount',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          else if (isSelected)
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Divider(color: AppColors.getBorderColor(context)),
          ),
          // Settings item
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                ref.read(navigationProvider.notifier).navigateTo(7);
                if (Navigator.of(context).canPop()) Navigator.of(context).pop();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                decoration: BoxDecoration(
                  color: selectedIndex == 7
                      ? AppColors.accent.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: selectedIndex == 7
                      ? Border.all(
                          color: AppColors.accent.withValues(alpha: 0.3))
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      FeatherIcons.settings,
                      size: 20,
                      color: selectedIndex == 7
                          ? AppColors.accent
                          : AppColors.getBodyColor(context),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: selectedIndex == 7
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: selectedIndex == 7
                            ? AppColors.accent
                            : AppColors.getBodyColor(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // User Profile at bottom
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Consumer(
              builder: (context, ref, _) {
                final authState = ref.watch(authProvider).value;
                final userName =
                    authState?.userName ?? (isFaculty ? 'Faculty' : 'Student');
                final userRole = authState?.userRole ?? 'student';
                final initials =
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'S';
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.getSurfaceColor(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.getBorderColor(context), width: 1),
                  ),
                  child: Row(
                    children: [
                      // Profile area → go to Settings
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            ref.read(navigationProvider.notifier).navigateTo(7);
                            if (Navigator.of(context).canPop())
                              Navigator.of(context).pop();
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor:
                                    AppColors.accent.withValues(alpha: 0.15),
                                child: Text(initials,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.accent)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.getHeadingColor(
                                              context)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      userRole[0].toUpperCase() +
                                          userRole.substring(1),
                                      style: TextStyle(
                                          fontSize: 11,
                                          color:
                                              AppColors.getBodyColor(context)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Settings button
                      Tooltip(
                        message: 'Settings',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            ref.read(navigationProvider.notifier).navigateTo(7);
                            if (Navigator.of(context).canPop())
                              Navigator.of(context).pop();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(FeatherIcons.settings,
                                size: 17,
                                color: AppColors.getBodyColor(context)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Logout button
                      Tooltip(
                        message: 'Logout',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor:
                                    AppColors.getSurfaceColor(context),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                                title: Text('Sign Out',
                                    style: TextStyle(
                                        color:
                                            AppColors.getHeadingColor(context),
                                        fontWeight: FontWeight.bold)),
                                content: Text(
                                    'Are you sure you want to sign out?',
                                    style: TextStyle(
                                        color:
                                            AppColors.getBodyColor(context))),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel')),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white),
                                    child: const Text('Sign Out'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await ref.read(authProvider.notifier).logout();
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(FeatherIcons.logOut,
                                size: 17, color: Colors.red.shade400),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

class SidebarItemModel {
  final IconData icon;
  final String title;

  SidebarItemModel({required this.icon, required this.title});
}
