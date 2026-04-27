import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../providers/api_providers.dart';
import '../../data/models/channel_model.dart';

class TeacherPostAnnouncementDialog extends ConsumerStatefulWidget {
  const TeacherPostAnnouncementDialog({super.key});

  @override
  ConsumerState<TeacherPostAnnouncementDialog> createState() =>
      _TeacherPostAnnouncementDialogState();
}

class _TeacherPostAnnouncementDialogState
    extends ConsumerState<TeacherPostAnnouncementDialog> {
  final _formKey     = GlobalKey<FormState>();
  final _titleCtrl   = TextEditingController();
  final _contentCtrl = TextEditingController();

  ChannelModel? _selectedChannel;
  bool          _isImportant = false;
  bool          _loading     = false;
  String?       _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedChannel == null) {
      setState(() => _error = 'Please select a subject');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final api = ApiService();
      await api.dio.post(
        '/channels/${_selectedChannel!.id}/announcements',
        data: {
          'title'       : _titleCtrl.text.trim(),
          'content'     : _contentCtrl.text.trim(),
          'is_important': _isImportant,
        },
      );
      ref.invalidate(channelAnnouncementsProvider(_selectedChannel!.id));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _error = 'Failed to post announcement. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(channelsProvider);
    const purple = Color(0xFFA855F7);

    return Dialog(
      backgroundColor: AppColors.getSurfaceColor(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: purple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(FeatherIcons.volume2,
                          color: purple, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Post Announcement',
                          style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getHeadingColor(context))),
                    ),
                    IconButton(
                      icon: const Icon(FeatherIcons.x, size: 18),
                      color: AppColors.getBodyColor(context),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Subject picker
                _fieldLabel(context, 'Subject *'),
                const SizedBox(height: 6),
                channelsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Could not load subjects',
                      style: TextStyle(color: AppColors.getBodyColor(context))),
                  data: (channels) => _dropdown<ChannelModel?>(
                    context: context,
                    value: _selectedChannel,
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Select a subject')),
                      ...channels.map((ch) =>
                          DropdownMenuItem(value: ch, child: Text(ch.subjectName.isNotEmpty ? ch.subjectName : ch.channelName))),
                    ],
                    onChanged: (v) => setState(() => _selectedChannel = v),
                  ),
                ),
                const SizedBox(height: 14),

                // Title
                _fieldLabel(context, 'Announcement Title *'),
                const SizedBox(height: 6),
                _field(
                  controller: _titleCtrl,
                  hint: 'e.g. Mid-Semester Exam Schedule',
                  context: context,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                ),
                const SizedBox(height: 14),

                // Content
                _fieldLabel(context, 'Content *'),
                const SizedBox(height: 6),
                _field(
                  controller: _contentCtrl,
                  hint: 'Write your announcement here...',
                  context: context,
                  maxLines: 4,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Content is required' : null,
                ),
                const SizedBox(height: 16),

                // Important toggle
                GestureDetector(
                  onTap: () => setState(() => _isImportant = !_isImportant),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: _isImportant
                          ? Colors.red.withValues(alpha: 0.08)
                          : AppColors.getBackgroundColor(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isImportant
                            ? Colors.red.withValues(alpha: 0.4)
                            : AppColors.getBorderColor(context),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isImportant
                              ? FeatherIcons.alertCircle
                              : FeatherIcons.circle,
                          size: 16,
                          color: _isImportant
                              ? Colors.red
                              : AppColors.getBodyColor(context),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Mark as Important',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _isImportant
                                  ? Colors.red
                                  : AppColors.getBodyColor(context),
                            ),
                          ),
                        ),
                        Text(
                          _isImportant ? 'ON' : 'OFF',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _isImportant
                                ? Colors.red
                                : AppColors.getBodyColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                    ),
                    child: Text(_error!,
                        style: const TextStyle(
                            color: Colors.red, fontSize: 13)),
                  ),
                  const SizedBox(height: 12),
                ],

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: AppColors.getBorderColor(context)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Cancel',
                            style: TextStyle(
                                color: AppColors.getBodyColor(context))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            : Text(
                                'Post Announcement',
                                style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold),
                              ),
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

  Widget _fieldLabel(BuildContext context, String text) => Text(text,
      style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.getBodyColor(context)));

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required BuildContext context,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) =>
      TextFormField(
        controller: controller,
        validator: validator,
        maxLines: maxLines,
        style: GoogleFonts.outfit(
            fontSize: 13, color: AppColors.getHeadingColor(context)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.outfit(
              fontSize: 13, color: AppColors.getBodyColor(context)),
          filled: true,
          fillColor: AppColors.getBackgroundColor(context),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.getBorderColor(context))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.getBorderColor(context))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: Color(0xFFA855F7), width: 1.5)),
        ),
      );

  Widget _dropdown<T>({
    required BuildContext context,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.getBackgroundColor(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.getBorderColor(context)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            items: items,
            onChanged: onChanged,
            dropdownColor: AppColors.getSurfaceColor(context),
            style: GoogleFonts.outfit(
                fontSize: 13, color: AppColors.getHeadingColor(context)),
            icon: Icon(Icons.keyboard_arrow_down,
                size: 16, color: AppColors.getBodyColor(context)),
            borderRadius: BorderRadius.circular(12),
            isExpanded: true,
          ),
        ),
      );
}
