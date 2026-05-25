# 📄 `features/dashboard/presentation/providers/api_providers.dart` — Complete Explanation

**File Path:** `frontend/lib/features/dashboard/presentation/providers/api_providers.dart`
**Lines:** 127
**Role:** Central Riverpod provider registry — all app-wide data fetching providers for channels, assignments, notifications, projects, events, and dashboard activity.

---

## 1. 📌 File Purpose

This file is the **Riverpod provider hub** for all dashboard data. It defines:
- Repository singletons (one per domain)
- `FutureProvider` instances (async data fetching)
- `NotifierProvider` for selected channel state
- Session caching strategies (`ref.keepAlive()`)

Every widget in the dashboard that shows data (subjects, assignments, notifications, etc.) watches one of these providers.

---

## 2. 🏗️ Repository Singletons

```dart
final _channelRepo      = ChannelRepository();
final _assignmentRepo   = AssignmentRepository();
final _announcementRepo = AnnouncementRepository();
final _notificationRepo = NotificationRepository();
final _projectRepo      = ProjectRepository();
final _eventRepo        = AcademicEventRepository();
```

- Module-level variables — created once when the file is first imported.
- All repository instances share the `ApiService` singleton (which has one Dio client).
- This is more efficient than creating a new repository inside each provider callback.

---

## 3. 📺 `channelsProvider` — Subject List

```dart
final channelsProvider = FutureProvider<List<ChannelModel>>((ref) async {
  ref.keepAlive(); // persist for the session — channels don't change often
  return _channelRepo.getMyChannels();
});
```

**`ref.keepAlive()` — Deep Explanation:**

Normally, when all widgets watching a provider are disposed (e.g., user navigates away), the provider is also disposed and its data is garbage collected. The next time a widget watches it, data is re-fetched from the network.

`ref.keepAlive()` prevents this. The provider stays alive and its data stays cached for the entire session.

**Why channels?**
A user's enrolled channels rarely change during a session (they don't enroll/unenroll while logged in). Keeping them alive avoids re-fetching on every tab switch.

**Invalidation:**
`AuthNotifier.logout()` calls `ref.invalidate(channelsProvider)` to clear this cache when logging out.

---

## 4. 📋 `allAssignmentsProvider` — Aggregated Assignments

```dart
final allAssignmentsProvider =
    FutureProvider<List<AssignmentModel>>((ref) async {
  ref.keepAlive();
  final channels = await ref.watch(channelsProvider.future);
  return _assignmentRepo.getAllAssignments(channels.map((c) => c.id).toList());
});
```

**Provider-to-provider dependency:**
```dart
final channels = await ref.watch(channelsProvider.future);
```
- `ref.watch(channelsProvider.future)` — Waits for `channelsProvider` to complete and returns its value.
- `allAssignmentsProvider` **depends on** `channelsProvider`. It won't start fetching until channel IDs are known.
- If `channelsProvider` re-fetches (after invalidation), `allAssignmentsProvider` will also re-run automatically.

**Why aggregate?**
The "Assignments" screen shows ALL assignments across ALL subjects. Fetching per-channel would require the UI to know channel IDs first. This provider does the aggregation so widgets get a flat list.

**Performance:**
`getAllAssignments(channelIds)` calls all channel endpoints in parallel via `Future.wait` — covered in the Repository documentation.

---

## 5. 📑 `channelAssignmentsProvider` — Per-Channel Assignments

```dart
final channelAssignmentsProvider =
    FutureProvider.family<List<AssignmentModel>, int>((ref, channelId) async {
  return _assignmentRepo.getAssignments(channelId);
});
```

**`FutureProvider.family`** — A provider that takes an argument (`channelId`).
- `ref.watch(channelAssignmentsProvider(42))` fetches assignments for channel 42.
- `ref.watch(channelAssignmentsProvider(99))` fetches for channel 99.
- Each argument creates a **separate provider instance**.
- Used in the per-subject assignments view inside `SubjectsViewWidget`.
- No `keepAlive()` — data is re-fetched each time the user opens a subject's assignments tab (fresh data).

---

## 6. 📢 `channelAnnouncementsProvider`

```dart
final channelAnnouncementsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>(
        (ref, channelId) async {
  return _announcementRepo.getAnnouncements(channelId);
});
```

Same `family` pattern — one instance per `channelId`. No caching — announcements are re-fetched on each view.

---

## 7. 🔔 `notificationsApiProvider`

```dart
final notificationsApiProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.keepAlive(); // don't re-fetch on every notification panel open
  return _notificationRepo.getNotifications();
});
```

`keepAlive()` — Notifications panel is opened frequently (clicking the bell). Without caching, each open would re-fetch. With caching, the list loads instantly from memory and is invalidated on logout.

**Real-time updates:**
New socket-pushed notifications are added to the separate `notificationProvider` (in `app_colors.dart`) — not to this API provider. The two notification systems are currently separate and not fully merged.

---

## 8. 📍 `selectedChannelProvider` — Active Message Channel

```dart
class _SelectedChannelNotifier extends Notifier<ChannelModel?> {
  @override
  ChannelModel? build() => null;
  void select(ChannelModel? ch) => state = ch;
}

final selectedChannelProvider =
    NotifierProvider<_SelectedChannelNotifier, ChannelModel?>(
  _SelectedChannelNotifier.new,
);
```

- Tracks which channel the user currently has open in the Messages view.
- `null` = no channel selected (shows channel list).
- `ChannelModel` = shows the message thread for that channel.
- Used by `MessagesViewWidget` to decide whether to show the channel list or the chat view.

---

## 9. 🗂️ `projectsProvider`

```dart
final projectsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return _projectRepo.getProjects();
});
```

No `keepAlive()` here — projects are re-fetched when the Projects tab is opened. This ensures fresh data (e.g., team members adding tasks). Note: This fetches API projects, separate from the local `projectProvider` (in `task_provider.dart`) which has hardcoded dummy data.

---

## 10. 📅 `academicEventsProvider`

```dart
final academicEventsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, year) async {
  return _eventRepo.getEvents(year: year);
});
```

Family parameter is `year` (e.g., 2024). Different years have separate cached providers.

---

## 11. 📊 `teacherStatsProvider`

```dart
final teacherStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.keepAlive(); // Expensive query — cache for the session
  final api = ApiService();
  final res = await api.getTeacherStats();
  final data = res.data as Map<String, dynamic>;
  return data['stats'] as Map<String, dynamic>? ?? {};
});
```

- Calls `GET /teacher/stats` — a DB-heavy query (counts of students, assignments, submissions).
- `keepAlive()` — Stats don't change within a session (or change rarely). Caching avoids repeated expensive queries.
- Only accessible to faculty (the UI conditionally shows this data based on `isFaculty`).

---

## 12. 🏃 `dashboardRecentActivityProvider`

```dart
final dashboardRecentActivityProvider =
    FutureProvider.family<Map<String, dynamic>, bool>((ref, isFaculty) async {
  final api = ApiService();
  try {
    final res = isFaculty
        ? await api.getTeacherRecentActivity()
        : await api.getStudentRecentActivity();
    final data = res.data as Map<String, dynamic>;
    final result = {
      'announcements': (data['announcements'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>(),
      'recentMessages': (data['recentMessages'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>(),
    };
    // Only keepAlive after successful fetch
    ref.keepAlive();
    return result;
  } catch (e) {
    rethrow;
  }
});
```

**The family argument `bool isFaculty`:**
- `ref.watch(dashboardRecentActivityProvider(true))` = teacher dashboard
- `ref.watch(dashboardRecentActivityProvider(false))` = student dashboard
- This avoids a circular import: importing `authProvider` here would create a dependency cycle.

**Conditional `ref.keepAlive()`:**
```dart
ref.keepAlive(); // Only after successful fetch
```
- Called INSIDE the try block, AFTER the API call succeeds.
- If the fetch fails, `keepAlive()` is never called.
- This means failed providers are **disposable** — `ref.invalidate()` on the retry button works correctly.
- If `keepAlive()` were called unconditionally at the start, a failed provider would persist and the retry wouldn't re-run the provider.

This is a **sophisticated Riverpod pattern** — conditional keepAlive based on success.

---

## 13. 🔄 Provider Dependency Graph

```
channelsProvider
    │ (watched by)
    ▼
allAssignmentsProvider
    │ (provides channel IDs to)
    ▼
AssignmentRepository.getAllAssignments()
    │ (parallel calls to)
    ▼
ApiService.getAssignments(channelId) × n
```

---

## 14. ✅ Final Summary

`api_providers.dart` is the **data distribution hub** of the Flutter app. Every major piece of server data flows through one of these providers. The `keepAlive()` strategy is carefully applied only where data is expensive or frequently accessed. The `family` providers enable per-channel data isolation without duplicating code. The conditional `keepAlive()` on `dashboardRecentActivityProvider` is a particularly elegant pattern worth studying.
