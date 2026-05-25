# 📄 `repositories/announcement_repository.dart` — Complete Explanation

**File Path:** `frontend/lib/features/dashboard/data/repositories/announcement_repository.dart`
**Role:** Data access for channel announcements — fetches and returns raw Map data (no typed model).

---

## 1. Source Code

```dart
class AnnouncementRepository {
  final _api = ApiService();

  Future<List<Map<String, dynamic>>> getAnnouncements(int channelId) async {
    final response = await _api.getAnnouncements(channelId);
    final data = response.data as Map<String, dynamic>;
    final list = data['announcements'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }
}
```

---

## 2. Why No Typed Model?

Announcements use `Map<String, dynamic>` instead of a dedicated model class. This is acceptable for simple display-only data but is a code smell — ideally there'd be an `AnnouncementModel` class for type safety.

**`.cast<Map<String, dynamic>>()`:**
- `List<dynamic>` contains `Map<dynamic, dynamic>` from JSON decoding.
- `.cast<Map<String, dynamic>>()` tells Dart to treat each element as the more specific type.
- This is a runtime cast, not compile-time checked — could throw `CastError` if the API returns unexpected data types.

---

## 3. Final Summary

`announcement_repository.dart` is the simplest repository but has a type-safety gap — it returns `Map<String, dynamic>` instead of a typed model. A future improvement would be to add an `AnnouncementModel` with `fromJson`.

---

# 📄 `repositories/notification_repository.dart` — Complete Explanation

**File Path:** `frontend/lib/features/dashboard/data/repositories/notification_repository.dart`
**Role:** Data access for user notifications — fetch all, mark read.

---

## 1. Source Code

```dart
class NotificationRepository {
  final _api = ApiService();

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final response = await _api.getNotifications();
    final data = response.data as Map<String, dynamic>;
    final list = data['notifications'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> markRead(int id) async {
    await _api.markNotificationRead(id);
  }
}
```

---

## 2. Two Simple Methods

1. `getNotifications()` — Fetches all notifications for the logged-in user (scoped by the backend via `req.user.id`).
2. `markRead(id)` — Marks a single notification as read (PUT request to backend).

Like `AnnouncementRepository`, it uses `Map<String, dynamic>` instead of a typed model.

---

## 3. Final Summary

`notification_repository.dart` is a thin 2-method wrapper. The same type-safety gap as `AnnouncementRepository` applies — a `NotificationModel` class would be a clean improvement.

---

# 📄 `repositories/project_repository.dart` — Complete Explanation

**File Path:** `frontend/lib/features/dashboard/data/repositories/project_repository.dart`
**Role:** Data access for API-backed projects (Kanban board) — full CRUD + nested task operations.

---

## 1. Source Code

```dart
class ProjectRepository {
  final _api = ApiService();

  Future<List<Map<String, dynamic>>> getProjects() async { ... }
  Future<Map<String, dynamic>> getProject(int id) async { ... }
  Future<void> createProject(Map<String, dynamic> data) async { ... }
  Future<void> deleteProject(int id) async { ... }
  Future<void> createTask(int projectId, Map<String, dynamic> data) async { ... }
  Future<void> updateTaskStatus(int projectId, int taskId, String status) async { ... }
}
```

---

## 2. Method Breakdown

| Method | Backend Call | Purpose |
|---|---|---|
| `getProjects()` | `GET /api/projects` | List all projects for current user |
| `getProject(id)` | `GET /api/projects/:id` | Full project detail with tasks |
| `createProject(data)` | `POST /api/projects` | Create new project |
| `deleteProject(id)` | `DELETE /api/projects/:id` | Delete project |
| `createTask(projectId, data)` | `POST /api/projects/:id/tasks` | Add a task to a project |
| `updateTaskStatus(...)` | `PATCH /api/projects/:id/tasks/:taskId/status` | Move task between Kanban columns. `status` must be `'todo'`, `'in_progress'`, or `'done'` |

---

## 3. Final Summary

`project_repository.dart` covers the complete project + task lifecycle. The `updateTaskStatus` method connects directly to the Kanban drag-and-drop in `ProjectDetailScreen`.

---

# 📄 `repositories/academic_event_repository.dart` — Complete Explanation

**File Path:** `frontend/lib/features/dashboard/data/repositories/academic_event_repository.dart`
**Role:** Data access for academic calendar events — supports optional month/year/type filters.

---

## 1. Source Code

```dart
class AcademicEventRepository {
  final _api = ApiService();

  Future<List<Map<String, dynamic>>> getEvents({
    int? year, int? month, String? type,
  }) async {
    final response = await _api.getAcademicEvents(year: year, month: month, type: type);
    final data = response.data as Map<String, dynamic>;
    final list = data['events'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }
}
```

---

## 2. Named Optional Parameters for Flexible Filtering

```dart
getEvents()                                // All events
getEvents(year: 2025)                      // Events in 2025
getEvents(year: 2025, month: 10)           // October 2025 only
getEvents(year: 2025, month: 10, type: 'exam') // October 2025 exams only
```

All three parameters are optional — calling `getEvents()` without arguments returns all events. The backend's dynamic query builder handles the filtering.

---

## 3. Final Summary

`academic_event_repository.dart` is a single-method repository but with flexible filtering. The named optional parameters mirror the backend's query parameters (`?year=&month=&type=`), creating a clean interface that matches the API's capabilities.
