import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/api_providers.dart';
import '../../data/models/channel_model.dart';
import 'subject_hub_widget.dart';

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
    final isMobile = MediaQuery.of(context).size.width < 600;

    return channelsAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent)),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(FeatherIcons.alertCircle,
                size: 48, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text('Failed to load subjects',
                style: TextStyle(color: AppColors.getBodyColor(context))),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(channelsProvider),
              icon: const Icon(FeatherIcons.refreshCw, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
      data: (channels) => SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 14 : 24),
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
                          fontSize: isMobile ? 20 : 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getHeadingColor(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${channels.length} enrolled courses',
                        style: GoogleFonts.outfit(
                          fontSize: isMobile ? 12 : 14,
                          color: AppColors.getBodyColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isMobile)
                  ElevatedButton.icon(
                    onPressed: () => ref.invalidate(channelsProvider),
                    icon: const Icon(FeatherIcons.refreshCw, size: 14),
                    label: const Text('Refresh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.getBorderColor(context),
                      foregroundColor: AppColors.getHeadingColor(context),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
              ],
            ),
            SizedBox(height: isMobile ? 14 : 28),

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
                        child: Icon(FeatherIcons.book,
                            size: 52,
                            color: AppColors.accent.withValues(alpha: 0.4)),
                      ),
                      const SizedBox(height: 24),
                      Text('No subjects enrolled yet',
                          style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getHeadingColor(context))),
                      const SizedBox(height: 8),
                      Text('Contact your administrator to enrol in channels.',
                          style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: AppColors.getBodyColor(context))),
                    ],
                  ),
                ),
              )
            else
              // ── Grid ──────────────────────────────────────────────────────
              LayoutBuilder(
                builder: (ctx, constraints) {
                  // Always 2 cols on mobile, 2 on tablet, 3 on desktop
                  final cols = constraints.maxWidth > 900 ? 3 : 2;
                  // Compact cards on mobile
                  final ratio = isMobile ? 2.1 : 1.75;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: isMobile ? 10 : 20,
                      mainAxisSpacing: isMobile ? 10 : 20,
                      childAspectRatio: ratio,
                    ),
                    itemCount: channels.length,
                    itemBuilder: (context, index) {
                      final ch = channels[index];
                      final color = _palette[index % _palette.length];
                      return _SubjectCard(
                          channel: ch, color: color, isMobile: isMobile);
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
  final bool isMobile;

  const _SubjectCard(
      {required this.channel, required this.color, this.isMobile = false});

  @override
  ConsumerState<_SubjectCard> createState() => _SubjectCardState();
}

class _SubjectCardState extends ConsumerState<_SubjectCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ch = widget.channel;
    final color = widget.color;
    final m = widget.isMobile;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => SubjectHubSheet(
              channel: widget.channel,
              color: widget.color,
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(m ? 10 : 16),
          decoration: BoxDecoration(
            color: _hovered
                ? color.withValues(alpha: 0.07)
                : AppColors.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovered
                  ? color.withValues(alpha: 0.5)
                  : AppColors.getBorderColor(context),
              width: 1.5,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                        color: color.withValues(alpha: 0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 6))
                  ]
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
                    padding: EdgeInsets.all(m ? 6 : 8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(FeatherIcons.book,
                        color: color, size: m ? 14 : 18),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: m ? 6 : 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Sem ${ch.semesterNumber}',
                      style: GoogleFonts.outfit(
                          fontSize: m ? 9 : 10,
                          fontWeight: FontWeight.w600,
                          color: color),
                    ),
                  ),
                ],
              ),
              SizedBox(height: m ? 6 : 10),

              // ── Subject name ───────────────────────────────────────────
              Text(
                ch.subjectName.isNotEmpty ? ch.subjectName : ch.channelName,
                style: GoogleFonts.outfit(
                  fontSize: m ? 12 : 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getHeadingColor(context),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (!m) const SizedBox(height: 3),

              // ── Teacher name (hide on very small mobile) ───────────────
              if (ch.teacherName != null && !m)
                Row(
                  children: [
                    Icon(FeatherIcons.user,
                        size: 10, color: AppColors.getBodyColor(context)),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        ch.teacherName!,
                        style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: AppColors.getBodyColor(context)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

              const Spacer(),

              // ── View Hub row ──────────────────────────────────────────
              Row(
                children: [
                  Icon(FeatherIcons.grid, size: m ? 10 : 12, color: color),
                  const SizedBox(width: 4),
                  Text(
                    'View Hub',
                    style: GoogleFonts.outfit(
                        fontSize: m ? 10 : 11,
                        color: color,
                        fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Icon(FeatherIcons.arrowRight,
                      size: m ? 10 : 12, color: color),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
