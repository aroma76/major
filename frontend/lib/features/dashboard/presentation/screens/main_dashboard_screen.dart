import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import '../widgets/sidebar_widget.dart';
import '../widgets/top_bar_widget.dart';
import '../widgets/announcements_panel.dart';
import '../widgets/calendar_view_widget.dart';
import '../widgets/subjects_view_widget.dart';
import '../widgets/assignments_view_widget.dart';
import '../widgets/projects_view_widget.dart';
import '../widgets/messages_view_widget.dart';
import '../widgets/notes_view_widget.dart';
import '../widgets/question_papers_view_widget.dart';
import '../widgets/settings_view_widget.dart';
import '../widgets/today_overview_widget.dart';
import '../widgets/teacher_overview_widget.dart';
import '../providers/task_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/auth/auth_provider.dart';

class MainDashboardScreen extends ConsumerStatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  ConsumerState<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends ConsumerState<MainDashboardScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(navigationProvider);
    final isMobile = MediaQuery.of(context).size.width < 850;
    final isFaculty = ref.read(authProvider).value?.isFaculty ?? false;

    // ── Student bottom nav items (indices match IndexedStack order) ──────────
    final studentBottomItems = [
      _MobileNavItem(icon: FeatherIcons.grid,          label: 'Home',        index: 0),
      _MobileNavItem(icon: FeatherIcons.book,          label: 'Subjects',    index: 1),
      _MobileNavItem(icon: FeatherIcons.fileText,      label: 'Assignments', index: 2),
      _MobileNavItem(icon: FeatherIcons.messageSquare, label: 'Messages',    index: 5),
      _MobileNavItem(icon: FeatherIcons.menu,          label: 'More',        index: -1),
    ];
    final facultyBottomItems = [
      _MobileNavItem(icon: FeatherIcons.grid,          label: 'Home',       index: 0),
      _MobileNavItem(icon: FeatherIcons.bookOpen,      label: 'Subjects',   index: 1),
      _MobileNavItem(icon: FeatherIcons.edit3,         label: 'Grades',     index: 2),
      _MobileNavItem(icon: FeatherIcons.messageSquare, label: 'Messages',   index: 5),
      _MobileNavItem(icon: FeatherIcons.menu,          label: 'More',       index: -1),
    ];

    final bottomItems = isFaculty ? facultyBottomItems : studentBottomItems;

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        width: 280,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.secondaryBackground
            : AppColors.lightSecondaryBackground,
        child: const SidebarWidget(),
      ),
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
      // ── Mobile bottom nav bar ──────────────────────────────────────────────
      bottomNavigationBar: isMobile
          ? _MobileBottomNavBar(
              items: bottomItems,
              selectedIndex: selectedIndex,
              onTap: (item) {
                if (item.index == -1) {
                  // "More" → open sidebar drawer via key
                  _scaffoldKey.currentState?.openDrawer();
                } else {
                  ref.read(navigationProvider.notifier).navigateTo(item.index);
                }
              },
            )
          : null,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Desktop sidebar
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
                      const NotesViewWidget(),
                      const QuestionPapersViewWidget(),
                      const SettingsViewWidget(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Desktop announcements panel
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


// ─────────────────────────────────────────────────────────────────────────────

class _MobileNavItem {
  final IconData icon;
  final String label;
  final int index; // -1 = "More" (opens drawer)
  const _MobileNavItem(
      {required this.icon, required this.label, required this.index});
}

class _MobileBottomNavBar extends ConsumerWidget {
  final List<_MobileNavItem> items;
  final int selectedIndex;
  final void Function(_MobileNavItem item) onTap;

  const _MobileBottomNavBar({
    required this.items,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.secondaryBackground : AppColors.lightSecondaryBackground,
        border: Border(
          top: BorderSide(color: AppColors.getBorderColor(context), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(8, 8, 8, bottomPad > 0 ? 4 : 8),
          child: Row(
            children: items.map((item) {
              final isSelected = item.index != -1 && selectedIndex == item.index;
              return Expanded(
                child: _BottomNavTile(
                  item: item,
                  isSelected: isSelected,
                  onTap: () => onTap(item),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _BottomNavTile extends StatefulWidget {
  final _MobileNavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _BottomNavTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_BottomNavTile> createState() => _BottomNavTileState();
}

class _BottomNavTileState extends State<_BottomNavTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _scale = Tween<double>(begin: 1.0, end: 0.88)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _anim.forward();
  void _onTapUp(TapUpDetails _) {
    _anim.reverse();
    widget.onTap();
  }

  void _onTapCancel() => _anim.reverse();

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accent.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.all(isSelected ? 6 : 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accent.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  widget.item.icon,
                  size: 20,
                  color: isSelected
                      ? AppColors.accent
                      : AppColors.getBodyColor(context),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                widget.item.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.accent
                      : AppColors.getBodyColor(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
