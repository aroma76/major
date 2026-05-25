# Word-by-Word Deep Dive: All Repository Files

> This document covers all 6 repository files. Repositories are the **data access layer** — they sit between providers (state management) and `ApiService` (HTTP client). Each repository takes raw Dio responses, extracts the relevant data, and returns typed Dart objects. They make providers cleaner and keep API parsing logic in one place.

---

## Before Reading — The Repository Pattern

Without repositories:

```dart
// Provider doing everything:
final channelsProvider = FutureProvider<List<ChannelModel>>((ref) async {
  final api = ApiService();
  final response = await api.getChannels();
  final data = response.data as Map<String, dynamic>;
  final list = data['channels'] as List<dynamic>? ?? [];
  return list.map((e) => ChannelModel.fromJson(e as Map<String, dynamic>)).toList();
});
```

With repositories:

```dart
// Provider: just calls repository
final channelsProvider = FutureProvider<List<ChannelModel>>((ref) async {
  return _channelRepo.getMyChannels(); // clean!
});

// Repository handles all the parsing
class ChannelRepository {
  Future<List<ChannelModel>> getMyChannels() async {
    final response = await _api.getChannels();
    final data = response.data as Map<String, dynamic>;
    final list = data['channels'] as List<dynamic>? ?? [];
    return list.map((e) => ChannelModel.fromJson(e as Map<String, dynamic>)).toList();
  }
}
```

**Separation of concerns:** Provider = when to fetch. Repository = how to fetch. Model = what the data looks like.

---

## `channel_repository.dart`

```dart
class ChannelRepository {
  final _api = ApiService();

  Future<List<ChannelModel>> getMyChannels() async {
    final response = await _api.getChannels();
    final data = response.data as Map<String, dynamic>;
    final list = data['channels'] as List<dynamic>? ?? [];
    return list
        .map((e) => ChannelModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ChannelModel> getChannelById(int id) async {
    final response = await _api.getChannelById(id);
    final data = response.data as Map<String, dynamic>;
    return ChannelModel.fromJson(data['channel'] as Map<String, dynamic>);
  }
}
```

### JSON Extraction Pattern

```dart
final data = response.data as Map<String, dynamic>;
```

**`response.data`** — Dio automatically deserializes JSON response bodies into Dart objects. `response.data` is `dynamic`.

**`as Map<String, dynamic>`** — cast to the expected type. The backend always sends `{ "channels": [...] }` so this cast is safe.

```dart
final list = data['channels'] as List<dynamic>? ?? [];
```

**`as List<dynamic>?`** — nullable cast. If the key `'channels'` is missing from the response, returns `null`.

**`?? []`** — empty list fallback. Prevents null reference if the backend returns `{}` without the key.

### `.map((e) => ChannelModel.fromJson(e as Map<String, dynamic>)).toList()`

**`.map(transform)`** — applies a function to every element, returning an `Iterable<ChannelModel>`.

**`e as Map<String, dynamic>`** — each element in the list is `dynamic`. Cast to the expected JSON object type before passing to `fromJson`.

**`.toList()`** — forces evaluation of the lazy `Iterable` into a `List<ChannelModel>`.

---

## `assignment_repository.dart`

```dart
class AssignmentRepository {
  final _api = ApiService();

  Future<List<AssignmentModel>> getAssignments(int channelId) async {
    final response = await _api.getAssignments(channelId);
    final data = response.data as Map<String, dynamic>;
    final list = data['assignments'] as List<dynamic>? ?? [];
    return list
        .map((e) => AssignmentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AssignmentModel>> getAllAssignments(List<int> channelIds) async {
    final results = await Future.wait(
      channelIds.map(
          (id) => getAssignments(id).catchError((_) => <AssignmentModel>[])),
    );
    return results.expand((list) => list).toList();
  }
}
```

### `getAllAssignments()` — Parallel Fetching

```dart
Future<List<AssignmentModel>> getAllAssignments(List<int> channelIds) async {
  final results = await Future.wait(
    channelIds.map(
      (id) => getAssignments(id).catchError((_) => <AssignmentModel>[])
    ),
  );
  return results.expand((list) => list).toList();
}
```

**`channelIds.map((id) => getAssignments(id))`** — creates an `Iterable<Future<List<AssignmentModel>>>` — a sequence of pending API calls (one per channel).

**`.catchError((_) => <AssignmentModel>[])`** — if ONE channel's assignment fetch fails (e.g., network error for channel 7), instead of throwing and failing ALL channels, it returns an empty list for that channel. The other channels' data is preserved.

**`<AssignmentModel>[]`** — an empty list with an explicit type annotation. `catchError` needs the return type to match the Future's type.

**`Future.wait([...futures])`** — runs ALL futures concurrently and waits for ALL to complete. If there are 5 channels, all 5 requests go out at the same time → total time ≈ slowest single request (not 5× a single request).

**`results`** — `List<List<AssignmentModel>>`. A list of lists — one inner list per channel.

**`.expand((list) => list)`** — "flattens" the list of lists into a single list:
```
[[A1, A2], [A3], [A4, A5]] → [A1, A2, A3, A4, A5]
```
`expand` applies a function that returns an `Iterable` and concatenates all results.

---

## `project_repository.dart`

```dart
class ProjectRepository {
  final _api = ApiService();

  Future<List<Map<String, dynamic>>> getProjects() async {
    final response = await _api.getProjects();
    final data = response.data as Map<String, dynamic>;
    final list = data['projects'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }
  ...
}
```

### `list.cast<Map<String, dynamic>>()`

**`.cast<T>()`** — Dart's method to convert `List<dynamic>` to `List<T>` (lazy type assertion, not deep conversion).

Compared to `.map((e) => e as Map<String, dynamic>).toList()`:
- `.cast<Map<String, dynamic>>()` — lazy (doesn't iterate until consumed), returns `List<Map<String, dynamic>>`
- `.map((e) => e as T).toList()` — eager (iterates immediately), more explicit

ProjectRepository returns raw `Map<String, dynamic>` instead of a typed `ProjectModel` because projects have complex nested task arrays that differ between list and detail views.

### Mutation Methods

```dart
Future<void> createProject(Map<String, dynamic> data) async {
  await _api.createProject(data);
}

Future<void> updateTaskStatus(int projectId, int taskId, String status) async {
  await _api.updateProjectTaskStatus(projectId, taskId, status);
}
```

**`Future<void>`** — returns a Future that completes with no value. `await` is used to wait for the operation to complete (and throw if it fails), even though there's no return value.

---

## All Other Repositories (Same Pattern)

### `announcement_repository.dart`

```dart
Future<List<Map<String, dynamic>>> getAnnouncements(int channelId) async {
  final response = await _api.getAnnouncements(channelId);
  final data = response.data as Map<String, dynamic>;
  final list = data['announcements'] as List<dynamic>? ?? [];
  return list.cast<Map<String, dynamic>>();
}
```

Returns raw maps (no typed model class) because announcement display varies by widget.

### `notification_repository.dart`

```dart
Future<List<Map<String, dynamic>>> getNotifications() async {
  final response = await _api.getNotifications();
  final data = response.data as Map<String, dynamic>;
  final list = data['notifications'] as List<dynamic>? ?? [];
  return list.cast<Map<String, dynamic>>();
}
```

Same pattern. The notification data is used directly in `NotificationPanel` without a typed model.

### `academic_event_repository.dart`

```dart
Future<List<Map<String, dynamic>>> getEvents({required int year}) async {
  final response = await _api.getAcademicEvents(year: year);
  final data = response.data as Map<String, dynamic>;
  final list = data['events'] as List<dynamic>? ?? [];
  return list.cast<Map<String, dynamic>>();
}
```

The `{required int year}` named parameter is passed through to `ApiService().getAcademicEvents(year: year)` → becomes `?year=2025` query parameter.

---

## Repository → Provider → Widget Data Flow

```
ChannelRepository.getMyChannels()
  │  calls ApiService().getChannels()
  │  parses response.data['channels']
  │  returns List<ChannelModel>
  ▼
channelsProvider (FutureProvider)
  │  calls _channelRepo.getMyChannels()
  │  wraps result in AsyncValue
  ▼
widget: ref.watch(channelsProvider)
  │  .when(
  │    loading: () => CircularProgressIndicator(),
  │    error: (e, _) => Text('Error'),
  │    data: (channels) => ListView.builder(...)
  │  )
  ▼
User sees channel list
```

### Why Not Call ApiService Directly from Widgets?

```dart
// BAD (widget calling API directly):
Widget build(BuildContext context) {
  final response = await ApiService().getChannels(); // breaks build()
  ...
}

// GOOD (widget watching provider):
Widget build(BuildContext context, WidgetRef ref) {
  final channelsAsync = ref.watch(channelsProvider); // reactive, cached
  ...
}
```

Direct API calls from widgets:
- Can't be cached between widget rebuilds
- Don't share state between sibling widgets
- Can't be easily tested
- Make `build()` async (not allowed)

Providers + Repositories solve all of these.

---

## Summary

| Repository | Returns | Typed Model? | Key Feature |
|---|---|---|---|
| `ChannelRepository` | `List<ChannelModel>` | ✅ Yes | Simple fetch + parse |
| `AssignmentRepository` | `List<AssignmentModel>` | ✅ Yes | `Future.wait` parallel multi-channel fetch |
| `ProjectRepository` | `List<Map<String, dynamic>>` | ❌ Raw map | `.cast<>()`, CRUD methods |
| `AnnouncementRepository` | `List<Map<String, dynamic>>` | ❌ Raw map | Simple per-channel fetch |
| `NotificationRepository` | `List<Map<String, dynamic>>` | ❌ Raw map | Simple single-user fetch |
| `AcademicEventRepository` | `List<Map<String, dynamic>>` | ❌ Raw map | Year parameter |
