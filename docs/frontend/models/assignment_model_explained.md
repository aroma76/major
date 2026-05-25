# 📄 `models/assignment_model.dart` — Complete Explanation

**File Path:** `frontend/lib/features/dashboard/data/models/assignment_model.dart`
**Lines:** 44
**Role:** Typed data class for assignment objects from the backend API, with smart computed properties for submission state.

---

## 1. Fields & Computed Properties

```dart
final int id;
final int channelId;           // Which subject this assignment belongs to
final String title;
final String? description;
final DateTime dueDate;
final int maxMarks;
final String? createdByName;   // Teacher's name (denormalized)
final String? submissionStatus; // null = not submitted by this student
final int? marks;              // Grade awarded (null until graded)
final String? feedback;        // Teacher's feedback (null until graded)

// Computed — no server round-trip needed:
bool get isSubmitted => submissionStatus != null;
bool get isOverdue => !isSubmitted && dueDate.isBefore(DateTime.now());
```

---

## 2. Smart Computed Properties

**`isSubmitted`** — Simply checks if `submissionStatus` is not null. No date comparison needed.

**`isOverdue`** — Combines both conditions:
- Must not be submitted (`!isSubmitted`)
- Due date must be in the past (`dueDate.isBefore(DateTime.now())`)

A submitted late assignment is **NOT** "overdue" — the student already submitted it. The order of conditions matters: `isSubmitted` is checked first.

---

## 3. `fromJson` — Key Parsing

```dart
factory AssignmentModel.fromJson(Map<String, dynamic> json) {
  return AssignmentModel(
    id: json['id'] as int,
    channelId: json['channel_id'] as int,
    title: json['title'] as String,
    description: json['description'] as String?,
    dueDate: DateTime.parse(json['due_date'] as String),
    maxMarks: json['max_marks'] as int? ?? 100,
    createdByName: json['created_by_name'] as String?,
    submissionStatus: json['submission_status'] as String?,
    marks: json['marks'] as int?,
    feedback: json['feedback'] as String?,
  );
}
```

`submissionStatus` comes from a LEFT JOIN between `assignments` and `assignment_submissions` in the backend query. It's `null` if the student hasn't submitted yet.

---

## 4. Frontend Usage

```dart
// In AssignmentsViewWidget
final isSubmitted = assignment.isSubmitted;  // true/false
final isOverdue = assignment.isOverdue;      // true/false

// Status chip color
final color = assignment.isSubmitted
    ? Colors.green
    : assignment.isOverdue
        ? Colors.red
        : Colors.orange; // pending
```

---

## 5. Final Summary

`AssignmentModel` is notable for its computed `isSubmitted` and `isOverdue` getters — they encode business logic in the model layer so widgets don't need to duplicate date/status calculations. The `submissionStatus` being nullable is the key sentinel value that drives the entire submission state display.
