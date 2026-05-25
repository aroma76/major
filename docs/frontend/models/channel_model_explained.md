# 📄 `models/channel_model.dart` — Complete Explanation

**File Path:** `frontend/lib/features/dashboard/data/models/channel_model.dart`
**Lines:** 28
**Role:** Represents a subject/channel — the core organizational unit tying together messages, assignments, and announcements.

---

## 1. Fields

```dart
final int id;
final String subjectName;      // e.g., "Data Structures"
final String channelName;      // e.g., "Data Structures - Sem 3 A"
final int semesterNumber;      // 1-8
final String? teacherName;     // Faculty name (nullable for unassigned channels)
final int? teacherId;          // FK to users (faculty)
```

---

## 2. Two Name Fields — `subjectName` vs `channelName`

- **`subjectName`** — Short form used in headers, tabs, and cards (e.g., "Data Structures")
- **`channelName`** — Full context-aware name (e.g., "Data Structures - Sem 3 A") used in channel lists and search

The distinction exists because multiple classes may teach the same subject in different semesters/sections.

---

## 3. `fromJson`

```dart
factory ChannelModel.fromJson(Map<String, dynamic> json) {
  return ChannelModel(
    id: json['id'] as int,
    subjectName: json['subject_name'] as String? ?? 'Unknown',
    channelName: json['channel_name'] as String? ?? 'Unknown',
    semesterNumber: json['semester_number'] as int? ?? 1,
    teacherName: json['teacher_name'] as String?,
    teacherId: json['teacher_id'] as int?,
  );
}
```

`teacherName` is nullable — channels without an assigned teacher show no teacher name.

---

## 4. Frontend Usage

```dart
// channelsProvider returns List<ChannelModel>
// SubjectHubSheet uses:
channel.subjectName   // displayed in hub sheet header
channel.teacherName   // "Teacher: Dr. Smith"
channel.id            // used as channelId for all nested API calls
```

---

## 5. Final Summary

`ChannelModel` is the simplest but most central model — its `id` is passed as a parameter to virtually every other provider (`channelAssignmentsProvider(channel.id)`, `messagesNotifierProvider(channel.id)`, etc.). The `subjectName`/`channelName` split provides the right level of detail for each UI context.
