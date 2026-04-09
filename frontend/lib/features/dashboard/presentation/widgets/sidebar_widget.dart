import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/task_provider.dart';
import '../../../../features/auth/auth_provider.dart';

class SidebarWidget extends ConsumerWidget {
  const SidebarWidget({super.key});

  static final List<SidebarItemModel> items = [
    SidebarItemModel(icon: FeatherIcons.grid, title: 'Dashboard'),
    SidebarItemModel(icon: FeatherIcons.book, title: 'Subjects'),
    SidebarItemModel(icon: FeatherIcons.fileText, title: 'Assignments'),
    SidebarItemModel(icon: FeatherIcons.folder, title: 'Projects'),
    SidebarItemModel(icon: FeatherIcons.calendar, title: 'Calendar'),
    SidebarItemModel(icon: FeatherIcons.messageSquare, title: 'Messages'),
    SidebarItemModel(icon: FeatherIcons.settings, title: 'Settings'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(navigationProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.secondaryBackground : AppColors.lightSecondaryBackground,
      ),
      child: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 16),

          // Header Logo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: SvgPicture.asset(
              'assets/images/adtu_logo.svg',
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
                      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.accent.withOpacity(0.12) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(color: AppColors.accent.withOpacity(0.3), width: 1)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.icon,
                            size: 20,
                            color: isSelected ? AppColors.accent : AppColors.getBodyColor(context),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? AppColors.accent : AppColors.getBodyColor(context),
                            ),
                          ),
                          if (isSelected) ...[
                            const Spacer(),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // User Profile at bottom
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Consumer(
              builder: (context, ref, _) {
                final authState = ref.watch(authProvider).value;
                final userName = authState?.userName ?? 'Student';
                final userRole = authState?.userRole ?? 'student';
                final initials = userName.isNotEmpty ? userName[0].toUpperCase() : 'S';
                return InkWell(
                  onTap: () {
                    ref.read(navigationProvider.notifier).navigateTo(6);
                    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.getSurfaceColor(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.getBorderColor(context), width: 1),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.accent.withOpacity(0.15),
                          child: Text(initials, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.accent)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.getHeadingColor(context)),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                userRole[0].toUpperCase() + userRole.substring(1),
                                style: TextStyle(fontSize: 11, color: AppColors.getBodyColor(context)),
                              ),
                            ],
                          ),
                        ),
                        Icon(FeatherIcons.logOut, size: 16, color: AppColors.getBodyColor(context)),
                      ],
                    ),
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
