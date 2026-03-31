import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/project_model.dart';
import 'package:intl/intl.dart';

class ProjectDetailScreen extends StatelessWidget {
  final ProjectModel project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(FeatherIcons.arrowLeft, color: AppColors.getHeadingColor(context)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          project.title,
          style: TextStyle(color: AppColors.getHeadingColor(context), fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProgressSection(context),
            const SizedBox(height: 32),
            _buildTeamSection(context),
            const SizedBox(height: 32),
            _buildMilestonesSection(context),
            const SizedBox(height: 32),
            _buildFilesSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.getBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Overall Progress',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getHeadingColor(context)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: project.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(project.progress * 100).toInt()}%',
                  style: TextStyle(color: project.color, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: project.progress,
              minHeight: 10,
              backgroundColor: AppColors.getBorderColor(context),
              valueColor: AlwaysStoppedAnimation<Color>(project.color),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildStat(context, 'Deadline', DateFormat('MMM d, y').format(project.deadline), FeatherIcons.calendar),
              const SizedBox(width: 32),
              _buildStat(context, 'Status', 'In Progress', FeatherIcons.activity),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(BuildContext context, String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.getBodyColor(context).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: AppColors.getBodyColor(context)),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: AppColors.getBodyColor(context), fontSize: 12)),
            Text(value, style: TextStyle(color: AppColors.getHeadingColor(context), fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ],
    );
  }

  Widget _buildTeamSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Team Members',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.getHeadingColor(context)),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: project.teamMembers.map((member) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.getSurfaceColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.getBorderColor(context)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=$member'),
                ),
                const SizedBox(width: 10),
                Text(member, style: TextStyle(color: AppColors.getHeadingColor(context), fontWeight: FontWeight.w500)),
              ],
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildMilestonesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Milestones',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.getHeadingColor(context)),
        ),
        const SizedBox(height: 16),
        _buildMilestoneItem(context, 'Project Planning', true),
        _buildMilestoneItem(context, 'UI/UX Design', true),
        _buildMilestoneItem(context, 'Backend Integration', true),
        _buildMilestoneItem(context, 'Final Testing', false),
      ],
    );
  }

  Widget _buildMilestoneItem(BuildContext context, String title, bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isCompleted ? Colors.green : AppColors.getBodyColor(context),
            size: 20,
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: TextStyle(
              color: isCompleted ? AppColors.getHeadingColor(context) : AppColors.getBodyColor(context),
              fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
              decoration: isCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'File Uploads',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.getHeadingColor(context)),
            ),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Upload'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.getBorderColor(context), style: BorderStyle.none), // Custom dashed border would be nice
          ),
          child: Column(
            children: [
              Icon(FeatherIcons.uploadCloud, size: 40, color: AppColors.getBodyColor(context).withOpacity(0.5)),
              const SizedBox(height: 16),
              Text(
                'Drag and drop files here',
                style: TextStyle(color: AppColors.getBodyColor(context)),
              ),
              const SizedBox(height: 8),
              Text(
                'Support PDF, ZIP, PNG (Max 50MB)',
                style: TextStyle(color: AppColors.getBodyColor(context).withOpacity(0.5), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
