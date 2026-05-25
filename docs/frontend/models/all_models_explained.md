# Word-by-Word Deep Dive: All Data Models

> This document covers all 5 data model files: `api_message_model.dart`, `assignment_model.dart`, `channel_model.dart`, `task_model.dart`, and `project_model.dart`. Models are **plain Dart classes** that represent the data shapes flowing between the backend API and the Flutter UI. They act as the contract between JSON and Dart objects.

---

## Before Reading — Why Models Exist

The backend sends raw JSON like:
```json
{ "id": 42, "channel_id": 7, "sender_name": "Rahul", "content": "Hello!", "created_at": "2025-05-23T10:30:00Z" }
```

Flutter works with typed Dart objects. Without models, you'd access data like:
```dart
final name = data['sender_name']; // type: dynamic, no autocomplete, no type safety
```

With a model (`ApiMessageModel`):
```dart
final name = msg.senderName; // type: String, full autocomplete, compile-time checking
```

Models also handle **type conversion** (JSON string `"2025-05-23T10:30:00Z"` → Dart `DateTime`).

---

## `channel_model.dart`

```dart
class ChannelModel {
  final int id;
  final String subjectName;
  final String channelName;
  final int semesterNumber;
  final String? teacherName;
  final int? teacherId;
```

### Fields Explained

**`final int id`** — the database primary key. Immutable after construction. Used as the parameter in `messagesNotifierProvider(channel.id)`, `channelAssignmentsProvider(channel.id)`, and `joinChannel(channel.id)`.

**`final String subjectName`** — the formal subject name (e.g., `'Mobile Application Development'`). Shown in channel tiles and headers.

**`final String channelName`** — the shorter channel name (e.g., `'MAD-6thSem'`). May be used as a fallback.

**`final int semesterNumber`** — which semester this subject belongs to. Used for grouping.

**`final String? teacherName`** — nullable. If a teacher hasn't been assigned, this is null. Widget shows fallback: `ch.teacherName ?? 'Faculty'`.

**`final int? teacherId`** — nullable. Used when the app needs to reference the teacher's user ID.

### `factory ChannelModel.fromJson(Map<String, dynamic> json)`

```dart
factory ChannelModel.fromJson(Map<String, dynamic> json) {
  return ChannelModel(
    id: json['id'] as int,
    subjectName: json['subject_name'] as String? ?? '',
    channelName: json['channel_name'] as String? ?? '',
    semesterNumber: json['semester_number'] as int? ?? 0,
    teacherName: json['teacher_name'] as String?,
    teacherId: json['teacher_id'] as int?,
  );
}
```

**`factory` constructor** — a special constructor that can return an existing instance or delegate. Here it simply creates a new `ChannelModel`. Used like: `ChannelModel.fromJson(data)`.

**`json['subject_name'] as String?`** — casts the dynamic value to `String?`. If the key doesn't exist, `json['subject_name']` returns `null`. The `as String?` cast is safe for null.

**`?? ''`** — if the value is null (key missing or explicitly null in JSON), fall back to empty string. Prevents null reference errors downstream.

**`json['teacher_id'] as int?`** — for nullable int fields, no `??` fallback — stays null to preserve "no teacher assigned" semantic.

---

## `assignment_model.dart`

```dart
class AssignmentModel {
  final int id;
  final int channelId;
  final String title;
  final String? description;
  final DateTime dueDate;
  final int maxMarks;
  final String? createdByName;
  final String? submissionStatus; // null = not submitted
  final int? marks;
  final String? feedback;
```

### Computed Properties

```dart
bool get isSubmitted => submissionStatus != null;
bool get isOverdue => !isSubmitted && dueDate.isBefore(DateTime.now());
```

**`bool get isSubmitted`** — getter (no parentheses): if `submissionStatus` is null → not submitted; non-null → submitted.

**`bool get isOverdue`** — BOTH conditions must be true:
- `!isSubmitted` — not yet submitted
- `dueDate.isBefore(DateTime.now())` — due date has passed

An assignment is NEVER "overdue" if it's been submitted — even if submitted after the deadline, the submission exists.

### `fromJson()` — Date Parsing

```dart
dueDate: DateTime.tryParse(json['due_date'] as String? ?? '') ?? DateTime.now(),
```

**`DateTime.tryParse(str)`** — parses an ISO 8601 string (e.g., `"2025-06-15T00:00:00.000Z"`) to a `DateTime`. Returns `null` if parsing fails (not a valid date string).

**`?? DateTime.now()`** — if parsing fails (malformed date or null from server), default to now. This is a safe fallback that prevents the app from crashing, though it may cause unexpected "due today" behavior — worth noting as a potential bug.

**`json['max_marks'] as int? ?? 100`** — default to 100 marks if not specified.

---

## `api_message_model.dart`

```dart
class ApiMessageModel {
  final int id;
  final int channelId;
  final int senderId;
  final String senderName;
  final String senderRole;
  final String? senderAvatar;
  final String? content;
  final String? fileUrl;
  final String? fileName;
  final bool isPinned;
  final DateTime createdAt;
  final int? parentId;
  final String? parentContent;
  final String? parentSenderName;
```

### The Reply (Thread) Fields

**`int? parentId`** — the ID of the message being replied to. `null` = top-level message.

**`String? parentContent`** — the TEXT CONTENT of the parent message. Fetched in the SQL JOIN in `messageController.js`:
```sql
parent.content AS parent_content
```
Stored here so the reply preview doesn't need a separate API call.

**`String? parentSenderName`** — the name of the person who sent the parent message. Shown in the reply preview as "↩ Rahul: Hello!".

### File vs Text Message

**`String? content`** — nullable. For FILE messages, `content` holds the caption. Can be null if no caption was added.

**`String? fileUrl`** — nullable. Only set for file messages. The Supabase signed/public URL.

**`String? fileName`** — nullable. The original filename (e.g., `'lecture_notes.pdf'`).

A message can be:
- Text only: `content='Hello'`, `fileUrl=null`
- File with caption: `content='See notes'`, `fileUrl='https://...'`, `fileName='notes.pdf'`
- File without caption: `content='notes.pdf'` (uses filename as caption in `_uploadFiles`), `fileUrl='https://...'`

### `toJson()` — Serialization

```dart
Map<String, dynamic> toJson() => {
  'id': id,
  'channel_id': channelId,
  ...
  'created_at': createdAt.toIso8601String(),
  ...
};
```

**`createdAt.toIso8601String()`** — converts `DateTime` back to an ISO 8601 string (`"2025-05-23T10:30:00.000Z"`). Used when caching messages in `SharedPreferences`.

**`toJson()` is not a factory** — it's a regular instance method. Called as `msg.toJson()`.

**Why `toJson`?** — `SharedPreferences` can only store `String`. The cache stores messages as `jsonEncode(msgs.map((m) => m.toJson()).toList())`. On load, `jsonDecode` + `ApiMessageModel.fromJson()` reverses this.

### `fromJson` Safe Casts

```dart
id: json['id'] as int,
senderId: json['sender_id'] as int,
```

**`as int`** (not `as int?`) — these fields are REQUIRED by the database (NOT NULL). If they're missing from the JSON, the cast fails with an error — which is the correct behavior (the API contract is broken).

```dart
senderName: json['sender_name'] as String? ?? 'Unknown',
```

**`as String?`** with `?? 'Unknown'` — nullable cast with fallback for optional fields.

---

## `task_model.dart` — Local Kanban Task

```dart
enum TaskStatus { todo, inProgress, done }
enum TaskPriority { low, medium, high }

class TaskModel {
  final String id;
  final String title;
  final String description;
  final String subject;
  final TaskStatus status;
  final TaskPriority priority;
  final DateTime dueDate;
  final DateTime createdAt;
```

**`enum TaskStatus`** — a Dart enum. Enums are type-safe constants:
```dart
// Can only be: TaskStatus.todo, TaskStatus.inProgress, or TaskStatus.done
// Prevents invalid values like 'in_progress' (typo) or 7 (wrong type)
```

**`String id`** — local task ID (generated client-side as `DateTime.now().millisecondsSinceEpoch.toString()`). NOT a database ID — tasks are local only.

### `copyWith()`

```dart
TaskModel copyWith({
  String? title,
  TaskStatus? status,
  ...
}) => TaskModel(
  id: id,                        // always preserve id
  title: title ?? this.title,    // use new or keep current
  status: status ?? this.status,
  ...
);
```

Used in `TaskNotifier.updateTaskStatus()`:
```dart
task.copyWith(status: newStatus)
```
Creates a new task with only the status changed. All other fields preserved.

---

## Summary: JSON → Model → Widget Flow

```
Backend API response (JSON)
  │
  ▼
AssignmentRepository.getAssignments(channelId)
  │  calls ApiService().getAssignments(channelId)
  │  parses: list.map((e) => AssignmentModel.fromJson(e))
  ▼
allAssignmentsProvider (FutureProvider)
  │  holds: AsyncValue<List<AssignmentModel>>
  ▼
ref.watch(allAssignmentsProvider)
  │  in TodayOverviewWidget — watches for changes
  │  .when(data: (assignments) => ...)
  ▼
Widget renders using typed fields:
  a.title, a.isSubmitted, a.isOverdue, a.dueDate
```

| Model | Source Data | Key Special Feature |
|---|---|---|
| `ChannelModel` | `/api/channels` | Fallbacks for optional teacher info |
| `AssignmentModel` | `/api/assignments/:channelId` | Computed `isSubmitted` and `isOverdue` getters |
| `ApiMessageModel` | `/api/messages/:channelId` + socket | `toJson()` for caching; reply thread fields |
| `TaskModel` | Local state only (Kanban board) | `enum` status/priority; client-generated ID |
| `ProjectModel` | Backend API or local seed data | Progress float, team members list |
