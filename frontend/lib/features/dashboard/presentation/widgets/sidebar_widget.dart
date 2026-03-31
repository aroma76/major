import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/task_provider.dart';

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
    
    return Container(
      width: 240,
      color: Theme.of(context).brightness == Brightness.dark 
          ? AppColors.secondaryBackground 
          : AppColors.lightSecondaryBackground,
      child: Column(
        children: [
          // Header Logo
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(FeatherIcons.zap, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  'EduNova',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getHeadingColor(context),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Navigation Items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = selectedIndex == index;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      ref.read(navigationProvider.notifier).navigateTo(index);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.accent.withOpacity(0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected 
                          ? Border.all(color: AppColors.accent.withOpacity(0.3), width: 1)
                          : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.icon,
                            size: 22,
                            color: isSelected ? AppColors.accent : AppColors.getBodyColor(context),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? AppColors.accent : AppColors.getBodyColor(context),
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
          
          // User Profile at bottom
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: InkWell(
              onTap: () {
                // Navigate to Settings/Profile (index 6)
                ref.read(navigationProvider.notifier).navigateTo(6);
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
                     const CircleAvatar(
                      radius: 20,
                      backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=11'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'John Doe',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getHeadingColor(context),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Student',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.getBodyColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(FeatherIcons.moreVertical, size: 18, color: AppColors.getBodyColor(context)),
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

class SidebarItemModel {
  final IconData icon;
  final String title;

  SidebarItemModel({required this.icon, required this.title});
}
