# 📄 `providers/task_provider.dart` — Complete Explanation

**File Path:** `frontend/lib/features/dashboard/presentation/providers/task_provider.dart`
**Lines:** 205
**Role:** Local Riverpod state management for the personal Kanban task board, navigation, and dashboard notes.

---

## 1. File Purpose

This file manages all **local (offline) UI state** for the student dashboard:
- Personal task board (Kanban cards)
- Navigation index (which tab is active)
- Assignment view type (list vs. kanban)
- Filter state (subject filter, priority filter, search query)
- Dashboard sticky notes

All state here is **in-memory only** — it's not persisted to any server or local storage. Refreshing the app resets everything.

---

## 2. `navigationProvider`

```dart
final navigationProvider =
    NotifierProvider<NavigationNotifier, int>(() => NavigationNotifier());

class NavigationNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void navigateTo(int index) => state = index;
}
```

- Tracks the currently selected navigation index (0=Home, 1=Subjects, 2=Projects, etc.)
- `MainDashboardScreen` uses `ref.watch(navigationProvider)` to decide which screen to show in the `_LazyIndexedStack`.
- `ref.read(navigationProvider.notifier).navigateTo(4)` — navigates to Messages.

---

## 3. `TaskNotifier` — Kanban Board

```dart
class TaskNotifier extends Notifier<List<TaskModel>> {
  @override
  List<TaskModel> build() => _initialTasks;  // starts empty

  static final List<TaskModel> _initialTasks = [];  // empty

  void addTask(TaskModel task) => state = [...state, task];

  void updateTaskStatus(String taskId, TaskStatus newStatus) {
    state = [
      for (final task in state)
        if (task.id == taskId) task.copyWith(status: newStatus) else task
    ];
  }

  void removeTask(String taskId) =>
      state = state.where((task) => task.id != taskId).toList();
}
```

**`updateTaskStatus` — Collection For Loop:**
```dart
state = [
  for (final task in state)
    if (task.id == taskId) task.copyWith(status: newStatus) else task
];
```
This is Dart's **collection `for`+`if`** syntax — creates a new list by transforming elements. For the matching task, `copyWith(status: newStatus)` creates a new `TaskModel` with only the status changed. All other tasks are kept as-is.

This pattern is:
1. **Immutable** — creates a new list
2. **Efficient** — O(n) single pass
3. **Type-safe** — Dart checks all elements are `TaskModel`

---

## 4. `DashboardNotesNotifier`

```dart
class DashboardNote {
  final String id;           // millisecond timestamp as string
  final String content;      // Note text
  final DashboardNoteType type; // note or question
  final DateTime createdAt;
  final bool isResolved;     // for questions: marks as answered
}
```

Full CRUD for sticky notes on the dashboard home screen:
- `add(content, type)` — Creates a new note with `DateTime.now().millisecondsSinceEpoch.toString()` as ID.
- `toggleResolved(id)` — Marks a question as answered/unanswered.
- `remove(id)` — Deletes a note.

---

## 5. Final Summary

`task_provider.dart` handles all the "personal workspace" state that doesn't need backend persistence. The Kanban board is intentionally local — students manage their own tasks. The navigation provider is the spine of the entire multi-screen layout. The `copyWith` pattern is used consistently for immutable updates.
