import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/sidebar_widget.dart';
import '../widgets/top_bar_widget.dart';
import '../widgets/announcements_panel.dart';
import '../widgets/calendar_view_widget.dart';
import '../widgets/subjects_view_widget.dart';
import '../widgets/assignments_view_widget.dart';
import '../widgets/projects_view_widget.dart';
import '../widgets/messages_view_widget.dart';
import '../widgets/settings_view_widget.dart';
import '../widgets/today_overview_widget.dart';
import '../widgets/teacher_overview_widget.dart';
import '../providers/task_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/auth/auth_provider.dart';

class MainDashboardScreen extends ConsumerWidget {
  const MainDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(navigationProvider);
    final isMobile = MediaQuery.of(context).size.width < 850;
    final isFaculty = ref.read(authProvider).value?.isFaculty ?? false;

    return Scaffold(
      drawer: isMobile
          ? Drawer(
              width: 280,
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.secondaryBackground
                  : AppColors.lightSecondaryBackground,
              child: const SidebarWidget(),
            )
          : null,
      endDrawer: isMobile && selectedIndex == 0
          ? Drawer(
              width: 320,
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.secondaryBackground
                  : AppColors.lightSecondaryBackground,
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.campaign_rounded,
                              color: AppColors.accent, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            'Announcements',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getHeadingColor(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Divider(color: AppColors.getBorderColor(context)),
                      const SizedBox(height: 8),
                      const AnnouncementsPanel(),
                    ],
                  ),
                ),
              ),
            )
          : null,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMobile)
            const SizedBox(
              width: 240,
              child: SidebarWidget(),
            ),
          Expanded(
            child: Column(
              children: [
                const TopBarWidget(),
                Expanded(
                  // IndexedStack keeps all tab widgets alive in memory.
                  // Switching tabs is instant — no rebuild, no refetch.
                  child: IndexedStack(
                    index: selectedIndex,
                    children: [
                      isFaculty
                          ? const TeacherOverviewWidget()
                          : const TodayOverviewWidget(),
                      const SubjectsViewWidget(),
                      const AssignmentsViewWidget(),
                      const ProjectsViewWidget(),
                      const CalendarViewWidget(),
                      const MessagesViewWidget(),
                      const SettingsViewWidget(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isMobile && selectedIndex == 0 && !isFaculty)
            Container(
              width: 300,
              height: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.secondaryBackground
                    : AppColors.lightSecondaryBackground,
                border: Border(
                  left: BorderSide(color: AppColors.getBorderColor(context), width: 1),
                ),
              ),
              child: const SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: AnnouncementsPanel(),
              ),
            ),
        ],
      ),
    );
  }
}


