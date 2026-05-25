# 📄 `models/project_model.dart` — Complete Explanation

**File Path:** `frontend/lib/features/dashboard/data/models/project_model.dart`
**Lines:** 21
**Role:** Local-only data class for the Kanban project board display.

---

## 1. Fields

```dart
final String id;           // String ID (e.g., 'p1') — not DB integer
final String title;        // Project name
final List<String> teamMembers;  // List of member names
final double progress;     // 0.0 to 1.0 (used for progress bar)
final DateTime deadline;
final String description;
final Color color;         // Flutter Color — for project card theming
```

---

## 2. Key Difference from Other Models

This model uses Flutter's `Color` class (from `material.dart`). It's designed for the **local task board** widget, not direct API data. The real API data is fetched as `Map<String, dynamic>` and used in `ProjectsViewWidget`.

- **`String id`** (not `int`) — Local projects use a string identifier (e.g., `'p1'`), whereas API projects use integer IDs.
- **`Color color`** — A Flutter UI concern, not part of the API response.

---

## 3. Dual Project System

There are TWO project systems in the app:
1. **Local `ProjectModel`** — For the personal Kanban board in `TaskBoardWidget`. No backend sync.
2. **API `Map<String, dynamic>`** — Real projects from `GET /api/projects`, used in `ProjectsViewWidget`.

`ProjectModel` is only used by `TaskNotifier` / `TaskBoardWidget`.

---

## 4. Final Summary

`project_model.dart` is a UI-layer model, not an API-layer model. Its use of `Color` and string IDs distinguishes it from the backend-sourced project data. The coexistence of two project systems (local vs. API) reflects a feature that evolved across different development phases.
