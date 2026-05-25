# 📄 `screens/project_detail_screen.dart` — Complete Explanation

**File Path:** `frontend/lib/.../screens/project_detail_screen.dart`
**Lines:** 294
**Role:** Full-page project detail view — progress card, team members, milestones, and file upload area. Navigated to via `MaterialPageRoute` from `ProjectsViewWidget`.

---

## 1. File Purpose

`ProjectDetailScreen` is a full Scaffold screen (with AppBar) that displays the details of a single project. It receives a `ProjectModel` from the calling widget and renders four sections.

---

## 2. Navigation Pattern

This is the only screen in the project that uses a **full route push** (`Navigator.push`) rather than in-place widget substitution. This is because project detail is conceptually a separate "page" (with AppBar back button), not just a content swap in the sidebar.

```dart
Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => ProjectDetailScreen(project: projectModel)),
);
```

---

## 3. `_buildProgressSection` — Progress Display

```dart
'${(project.progress * 100).toInt()}%'
```
`project.progress` is 0.0–1.0. `(progress * 100).toInt()` converts to 0–100 integer for display.

```dart
LinearProgressIndicator(
  value: project.progress,
  valueColor: AlwaysStoppedAnimation<Color>(project.color),
)
```
`AlwaysStoppedAnimation<Color>` — Wraps a static color to satisfy Flutter's `Animation<Color>` type requirement. It never actually animates.

---

## 4. Team Members — Pravatar Avatars

```dart
CircleAvatar(
  radius: 12,
  backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=$member'),
),
```

`pravatar.cc` — A placeholder avatar service. `?u=$member` uses the member's name as a seed for a consistent (but fake) avatar. In production, this should use the user's actual profile image URL.

---

## 5. Milestones — Hardcoded Placeholder

```dart
_buildMilestoneItem(context, 'Project Planning', true),
_buildMilestoneItem(context, 'UI/UX Design', true),
_buildMilestoneItem(context, 'Backend Integration', true),
_buildMilestoneItem(context, 'Final Testing', false),
```

⚠️ **Hardcoded milestones** — These four items are not from any API or database. They are static placeholder data. The backend has no milestone tracking feature yet.

`TextDecoration.lineThrough` — Completed milestones show strikethrough text, matching the notes widget's resolved-question pattern.

---

## 6. File Upload Section — Unimplemented

```dart
TextButton.icon(
  onPressed: () {},  // No-op
  ...
),
```

The "Upload" button does nothing (`onPressed: () {}`). The section shows a drag-and-drop UI placeholder but has no backend integration.

---

## 7. Known Issues

1. **Hardcoded milestones** — Not backed by data
2. **File upload unimplemented** — `onPressed: () {}`
3. **Status hardcoded** — `'Status', 'In Progress'` is always "In Progress"
4. **Pravatar avatars** — Placeholder images, not real user photos

---

## 8. Final Summary

`ProjectDetailScreen` is a partially implemented screen. The progress bar and team members sections display real data from `ProjectModel`. The milestones and file upload sections are UI mockups without backend support. It demonstrates `AlwaysStoppedAnimation<Color>` for static color in `LinearProgressIndicator` and the `Navigator.push` full-screen navigation pattern.
