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
import '../providers/task_provider.dart';
import '../../../../core/theme/app_colors.dart';

class MainDashboardScreen extends ConsumerWidget {
  const MainDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(navigationProvider);
    final isMobile = MediaQuery.of(context).size.width < 850;

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
                  child: _buildBody(context, selectedIndex),
                ),
              ],
            ),
          ),
          if (!isMobile && selectedIndex == 0)
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

  Widget _buildBody(BuildContext context, int index) {
    switch (index) {
      case 0: // Dashboard
        return _buildDashboardView(context);
      case 1: // Subjects
        return const SubjectsViewWidget();
      case 2: // Assignments
        return const AssignmentsViewWidget();
      case 3: // Projects
        return const ProjectsViewWidget();
      case 4: // Calendar
        return const CalendarViewWidget();
      case 5: // Messages
        return const MessagesViewWidget();
      case 6: // Settings
        return const SettingsViewWidget();
      default:
        return _buildDashboardView(context);
    }
  }

  Widget _buildDashboardView(BuildContext context) {
    return const TodayOverviewWidget();
  }
}

