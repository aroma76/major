# 📄 `widgets/notes_questions_widget.dart` — Complete Explanation

**File Path:** `frontend/lib/.../widgets/notes_questions_widget.dart`
**Lines:** 609
**Role:** Dashboard quick-notes widget — a tabbed local notepad (Notes + Questions) backed by in-memory Riverpod state, with animated add/edit UX, hover-reveal delete, and question resolve-toggle.

---

## 1. File Purpose

`NotesQuestionsWidget` is the "quick pad" section of the student dashboard — like a sticky note board. Students jot down quick notes or questions during lectures. This data is **local only** (not synced to backend) — it's backed by `dashboardNotesProvider` which is an in-memory `NotifierProvider`.

---

## 2. State Architecture

```dart
final notes = ref.watch(dashboardNotesProvider);
final notesList = notes.where((n) => n.type == DashboardNoteType.note).toList();
final questionsList = notes.where((n) => n.type == DashboardNoteType.question).toList();
```

`dashboardNotesProvider` — Returns a `List<DashboardNote>`. Notes are filtered by `DashboardNoteType.note` vs `.question` to populate the two tabs.

---

## 3. `TabController` Setup

```dart
late TabController _tabCtrl;

@override
void initState() {
  super.initState();
  _tabCtrl = TabController(length: 2, vsync: this);
}
```

**`SingleTickerProviderStateMixin`** — Required by `TabController` to drive its animation. Without the mixin, `vsync: this` would fail.

**`length: 2`** — Two tabs: Notes + Questions.

**`dispose()`:**
```dart
_tabCtrl.dispose();
_noteCtrl.dispose();
_questionCtrl.dispose();
```
All three controllers must be disposed to prevent memory leaks.

---

## 4. Dynamic Height Calculation

```dart
double _computeHeight(int noteCount, int questionCount) {
  final maxItems = noteCount > questionCount ? noteCount : questionCount;
  const baseHeight = 120.0;
  const perItem = 76.0;
  final computed = baseHeight + (maxItems * perItem);
  return computed.clamp(140.0, 360.0);
}
```

**Why dynamic height?** `TabBarView` needs a fixed height (can't be `Expanded` inside a `SingleChildScrollView`). Instead of fixed height, this calculates based on the tab with more items.

- `baseHeight` = space for the "Add" button and empty state
- `perItem` = estimated height per note card
- `.clamp(140.0, 360.0)` — Minimum 140px (empty state), maximum 360px (scrolls within)

**Limitation:** `max(noteCount, questionCount)` is used — the tab with fewer items will have empty space at the bottom.

---

## 5. `AnimatedCrossFade` — Add/Input Toggle

```dart
AnimatedCrossFade(
  duration: const Duration(milliseconds: 250),
  crossFadeState: isAdding ? CrossFadeState.showSecond : CrossFadeState.showFirst,
  firstChild: _AddButton(label: addLabel, ...),
  secondChild: _InputArea(controller: controller, ...),
),
```

`AnimatedCrossFade` smoothly fades between two children. When `isAdding` is false, shows `_AddButton`. When true, shows `_InputArea`. The transition takes 250ms.

---

## 6. Question "Resolve" Toggle

```dart
if (widget.onToggleResolved != null)
  GestureDetector(
    onTap: widget.onToggleResolved,
    child: Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isResolved ? widget.accentColor : Colors.transparent,
        border: Border.all(color: ...),
      ),
      child: isResolved ? const Icon(Icons.check, size: 11, color: Colors.white) : null,
    ),
  )
```

Only shown for Questions tab (`onToggleResolved != null`). Tapping toggles the question between resolved (filled circle + checkmark) and unresolved (empty circle).

Resolved questions show **strikethrough text**:
```dart
decoration: isResolved ? TextDecoration.lineThrough : null,
```

---

## 7. Hover-Reveal Delete Button

```dart
AnimatedOpacity(
  opacity: _hovered ? 1.0 : 0.0,
  duration: const Duration(milliseconds: 180),
  child: IconButton(
    icon: Icon(FeatherIcons.trash2, color: Colors.red),
    onPressed: widget.onDelete,
  ),
),
```

The trash icon is always in the widget tree (no conditional rebuild) but its opacity is animated from 0 (invisible) to 1 (visible) on hover. This avoids layout shifts while providing a clean "hover to reveal" UX.

---

## 8. Final Summary

`NotesQuestionsWidget` is a self-contained local notepad with a two-tab structure (Notes + Questions). Its dynamic height calculation handles variable content, and `AnimatedCrossFade` creates smooth add/input transitions. The question "resolve" toggle with strikethrough is a thoughtful UX detail for student-teacher interaction preparation.

---

# 📄 `widgets/notes_view_widget.dart` — Complete Explanation

**File Path:** `frontend/lib/.../widgets/notes_view_widget.dart`
**Lines:** 24

---

## File Purpose

`NotesViewWidget` is a thin wrapper that delegates entirely to `SubjectFilesView`:

```dart
class NotesViewWidget extends StatelessWidget {
  const NotesViewWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const SubjectFilesView(
      fileType: SavedFileType.note,
      title: 'Notes',
      subtitle: 'Files saved as notes from your subject channels',
      headerIcon: FeatherIcons.bookOpen,
      accentColor: Color(0xFF58A6FF),
      emptyTitle: 'No notes saved yet',
      emptyHint: 'Save files shared in chat as notes\nto find them here, grouped by subject.',
      emptyIcon: FeatherIcons.bookOpen,
    );
  }
}
```

- `SavedFileType.note` — Filters `savedFilesProvider` for files marked as notes
- The entire layout, grid, subject grouping, and file display logic lives in `SubjectFilesView`
- This widget only configures the type and display labels

**Why a separate widget at all?** The sidebar navigation maps index 5 to "Notes" — it needs a widget to render. This thin wrapper decouples the navigation mapping from the implementation.

---

# 📄 `widgets/question_papers_view_widget.dart` — Complete Explanation

**File Path:** `frontend/lib/.../widgets/question_papers_view_widget.dart`
**Lines:** 24

---

## File Purpose

Identical pattern to `NotesViewWidget` — a thin wrapper for `SubjectFilesView` with `SavedFileType.questionPaper`:

```dart
return const SubjectFilesView(
  fileType: SavedFileType.questionPaper,
  title: 'Question Papers',
  subtitle: 'Past question papers saved from your subject channels',
  headerIcon: FeatherIcons.fileMinus,
  accentColor: Color(0xFF238636),
  emptyTitle: 'No question papers saved yet',
  emptyHint: 'Save files shared in chat as question papers\nto find them here...',
  emptyIcon: FeatherIcons.fileMinus,
);
```

- `SavedFileType.questionPaper` — Different enum case than `note`
- `accentColor: Color(0xFF238636)` — GitHub green (vs blue for Notes)
- Different label text

The two wrappers (`NotesViewWidget` and `QuestionPapersViewWidget`) allow the same `SubjectFilesView` component to serve two different content categories without duplication, configured purely through parameters.
