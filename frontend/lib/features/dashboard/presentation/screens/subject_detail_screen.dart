import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/subject_model.dart';

class SubjectDetailScreen extends StatelessWidget {
  final SubjectModel subject;

  const SubjectDetailScreen({super.key, required this.subject});

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
          subject.name,
          style: TextStyle(color: AppColors.getHeadingColor(context), fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Teacher Info Card
            _buildInfoCard(
              context,
              title: 'Teacher Information',
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: subject.color.withOpacity(0.2),
                    child: Icon(FeatherIcons.user, color: subject.color),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject.teacher,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getHeadingColor(context),
                        ),
                      ),
                      Text(
                        'Course Instructor',
                        style: TextStyle(color: AppColors.getBodyColor(context)),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(FeatherIcons.messageCircle, color: AppColors.accent),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Stats Row
            Row(
              children: [
                Expanded(child: _buildStatCard(context, 'Attendance', '92%', FeatherIcons.userCheck, Colors.green)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard(context, 'Assignments', '${subject.pendingTasks} Pending', FeatherIcons.fileText, Colors.orange)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard(context, 'Grade', 'A-', FeatherIcons.trendingUp, Colors.blue)),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Tab-like section
            _buildSectionHeader(context, 'Announcements'),
            const SizedBox(height: 16),
            _buildAnnouncementItem(context, 'Midterm exam scheduled for next Friday.', '2 days ago'),
            _buildAnnouncementItem(context, 'Assignment 3 instructions updated.', '5 days ago'),
            
            const SizedBox(height: 32),
            
            _buildSectionHeader(context, 'Files & Resources'),
            const SizedBox(height: 16),
            _buildFileItem(context, 'Syllabus.pdf', '1.2 MB'),
            _buildFileItem(context, 'Lecture_Notes_Week4.pptx', '4.5 MB'),
            _buildFileItem(context, 'Sample_Projects.zip', '12.8 MB'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, {required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorderColor(context), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.getBodyColor(context),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorderColor(context), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.getHeadingColor(context),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.getBodyColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.getHeadingColor(context),
          ),
        ),
        TextButton(onPressed: () {}, child: const Text('View All')),
      ],
    );
  }

  Widget _buildAnnouncementItem(BuildContext context, String text, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.getBorderColor(context), width: 1),
      ),
      child: Row(
        children: [
          const Icon(FeatherIcons.info, size: 18, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: AppColors.getHeadingColor(context)),
            ),
          ),
          Text(
            time,
            style: TextStyle(fontSize: 12, color: AppColors.getBodyColor(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildFileItem(BuildContext context, String name, String size) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.getBorderColor(context), width: 1),
      ),
      child: Row(
        children: [
          const Icon(FeatherIcons.file, size: 20, color: AppColors.textBody),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getHeadingColor(context)),
                ),
                Text(
                  size,
                  style: TextStyle(fontSize: 12, color: AppColors.getBodyColor(context)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(FeatherIcons.download, size: 18),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
