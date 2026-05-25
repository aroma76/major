# 📄 `widgets/subject_color_manager.dart` — Complete Explanation

**File Path:** `frontend/lib/.../widgets/subject_color_manager.dart`
**Lines:** 37
**Role:** Deterministic, hash-based color assignment for subject names — ensures the same subject always gets the same color throughout the app.

---

## 1. File Purpose

When displaying subjects (channels) in the UI, each subject needs a consistent color — for progress bars, sidebar dots, deadline cards, and kanban labels. `SubjectColorManager` solves this with a deterministic hash algorithm.

> **Beginner Analogy:** Like how each person always sits in the same color seat in a classroom — the color is assigned by a rule (the rule here is the subject's name), so it's always the same, every time.

---

## 2. The Hash Algorithm

```dart
static Color forSubject(String subjectName) {
  final hash = subjectName.toLowerCase().codeUnits.fold(0, (a, b) => a + b);
  return _palette[hash % _palette.length];
}
```

**Line-by-line:**

**`subjectName.toLowerCase()`** — Normalizes case: "Data Structures" and "data structures" map to the same color.

**`.codeUnits`** — Converts the string to a `List<int>` of Unicode code points:
- `'a'` → 97
- `'b'` → 98
- `'data'` → [100, 97, 116, 97]

**`.fold(0, (a, b) => a + b)`** — Sums all code units:
- `fold` is Dart's reduce with initial value
- `a` = running total, starts at 0
- `b` = next code unit
- Result: a single integer (the hash)

**`hash % _palette.length`** — Modulo maps the hash to a valid index (0 to 9).

**Example:** "data structures" → sum of code units → say 1,847 → `1847 % 10 = 7` → Color index 7 (Mint).

**Deterministic:** The same string always produces the same hash → same color → consistent UI.

**Simple but effective:** This is a simple additive hash. Not cryptographically secure but perfect for UI color assignment.

---

## 3. The Color Palette

```dart
static const List<Color> _palette = [
  Color(0xFF58A6FF), // Blue (GitHub blue)
  Color(0xFF3FB950), // Green (GitHub green)
  Color(0xFFF78166), // Coral
  Color(0xFFD2A8FF), // Purple
  Color(0xFFFFA657), // Orange
  Color(0xFF79C0FF), // Sky
  Color(0xFFFF7B72), // Red
  Color(0xFF56D364), // Mint
  Color(0xFFE3B341), // Gold
  Color(0xFF7EE787), // Light Green
];
```

10 colors — all vibrant, high-contrast GitHub-inspired colors. All `const` — zero runtime cost.

---

## 4. Helper Methods

```dart
static Color forSubjectDark(String subjectName) {
  return forSubject(subjectName).withValues(alpha: 0.85);
}

static LinearGradient gradientForSubject(String subjectName) {
  final base = forSubject(subjectName);
  return LinearGradient(
    colors: [base, base.withValues(alpha: 0.6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
```

- `forSubjectDark` — Slightly reduced opacity version for dark backgrounds
- `gradientForSubject` — Creates a gradient from full color → 60% opacity for card headers

---

## 5. Final Summary

A tiny but elegant utility. The additive hash algorithm is simple, deterministic, and consistent. Used in `TodayOverviewWidget` (deadline cards), `SubjectsViewWidget` (channel list), `KanbanBoardWidget` (task cards), and wherever subject-specific color is needed.

---

# 📄 `widgets/kanban_board_widget.dart` — Complete Explanation

**File Path:** `frontend/lib/.../widgets/kanban_board_widget.dart`
**Lines:** 316
**Role:** Drag-and-drop Kanban board UI for personal tasks — responsive columns, `DragTarget`/`LongPressDraggable`, and visual drag feedback.

---

## 1. File Purpose

Renders the personal task board in three columns (To Do / In Progress / Done) with Flutter's built-in drag-and-drop system. Tapping a card opens `TaskDetailsDialog`. Long-pressing picks up the card for drag-and-drop status change.

---

## 2. Responsive Column Calculation

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
```

**`LayoutBuilder`** — Gives access to the parent's `BoxConstraints` (available width).

**Column count formula:**
- `(availableWidth / (280 + 20)).floor()` — How many 280px columns fit (with 20px gap between each)?
- Mobile (400px wide): `(400 / 300).floor() = 1` → 1 column (stacked)
- Tablet (900px wide): `(900 / 300).floor() = 3` → 3 columns (side by side)
- Clamped to 1-3

**Item width formula:**
- Single column: full width
- Multiple columns: `(totalWidth - gaps) / columns`
- Gap count = `crossAxisCount - 1` (gaps between columns, not at edges)

---

## 3. `DragTarget` — Drop Zone

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
      ),
      child: ListView.builder(...)
    );
  },
),
```

**`DragTarget<TaskModel>`** — Only accepts drags of type `TaskModel` (type-safe).

**`onAcceptWithDetails(details)`** — Called when a card is dropped here.
- `details.data` — The `TaskModel` that was dragged
- Calls `updateTaskStatus(task.id, status)` — updates state with new column's status

**`candidateData.isNotEmpty`** — True when a card is hovering OVER this drop zone (but not yet dropped). Used to show a highlight background — visual feedback that "you can drop here".

---

## 4. `LongPressDraggable` — Drag Source

```dart
LongPressDraggable<TaskModel>(
  data: task,                    // The data carried during drag
  feedback: Material(            // What shows under your finger while dragging
    color: Colors.transparent,
    child: SizedBox(width: 330, child: _buildCardContent(context, task, isDragging: true)),
  ),
  childWhenDragging: Opacity(    // Original position placeholder
    opacity: 0.3,
    child: _buildCardContent(context, task),
  ),
  child: InkWell(               // Normal tap behavior
    onTap: () => showDialog(...TaskDetailsDialog(task: task)),
    child: _buildCardContent(context, task),
  ),
),
```

**`LongPressDraggable` vs `Draggable`:**
- `Draggable` — Starts immediately on touch
- `LongPressDraggable` — Requires a long press (300ms+) before drag starts
- Better for lists/cards where a quick tap = open, long press = drag

**`feedback`** — The floating "ghost" card that follows the user's finger. Uses `isDragging: true` to add a drop shadow.

**`childWhenDragging`** — The faded card shown in the original position while dragging. 30% opacity indicates "this card is being moved".

---

## 5. Priority Color Switch

```dart
Color priorityColor;
switch (task.priority) {
  case TaskPriority.high:   priorityColor = AppColors.priorityHigh;   break;
  case TaskPriority.medium: priorityColor = AppColors.priorityMedium; break;
  case TaskPriority.low:    priorityColor = AppColors.priorityLow;    break;
}
```

Maps the `TaskPriority` enum to a color constant. Used for the priority badge on each card.

---

## 6. State Management Connection

```dart
final tasks = ref.watch(filteredTasksProvider);
```

`filteredTasksProvider` — A derived provider that takes `taskProvider` and applies search/filter criteria from `searchQueryProvider` and `selectedSubjectFilterProvider`. The Kanban board automatically shows only filtered tasks.

---

## 7. Known Issues

1. **Hardcoded avatar:** `NetworkImage('https://i.pravatar.cc/150?img=11')` — placeholder avatar. Should use the actual task assignee's avatar.
2. **Hardcoded "2" link count** — Decorative only, not connected to real data.
3. **Local state only** — Drag-and-drop changes `task_provider` (in-memory); not synced to backend.

---

## 8. Final Summary

`KanbanBoardWidget` uses Flutter's native drag-and-drop system (`LongPressDraggable` + `DragTarget`) with type-safe `TaskModel` data passing. The responsive layout calculation dynamically determines column count from available width. Visual feedback (hover highlight, drag shadow, ghost card) creates a polished Trello-like experience.

---

# 📄 `widgets/settings_view_widget.dart` — Complete Explanation

**File Path:** `frontend/lib/.../widgets/settings_view_widget.dart`
**Lines:** 674
**Role:** Full settings screen — profile display/editing, theme toggle, notification preferences, password change, and logout confirmation.

---

## 1. File Purpose

The settings screen provides user account management and app preferences. Key sections:
- **Account Profile** — Avatar initials, name, email, role display + Edit Profile dialog
- **Preferences** — Dark mode toggle, push notification toggle, email summary toggle
- **Security** — Change password dialog + logout

---

## 2. `_showEditProfile()` — Dialog with StatefulBuilder

```dart
void _showEditProfile(BuildContext context, WidgetRef ref) {
  final authState = ref.read(authProvider).value;
  final nameCtrl = TextEditingController(text: authState?.userName ?? '');
  final dobCtrl = TextEditingController(
    text: authState?.user?['dob'] != null
        ? (authState!.user!['dob'] as String).substring(0, 10)
        : '',
  );
  bool isLoading = false;
  String? errorMsg;

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(...),
    ),
  );
}
```

**`ref.read` (not `ref.watch`)** — In a method called from a button press, we read the current auth state once. We don't need reactivity here.

**`StatefulBuilder`** — Allows calling `setState()` inside a dialog to update `isLoading` and `errorMsg` without a `StatefulWidget`. The dialog's `setState` only rebuilds the dialog content, not the entire screen.

**DOB extraction:**
```dart
(authState!.user!['dob'] as String).substring(0, 10)
```
DOB is stored as `TIMESTAMPTZ` in DB → comes back as `'2003-05-26T00:00:00.000Z'` from JSON. `.substring(0, 10)` extracts just the date part `'2003-05-26'`.

**Save flow:**
```dart
await ref.read(authProvider.notifier).updateProfile(name: ..., dob: ...);
if (context.mounted) { Navigator.pop(context); ScaffoldMessenger...showSnackBar(...); }
```
- Calls `AuthNotifier.updateProfile()` which calls `PUT /api/auth/profile`
- `context.mounted` — Checks if the widget is still in the tree after the async gap (prevents `setState after dispose` errors)

---

## 3. `_showChangePassword()` — Client-Side Validation

```dart
if (newController.text != confirmController.text) {
  setState(() => errorMsg = 'New passwords do not match');
  return;
}
if (newController.text.length < 6) {
  setState(() => errorMsg = 'Password must be at least 6 characters');
  return;
}
```

Two validation checks BEFORE the API call:
1. Password confirmation match
2. Minimum length (6 chars in UI; 8 chars in backend — slight inconsistency)

If validation fails, `setState` updates `errorMsg` which shows a red error text in the dialog. `return` prevents the API call.

---

## 4. Toggle Tiles — Preference Section

```dart
_buildToggleTile(context, 'Dark Mode', '...', themeMode == ThemeMode.dark,
  (val) => ref.read(themeModeProvider.notifier).toggle(),
  icon: themeMode == ThemeMode.dark ? FeatherIcons.moon : FeatherIcons.sun,
),
```

**`themeMode == ThemeMode.dark`** — Current switch state.
**`onChanged: (val) => ref.read(themeModeProvider.notifier).toggle()`** — Ignores the `val` boolean from the Switch (since `toggle()` flips the current state). This is safe because the switch's `value` is driven by Riverpod state.

**Push Notifications & Email Summary** — Currently local state only (toggle state stored in `isNotificationsEnabledProvider`, not synced to backend). In production, these should call `PUT /api/user/preferences`.

---

## 5. `_buildSettingCard` and `_buildSectionHeader`

Reusable UI builders:
- `_buildSectionHeader` — Uppercase, letter-spaced section title (e.g., "PREFERENCES")
- `_buildSettingCard` — White/dark bordered card container with rounded corners
- `_buildToggleTile` — Row with icon + title/subtitle + switch
- `_buildActionTile` — Row with icon + title/subtitle + chevron (tappable)
- `_buildDialogField` — Labeled text input for dialogs
- `_buildReadOnlyField` — Non-editable field with lock icon

**`isDanger: true`** in `_buildActionTile` for Logout:
- Uses `Colors.red` for icon and title text
- Red background (10% opacity) for the icon container
- Visually signals this is a destructive action

---

## 6. Final Summary

`SettingsViewWidget` demonstrates `StatefulBuilder` for in-dialog state management, `context.mounted` safety after async operations, and `ref.read` for one-time data reads in event handlers. The reusable UI helpers (`_buildToggleTile`, `_buildActionTile`) avoid code duplication while maintaining visual consistency.
