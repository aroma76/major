# Word-by-Word Deep Dive: `assignments_and_kanban_view_widgets_explained.md`

> Covers `assignments_view_widget.dart` and `kanban_board_widget.dart`. The assignments view is a dual-mode screen (List vs Kanban Board) with subject/priority filters. The Kanban board implements **drag-and-drop** between columns using Flutter's built-in `LongPressDraggable` + `DragTarget` system.

---

## PART 1: `assignments_view_widget.dart`

---

## Lines 15–30 — State Reading

```dart
final tasks = ref.watch(taskProvider);
final viewType = ref.watch(assignmentViewTypeProvider);
final selectedSubject = ref.watch(selectedSubjectFilterProvider);
final selectedPriority = ref.watch(selectedPriorityFilterProvider);

final filteredTasks = tasks.where((task) {
  final matchesSubject =
      selectedSubject == null || task.subject == selectedSubject;
  final matchesPriority =
      selectedPriority == null || task.priority == selectedPriority;
  return matchesSubject && matchesPriority;
}).toList();
```

### Four Providers Watched

**`taskProvider`** — the complete list of all tasks.

**`assignmentViewTypeProvider`** — enum `AssignmentViewType.list` or `AssignmentViewType.kanban`. Controls which view is shown.

**`selectedSubjectFilterProvider`** — `String?`. `null` = all subjects; a specific subject name = filter to that subject.

**`selectedPriorityFilterProvider`** — `TaskPriority?`. `null` = all priorities.

### Inline Filtering

```dart
final matchesSubject =
    selectedSubject == null || task.subject == selectedSubject;
```

**Short-circuit logic:** If `selectedSubject == null` (no filter active), the whole expression is `true` regardless of `task.subject`. Only when a filter IS active does it check `task.subject == selectedSubject`.

Same pattern for priority. Both conditions must be `true` (`&&`) for the task to appear.

---

## Lines 101–108 — `AnimatedSwitcher`

```dart
AnimatedSwitcher(
  duration: const Duration(milliseconds: 300),
  child: viewType == AssignmentViewType.kanban
      ? const KanbanBoardWidget()
      : _buildListView(context, filteredTasks),
),
```

**`AnimatedSwitcher`** — animates when its `child` changes. When `viewType` toggles between kanban and list, the outgoing widget fades out and the incoming widget fades in over 300ms.

**Why not just use `if/else`?** — A plain `if/else` would swap instantly. `AnimatedSwitcher` adds the transition animation for a polished feel.

**Important:** `AnimatedSwitcher` uses the child widget's `key` to detect changes. Since `KanbanBoardWidget` and `_buildListView` are different types, Flutter automatically detects the change.

---

## Lines 113–143 — View Toggler (List ↔ Board)

```dart
Container(
  padding: const EdgeInsets.all(4),
  decoration: BoxDecoration(
    color: AppColors.getSurfaceColor(context),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.getBorderColor(context)),
  ),
  child: Row(children: [
    _buildToggleItem(context, ref, AssignmentViewType.list, 'List', Icons.format_list_bulleted, currentView == AssignmentViewType.list),
    _buildToggleItem(context, ref, AssignmentViewType.kanban, 'Board', Icons.view_column_outlined, currentView == AssignmentViewType.kanban),
  ]),
),
```

**Segmented control** — the container looks like a pill. The selected item gets a filled background; the other is transparent. Toggling calls:

```dart
ref.read(assignmentViewTypeProvider.notifier).setViewType(type)
```

---

## Lines 182–243 — Filter Bar

```dart
final subjects = allTasks.map((t) => t.subject).toSet().toList();
```

**`.map((t) => t.subject)`** — extracts all subject strings.

**`.toSet()`** — removes duplicates. If there are 10 tasks all from "Mobile App Dev", the Set contains it only once.

**`.toList()`** — converts back to a `List` for the dropdown items.

### Generic Dropdown Builder

```dart
Widget _buildDropdownFilter<T>(
  BuildContext context, {
  required String hint,
  required T value,
  required List<DropdownMenuItem<T>> items,
  required ValueChanged<T> onChanged,
}) { ... }
```

**`<T>`** — generic type parameter. The SAME method works for both `String?` (subject filter) and `TaskPriority?` (priority filter). This avoids duplicating dropdown-building code.

**`ValueChanged<T>`** — a typedef in Flutter: `typedef ValueChanged<T> = void Function(T value)`. The callback receives the selected value.

**`DropdownButtonHideUnderline`** — removes the default underline that `DropdownButton` shows below itself (replaced by our custom `Container` border).

**`TaskPriority.values`** — all enum values as a `List<TaskPriority>`. For the priority dropdown items:
```dart
...TaskPriority.values.map((p) =>
    DropdownMenuItem(value: p, child: Text(p.name.toUpperCase()))),
```
**`p.name`** — Dart enum `.name` getter returns the enum constant name as a string: `TaskPriority.high.name == 'high'`. `.toUpperCase()` → `'HIGH'`.

---

## Lines 430–479 — Status Icon and Priority Tag

```dart
Widget _buildStatusIcon(TaskStatus status) {
  Color color;
  IconData icon;
  switch (status) {
    case TaskStatus.todo:
      color = AppColors.todoColor;
      icon = Icons.radio_button_unchecked;
      break;
    case TaskStatus.inProgress:
      color = AppColors.inProgressColor;
      icon = Icons.pending_actions;
      break;
    case TaskStatus.done:
      color = AppColors.doneColor;
      icon = Icons.check_circle_outline;
      break;
  }
  return Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
    child: Icon(icon, color: color, size: 20),
  );
}
```

**`switch` on enum** — exhaustive switch. Dart ensures ALL enum cases are covered. If you add `TaskStatus.cancelled` later without updating this switch, the Dart analyzer warns you.

**`BoxShape.circle`** — creates a circular background without needing `borderRadius`. Only works when the container is square (same width and height).

**`withValues(alpha: 0.1)`** — 10% opacity background matches the icon color. Very subtle tinted circle.

```dart
Widget _buildPriorityTag(TaskPriority priority) {
  ...
  return Container(
    child: Text(
      priority.name.toUpperCase(),
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
    ),
  );
}
```

**`priority.name`** — `'high'`, `'medium'`, or `'low'`. `.toUpperCase()` → `'HIGH'`, `'MEDIUM'`, `'LOW'`. Displayed as a small badge.

---

## PART 2: `kanban_board_widget.dart`

---

## Before Reading — Drag and Drop in Flutter

Flutter has two widgets for drag-and-drop:
- **`Draggable<T>`** — starts dragging on pointer-down (immediate)
- **`LongPressDraggable<T>`** — starts dragging after a long-press (holds for ~500ms)

Both work with **`DragTarget<T>`** — a widget that accepts drops of type `T`.

The flow:
1. User long-presses a card → `LongPressDraggable` activates
2. A "feedback" widget follows the finger
3. The original card becomes semi-transparent (`childWhenDragging`)
4. User releases over a `DragTarget` column → `onAcceptWithDetails` fires → status updated

---

## Lines 16–63 — Responsive Column Layout

```dart
return LayoutBuilder(
  builder: (context, constraints) {
    double minWidth = 280;
    int crossAxisCount = (constraints.maxWidth / (minWidth + 20)).floor();
    if (crossAxisCount < 1) crossAxisCount = 1;
    if (crossAxisCount > 3) crossAxisCount = 3;

    final double itemWidth = crossAxisCount == 1
        ? constraints.maxWidth
        : (constraints.maxWidth - (20 * (crossAxisCount - 1))) / crossAxisCount;

    return Wrap(spacing: 20, runSpacing: 32, children: [/* 3 columns */]);
  },
);
```

**`constraints.maxWidth`** — the available width given by the parent.

**`(constraints.maxWidth / (minWidth + 20)).floor()`** — divides by `300` (280px min column + 20px gap), floors to whole number.
- 600px screen → `600/300 = 2.0` → 2 columns
- 300px screen → `300/300 = 1.0` → 1 column (stack vertically)
- 1200px screen → `1200/300 = 4.0` → capped to 3 (three Kanban states)

**`clamp(1, 3)`** — guards: min 1, max 3 (exactly 3 Kanban columns).

**`itemWidth` calculation:**
- 1 column: full available width
- Multiple columns: `(totalWidth - gaps) / columns`
  - `20 * (crossAxisCount - 1)` — total gap space between columns
  - Divided equally among columns

**`Wrap`** — lays out children left-to-right, wrapping to the next row when they don't fit. `spacing: 20` = horizontal gap. `runSpacing: 32` = vertical gap between rows.

---

## Lines 123–148 — `DragTarget<TaskModel>`

```dart
DragTarget<TaskModel>(
  onAcceptWithDetails: (details) {
    final task = details.data;
    ref.read(taskProvider.notifier).updateTaskStatus(task.id, status);
  },
  builder: (context, candidateData, rejectedData) {
    return Container(
      decoration: BoxDecoration(
        color: candidateData.isNotEmpty
            ? AppColors.accent.withValues(alpha: 0.05)
            : Colors.transparent,
        ...
      ),
      child: ListView.builder(...),
    );
  },
),
```

**`DragTarget<TaskModel>`** — accepts drops of type `TaskModel`. Only `LongPressDraggable<TaskModel>` items will be accepted (same generic type).

**`onAcceptWithDetails(details)`** — fires when a dragged item is DROPPED on this target. `details.data` is the `TaskModel` that was dragged.

**`ref.read(taskProvider.notifier).updateTaskStatus(task.id, status)`** — updates the task's status in the provider. The `status` parameter is the column's status (e.g., `TaskStatus.inProgress`). Dragging a card from "To Do" to "In Progress" calls this with `TaskStatus.inProgress`.

**`candidateData.isNotEmpty`** — `candidateData` is a list of items currently hovering OVER this target (but not yet dropped). When a card hovers over the column, we show a subtle blue tint (`alpha: 0.05`) as visual feedback.

**`rejectedData`** — items that were dragged over but REJECTED (wrong type). Not used here since all draggables are `TaskModel`.

---

## Lines 154–181 — `LongPressDraggable<TaskModel>`

```dart
LongPressDraggable<TaskModel>(
  data: task,
  feedback: Material(
    color: Colors.transparent,
    child: SizedBox(
      width: 330,
      child: _buildCardContent(context, task, isDragging: true),
    ),
  ),
  childWhenDragging: Opacity(
    opacity: 0.3,
    child: _buildCardContent(context, task),
  ),
  child: InkWell(
    onTap: () => showDialog(context: context, builder: (_) => TaskDetailsDialog(task: task)),
    child: _buildCardContent(context, task),
  ),
),
```

**`data: task`** — the payload carried during the drag. Received as `details.data` in `DragTarget.onAcceptWithDetails`.

**`feedback`** — the widget that FOLLOWS the finger/cursor during drag:
- `Material(color: Colors.transparent)` — required wrapper so the feedback widget has proper painting context
- `SizedBox(width: 330)` — explicit width (the feedback widget has no layout constraints from a parent)
- `_buildCardContent(..., isDragging: true)` — uses the same card design but with accent border and shadow

**`childWhenDragging`** — what replaces the original card while it's being dragged. `Opacity(opacity: 0.3)` makes it look "ghosted" — the card slot is still visible but faded.

**`child`** — the normal display. Has `InkWell` so tapping opens the task dialog (without dragging).

---

## Lines 184–314 — `_buildCardContent` — `isDragging` Flag

```dart
Widget _buildCardContent(BuildContext context, TaskModel task,
    {bool isDragging = false}) {
  return Container(
    decoration: BoxDecoration(
      border: Border.all(
        color: isDragging ? AppColors.accent : AppColors.getBorderColor(context),
      ),
      boxShadow: isDragging
          ? [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 5)]
          : null,
    ),
  );
}
```

**`{bool isDragging = false}`** — named optional parameter with default. When called without this parameter, `isDragging = false` (normal display).

**`isDragging` effects:**
- Border → accent blue (visible against any background)
- `boxShadow` → added (card appears to "lift" off the surface)
- Without `isDragging` → normal border, no shadow

This single method serves THREE purposes (normal, ghosted, feedback) with the same code path — DRY principle.

---

## Summary: How Drag and Drop Works End-to-End

```
User long-presses "Fix Bug" task card (in "To Do" column)
  │
  ▼ LongPressDraggable activates
  ├─ Feedback widget appears under finger (card with blue border + shadow)
  └─ Original card becomes 30% opacity (ghosted)
        │
        ▼ User drags to "In Progress" column
        │
        ├─ DragTarget.builder sees candidateData.isNotEmpty
        └─ Column background gets slight blue tint (5% accent)
              │
              ▼ User releases finger (drop)
              │
              ▼ DragTarget.onAcceptWithDetails fires
              ref.read(taskProvider.notifier).updateTaskStatus(task.id, TaskStatus.inProgress)
                    │
                    ▼ TaskNotifier.state updated (immutable copy with new status)
                    │
                    ▼ filteredTasksProvider recomputes
                    │
                    ▼ KanbanBoardWidget rebuilds
                    "To Do" column: task removed
                    "In Progress" column: task added ✓
```
