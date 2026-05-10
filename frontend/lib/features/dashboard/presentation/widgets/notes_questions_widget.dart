import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/task_provider.dart';

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

  void _submitNote() {
    final text = _noteCtrl.text.trim();
    if (text.isEmpty) return;
    ref.read(dashboardNotesProvider.notifier).add(text, DashboardNoteType.note);
    _noteCtrl.clear();
    setState(() => _addingNote = false);
  }

  void _submitQuestion() {
    final text = _questionCtrl.text.trim();
    if (text.isEmpty) return;
    ref
        .read(dashboardNotesProvider.notifier)
        .add(text, DashboardNoteType.question);
    _questionCtrl.clear();
    setState(() => _addingQuestion = false);
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(dashboardNotesProvider);
    final notesList =
        notes.where((n) => n.type == DashboardNoteType.note).toList();
    final questionsList =
        notes.where((n) => n.type == DashboardNoteType.question).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab bar
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
            labelStyle:
                GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 12),
            unselectedLabelStyle:
                GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 12),
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
                    if (notesList.isNotEmpty) ...[
                      const SizedBox(width: 5),
                      _CountBadge(notesList.length),
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
                    if (questionsList.isNotEmpty) ...[
                      const SizedBox(width: 5),
                      _CountBadge(questionsList.length,
                          color: const Color(0xFFD29922)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Tab views
        SizedBox(
          // dynamic height, capped
          height: _computeHeight(notesList.length, questionsList.length),
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              // ── Notes Tab ─────────────────────────────────────────────────
              _NoteTabContent(
                items: notesList,
                isAdding: _addingNote,
                controller: _noteCtrl,
                emptyIcon: FeatherIcons.edit3,
                emptyLabel: 'No notes yet',
                emptyHint: 'Jot down quick thoughts or reminders',
                inputHint: 'Write your note here...',
                accentColor: AppColors.accent,
                addLabel: 'Add Note',
                onToggleAdd: () => setState(() => _addingNote = !_addingNote),
                onSubmit: _submitNote,
                onDelete: (id) =>
                    ref.read(dashboardNotesProvider.notifier).remove(id),
                onToggleResolved: null,
              ),

              // ── Questions Tab ─────────────────────────────────────────────
              _NoteTabContent(
                items: questionsList,
                isAdding: _addingQuestion,
                controller: _questionCtrl,
                emptyIcon: FeatherIcons.helpCircle,
                emptyLabel: 'No questions noted',
                emptyHint: 'Note questions you want to ask your teacher',
                inputHint: 'Write your question here...',
                accentColor: const Color(0xFFD29922),
                addLabel: 'Add Question',
                onToggleAdd: () =>
                    setState(() => _addingQuestion = !_addingQuestion),
                onSubmit: _submitQuestion,
                onDelete: (id) =>
                    ref.read(dashboardNotesProvider.notifier).remove(id),
                onToggleResolved: (id) => ref
                    .read(dashboardNotesProvider.notifier)
                    .toggleResolved(id),
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _computeHeight(int noteCount, int questionCount) {
    final maxItems = noteCount > questionCount ? noteCount : questionCount;
    const baseHeight = 120.0; // empty state / input area
    const perItem = 76.0;
    final computed = baseHeight + (maxItems * perItem);
    return computed.clamp(140.0, 360.0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _NoteTabContent extends StatelessWidget {
  final List<DashboardNote> items;
  final bool isAdding;
  final TextEditingController controller;
  final IconData emptyIcon;
  final String emptyLabel;
  final String emptyHint;
  final String inputHint;
  final Color accentColor;
  final String addLabel;
  final VoidCallback onToggleAdd;
  final VoidCallback onSubmit;
  final void Function(String id) onDelete;
  final void Function(String id)? onToggleResolved;

  const _NoteTabContent({
    required this.items,
    required this.isAdding,
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
    required this.onToggleResolved,
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
                return _NoteCard(
                  note: item,
                  accentColor: accentColor,
                  onDelete: () => onDelete(item.id),
                  onToggleResolved: onToggleResolved == null
                      ? null
                      : () => onToggleResolved!(item.id),
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
  const _AddButton(
      {required this.label, required this.color, required this.onTap});

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
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 16, color: widget.color),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputArea extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final Color accentColor;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  const _InputArea({
    required this.controller,
    required this.hintText,
    required this.accentColor,
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
              borderSide: BorderSide(color: AppColors.getBorderColor(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.getBorderColor(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: accentColor, width: 1.5),
            ),
          ),
          onSubmitted: (_) => onSubmit(),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: onCancel,
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
              onPressed: onSubmit,
              child: Text('Save',
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

class _NoteCard extends StatefulWidget {
  final DashboardNote note;
  final Color accentColor;
  final VoidCallback onDelete;
  final VoidCallback? onToggleResolved;

  const _NoteCard({
    required this.note,
    required this.accentColor,
    required this.onDelete,
    required this.onToggleResolved,
  });

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final isResolved = note.isResolved;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isResolved
              ? widget.accentColor.withValues(alpha: 0.07)
              : AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isResolved
                ? widget.accentColor.withValues(alpha: 0.3)
                : AppColors.getBorderColor(context),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resolved checkbox for questions
            if (widget.onToggleResolved != null)
              GestureDetector(
                onTap: widget.onToggleResolved,
                child: Container(
                  margin: const EdgeInsets.only(top: 2, right: 10),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isResolved ? widget.accentColor : Colors.transparent,
                    border: Border.all(
                      color: isResolved
                          ? widget.accentColor
                          : AppColors.getBorderColor(context),
                      width: 1.5,
                    ),
                  ),
                  child: isResolved
                      ? const Icon(Icons.check, size: 11, color: Colors.white)
                      : null,
                ),
              )
            else
              Container(
                margin: const EdgeInsets.only(top: 4, right: 10),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.accentColor,
                ),
              ),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.content,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: isResolved
                          ? AppColors.getBodyColor(context)
                          : AppColors.getHeadingColor(context),
                      decoration:
                          isResolved ? TextDecoration.lineThrough : null,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d, h:mm a').format(note.createdAt),
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      color: AppColors.getBodyColor(context)
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),

            // Delete button (shown on hover)
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
                color: AppColors.getBodyColor(context).withValues(alpha: 0.5),
              )),
          const SizedBox(height: 4),
          Text(hint,
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: AppColors.getBodyColor(context).withValues(alpha: 0.35),
              ),
              textAlign: TextAlign.center),
        ],
      ),
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
      child: Text(
        '$count',
        style: GoogleFonts.outfit(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
