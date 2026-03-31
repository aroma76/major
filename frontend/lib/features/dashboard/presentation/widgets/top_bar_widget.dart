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
    var size = renderBox.size;

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

    return Container(
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
          Container(
            width: 400,
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
                      hintText: 'Search assignments, subjects...',
                      hintStyle: TextStyle(color: AppColors.getBodyColor(context), fontSize: 14),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    style: TextStyle(color: AppColors.getHeadingColor(context), fontSize: 14),
                  ),
                ),
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
              const SizedBox(width: 16),
              
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
              const SizedBox(width: 16),
              
              InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => const CreateTaskDialog(),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                  child: const Row(
                    children: [
                      Icon(Icons.add, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
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
    );
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }
}
