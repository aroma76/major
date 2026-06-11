import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/api_providers.dart';
import '../../data/models/channel_model.dart';
import '../../data/repositories/notes_repository.dart';

final _notesRepo = NotesRepository();

class NotesQuestionsWidget extends ConsumerStatefulWidget {
  const NotesQuestionsWidget({super.key});

  @override
  ConsumerState<NotesQuestionsWidget> createState() =>
      _NotesQuestionsWidgetState();
}

class _NotesQuestionsWidgetState extends ConsumerState<NotesQuestionsWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _noteCtrl = TextEditingController();
  final _questionCtrl = TextEditingController();
  bool _addingNote = false;
  bool _addingQuestion = false;
  bool _savingNote = false;
  bool _savingQuestion = false;

  // Selected channel for creating notes/questions
  ChannelModel? _selectedChannel;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _noteCtrl.dispose();
    _questionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitNote(List<ChannelModel> channels) async {
    final text = _noteCtrl.text.trim();
    if (text.isEmpty) return;

    final channel = _selectedChannel ?? (channels.isNotEmpty ? channels.first : null);
    if (channel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a subject first')),
      );
      return;
    }

    setState(() => _savingNote = true);
    try {
      await _notesRepo.createNote(channel.id, text, '', 'note');
      _noteCtrl.clear();
      setState(() => _addingNote = false);
      // Invalidate to refresh both tabs
      ref.invalidate(allNotesProvider('note'));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save note: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      if (mounted) setState(() => _savingNote = false);
    }
  }

  Future<void> _submitQuestion(List<ChannelModel> channels) async {
    final text = _questionCtrl.text.trim();
    if (text.isEmpty) return;

    final channel = _selectedChannel ?? (channels.isNotEmpty ? channels.first : null);
    if (channel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a subject first')),
      );
      return;
    }

    setState(() => _savingQuestion = true);
    try {
      await _notesRepo.createNote(channel.id, text, '', 'question');
      _questionCtrl.clear();
      setState(() => _addingQuestion = false);
      ref.invalidate(allNotesProvider('question'));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save question: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      if (mounted) setState(() => _savingQuestion = false);
    }
  }

  Future<void> _deleteNote(int noteId, int channelId, String type) async {
    try {
      await _notesRepo.deleteNote(channelId, noteId);
      ref.invalidate(allNotesProvider(type));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(channelsProvider);
    final notesAsync = ref.watch(allNotesProvider('note'));
    final questionsAsync = ref.watch(allNotesProvider('question'));

    return channelsAsync.when(
      loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))),
      error: (_, __) => const SizedBox.shrink(),
      data: (channels) {
        // Auto-select first channel if none selected
        if (_selectedChannel == null && channels.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedChannel = channels.first);
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Tab Bar ───────────────────────────────────────────────────
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.getSurfaceColor(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.getBorderColor(context)),
              ),
              child: TabBar(
                controller: _tabCtrl,
                indicator: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 12),
                unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 12),
                labelColor: AppColors.accent,
                unselectedLabelColor: AppColors.getBodyColor(context),
                dividerColor: Colors.transparent,
                splashBorderRadius: BorderRadius.circular(10),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(FeatherIcons.edit3, size: 13),
                        const SizedBox(width: 5),
                        const Text('Notes'),
                        if (notesAsync.hasValue && (notesAsync.value?.isNotEmpty ?? false)) ...[
                          const SizedBox(width: 5),
                          _CountBadge(notesAsync.value!.length),
                        ],
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(FeatherIcons.helpCircle, size: 13),
                        const SizedBox(width: 5),
                        const Text('Questions'),
                        if (questionsAsync.hasValue && (questionsAsync.value?.isNotEmpty ?? false)) ...[
                          const SizedBox(width: 5),
                          _CountBadge(questionsAsync.value!.length, color: const Color(0xFFD29922)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Subject Selector ─────────────────────────────────────────
            if (channels.isNotEmpty)
              _SubjectPicker(
                channels: channels,
                selected: _selectedChannel,
                onChanged: (ch) => setState(() => _selectedChannel = ch),
              ),
            const SizedBox(height: 12),

            // ── Tab views ────────────────────────────────────────────────
            SizedBox(
              height: 300,
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  // ── Notes Tab ─────────────────────────────────────────
                  notesAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
                    error: (e, _) => _ErrorState(message: 'Failed to load notes'),
                    data: (notes) => _NoteTabContent(
                      items: notes,
                      isAdding: _addingNote,
                      isSaving: _savingNote,
                      controller: _noteCtrl,
                      emptyIcon: FeatherIcons.edit3,
                      emptyLabel: 'No notes yet',
                      emptyHint: 'Jot down quick thoughts or reminders',
                      inputHint: 'Write your note here...',
                      accentColor: AppColors.accent,
                      addLabel: 'Add Note',
                      onToggleAdd: () => setState(() => _addingNote = !_addingNote),
                      onSubmit: () => _submitNote(channels),
                      onDelete: (noteId, channelId) => _deleteNote(noteId, channelId, 'note'),
                    ),
                  ),

                  // ── Questions Tab ─────────────────────────────────────
                  questionsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFD29922), strokeWidth: 2)),
                    error: (e, _) => _ErrorState(message: 'Failed to load questions'),
                    data: (questions) => _NoteTabContent(
                      items: questions,
                      isAdding: _addingQuestion,
                      isSaving: _savingQuestion,
                      controller: _questionCtrl,
                      emptyIcon: FeatherIcons.helpCircle,
                      emptyLabel: 'No questions noted',
                      emptyHint: 'Note questions you want to ask your teacher',
                      inputHint: 'Write your question here...',
                      accentColor: const Color(0xFFD29922),
                      addLabel: 'Add Question',
                      onToggleAdd: () => setState(() => _addingQuestion = !_addingQuestion),
                      onSubmit: () => _submitQuestion(channels),
                      onDelete: (noteId, channelId) => _deleteNote(noteId, channelId, 'question'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SubjectPicker extends StatelessWidget {
  final List<ChannelModel> channels;
  final ChannelModel? selected;
  final void Function(ChannelModel?) onChanged;

  const _SubjectPicker({
    required this.channels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.getBorderColor(context)),
      ),
      child: Row(
        children: [
          Icon(FeatherIcons.book, size: 14, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ChannelModel>(
                value: selected,
                isExpanded: true,
                dropdownColor: AppColors.getSurfaceColor(context),
                style: GoogleFonts.outfit(
                    fontSize: 12, color: AppColors.getHeadingColor(context)),
                icon: Icon(Icons.keyboard_arrow_down,
                    size: 16, color: AppColors.getBodyColor(context)),
                hint: Text('Select subject',
                    style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.getBodyColor(context))),
                items: channels
                    .map((ch) => DropdownMenuItem(
                          value: ch,
                          child: Text(
                            ch.subjectName.isNotEmpty
                                ? ch.subjectName
                                : ch.channelName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _NoteTabContent extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final bool isAdding;
  final bool isSaving;
  final TextEditingController controller;
  final IconData emptyIcon;
  final String emptyLabel;
  final String emptyHint;
  final String inputHint;
  final Color accentColor;
  final String addLabel;
  final VoidCallback onToggleAdd;
  final VoidCallback onSubmit;
  final void Function(int noteId, int channelId) onDelete;

  const _NoteTabContent({
    required this.items,
    required this.isAdding,
    required this.isSaving,
    required this.controller,
    required this.emptyIcon,
    required this.emptyLabel,
    required this.emptyHint,
    required this.inputHint,
    required this.accentColor,
    required this.addLabel,
    required this.onToggleAdd,
    required this.onSubmit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Input area
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          crossFadeState:
              isAdding ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: _AddButton(
            label: addLabel,
            color: accentColor,
            onTap: onToggleAdd,
          ),
          secondChild: _InputArea(
            controller: controller,
            hintText: inputHint,
            accentColor: accentColor,
            isSaving: isSaving,
            onSubmit: onSubmit,
            onCancel: onToggleAdd,
          ),
        ),
        const SizedBox(height: 12),

        // List
        if (items.isEmpty)
          _EmptyState(icon: emptyIcon, label: emptyLabel, hint: emptyHint)
        else
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                final noteId = item['id'] as int;
                final channelId = item['channel_id'] as int;
                final content = item['title'] as String? ?? '';
                final authorName = item['author_name'] as String? ?? '';
                final createdAtRaw = item['created_at'] as String? ?? '';
                final createdAt =
                    DateTime.tryParse(createdAtRaw) ?? DateTime.now();

                return _NoteCard(
                  content: content,
                  authorName: authorName,
                  createdAt: createdAt,
                  accentColor: accentColor,
                  onDelete: () => onDelete(noteId, channelId),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _AddButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AddButton({required this.label, required this.color, required this.onTap});

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.color.withValues(alpha: 0.1)
                : AppColors.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovered
                  ? widget.color.withValues(alpha: 0.5)
                  : AppColors.getBorderColor(context),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 16, color: widget.color),
              const SizedBox(width: 6),
              Text(widget.label,
                  style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: widget.color)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _InputArea extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final Color accentColor;
  final bool isSaving;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  const _InputArea({
    required this.controller,
    required this.hintText,
    required this.accentColor,
    required this.isSaving,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          style: GoogleFonts.outfit(
              color: AppColors.getHeadingColor(context), fontSize: 13),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.outfit(
                color: AppColors.getBodyColor(context).withValues(alpha: 0.5),
                fontSize: 12),
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.03),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: AppColors.getBorderColor(context))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: AppColors.getBorderColor(context))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: accentColor, width: 1.5)),
          ),
          onSubmitted: (_) => onSubmit(),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: isSaving ? null : onCancel,
              child: Text('Cancel',
                  style: GoogleFonts.outfit(
                      color: AppColors.getBodyColor(context), fontSize: 12)),
            ),
            const SizedBox(width: 6),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: isSaving ? null : onSubmit,
              child: isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text('Save',
                      style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _NoteCard extends StatefulWidget {
  final String content;
  final String authorName;
  final DateTime createdAt;
  final Color accentColor;
  final VoidCallback onDelete;

  const _NoteCard({
    required this.content,
    required this.authorName,
    required this.createdAt,
    required this.accentColor,
    required this.onDelete,
  });

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hovered
                ? widget.accentColor.withValues(alpha: 0.4)
                : AppColors.getBorderColor(context),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 4, right: 10),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: widget.accentColor),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.content,
                      style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: AppColors.getHeadingColor(context),
                          height: 1.4)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        DateFormat('MMM d, h:mm a').format(widget.createdAt),
                        style: GoogleFonts.outfit(
                            fontSize: 10,
                            color: AppColors.getBodyColor(context)
                                .withValues(alpha: 0.6)),
                      ),
                      if (widget.authorName.isNotEmpty) ...[
                        Text(' · ',
                            style: GoogleFonts.outfit(
                                fontSize: 10,
                                color: AppColors.getBodyColor(context)
                                    .withValues(alpha: 0.4))),
                        Text(widget.authorName,
                            style: GoogleFonts.outfit(
                                fontSize: 10,
                                color: widget.accentColor
                                    .withValues(alpha: 0.8))),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            AnimatedOpacity(
              opacity: _hovered ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 180),
              child: IconButton(
                icon: Icon(FeatherIcons.trash2,
                    size: 14, color: Colors.red.withValues(alpha: 0.8)),
                onPressed: widget.onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;

  const _EmptyState(
      {required this.icon, required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 28,
              color: AppColors.getBodyColor(context).withValues(alpha: 0.3)),
          const SizedBox(height: 8),
          Text(label,
              style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color:
                      AppColors.getBodyColor(context).withValues(alpha: 0.5))),
          const SizedBox(height: 4),
          Text(hint,
              style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: AppColors.getBodyColor(context)
                      .withValues(alpha: 0.35)),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(message,
          style: GoogleFonts.outfit(
              fontSize: 12, color: Colors.red.withValues(alpha: 0.7))),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final Color color;
  const _CountBadge(this.count, {this.color = AppColors.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$count',
          style: GoogleFonts.outfit(
              fontSize: 9, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
