import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';

class CreateProjectDialog extends StatefulWidget {
  const CreateProjectDialog({super.key});

  @override
  State<CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<CreateProjectDialog> {
  final _formKey        = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _memberController = TextEditingController();

  String   _priority = 'Medium';
  DateTime? _deadline;
  final List<String> _members = [];

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _memberController.dispose();
    super.dispose();
  }

  void _addMember() {
    final name = _memberController.text.trim();
    if (name.isEmpty) return;
    if (!_members.contains(name)) {
      setState(() => _members.add(name));
    }
    _memberController.clear();
  }

  void _removeMember(int index) => setState(() => _members.removeAt(index));

  Future<void> _pickDeadline() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 14)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: isDark
              ? ColorScheme.dark(primary: AppColors.accent, onPrimary: Colors.white,
                  surface: AppColors.surface, onSurface: Colors.white)
              : ColorScheme.light(primary: AppColors.accent, onPrimary: Colors.white,
                  onSurface: Colors.black87),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 720),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.getBorderColor(context)),
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ───────────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(FeatherIcons.folder, color: AppColors.accent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text('Create New Project',
                          style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold,
                              color: AppColors.getHeadingColor(context))),
                    ]),
                    IconButton(
                      icon: Icon(FeatherIcons.x, color: AppColors.getBodyColor(context)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Project Name ──────────────────────────────────────────────
                _label(context, 'Project Name'),
                const SizedBox(height: 8),
                _textField(context: context, controller: _nameController,
                    hint: 'Enter project title...', isDark: isDark,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null),
                const SizedBox(height: 16),

                // ── Description ───────────────────────────────────────────────
                _label(context, 'Description'),
                const SizedBox(height: 8),
                _textField(context: context, controller: _descController,
                    hint: 'What is this project about?', isDark: isDark, maxLines: 3),
                const SizedBox(height: 16),

                // ── Team Members ──────────────────────────────────────────────
                _label(context, 'Team Members'),
                const SizedBox(height: 4),
                Text('Type a name and press Enter or tap + to add',
                    style: GoogleFonts.outfit(fontSize: 11, color: AppColors.getBodyColor(context))),
                const SizedBox(height: 8),

                // Input row
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _memberController,
                      style: GoogleFonts.outfit(color: AppColors.getHeadingColor(context), fontSize: 14),
                      onSubmitted: (_) => _addMember(),
                      inputFormatters: [LengthLimitingTextInputFormatter(50)],
                      decoration: InputDecoration(
                        hintText: 'e.g. Rahul Sharma',
                        hintStyle: GoogleFonts.outfit(color: AppColors.getBodyColor(context), fontSize: 13),
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.getBorderColor(context))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.accent, width: 2)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _addMember,
                    child: Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(FeatherIcons.plus, size: 18, color: Colors.white),
                    ),
                  ),
                ]),

                // Member chips
                if (_members.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _members.asMap().entries.map((e) => _MemberChip(
                      name: e.value,
                      onRemove: () => _removeMember(e.key),
                    )).toList(),
                  ),
                ],
                const SizedBox(height: 16),

                // ── Deadline ──────────────────────────────────────────────────
                _label(context, 'Deadline'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickDeadline,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _deadline != null ? AppColors.accent : AppColors.getBorderColor(context),
                        width: _deadline != null ? 1.5 : 1,
                      ),
                    ),
                    child: Row(children: [
                      Icon(FeatherIcons.calendar, size: 16,
                          color: _deadline != null ? AppColors.accent : AppColors.getBodyColor(context)),
                      const SizedBox(width: 10),
                      Text(
                        _deadline == null ? 'Pick a date' : DateFormat('MMM d, yyyy').format(_deadline!),
                        style: GoogleFonts.outfit(fontSize: 14,
                            color: _deadline == null ? AppColors.getBodyColor(context) : AppColors.getHeadingColor(context),
                            fontWeight: _deadline != null ? FontWeight.w600 : FontWeight.normal),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Priority ──────────────────────────────────────────────────
                _label(context, 'Priority'),
                const SizedBox(height: 8),
                Row(
                  children: ['Low', 'Medium', 'High'].map((p) => Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: ChoiceChip(
                      label: Text(p, style: GoogleFonts.outfit(
                          color: _priority == p ? AppColors.accent : AppColors.getBodyColor(context),
                          fontWeight: _priority == p ? FontWeight.bold : FontWeight.normal)),
                      selected: _priority == p,
                      onSelected: (s) { if (s) setState(() => _priority = p); },
                      selectedColor: AppColors.accent.withValues(alpha: 0.2),
                      backgroundColor: AppColors.getBorderColor(context).withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      side: BorderSide(color: _priority == p ? AppColors.accent : AppColors.getBorderColor(context)),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 32),

                // ── Actions ───────────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel', style: GoogleFonts.outfit(
                          color: AppColors.getBodyColor(context), fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      icon: const Icon(FeatherIcons.folder, size: 16, color: Colors.white),
                      label: Text('Create Project', style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold, color: Colors.white)),
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          Navigator.pop(context, {
                            'name':         _nameController.text.trim(),
                            'description':  _descController.text.trim(),
                            'priority':     _priority,
                            'deadline':     _deadline?.toIso8601String(),
                            'member_names': List<String>.from(_members),
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Text(text,
      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold,
          color: AppColors.getHeadingColor(context)));

  Widget _textField({required BuildContext context, required TextEditingController controller,
      required String hint, required bool isDark, int maxLines = 1,
      String? Function(String?)? validator}) =>
      TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: validator,
        style: GoogleFonts.outfit(color: AppColors.getHeadingColor(context), fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.outfit(color: AppColors.getBodyColor(context), fontSize: 14),
          filled: true,
          fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.getBorderColor(context))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.accent, width: 2)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red)),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2)),
          contentPadding: const EdgeInsets.all(16),
        ),
      );
}

// ── Member Chip ───────────────────────────────────────────────────────────────

class _MemberChip extends StatelessWidget {
  final String name;
  final VoidCallback onRemove;

  const _MemberChip({required this.name, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: AppColors.accent.withValues(alpha: 0.25),
            child: Text(initial,
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.accent)),
          ),
          const SizedBox(width: 6),
          Text(name, style: GoogleFonts.outfit(
              fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accent)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, size: 14, color: AppColors.accent),
          ),
        ],
      ),
    );
  }
}
