import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/auth/auth_provider.dart';
import '../providers/task_provider.dart';
import '../providers/api_providers.dart';
import 'announcements_panel.dart';
import 'teacher_create_assignment_dialog.dart';
import 'teacher_post_announcement_dialog.dart';

// ── Teacher-specific stat model ───────────────────────────────────────────────
class _TeacherStat {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const _TeacherStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });
}

// ── Quick action model ────────────────────────────────────────────────────────
class _TeacherAction {
  final IconData icon;
  final String label;
  final Color color;
  final String description;

  const _TeacherAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.description,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Widget
// ─────────────────────────────────────────────────────────────────────────────

class TeacherOverviewWidget extends ConsumerStatefulWidget {
  const TeacherOverviewWidget({super.key});

  @override
  ConsumerState<TeacherOverviewWidget> createState() =>
      _TeacherOverviewWidgetState();
}

class _TeacherOverviewWidgetState extends ConsumerState<TeacherOverviewWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // Stats are now loaded from the API — no static list

  static const _actions = [
    _TeacherAction(
      icon: FeatherIcons.plusSquare,
      label: 'New Assignment',
      color: Color(0xFF58A6FF),
      description: 'Create & publish',
    ),
    _TeacherAction(
      icon: FeatherIcons.volume2,
      label: 'Announcement',
      color: Color(0xFF3FB950),
      description: 'Broadcast to class',
    ),
    _TeacherAction(
      icon: FeatherIcons.checkSquare,
      label: 'Grade Work',
      color: Color(0xFFD29922),
      description: 'Review submissions',
    ),
    _TeacherAction(
      icon: FeatherIcons.calendar,
      label: 'Schedule',
      color: Color(0xFFA475F9),
      description: 'View timetable',
    ),
  ];

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

  String _formatDate() {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final now = DateTime.now();
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
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
              _TeacherHeroBanner(greeting: _getGreeting(), date: _formatDate()),
              SizedBox(height: isMobile ? 20 : 28),

              // ── Stat Cards (real API) ─────────────────────────────────────
              _SectionHeader(
                  title: 'At a Glance', icon: FeatherIcons.barChart2),
              const SizedBox(height: 14),
              ref.watch(teacherStatsProvider).when(
                    loading: () => const SizedBox(
                      height: 120,
                      child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.accent)),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (stats) {
                      final students = stats['totalStudents'] as int? ?? 0;
                      final pending = stats['pendingReviews'] as int? ?? 0;
                      final projects = stats['activeProjects'] as int? ?? 0;
                      final subjects = stats['totalSubjects'] as int? ?? 0;
                      final liveStats = [
                        _TeacherStat(
                          label: 'Total Students',
                          value: '$students',
                          icon: FeatherIcons.users,
                          color: const Color(0xFF58A6FF),
                          subtitle: 'Across $subjects subjects',
                        ),
                        _TeacherStat(
                          label: 'Pending Reviews',
                          value: '$pending',
                          icon: FeatherIcons.fileText,
                          color: const Color(0xFFD29922),
                          subtitle: 'Submissions to grade',
                        ),
                        _TeacherStat(
                          label: 'Active Projects',
                          value: '$projects',
                          icon: FeatherIcons.folder,
                          color: const Color(0xFFA475F9),
                          subtitle: 'Your projects',
                        ),
                        _TeacherStat(
                          label: 'My Subjects',
                          value: '$subjects',
                          icon: FeatherIcons.bookOpen,
                          color: const Color(0xFF3FB950),
                          subtitle: 'Channels assigned',
                        ),
                      ];
                      return _StatGrid(stats: liveStats);
                    },
                  ),
              SizedBox(height: isMobile ? 20 : 28),

              // ── Quick Actions ────────────────────────────────────────────
              _SectionHeader(title: 'Quick Actions', icon: FeatherIcons.zap),
              const SizedBox(height: 14),
              _QuickActionsGrid(
                  actions: _actions, ref: ref, isMobile: isMobile),
              SizedBox(height: isMobile ? 20 : 28),

              // ── Managed Subjects (real API data) ─────────────────────────
              ref.watch(channelsProvider).when(
                    loading: () => const Center(
                        child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: AppColors.accent),
                    )),
                    error: (e, _) => const SizedBox.shrink(),
                    data: (channels) => channels.isEmpty
                        ? const SizedBox.shrink()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: _SectionHeader(
                                      title: 'Your Subjects',
                                      icon: FeatherIcons.bookOpen,
                                    ),
                                  ),
                                  _OutlineButton(
                                    label: 'View All',
                                    icon: FeatherIcons.chevronRight,
                                    onTap: () => ref
                                        .read(navigationProvider.notifier)
                                        .navigateTo(1),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              ...channels.asMap().entries.map((entry) {
                                final ch = entry.value;
                                final colors = [
                                  const Color(0xFF58A6FF),
                                  const Color(0xFFD29922),
                                  const Color(0xFF3FB950),
                                  const Color(0xFFA475F9),
                                  const Color(0xFFFF6B6B),
                                ];
                                final color = colors[entry.key % colors.length];
                                return _SubjectManagementCard(
                                  name: ch.subjectName.isNotEmpty
                                      ? ch.subjectName
                                      : ch.channelName,
                                  studentCount: 0,
                                  pendingSubmissions: 0,
                                  avgProgress: 0.5,
                                  color: color,
                                );
                              }),
                            ],
                          ),
                  ),
              SizedBox(height: isMobile ? 20 : 28),

              // ── Recent Announcements ─────────────────────────────────────
              _SectionHeader(
                  title: 'Recent Announcements', icon: FeatherIcons.bell),
              const SizedBox(height: 14),
              const AnnouncementsPanel(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero Banner (Teacher-themed)
// ─────────────────────────────────────────────────────────────────────────────

class _TeacherHeroBanner extends ConsumerWidget {
  final String greeting;
  final String date;

  const _TeacherHeroBanner({required this.greeting, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider).value;
    final firstName = (authState?.userName ?? 'Faculty').split(' ').first;
    final statsAsync = ref.watch(teacherStatsProvider);
    final statsData = statsAsync.asData?.value;
    final students = statsData?['totalStudents'] as int? ?? 0;
    final subjects = statsData?['totalSubjects'] as int? ?? 0;
    final pending = statsData?['pendingReviews'] as int? ?? 0;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 18 : 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6B21A8), Color(0xFFA855F7), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFA855F7).withValues(alpha: 0.35),
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
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 50,
            bottom: -35,
            child: Container(
              width: 90,
              height: 90,
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(FeatherIcons.award,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$greeting, $firstName!',
                          style: GoogleFonts.outfit(
                            fontSize: isMobile ? 18 : 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          date,
                          style: GoogleFonts.outfit(
                            fontSize: isMobile ? 11 : 13,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 14 : 20),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _BannerChip(
                      icon: FeatherIcons.users, label: '$students Students'),
                  _BannerChip(
                      icon: FeatherIcons.bookOpen, label: '$subjects Subjects'),
                  if (pending > 0)
                    _BannerChip(
                      icon: FeatherIcons.alertCircle,
                      label: '$pending Pending Reviews',
                      isUrgent: true,
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BannerChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isUrgent;

  const _BannerChip(
      {required this.icon, required this.label, this.isUrgent = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: isUrgent
            ? Colors.red.withValues(alpha: 0.25)
            : Colors.white.withValues(alpha: 0.15),
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
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat Grid
// ─────────────────────────────────────────────────────────────────────────────

class _StatGrid extends StatelessWidget {
  final List<_TeacherStat> stats;

  const _StatGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 650;
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 2 : 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: isMobile ? 1.6 : 1.6,
      ),
      itemCount: stats.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) => _StatCard(stat: stats[index]),
    );
  }
}

class _StatCard extends StatefulWidget {
  final _TeacherStat stat;
  const _StatCard({required this.stat});

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.stat;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _hovered
              ? s.color.withValues(alpha: 0.1)
              : AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _hovered
                ? s.color.withValues(alpha: 0.45)
                : AppColors.getBorderColor(context),
            width: 1.5,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: s.color.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: s.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(s.icon, color: s.color, size: 18),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.value,
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getHeadingColor(context),
                  ),
                ),
                Text(
                  s.label,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getBodyColor(context),
                  ),
                ),
                if (s.subtitle != null)
                  Text(
                    s.subtitle!,
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      color: s.color,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Actions Row
// ─────────────────────────────────────────────────────────────────────────────

class _QuickActionsGrid extends StatelessWidget {
  final List<_TeacherAction> actions;
  final WidgetRef ref;
  final bool isMobile;

  const _QuickActionsGrid(
      {required this.actions, required this.ref, this.isMobile = false});

  @override
  Widget build(BuildContext ctx) {
    if (isMobile) {
      // 2×2 grid on mobile
      return Column(
        children: [
          for (int row = 0; row < 2; row++) ...[
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _QuickActionCard(action: actions[row * 2], ref: ref),
                  ),
                ),
                Expanded(
                  child:
                      _QuickActionCard(action: actions[row * 2 + 1], ref: ref),
                ),
              ],
            ),
            if (row < 1) const SizedBox(height: 10),
          ],
        ],
      );
    }
    // Desktop: single row of 4
    return Row(
      children: actions.map((action) {
        final isLast = actions.indexOf(action) == actions.length - 1;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 12),
            child: _QuickActionCard(action: action, ref: ref),
          ),
        );
      }).toList(),
    );
  }
}

class _QuickActionCard extends StatefulWidget {
  final _TeacherAction action;
  final WidgetRef ref;

  const _QuickActionCard({required this.action, required this.ref});

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
  bool _hovered = false;

  void _handleTap(BuildContext context) {
    final a = widget.action;
    if (a.label == 'New Assignment') {
      showDialog(
        context: context,
        builder: (_) => const TeacherCreateAssignmentDialog(),
      );
    } else if (a.label == 'Announcement') {
      showDialog(
        context: context,
        builder: (_) => const TeacherPostAnnouncementDialog(),
      );
    } else if (a.label == 'Grade Work') {
      widget.ref.read(navigationProvider.notifier).navigateTo(2); // Projects
    } else if (a.label == 'Schedule') {
      widget.ref.read(navigationProvider.notifier).navigateTo(3); // Calendar
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.action;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => _handleTap(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
          decoration: BoxDecoration(
            color: _hovered
                ? a.color.withValues(alpha: 0.12)
                : AppColors.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovered
                  ? a.color.withValues(alpha: 0.5)
                  : AppColors.getBorderColor(context),
              width: 1.5,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: a.color.withValues(alpha: 0.18),
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
                  color: a.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(a.icon, color: a.color, size: 20),
              ),
              const SizedBox(height: 9),
              Text(
                a.label,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getHeadingColor(context),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                a.description,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  color: a.color,
                  fontWeight: FontWeight.w500,
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
// Managed Subject Card
// ─────────────────────────────────────────────────────────────────────────────

class _SubjectManagementCard extends StatefulWidget {
  final String name;
  final int studentCount;
  final int pendingSubmissions;
  final double avgProgress;
  final Color color;

  const _SubjectManagementCard({
    required this.name,
    required this.studentCount,
    required this.pendingSubmissions,
    required this.avgProgress,
    required this.color,
  });

  @override
  State<_SubjectManagementCard> createState() => _SubjectManagementCardState();
}

class _SubjectManagementCardState extends State<_SubjectManagementCard>
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
    _barAnim = Tween<double>(begin: 0, end: widget.avgProgress)
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: widget.color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(FeatherIcons.users,
                            size: 12, color: AppColors.getBodyColor(context)),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.studentCount} students enrolled',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppColors.getBodyColor(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                children: [
                  _SubjectBadge(
                    label: '${(widget.avgProgress * 100).toInt()}% avg',
                    color: widget.color,
                  ),
                  if (widget.pendingSubmissions > 0) ...[
                    const SizedBox(width: 8),
                    _SubjectBadge(
                      label: '${widget.pendingSubmissions} to grade',
                      color: const Color(0xFFD29922),
                      icon: FeatherIcons.alertCircle,
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AnimatedBuilder(
                  animation: _barAnim,
                  builder: (context, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _barAnim.value,
                      backgroundColor: AppColors.getBorderColor(context)
                          .withValues(alpha: 0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(widget.color),
                      minHeight: 6,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Class avg. progress',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: AppColors.getBodyColor(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubjectBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _SubjectBadge({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
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

class _OutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _OutlineButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.getBorderColor(context)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.getBodyColor(context),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(icon, size: 14, color: AppColors.getBodyColor(context)),
          ],
        ),
      ),
    );
  }
}
