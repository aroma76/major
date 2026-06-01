import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/api_service.dart';

class CreateProjectDialog extends StatefulWidget {
  const CreateProjectDialog({super.key});

  @override
  State<CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<CreateProjectDialog> {
  final _formKey        = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _searchCtrl     = TextEditingController();

  String   _priority = 'Medium';
  DateTime? _deadline;

  // Selected members: list of {id, name, avatar_initials}
  final List<Map<String, dynamic>> _selectedMembers = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;
  Timer? _debounce;

  final _api = ApiService();

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _doSearch(query.trim()));
  }

  Future<void> _doSearch(String q) async {
    setState(() => _searching = true);
    try {
      final res = await _api.searchUsers(q);
      final users = (res.data['users'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      // Exclude already selected
      final selectedIds = _selectedMembers.map((m) => m['id']).toSet();
      if (mounted) {
        setState(() {
          _searchResults = users.where((u) => !selectedIds.contains(u['id'])).toList();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _searchResults = []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _addMember(Map<String, dynamic> user) {
    setState(() {
      _selectedMembers.add(user);
      _searchResults.remove(user);
      _searchCtrl.clear();
      _searchResults = [];
    });
  }

  void _removeMember(int index) => setState(() => _selectedMembers.removeAt(index));

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
              ? ColorScheme.dark(primary: AppColors.accent, onPrimary: Colors.white, surface: AppColors.surface, onSurface: Colors.white)
              : ColorScheme.light(primary: AppColors.accent, onPrimary: Colors.white, onSurface: Colors.black87),
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
                // ── Header ────────────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
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
                            style: GoogleFonts.outfit(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.getHeadingColor(context))),
                      ],
                    ),
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
                _textField(
                  context: context,
                  controller: _nameController,
                  hint: 'Enter project title...',
                  isDark: isDark,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),

                // ── Description ───────────────────────────────────────────────
                _label(context, 'Description'),
                const SizedBox(height: 8),
                _textField(
                  context: context,
                  controller: _descController,
                  hint: 'What is this project about?',
                  isDark: isDark,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                // ── Team Members ──────────────────────────────────────────────
                _label(context, 'Team Members'),
                const SizedBox(height: 8),

                // Search bar
                TextField(
                  controller: _searchCtrl,
                  style: GoogleFonts.outfit(color: AppColors.getHeadingColor(context), fontSize: 14),
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search by name or roll number...',
                    hintStyle: GoogleFonts.outfit(color: AppColors.getBodyColor(context), fontSize: 13),
                    prefixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)))
                        : const Icon(FeatherIcons.search, size: 16, color: AppColors.accent),
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.getBorderColor(context))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent, width: 2)),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),

                // Search results dropdown
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: AppColors.getSurfaceColor(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.getBorderColor(context)),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      children: _searchResults.map((user) {
                        final initials = (user['avatar_initials'] as String? ?? (user['name'] as String).substring(0, 1)).toUpperCase();
                        return InkWell(
                          onTap: () => _addMember(user),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppColors.accent.withValues(alpha: 0.18),
                                  child: Text(initials,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accent)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(user['name'] as String,
                                          style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppColors.getHeadingColor(context), fontSize: 13)),
                                      if (user['roll_number'] != null)
                                        Text(user['roll_number'].toString(),
                                            style: GoogleFonts.outfit(fontSize: 11, color: AppColors.getBodyColor(context))),
                                    ],
                                  ),
                                ),
                                const Icon(FeatherIcons.plus, size: 14, color: AppColors.accent),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                // Selected members chips
                if (_selectedMembers.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedMembers.asMap().entries.map((e) {
                      final i = e.key;
                      final m = e.value;
                      final initials = (m['avatar_initials'] as String? ?? (m['name'] as String).substring(0, 1)).toUpperCase();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 9,
                              backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                              child: Text(initials,
                                  style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.accent)),
                            ),
                            const SizedBox(width: 6),
                            Text(m['name'] as String,
                                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accent)),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => _removeMember(i),
                              child: const Icon(Icons.close, size: 13, color: AppColors.accent),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
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
                    child: Row(
                      children: [
                        Icon(FeatherIcons.calendar, size: 16,
                            color: _deadline != null ? AppColors.accent : AppColors.getBodyColor(context)),
                        const SizedBox(width: 10),
                        Text(
                          _deadline == null ? 'Pick a date' : DateFormat('MMM d, yyyy').format(_deadline!),
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: _deadline == null ? AppColors.getBodyColor(context) : AppColors.getHeadingColor(context),
                            fontWeight: _deadline != null ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
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
                      label: Text(p,
                          style: GoogleFonts.outfit(
                            color: _priority == p ? AppColors.accent : AppColors.getBodyColor(context),
                            fontWeight: _priority == p ? FontWeight.bold : FontWeight.normal,
                          )),
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
                      child: Text('Cancel',
                          style: GoogleFonts.outfit(color: AppColors.getBodyColor(context), fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      icon: const Icon(FeatherIcons.folder, size: 16, color: Colors.white),
                      label: Text('Create Project',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          Navigator.pop(context, {
                            'name':        _nameController.text.trim(),
                            'description': _descController.text.trim(),
                            'priority':    _priority,
                            'deadline':    _deadline?.toIso8601String(),
                            'member_ids':  _selectedMembers.map((m) => (m['id'] as num).toInt()).toList(),
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
      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.getHeadingColor(context)));

  Widget _textField({
    required BuildContext context,
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) =>
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
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.getBorderColor(context))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent, width: 2)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 2)),
          contentPadding: const EdgeInsets.all(16),
        ),
      );
}
