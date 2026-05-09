import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/channel_model.dart';
import '../../data/models/assignment_model.dart';
import '../providers/api_providers.dart';
import '../providers/task_provider.dart';

// ── Subject Hub Sheet ──────────────────────────────────────────────────────────
// Opens as a modal bottom-sheet / side-panel showing everything for one subject.

class SubjectHubSheet extends ConsumerStatefulWidget {
  final ChannelModel channel;
  final Color color;

  const SubjectHubSheet({super.key, required this.channel, required this.color});

  @override
  ConsumerState<SubjectHubSheet> createState() => _SubjectHubSheetState();
}

class _SubjectHubSheetState extends ConsumerState<SubjectHubSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  static const _tabLabels = ['Overview', 'Assignments', 'Announcements', 'Chat'];
  static const _tabIcons = [
    FeatherIcons.grid,
    FeatherIcons.checkSquare,
    FeatherIcons.bell,
    FeatherIcons.messageSquare,
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _openChat() {
    Navigator.pop(context);
    ref.read(selectedChannelProvider.notifier).select(widget.channel);
    ref.read(navigationProvider.notifier).navigateTo(4); // Messages
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    final color = widget.color;
    final ch = widget.channel;

    return Container(
      height: MediaQuery.of(context).size.height * (isMobile ? 0.92 : 0.88),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ── Drag handle ──
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.getBorderColor(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(FeatherIcons.book, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ch.subjectName,
                          style: GoogleFonts.outfit(
                              fontSize: 18, fontWeight: FontWeight.bold,
                              color: AppColors.getHeadingColor(context)),
                          overflow: TextOverflow.ellipsis),
                      if (ch.teacherName != null)
                        Text(ch.teacherName!,
                            style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: AppColors.getBodyColor(context))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Sem ${ch.semesterNumber}',
                      style: GoogleFonts.outfit(
                          fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(FeatherIcons.x,
                      color: AppColors.getBodyColor(context), size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // ── Tab Bar ──
          Container(
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: AppColors.getBorderColor(context))),
            ),
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: color,
              unselectedLabelColor: AppColors.getBodyColor(context),
              indicatorColor: color,
              indicatorWeight: 2,
              labelStyle: GoogleFonts.outfit(
                  fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle:
                  GoogleFonts.outfit(fontSize: 13),
              tabs: List.generate(4, (i) => Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_tabIcons[i], size: 14),
                    const SizedBox(width: 6),
                    Text(_tabLabels[i]),
                  ],
                ),
              )),
            ),
          ),
          // ── Tab Views ──
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _OverviewTab(channel: ch, color: color, onOpenChat: _openChat),
                _AssignmentsTab(channelId: ch.id, color: color),
                _AnnouncementsTab(channelId: ch.id, color: color),
                _ChatShortcutTab(color: color, onOpenChat: _openChat, channel: ch),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Overview Tab ───────────────────────────────────────────────────────────────
class _OverviewTab extends ConsumerWidget {
  final ChannelModel channel;
  final Color color;
  final VoidCallback onOpenChat;

  const _OverviewTab(
      {required this.channel, required this.color, required this.onOpenChat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignAsync = ref.watch(channelAssignmentsProvider(channel.id));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Quick stats row ──
          assignAsync.when(
            loading: () => const SizedBox(
                height: 80, child: Center(child: CircularProgressIndicator())),
            error: (_, __) => const SizedBox.shrink(),
            data: (assignments) {
              final pending = assignments
                  .where((a) => !a.isSubmitted && !a.isOverdue)
                  .length;
              final overdue =
                  assignments.where((a) => a.isOverdue).length;
              final submitted =
                  assignments.where((a) => a.isSubmitted).length;

              return Row(
                children: [
                  _StatChip(
                      label: 'Pending',
                      value: '$pending',
                      color: const Color(0xFFD29922),
                      icon: FeatherIcons.clock),
                  const SizedBox(width: 10),
                  _StatChip(
                      label: 'Overdue',
                      value: '$overdue',
                      color: Colors.red,
                      icon: FeatherIcons.alertCircle),
                  const SizedBox(width: 10),
                  _StatChip(
                      label: 'Done',
                      value: '$submitted',
                      color: const Color(0xFF3FB950),
                      icon: FeatherIcons.checkCircle),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // ── Subject info card ──
          _SectionHeader('Subject Info', color),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.getBorderColor(context)),
            ),
            child: Column(
              children: [
                _InfoRow(FeatherIcons.hash, 'Channel',
                    channel.channelName, context),
                const SizedBox(height: 10),
                _InfoRow(FeatherIcons.bookOpen, 'Semester',
                    'Semester ${channel.semesterNumber}', context),
                if (channel.teacherName != null) ...[
                  const SizedBox(height: 10),
                  _InfoRow(FeatherIcons.user, 'Teacher',
                      channel.teacherName!, context),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Upcoming assignments ──
          assignAsync.maybeWhen(
            data: (assignments) {
              final upcoming = assignments
                  .where((a) => !a.isSubmitted)
                  .take(3)
                  .toList();
              if (upcoming.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader('Upcoming Assignments', color),
                  const SizedBox(height: 10),
                  ...upcoming
                      .map((a) => _MiniAssignmentCard(a: a, color: color)),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),

          // ── Open chat button ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onOpenChat,
              icon: const Icon(FeatherIcons.messageSquare, size: 16),
              label: Text('Open Channel Chat',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Assignments Tab ────────────────────────────────────────────────────────────
class _AssignmentsTab extends ConsumerWidget {
  final int channelId;
  final Color color;
  const _AssignmentsTab({required this.channelId, required this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(channelAssignmentsProvider(channelId));
    return async.when(
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
          child: Text('Failed to load assignments',
              style: GoogleFonts.outfit(
                  color: AppColors.getBodyColor(context)))),
      data: (assignments) {
        if (assignments.isEmpty) {
          return _EmptyTab(
              icon: FeatherIcons.checkSquare,
              label: 'No assignments yet',
              color: color);
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: assignments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) =>
              _AssignmentCard(a: assignments[i], color: color),
        );
      },
    );
  }
}

// ── Announcements Tab ──────────────────────────────────────────────────────────
class _AnnouncementsTab extends ConsumerWidget {
  final int channelId;
  final Color color;
  const _AnnouncementsTab(
      {required this.channelId, required this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(channelAnnouncementsProvider(channelId));
    return async.when(
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
          child: Text('Failed to load announcements',
              style: GoogleFonts.outfit(
                  color: AppColors.getBodyColor(context)))),
      data: (announcements) {
        if (announcements.isEmpty) {
          return _EmptyTab(
              icon: FeatherIcons.bell,
              label: 'No announcements',
              color: color);
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: announcements.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) =>
              _AnnouncementCard(data: announcements[i], color: color),
        );
      },
    );
  }
}

// ── Chat Shortcut Tab ──────────────────────────────────────────────────────────
class _ChatShortcutTab extends StatelessWidget {
  final Color color;
  final VoidCallback onOpenChat;
  final ChannelModel channel;
  const _ChatShortcutTab(
      {required this.color,
      required this.onOpenChat,
      required this.channel});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child:
                  Icon(FeatherIcons.messageSquare, size: 48, color: color),
            ),
            const SizedBox(height: 20),
            Text('${channel.subjectName} Chat',
                style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getHeadingColor(context)),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
                'Jump into the live channel to chat with classmates and your teacher.',
                style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppColors.getBodyColor(context)),
                textAlign: TextAlign.center),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onOpenChat,
                icon:
                    const Icon(FeatherIcons.messageSquare, size: 16),
                label: Text('Open Chat',
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small reusable widgets ─────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionHeader(this.title, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 16,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title,
            style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.getHeadingColor(context))),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _StatChip(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(value,
                style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 10, color: AppColors.getBodyColor(context))),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final BuildContext ctx;
  const _InfoRow(this.icon, this.label, this.value, this.ctx);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.getBodyColor(ctx)),
        const SizedBox(width: 8),
        Text('$label: ',
            style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppColors.getBodyColor(ctx))),
        Expanded(
          child: Text(value,
              style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getHeadingColor(ctx)),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _MiniAssignmentCard extends StatelessWidget {
  final AssignmentModel a;
  final Color color;
  const _MiniAssignmentCard({required this.a, required this.color});

  @override
  Widget build(BuildContext context) {
    final isOverdue = a.isOverdue;
    final statusColor = isOverdue ? Colors.red : color;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.getBorderColor(context)),
      ),
      child: Row(
        children: [
          Icon(
              isOverdue ? FeatherIcons.alertCircle : FeatherIcons.clock,
              color: statusColor,
              size: 14),
          const SizedBox(width: 10),
          Expanded(
            child: Text(a.title,
                style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getHeadingColor(context)),
                overflow: TextOverflow.ellipsis),
          ),
          Text(
              DateFormat('MMM d').format(a.dueDate.toLocal()),
              style: GoogleFonts.outfit(
                  fontSize: 11, color: statusColor)),
        ],
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final AssignmentModel a;
  final Color color;
  const _AssignmentCard({required this.a, required this.color});

  @override
  Widget build(BuildContext context) {
    final statusColor = a.isSubmitted
        ? const Color(0xFF3FB950)
        : a.isOverdue
            ? Colors.red
            : const Color(0xFFD29922);
    final statusLabel = a.isSubmitted
        ? 'Submitted'
        : a.isOverdue
            ? 'Overdue'
            : 'Pending';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.getBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(a.title,
                    style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getHeadingColor(context))),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(statusLabel,
                    style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor)),
              ),
            ],
          ),
          if (a.description != null && a.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(a.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.getBodyColor(context))),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(FeatherIcons.calendar,
                  size: 11, color: AppColors.getBodyColor(context)),
              const SizedBox(width: 4),
              Text('Due ${DateFormat('MMM d, y').format(a.dueDate.toLocal())}',
                  style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: AppColors.getBodyColor(context))),
              const Spacer(),
              if (a.marks != null)
                Text('${a.marks}/${a.maxMarks} marks',
                    style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF3FB950))),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color color;
  const _AnnouncementCard({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? '';
    final content = data['content'] as String? ?? '';
    final isImportant = data['is_important'] as bool? ?? false;
    final createdBy = data['created_by_name'] as String? ?? 'Teacher';
    final rawDate = data['created_at'] as String?;
    final date = rawDate != null
        ? DateFormat('MMM d, y').format(DateTime.parse(rawDate).toLocal())
        : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isImportant
              ? Colors.orange.withValues(alpha: 0.4)
              : AppColors.getBorderColor(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isImportant) ...[
                const Icon(FeatherIcons.alertCircle,
                    size: 13, color: Colors.orange),
                const SizedBox(width: 5),
              ],
              Expanded(
                child: Text(title,
                    style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getHeadingColor(context))),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(content,
              style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppColors.getBodyColor(context))),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(FeatherIcons.user,
                  size: 10, color: AppColors.getBodyColor(context)),
              const SizedBox(width: 4),
              Text(createdBy,
                  style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: AppColors.getBodyColor(context))),
              const Spacer(),
              Text(date,
                  style: GoogleFonts.outfit(
                      fontSize: 10,
                      color: AppColors.getBodyColor(context))),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _EmptyTab(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                shape: BoxShape.circle),
            child: Icon(icon, size: 40, color: color.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 16),
          Text(label,
              style: GoogleFonts.outfit(
                  fontSize: 15,
                  color: AppColors.getBodyColor(context))),
        ],
      ),
    );
  }
}
