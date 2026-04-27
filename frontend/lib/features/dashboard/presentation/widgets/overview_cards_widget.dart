import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/task_provider.dart';
import '../../data/models/task_model.dart';

class OverviewCardsWidget extends ConsumerWidget {
  const OverviewCardsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskProvider);
    
    // Calculate stats
    final totalFilesCount = tasks.fold(0, (sum, task) => sum + (task.attachments != null ? 1 : 0)) + 4; // Mock base
    final pendingTasksCount = tasks.where((t) => t.status != TaskStatus.done).length;
    final subjectsCount = tasks.map((t) => t.subject).toSet().length;
    final urgentTasksCount = tasks.where((t) => t.priority == TaskPriority.high && t.status != TaskStatus.done).length;
    return LayoutBuilder(
      builder: (context, constraints) {
        // responsive columns: repeat(auto-fit, minmax(250px, 1fr))
        double minWidth = 250;
        int crossAxisCount = (constraints.maxWidth / (minWidth + 24)).floor();
        if (crossAxisCount < 1) crossAxisCount = 1;
        if (crossAxisCount > 4) crossAxisCount = 4;
        
        final double itemWidth = crossAxisCount == 1 
            ? constraints.maxWidth 
            : (constraints.maxWidth - (24 * (crossAxisCount - 1))) / crossAxisCount;

        return Wrap(
          spacing: 24,
          runSpacing: 24,
          children: [
            _buildStatCard(
              context,
              title: 'Uploaded Material',
              value: totalFilesCount.toString().padLeft(2, '0'),
              icon: FeatherIcons.file,
              gradient: const LinearGradient(
                colors: [Color(0xFF58A6FF), Color(0xFF1F6FEB)],
              ),
              width: itemWidth,
            ),
            _buildStatCard(
              context,
              title: 'Pending Tasks',
              value: pendingTasksCount.toString().padLeft(2, '0'),
              icon: FeatherIcons.clock,
              gradient: const LinearGradient(
                colors: [Color(0xFFD29922), Color(0xFF9E6A03)],
              ),
              width: itemWidth,
            ),
            _buildStatCard(
              context,
              title: 'Subjects Count',
              value: subjectsCount.toString().padLeft(2, '0'),
              icon: FeatherIcons.bookOpen,
              gradient: const LinearGradient(
                colors: [Color(0xFF238636), Color(0xFF2EA043)],
              ),
              width: itemWidth,
            ),
            _buildStatCard(
              context,
              title: 'Urgent Tasks',
              value: urgentTasksCount.toString().padLeft(2, '0'),
              icon: FeatherIcons.alertCircle,
              gradient: const LinearGradient(
                colors: [Color(0xFFF85149), Color(0xFFDA3633)],
              ),
              width: itemWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Gradient gradient,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.getBorderColor(context), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.getBodyColor(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getHeadingColor(context),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                 BoxShadow(
                   color: (gradient as LinearGradient).colors.first.withValues(alpha: 0.3),
                   blurRadius: 10,
                   offset: const Offset(0, 4),
                 ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }
}
