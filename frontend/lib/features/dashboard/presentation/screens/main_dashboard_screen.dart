import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import '../widgets/sidebar_widget.dart';
import '../widgets/top_bar_widget.dart';
import '../widgets/announcements_panel.dart';
import '../widgets/calendar_view_widget.dart';
import '../widgets/subjects_view_widget.dart';
import '../widgets/projects_view_widget.dart';
import '../widgets/messages_view_widget.dart';
import '../widgets/notes_view_widget.dart';
import '../widgets/question_papers_view_widget.dart';
import '../widgets/settings_view_widget.dart';
import '../widgets/today_overview_widget.dart';
import '../widgets/teacher_overview_widget.dart';
import '../widgets/notification_toast.dart';
import '../providers/task_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/auth/auth_provider.dart';
import '../../../../core/utils/responsive.dart';

class MainDashboardScreen extends ConsumerStatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  ConsumerState<MainDashboardScreen> createState() =>
      _MainDashboardScreenState();
}

class _MainDashboardScreenState extends ConsumerState<MainDashboardScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(navigationProvider);
    final isMobile = Responsive.isMobile(context);
    final isFaculty = ref.read(authProvider).value?.isFaculty ?? false;

    // ── Student bottom nav items (indices match IndexedStack order) ──────────────
    final studentBottomItems = [
      _MobileNavItem(icon: FeatherIcons.grid, label: 'Home', index: 0),
      _MobileNavItem(icon: FeatherIcons.book, label: 'Subjects', index: 1),
      _MobileNavItem(icon: FeatherIcons.folder, label: 'Projects', index: 2),
      _MobileNavItem(
          icon: FeatherIcons.messageSquare, label: 'Messages', index: 4),
      _MobileNavItem(icon: FeatherIcons.menu, label: 'More', index: -1),
    ];
    final facultyBottomItems = [
      _MobileNavItem(icon: FeatherIcons.grid, label: 'Home', index: 0),
      _MobileNavItem(icon: FeatherIcons.bookOpen, label: 'Subjects', index: 1),
      _MobileNavItem(icon: FeatherIcons.folder, label: 'Projects', index: 2),
      _MobileNavItem(
          icon: FeatherIcons.messageSquare, label: 'Messages', index: 4),
      _MobileNavItem(icon: FeatherIcons.menu, label: 'More', index: -1),
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
      body: NotificationToastOverlay(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Desktop sidebar
            if (!isMobile)
              const RepaintBoundary(
                child: SizedBox(
                  width: 240,
                  child: SidebarWidget(),
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  const RepaintBoundary(child: TopBarWidget()),
                  Expanded(
                    child: _LazyIndexedStack(
                      index: selectedIndex,
                      children: [
                        // 0 – Dashboard
                        isFaculty
                            ? const TeacherOverviewWidget()
                            : const TodayOverviewWidget(),
                        // 1 – Subjects (with built-in Assignments tab per subject)
                        const SubjectsViewWidget(),
                        // 2 – Projects
                        const ProjectsViewWidget(),
                        // 3 – Calendar
                        const CalendarViewWidget(),
                        // 4 – Messages
                        const MessagesViewWidget(),
                        // 5 – Notes
                        const NotesViewWidget(),
                        // 6 – Question Papers
                        const QuestionPapersViewWidget(),
                        // 7 – Settings
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
                    left: BorderSide(
                        color: AppColors.getBorderColor(context), width: 1),
                  ),
                ),
                child: const SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: AnnouncementsPanel(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
/// Lazy-loading IndexedStack: only builds a screen on its FIRST visit, then
/// keeps it alive. Hidden screens that have never been visited are rendered as
/// an empty [SizedBox], so they never fire API calls or build widgets.
class _LazyIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const _LazyIndexedStack({required this.index, required this.children});

  @override
  State<_LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<_LazyIndexedStack> {
  late final Set<int> _loaded;

  @override
  void initState() {
    super.initState();
    _loaded = {widget.index}; // only load the initial screen
  }

  @override
  void didUpdateWidget(_LazyIndexedStack old) {
    super.didUpdateWidget(old);
    if (!_loaded.contains(widget.index)) {
      setState(() => _loaded.add(widget.index)); // build on first visit
    }
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      children: List.generate(widget.children.length, (i) {
        // Screens not yet visited get a cheap placeholder
        if (!_loaded.contains(i)) return const SizedBox.shrink();
        return widget.children[i];
      }),
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
        color: isDark
            ? AppColors.secondaryBackground
            : AppColors.lightSecondaryBackground,
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
              final isSelected =
                  item.index != -1 && selectedIndex == item.index;
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
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
