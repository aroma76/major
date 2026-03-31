import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';

class CreateProjectDialog extends StatefulWidget {
  const CreateProjectDialog({super.key});

  @override
  State<CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<CreateProjectDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _teamController = TextEditingController();
  final _deadlineController = TextEditingController();
  String _priority = 'Medium';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.getBorderColor(context), width: 1),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Create New Project',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getHeadingColor(context),
                    ),
                  ),
                  IconButton(
                    icon: Icon(FeatherIcons.x, color: AppColors.getBodyColor(context)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              _buildTextField(
                label: 'Project Name',
                controller: _nameController,
                hint: 'Enter project title...',
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                label: 'Description',
                controller: _descriptionController,
                hint: 'What is this project about?',
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      label: 'Team Members',
                      controller: _teamController,
                      hint: 'Separate with commas...',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      label: 'Deadline',
                      controller: _deadlineController,
                      hint: 'YYYY-MM-DD',
                      onTap: () {
                        // Date picker logic could go here
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              Text(
                'Priority',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getHeadingColor(context),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: ['Low', 'Medium', 'High'].map((p) => Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ChoiceChip(
                    label: Text(p),
                    selected: _priority == p,
                    onSelected: (bool selected) {
                      if (selected) setState(() => _priority = p);
                    },
                    selectedColor: AppColors.accent.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: _priority == p ? AppColors.accent : AppColors.getBodyColor(context),
                      fontWeight: _priority == p ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor: AppColors.getBorderColor(context).withOpacity(0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: BorderSide(color: _priority == p ? AppColors.accent : AppColors.getBorderColor(context)),
                  ),
                )).toList(),
              ),
              
              const SizedBox(height: 32),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: TextStyle(color: AppColors.getBodyColor(context))),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        // Logic to save project can be added here
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Create Project', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.getHeadingColor(context),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          onTap: onTap,
          readOnly: onTap != null,
          style: TextStyle(color: AppColors.getHeadingColor(context), fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.getBodyColor(context), fontSize: 14),
            filled: true,
            fillColor: AppColors.getSurfaceColor(context),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.getBorderColor(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.accent, width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }
}
