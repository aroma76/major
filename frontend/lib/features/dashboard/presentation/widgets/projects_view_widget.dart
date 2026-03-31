import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/task_provider.dart';
import '../../data/models/project_model.dart';
import '../screens/project_detail_screen.dart';
import 'create_project_dialog.dart';

class ProjectsViewWidget extends ConsumerWidget {
  const ProjectsViewWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Collaboration Projects',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getHeadingColor(context),
                    ),
                  ),
                  Text(
                    'Track and manage your team projects',
                    style: TextStyle(color: AppColors.getBodyColor(context), fontSize: 16),
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              return _buildProjectCard(context, project);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(BuildContext context, ProjectModel project) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProjectDetailScreen(project: project),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.getBorderColor(context), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                     Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: project.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.folder_copy_outlined, color: project.color),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getHeadingColor(context),
                          ),
                        ),
                        Text(
                          'Team: ${project.teamMembers.join(", ")}',
                          style: TextStyle(fontSize: 12, color: AppColors.getBodyColor(context)),
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Deadline',
                      style: TextStyle(fontSize: 12, color: AppColors.getBodyColor(context)),
                    ),
                    Text(
                      DateFormat('MMM d, y').format(project.deadline),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getHeadingColor(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progress',
                  style: TextStyle(color: AppColors.getBodyColor(context), fontSize: 13),
                ),
                Text(
                  '${(project.progress * 100).toInt()}%',
                  style: TextStyle(color: AppColors.getHeadingColor(context), fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: project.progress,
                backgroundColor: AppColors.getBorderColor(context),
                valueColor: AlwaysStoppedAnimation<Color>(project.color),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    for (int i = 0; i < project.teamMembers.length; i++)
                      Align(
                        widthFactor: 0.6,
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.getSurfaceColor(context),
                          child: CircleAvatar(
                            radius: 12,
                            backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=${project.teamMembers[i]}'),
                          ),
                        ),
                      ),
                    const SizedBox(width: 16),
                    Text('+ 3 milestones', style: TextStyle(color: AppColors.getBodyColor(context), fontSize: 11)),
                  ],
                ),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ProjectDetailScreen(project: project),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.getBorderColor(context)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('View Details', style: TextStyle(color: AppColors.getHeadingColor(context))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
