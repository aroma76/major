# 📄 `models/task_model.dart` — Complete Explanation

**File Path:** `frontend/lib/features/dashboard/data/models/task_model.dart`
**Lines:** 56
**Role:** Immutable data class for personal student tasks on the local Kanban board, with enums for status/priority.

---

## 1. Enums

```dart
enum TaskStatus { todo, inProgress, done }
enum TaskPriority { low, medium, high }
```

Enums provide type safety — the compiler catches invalid status values like `'in progress'` (wrong string) at compile time. The Kanban board's three columns map to `todo`, `inProgress`, `done`.

---

## 2. Fields

```dart
class TaskModel {
  final String id;
  final String title;
  final String description;
  final String subject;       // Which subject this task relates to
  final TaskStatus status;    // todo / inProgress / done
  final TaskPriority priority; // low / medium / high
  final DateTime dueDate;
  final String? attachments;
  final String? notes;
  final String? questions;
}
```

---

## 3. `copyWith` Pattern

```dart
TaskModel copyWith({ String? id, String? title, TaskStatus? status, ... }) {
  return TaskModel(
    id: id ?? this.id,          // Use new value if provided, else keep current
    title: title ?? this.title,
    status: status ?? this.status,
    ...
  );
}
```

This is Dart's **immutable update pattern**. Instead of mutating the object (`task.status = done`), you create a new instance with the changed field. This is required for Riverpod state management to detect changes — Riverpod compares state by reference, so a mutated object would NOT trigger a rebuild.

**Usage in `TaskNotifier`:**
```dart
// Update only the status, keep all other fields
task.copyWith(status: TaskStatus.done)
```

---

## 4. Relationship to Backend

`TaskModel` is **100% local** — it maps to the personal task board in `CreateTaskDialog` + `TaskDetailsDialog`. It does NOT correspond to the `tasks` table in the backend database (those tasks belong to projects, not the personal board).

---

## 5. Final Summary

`TaskModel` demonstrates the Dart immutable update pattern with `copyWith`. The `TaskStatus` and `TaskPriority` enums prevent invalid states at compile time. All fields are final (immutable), enforcing the Riverpod state management contract.
