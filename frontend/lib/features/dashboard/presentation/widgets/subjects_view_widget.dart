import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/api_providers.dart';
import '../providers/task_provider.dart';
import '../../data/models/channel_model.dart';

class SubjectsViewWidget extends ConsumerWidget {
  const SubjectsViewWidget({super.key});

  static const _palette = [
    Color(0xFF58A6FF),
    Color(0xFFD29922),
    Color(0xFF3FB950),
    Color(0xFFA475F9),
    Color(0xFFFF6B6B),
    Color(0xFF26C6DA),
    Color(0xFFFF9800),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelsAsync = ref.watch(channelsProvider);

    return channelsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(FeatherIcons.alertCircle, size: 48, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text('Failed to load subjects', style: TextStyle(color: AppColors.getBodyColor(context))),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(channelsProvider),
              icon: const Icon(FeatherIcons.refreshCw, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
      data: (channels) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Subjects',
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getHeadingColor(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${channels.length} enrolled courses this semester',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: AppColors.getBodyColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(channelsProvider),
                  icon: const Icon(FeatherIcons.refreshCw, size: 14),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.getBorderColor(context),
                    foregroundColor: AppColors.getHeadingColor(context),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── Empty state ──────────────────────────────────────────────────
            if (channels.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.07),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(FeatherIcons.book, size: 52, color: AppColors.accent.withValues(alpha: 0.4)),
                      ),
                      const SizedBox(height: 24),
                      Text('No subjects enrolled yet', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getHeadingColor(context))),
                      const SizedBox(height: 8),
                      Text('Contact your administrator to enrol in channels.', style: GoogleFonts.outfit(fontSize: 14, color: AppColors.getBodyColor(context))),
                    ],
                  ),
                ),
              )
            else
              // ── Grid ──────────────────────────────────────────────────────
              LayoutBuilder(
                builder: (context, constraints) {
                  final cols = constraints.maxWidth > 900 ? 3 : constraints.maxWidth > 550 ? 2 : 1;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      childAspectRatio: 1.75,
                    ),
                    itemCount: channels.length,
                    itemBuilder: (context, index) {
                      final ch = channels[index];
                      final color = _palette[index % _palette.length];
                      return _SubjectCard(channel: ch, color: color);
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _SubjectCard extends ConsumerStatefulWidget {
  final ChannelModel channel;
  final Color color;

  const _SubjectCard({required this.channel, required this.color});

  @override
  ConsumerState<_SubjectCard> createState() => _SubjectCardState();
}

class _SubjectCardState extends ConsumerState<_SubjectCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ch = widget.channel;
    final color = widget.color;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          ref.read(selectedChannelProvider.notifier).select(ch);
          ref.read(navigationProvider.notifier).navigateTo(5);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _hovered ? color.withValues(alpha: 0.07) : AppColors.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _hovered ? color.withValues(alpha: 0.5) : AppColors.getBorderColor(context),
              width: 1.5,
            ),
            boxShadow: _hovered
                ? [BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 6))]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Icon + Semester badge ──────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(FeatherIcons.book, color: color, size: 18),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Sem ${ch.semesterNumber}',
                      style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: color),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Subject name ───────────────────────────────────────────
              Text(
                ch.subjectName.isNotEmpty ? ch.subjectName : ch.channelName,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getHeadingColor(context),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),

              // ── Teacher name ───────────────────────────────────────────
              if (ch.teacherName != null)
                Row(
                  children: [
                    Icon(FeatherIcons.user, size: 10, color: AppColors.getBodyColor(context)),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        ch.teacherName!,
                        style: GoogleFonts.outfit(fontSize: 11, color: AppColors.getBodyColor(context)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

              const Spacer(),

              // ── Open chat row ──────────────────────────────────────────
              Row(
                children: [
                  Icon(FeatherIcons.messageSquare, size: 12, color: color),
                  const SizedBox(width: 5),
                  Text(
                    'Open Chat',
                    style: GoogleFonts.outfit(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Icon(FeatherIcons.arrowRight, size: 12, color: color),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

