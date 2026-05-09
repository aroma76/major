import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/auth/auth_provider.dart';
import '../providers/task_provider.dart';
import '../providers/api_providers.dart';
import '../../data/models/task_model.dart';
import 'subject_color_manager.dart';
import 'kanban_board_widget.dart';
import 'announcements_panel.dart';

class TodayOverviewWidget extends ConsumerStatefulWidget {
  const TodayOverviewWidget({super.key});

  @override
  ConsumerState<TodayOverviewWidget> createState() => _TodayOverviewWidgetState();
}

class _TodayOverviewWidgetState extends ConsumerState<TodayOverviewWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _getGreetingEmoji() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '☀️';
    if (hour < 17) return '🌤️';
    return '🌙';
  }

  String _formatDate() {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final now = DateTime.now();
    final weekday = days[now.weekday - 1];
    return '$weekday, ${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(taskProvider);
    final channelsAsync = ref.watch(channelsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 600;

    final pendingCount = tasks.where((t) => t.status != TaskStatus.done).length;
    final urgentCount = tasks.where((t) =>
        t.priority == TaskPriority.high && t.status != TaskStatus.done).length;

    // Today's deadlines: tasks due within 7 days
    final now = DateTime.now();
    final upcomingTasks = tasks
        .where((t) =>
            t.dueDate.isAfter(now) &&
            t.dueDate.isBefore(now.add(const Duration(days: 7))) &&
            t.status != TaskStatus.done)
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Hero Banner ─────────────────────────────────────────────
              _HeroBanner(
                greeting: _getGreeting(),
                emoji: _getGreetingEmoji(),
                date: _formatDate(),
                pendingCount: pendingCount,
                urgentCount: urgentCount,
                isDark: isDark,
                isMobile: isMobile,
              ),
              const SizedBox(height: 24),

              // ── Quick Action Buttons ─────────────────────────────────────
              _QuickActions(ref: ref, isMobile: isMobile),
              const SizedBox(height: 24),

              // ── Upcoming Deadlines ───────────────────────────────────────
              if (upcomingTasks.isNotEmpty) ...[
                _SectionHeader(title: 'Upcoming Deadlines', icon: FeatherIcons.clock),
                const SizedBox(height: 14),
                SizedBox(
                  height: 106,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: upcomingTasks.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) =>
                        _DeadlineCard(task: upcomingTasks[index]),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ── Subject Progress (real channels) ───────────────────────────
              channelsAsync.whenOrNull(
                data: (channels) => channels.isEmpty
                    ? const SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionHeader(title: 'Enrolled Subjects', icon: FeatherIcons.bookOpen),
                          const SizedBox(height: 14),
                          ...channels.map((ch) => _SubjectProgressRow(
                                name: ch.subjectName.isNotEmpty ? ch.subjectName : ch.channelName,
                                progress: 0.0,
                                teacher: ch.teacherName ?? 'Faculty',
                                pendingTasks: 0,
                              )),
                          const SizedBox(height: 24),
                        ],
                      ),
              ) ?? const SizedBox.shrink(),

              // ── Task Board ───────────────────────────────────────────────
              _SectionHeader(title: 'Task Board', icon: FeatherIcons.trello),
              const SizedBox(height: 14),
              const KanbanBoardWidget(),
              const SizedBox(height: 32),

              // ── Recent Announcements ─────────────────────────────────────
              _SectionHeader(title: 'Recent Announcements & Chat', icon: FeatherIcons.bell),
              const SizedBox(height: 14),
              const AnnouncementsPanel(),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  final String greeting;
  final String emoji;
  final String date;
  final int pendingCount;
  final int urgentCount;
  final bool isDark;
  final bool isMobile;

  const _HeroBanner({
    required this.greeting,
    required this.emoji,
    required this.date,
    required this.pendingCount,
    required this.urgentCount,
    required this.isDark,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, _) {
      final authState = ref.watch(authProvider).value;
      final firstName = (authState?.userName ?? 'Student').split(' ').first;

      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(isMobile ? 18 : 28),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1F6FEB), Color(0xFF58A6FF), Color(0xFF3FB950)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF58A6FF).withValues(alpha: 0.35),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: 40,
              bottom: -30,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Content
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 10),
                    Text(
                      '$greeting, $firstName!',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  date,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _StatChip(
                      icon: FeatherIcons.clock,
                      label: '$pendingCount Pending Tasks',
                    ),
                    if (urgentCount > 0)
                      _StatChip(
                        icon: FeatherIcons.alertCircle,
                        label: '$urgentCount Urgent',
                        isUrgent: true,
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isUrgent;

  const _StatChip({required this.icon, required this.label, this.isUrgent = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: isUrgent
            ? Colors.red.withValues(alpha: 0.25)
            : Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(50),
        border: isUrgent
            ? Border.all(color: Colors.red.withValues(alpha: 0.5))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  final WidgetRef ref;
  final bool isMobile;
  const _QuickActions({required this.ref, this.isMobile = false});

  @override
  Widget build(BuildContext context) {
    // All 6 quick-access destinations
    final actions = [
      _QuickAction(icon: FeatherIcons.book,          label: 'Subjects',         color: const Color(0xFFD29922), navIndex: 1),
      _QuickAction(icon: FeatherIcons.messageSquare, label: 'Messages',          color: const Color(0xFF58A6FF), navIndex: 4),
      _QuickAction(icon: FeatherIcons.calendar,      label: 'Calendar',          color: const Color(0xFF238636), navIndex: 3),
      _QuickAction(icon: FeatherIcons.folder,        label: 'Projects',          color: const Color(0xFFA475F9), navIndex: 2),
      _QuickAction(icon: FeatherIcons.bookOpen,      label: 'Notes',             color: const Color(0xFF1F6FEB), navIndex: 5),
      _QuickAction(icon: FeatherIcons.fileMinus,     label: 'Question Papers',   color: const Color(0xFFE05252), navIndex: 6),
    ];

    // Helper: build a card tapping to the given index
    Widget card(_QuickAction action) => _QuickActionCard(
          action: action,
          onTap: () => ref.read(navigationProvider.notifier).navigateTo(action.navIndex),
        );

    if (isMobile) {
      // 3 rows × 2 columns on mobile
      return Column(
        children: [
          for (int row = 0; row < 3; row++) ...[
            Row(
              children: [
                Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: card(actions[row * 2]))),
                Expanded(child: card(actions[row * 2 + 1])),
              ],
            ),
            if (row < 2) const SizedBox(height: 10),
          ],
        ],
      );
    }

    // Desktop: 2 rows × 3 columns
    return Column(
      children: [
        Row(
          children: actions.sublist(0, 3).map((a) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: actions.indexOf(a) == 2 ? 0 : 12),
              child: card(a),
            ),
          )).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          children: actions.sublist(3, 6).map((a) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: actions.indexOf(a) == 5 ? 0 : 12),
              child: card(a),
            ),
          )).toList(),
        ),
      ],
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final int navIndex;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.navIndex});
}

class _QuickActionCard extends StatefulWidget {
  final _QuickAction action;
  final VoidCallback onTap;
  const _QuickActionCard({required this.action, required this.onTap});

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.action.color.withValues(alpha: 0.15)
                : AppColors.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovered
                  ? widget.action.color.withValues(alpha: 0.5)
                  : AppColors.getBorderColor(context),
              width: 1.5,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: widget.action.color.withValues(alpha: 0.2),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.action.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.action.icon, color: widget.action.color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                widget.action.label,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getHeadingColor(context),
                ),
                textAlign: TextAlign.center,
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

// ─────────────────────────────────────────────────────────────────────────────
class _DeadlineCard extends StatelessWidget {
  final TaskModel task;
  const _DeadlineCard({required this.task});

  int get _daysLeft {
    final diff = task.dueDate.difference(DateTime.now());
    return diff.inDays;
  }

  Color get _urgencyColor {
    if (_daysLeft <= 1) return const Color(0xFFFF4D4D);
    if (_daysLeft <= 3) return const Color(0xFFFFD93D);
    return const Color(0xFF3FB950);
  }

  @override
  Widget build(BuildContext context) {
    final subjectColor = SubjectColorManager.forSubject(task.subject);
    final days = _daysLeft;

    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: subjectColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  task.subject,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: subjectColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            task.title,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.getHeadingColor(context),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _urgencyColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              days == 0 ? 'Due today!' : 'In $days day${days == 1 ? '' : 's'}',
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: _urgencyColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _SubjectProgressRow extends StatefulWidget {
  final String name;
  final double progress;
  final String teacher;
  final int pendingTasks;

  const _SubjectProgressRow({
    required this.name,
    required this.progress,
    required this.teacher,
    required this.pendingTasks,
  });

  @override
  State<_SubjectProgressRow> createState() => _SubjectProgressRowState();
}

class _SubjectProgressRowState extends State<_SubjectProgressRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _barCtrl;
  late Animation<double> _barAnim;

  @override
  void initState() {
    super.initState();
    _barCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _barAnim = Tween<double>(begin: 0, end: widget.progress)
        .animate(CurvedAnimation(parent: _barCtrl, curve: Curves.easeOutCubic));
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _barCtrl.forward();
    });
  }

  @override
  void dispose() {
    _barCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = SubjectColorManager.forSubject(widget.name);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getHeadingColor(context),
                      ),
                    ),
                    Text(
                      widget.teacher,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: AppColors.getBodyColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${(widget.progress * 100).toInt()}%',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              if (widget.pendingTasks > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD29922).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${widget.pendingTasks} pending',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFD29922),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          AnimatedBuilder(
            animation: _barAnim,
            builder: (context, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _barAnim.value,
                  backgroundColor: AppColors.getBorderColor(context).withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 6,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.accent),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.getHeadingColor(context),
          ),
        ),
      ],
    );
  }
}

