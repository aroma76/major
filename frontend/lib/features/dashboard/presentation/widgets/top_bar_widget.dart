import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import '../../../../core/theme/app_colors.dart';
import 'create_task_dialog.dart';
import 'notification_panel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/task_provider.dart';

class TopBarWidget extends ConsumerStatefulWidget {
  const TopBarWidget({super.key});

  @override
  ConsumerState<TopBarWidget> createState() => _TopBarWidgetState();
}

class _TopBarWidgetState extends ConsumerState<TopBarWidget> {
  final LayerLink _notificationLink = LayerLink();
  OverlayEntry? _overlayEntry;

  void _toggleNotifications() {
    if (_overlayEntry == null) {
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
    } else {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    return OverlayEntry(
      builder: (context) => Positioned(
        width: 350,
        child: CompositedTransformFollower(
          link: _notificationLink,
          showWhenUnlinked: false,
          offset: const Offset(-310, 50),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            child: const NotificationPanel(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationProvider);
    final themeMode = ref.watch(themeModeProvider);
    final selectedIndex = ref.watch(navigationProvider);
    final isMobile = MediaQuery.of(context).size.width < 850;

    const sectionTitles = [
      'Dashboard', 'Subjects', 'Assignments',
      'Projects', 'Calendar', 'Messages', 'Settings',
    ];
    final currentTitle = selectedIndex < sectionTitles.length
        ? sectionTitles[selectedIndex]
        : 'Dashboard';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.getBackgroundColor(context),
        border: Border(
           bottom: BorderSide(color: AppColors.getBorderColor(context), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [

          Row(
            children: [
              if (isMobile)
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: InkWell(
                    onTap: () => Scaffold.of(context).openDrawer(),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.getSurfaceColor(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.getBorderColor(context), width: 1),
                      ),
                      child: Icon(FeatherIcons.menu, size: 20, color: AppColors.getHeadingColor(context)),
                    ),
                  ),
                ),
              Container(
                constraints: BoxConstraints(maxWidth: isMobile ? MediaQuery.of(context).size.width * 0.4 : 400),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.getSurfaceColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.getBorderColor(context), width: 1),
                ),
                child: Row(
                  children: [
                    Icon(FeatherIcons.search, size: 20, color: AppColors.getBodyColor(context)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        onChanged: (value) {
                          ref.read(searchQueryProvider.notifier).set(value);
                        },
                        decoration: InputDecoration(
                          hintText: isMobile ? 'Search...' : 'Search assignments, subjects...',
                          hintStyle: TextStyle(color: AppColors.getBodyColor(context), fontSize: 14),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        style: TextStyle(color: AppColors.getHeadingColor(context), fontSize: 14),
                      ),
                    ),
                    if (!isMobile)
                      Text(
                        '⌘K',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getBodyColor(context),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          
          // Action Icons and Notifications
          Row(
            children: [
              // Notification Bell with badge
              CompositedTransformTarget(
                link: _notificationLink,
                child: InkWell(
                  onTap: _toggleNotifications,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                     padding: const EdgeInsets.all(10),
                     decoration: BoxDecoration(
                       color: AppColors.getSurfaceColor(context),
                       borderRadius: BorderRadius.circular(12),
                       border: Border.all(color: AppColors.getBorderColor(context), width: 1),
                     ),
                     child: Stack(
                       clipBehavior: Clip.none,
                       children: [
                         Icon(FeatherIcons.bell, size: 20, color: AppColors.getHeadingColor(context)),
                         if (notifications.isNotEmpty)
                           Positioned(
                             top: -2,
                             right: -2,
                             child: Container(
                               padding: const EdgeInsets.all(4),
                               decoration: const BoxDecoration(
                                 color: Colors.red,
                                 shape: BoxShape.circle,
                               ),
                               constraints: const BoxConstraints(
                                 minWidth: 12,
                                 minHeight: 12,
                               ),
                               child: Text(
                                 '${notifications.length}',
                                 style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                                 textAlign: TextAlign.center,
                               ),
                             ),
                           ),
                       ],
                     ),
                   ),
                ),
              ),
              const SizedBox(width: 8),
              
              // Dark/Light Mode toggle
               InkWell(
                 onTap: () {
                    ref.read(themeModeProvider.notifier).toggle();
                 },
                 borderRadius: BorderRadius.circular(12),
                 child: Container(
                   padding: const EdgeInsets.all(10),
                   decoration: BoxDecoration(
                     color: AppColors.getSurfaceColor(context),
                     borderRadius: BorderRadius.circular(12),
                     border: Border.all(color: AppColors.getBorderColor(context), width: 1),
                   ),
                   child: Icon(
                     themeMode == ThemeMode.dark 
                       ? FeatherIcons.moon 
                       : FeatherIcons.sun, 
                     size: 20, 
                     color: AppColors.getHeadingColor(context)
                   ),
                 ),
               ),
              const SizedBox(width: 8),

              if (isMobile)
                InkWell(
                  onTap: () => Scaffold.of(context).openEndDrawer(),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.getSurfaceColor(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.getBorderColor(context), width: 1),
                    ),
                    child: Icon(FeatherIcons.sidebar, size: 20, color: AppColors.getHeadingColor(context)),
                  ),
                ),
              if (isMobile) const SizedBox(width: 8),
              
              InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => const CreateTaskDialog(),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add, color: Colors.white, size: 18),
                      if (!isMobile) const SizedBox(width: 8),
                      if (!isMobile)
                        const Text(
                          'Create New',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    // ── Breadcrumb bar ───────────────────────────────────────────────────
    Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        border: Border(
          bottom: BorderSide(color: AppColors.getBorderColor(context), width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.home_outlined, size: 13, color: AppColors.getBodyColor(context)),
          const SizedBox(width: 5),
          Text(
            'ADTU Collab',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.getBodyColor(context),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.chevron_right, size: 14, color: AppColors.getBodyColor(context)),
          ),
          Text(
            currentTitle,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    ),
      ],
    );
  }


  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }
}
