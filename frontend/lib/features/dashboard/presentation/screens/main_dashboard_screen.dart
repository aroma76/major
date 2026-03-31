import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/sidebar_widget.dart';
import '../widgets/top_bar_widget.dart';
import '../widgets/kanban_board_widget.dart';
import '../widgets/overview_cards_widget.dart';
import '../widgets/announcements_panel.dart';
import '../widgets/calendar_view_widget.dart';
import '../widgets/subjects_view_widget.dart';
import '../widgets/assignments_view_widget.dart';
import '../widgets/projects_view_widget.dart';
import '../widgets/messages_view_widget.dart';
import '../widgets/settings_view_widget.dart';
import '../providers/task_provider.dart';
import '../../../../core/theme/app_colors.dart';

class MainDashboardScreen extends ConsumerWidget {
  const MainDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(navigationProvider);

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SidebarWidget(),
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
          if (selectedIndex == 0)
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
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const OverviewCardsWidget(),
            const SizedBox(height: 32),
            const KanbanBoardWidget(),
          ],
        ),
      ),
    );
  }
}
