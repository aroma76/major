import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/api_providers.dart';
import '../screens/project_detail_screen.dart';
import '../../data/models/project_model.dart';
import 'create_project_dialog.dart';

class ProjectsViewWidget extends ConsumerWidget {
  const ProjectsViewWidget({super.key});

  static const _palette = [
    Color(0xFF58A6FF),
    Color(0xFFD29922),
    Color(0xFF3FB950),
    Color(0xFFA475F9),
    Color(0xFFFF6B6B),
    Color(0xFF26C6DA),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Collaboration Projects',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getHeadingColor(context),
                    ),
                  ),
                  Text(
                    'Track and manage your team projects',
                    style: GoogleFonts.outfit(
                      color: AppColors.getBodyColor(context),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const CreateProjectDialog(),
                  );
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Project'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // ── Content ───────────────────────────────────────────────────────
          projectsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Column(
                  children: [
                    Icon(FeatherIcons.alertCircle, size: 48, color: Colors.red.shade400),
                    const SizedBox(height: 16),
                    Text('Failed to load projects',
                        style: GoogleFonts.outfit(color: AppColors.getBodyColor(context))),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => ref.invalidate(projectsProvider),
                      icon: const Icon(FeatherIcons.refreshCw, size: 16),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent, foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            data: (projects) {
              if (projects.isEmpty) {
                return Center(
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
                          child: Icon(FeatherIcons.folder, size: 52, color: AppColors.accent.withValues(alpha: 0.4)),
                        ),
                        const SizedBox(height: 24),
                        Text('No projects yet',
                            style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.getHeadingColor(context))),
                        const SizedBox(height: 8),
                        Text('Click "New Project" to create your first collaboration project.',
                            style: GoogleFonts.outfit(
                                fontSize: 14, color: AppColors.getBodyColor(context))),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: projects.length,
                itemBuilder: (context, index) {
                  final p = projects[index];
                  final color = _palette[index % _palette.length];
                  return _ProjectCard(data: p, color: color);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _ProjectCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final Color color;

  const _ProjectCard({required this.data, required this.color});

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.data;
    final color = widget.color;
    final title = p['title'] as String? ?? 'Untitled';
    final description = p['description'] as String? ?? '';
    final progress = ((p['progress'] as num?) ?? 0) / 100.0;
    final deadlineRaw = p['deadline'] as String?;
    final deadline = deadlineRaw != null ? DateTime.tryParse(deadlineRaw) : null;
    final members = (p['members'] as List<dynamic>?)
            ?.map((m) => (m['name'] ?? m['roll_number'] ?? '?').toString())
            .toList() ??
        [];
    final id = (p['id'] as num?)?.toInt() ?? 0;

    // Build a ProjectModel for the detail screen (uses local model shape)
    final projectModel = ProjectModel(
      id: id.toString(),
      title: title,
      teamMembers: members,
      progress: progress,
      deadline: deadline ?? DateTime.now().add(const Duration(days: 30)),
      description: description,
      color: color,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ProjectDetailScreen(project: projectModel)),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _hovered ? color.withValues(alpha: 0.05) : AppColors.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _hovered ? color.withValues(alpha: 0.45) : AppColors.getBorderColor(context),
              width: 1.5,
            ),
            boxShadow: _hovered
                ? [BoxShadow(color: color.withValues(alpha: 0.14), blurRadius: 20, offset: const Offset(0, 6))]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Row ─────────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.folder_copy_outlined, color: color, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.getHeadingColor(context))),
                        if (description.isNotEmpty)
                          Text(description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                  fontSize: 13, color: AppColors.getBodyColor(context))),
                      ],
                    ),
                  ),
                  if (deadline != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Deadline',
                            style: GoogleFonts.outfit(
                                fontSize: 11, color: AppColors.getBodyColor(context))),
                        Text(DateFormat('MMM d, y').format(deadline),
                            style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: deadline.isBefore(DateTime.now())
                                    ? Colors.red.shade400
                                    : AppColors.getHeadingColor(context))),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Progress Bar ─────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Progress',
                      style: GoogleFonts.outfit(
                          color: AppColors.getBodyColor(context), fontSize: 13)),
                  Text('${(progress * 100).toInt()}%',
                      style: GoogleFonts.outfit(
                          color: AppColors.getHeadingColor(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.getBorderColor(context).withValues(alpha: 0.4),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 7,
                ),
              ),
              const SizedBox(height: 20),

              // ── Bottom Row ───────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Member avatars
                  Row(
                    children: [
                      for (int i = 0; i < members.take(4).length; i++)
                        Align(
                          widthFactor: 0.65,
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.getSurfaceColor(context),
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: color.withValues(alpha: 0.15),
                              child: Text(
                                members[i].isNotEmpty ? members[i][0].toUpperCase() : '?',
                                style: GoogleFonts.outfit(
                                    fontSize: 11, fontWeight: FontWeight.bold, color: color),
                              ),
                            ),
                          ),
                        ),
                      if (members.length > 4)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text('+${members.length - 4} more',
                              style: GoogleFonts.outfit(
                                  fontSize: 11, color: AppColors.getBodyColor(context))),
                        ),
                      if (members.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: Text('${members.length} member${members.length != 1 ? 's' : ''}',
                              style: GoogleFonts.outfit(
                                  fontSize: 11, color: AppColors.getBodyColor(context))),
                        ),
                    ],
                  ),

                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ProjectDetailScreen(project: projectModel)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: color.withValues(alpha: 0.5)),
                      foregroundColor: color,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: Text('View Details', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
