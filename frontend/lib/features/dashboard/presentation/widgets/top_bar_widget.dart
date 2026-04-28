import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/auth/auth_provider.dart';
import 'create_task_dialog.dart';
import 'notification_panel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/task_provider.dart';
import '../providers/api_providers.dart';

class TopBarWidget extends ConsumerStatefulWidget {
  const TopBarWidget({super.key});

  @override
  ConsumerState<TopBarWidget> createState() => _TopBarWidgetState();
}

class _TopBarWidgetState extends ConsumerState<TopBarWidget> {
  final LayerLink _notificationLink = LayerLink();
  OverlayEntry? _overlayEntry;

  void _dismissOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _toggleNotifications() {
    if (_overlayEntry == null) {
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
    } else {
      _dismissOverlay();
    }
  }

  OverlayEntry _createOverlayEntry() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 850;
    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _dismissOverlay,
              behavior: HitTestBehavior.translucent,
            ),
          ),
          Positioned(
            width: isMobile ? screenWidth - 32 : 350,
            child: CompositedTransformFollower(
              link: _notificationLink,
              showWhenUnlinked: false,
              offset: isMobile
                  ? Offset(-(screenWidth - 32 - 40), 50)
                  : const Offset(-310, 50),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                child: const NotificationPanel(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifAsync = ref.watch(notificationsApiProvider);
    final unreadCount = notifAsync.whenOrNull(
      data: (list) => list.where((n) => !(n['is_read'] as bool? ?? false)).length,
    ) ?? 0;
    final themeMode = ref.watch(themeModeProvider);
    final selectedIndex = ref.watch(navigationProvider);

    // Auto-dismiss notification overlay when user switches tabs
    ref.listen(navigationProvider, (_, __) => _dismissOverlay());

    final isMobile = MediaQuery.of(context).size.width < 850;
    final isFaculty = ref.watch(authProvider).value?.isFaculty ?? false;

    final studentTitles = [
      'Dashboard', 'Subjects', 'Assignments',
      'Projects', 'Calendar', 'Messages', 'Settings',
    ];
    final facultyTitles = [
      'Dashboard', 'Manage Subjects', 'Submissions & Grading',
      'Student Projects', 'Schedule', 'Messages', 'Settings',
    ];
    final sectionTitles = isFaculty ? facultyTitles : studentTitles;
    final currentTitle = selectedIndex < sectionTitles.length
        ? sectionTitles[selectedIndex]
        : 'Dashboard';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Main top bar ────────────────────────────────────────────────────
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 24,
            vertical: isMobile ? 10 : 16,
          ),
          decoration: BoxDecoration(
            color: AppColors.getBackgroundColor(context),
            border: Border(
              bottom: BorderSide(color: AppColors.getBorderColor(context), width: 1),
            ),
          ),
          child: Row(
            children: [
              // ── Left side ─────────────────────────────────────────────────
              if (isMobile) ...[
                // Hamburger — opens drawer
                _IconBtn(
                  icon: FeatherIcons.menu,
                  onTap: () => Scaffold.of(context).openDrawer(),
                ),
                const SizedBox(width: 8),
                // Current page title on mobile
                Expanded(
                  child: Text(
                    currentTitle,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getHeadingColor(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else ...[
                // Desktop: search bar
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.getSurfaceColor(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.getBorderColor(context), width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(FeatherIcons.search,
                            size: 18, color: AppColors.getBodyColor(context)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            onChanged: (v) =>
                                ref.read(searchQueryProvider.notifier).set(v),
                            decoration: InputDecoration(
                              hintText: 'Search assignments, subjects...',
                              hintStyle: TextStyle(
                                  color: AppColors.getBodyColor(context),
                                  fontSize: 13),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                            style: TextStyle(
                                color: AppColors.getHeadingColor(context),
                                fontSize: 13),
                          ),
                        ),
                        Text('⌘K',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.getBodyColor(context))),
                      ],
                    ),
                  ),
                ),
              ],

              // ── Right side ─────────────────────────────────────────────────
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Notification bell
                  CompositedTransformTarget(
                    link: _notificationLink,
                    child: _IconBtn(
                      onTap: _toggleNotifications,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(FeatherIcons.bell,
                              size: 20,
                              color: AppColors.getHeadingColor(context)),
                          if (unreadCount > 0)
                            Positioned(
                              top: -3,
                              right: -3,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: const BoxDecoration(
                                    color: Colors.red, shape: BoxShape.circle),
                                child: Text(
                                  '$unreadCount',
                                  style: const TextStyle(
                                      fontSize: 8,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Theme toggle
                  _IconBtn(
                    icon: themeMode == ThemeMode.dark
                        ? FeatherIcons.moon
                        : FeatherIcons.sun,
                    onTap: () =>
                        ref.read(themeModeProvider.notifier).toggle(),
                  ),
                  const SizedBox(width: 6),

                  // Mobile: search icon (opens search bottom sheet)
                  if (isMobile) ...[
                    _IconBtn(
                      icon: FeatherIcons.search,
                      onTap: () => _showMobileSearch(context),
                    ),
                    const SizedBox(width: 6),
                  ],

                  // Create task / post button
                  _CreateButton(isMobile: isMobile, isFaculty: isFaculty),
                ],
              ),
            ],
          ),
        ),

        // ── Breadcrumb (desktop only) ────────────────────────────────────────
        if (!isMobile)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.getSurfaceColor(context),
              border: Border(
                bottom:
                    BorderSide(color: AppColors.getBorderColor(context), width: 1),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.home_outlined,
                    size: 13, color: AppColors.getBodyColor(context)),
                const SizedBox(width: 5),
                Text(
                  'ADTU Collab',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.getBodyColor(context)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.chevron_right,
                      size: 14, color: AppColors.getBodyColor(context)),
                ),
                Text(
                  currentTitle,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _showMobileSearch(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MobileSearchSheet(ref: ref),
    );
  }

  @override
  void dispose() {
    _dismissOverlay();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Reusable icon button with consistent styling
class _IconBtn extends StatelessWidget {
  final IconData? icon;
  final Widget? child;
  final VoidCallback onTap;

  const _IconBtn({this.icon, this.child, required this.onTap})
      : assert(icon != null || child != null);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.getBorderColor(context), width: 1),
        ),
        child: icon != null
            ? Icon(icon, size: 19, color: AppColors.getHeadingColor(context))
            : child,
      ),
    );
  }
}

class _CreateButton extends ConsumerWidget {
  final bool isMobile;
  final bool isFaculty;

  const _CreateButton({required this.isMobile, required this.isFaculty});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => showDialog(
        context: context,
        builder: (_) => const CreateTaskDialog(),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10 : 16,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          gradient: AppColors.accentGradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, color: Colors.white, size: 18),
            if (!isMobile) ...[
              const SizedBox(width: 6),
              Text(
                isFaculty ? 'Post / Create' : 'New Task',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Mobile search bottom sheet
class _MobileSearchSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _MobileSearchSheet({required this.ref});

  @override
  ConsumerState<_MobileSearchSheet> createState() => _MobileSearchSheetState();
}

class _MobileSearchSheetState extends ConsumerState<_MobileSearchSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    // Clear search when sheet dismissed
    ref.read(searchQueryProvider.notifier).set('');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      decoration: BoxDecoration(
        color:
            isDark ? AppColors.secondaryBackground : AppColors.lightSecondaryBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.getBorderColor(context))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.getBorderColor(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          TextField(
            controller: _ctrl,
            autofocus: true,
            onChanged: (v) =>
                ref.read(searchQueryProvider.notifier).set(v),
            style: TextStyle(
                color: AppColors.getHeadingColor(context), fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Search assignments, subjects...',
              hintStyle: TextStyle(
                  color: AppColors.getBodyColor(context), fontSize: 14),
              prefixIcon: Icon(FeatherIcons.search,
                  size: 18, color: AppColors.getBodyColor(context)),
              filled: true,
              fillColor: AppColors.getSurfaceColor(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: AppColors.getBorderColor(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: AppColors.getBorderColor(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: AppColors.accent, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              _ctrl.clear();
              ref.read(searchQueryProvider.notifier).set('');
              Navigator.pop(context);
            },
            child: Text('Cancel',
                style:
                    TextStyle(color: AppColors.getBodyColor(context))),
          ),
        ],
      ),
    );
  }
}
