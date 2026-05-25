# Word-by-Word Deep Dive: All Provider Files

> This document covers all four provider files: `api_providers.dart`, `messages_notifier.dart`, `task_provider.dart`, and `saved_files_provider.dart`. Providers are the **state management layer** — the bridge between the UI (widgets) and data (API, local storage). Understanding providers means understanding how data flows from the backend to the screen.

---

## Before Reading — Riverpod Provider Types

| Provider Type | When to Use | Returns |
|---|---|---|
| `Provider<T>` | Sync computed value, derived from other providers | `T` directly |
| `FutureProvider<T>` | Async data fetch (one-shot) | `AsyncValue<T>` (loading/data/error) |
| `FutureProvider.family<T, A>` | Async fetch with a parameter (e.g., channel ID) | `AsyncValue<T>` |
| `NotifierProvider<N, T>` | Mutable state with methods to change it | `T` directly (Notifier manages it) |
| `NotifierProvider.autoDispose.family<N, T, A>` | Auto-cleanup mutable state per parameter | `T` |

**`AsyncValue<T>`** — Riverpod's wrapper for async state. Has three states:
- `AsyncLoading` — data not yet fetched
- `AsyncData<T>` — fetch succeeded, holds the data
- `AsyncError` — fetch failed, holds the error

**`ref.watch(provider)`** — read value AND subscribe (widget rebuilds when value changes)

**`ref.read(provider)`** — read value WITHOUT subscribing (used in callbacks/event handlers)

---

## `api_providers.dart` — All Backend Data Providers

### Lines 14–21 — Repository Instances

```dart
final _channelRepo = ChannelRepository();
final _assignmentRepo = AssignmentRepository();
final _announcementRepo = AnnouncementRepository();
final _notificationRepo = NotificationRepository();
final _projectRepo = ProjectRepository();
final _eventRepo = AcademicEventRepository();
```

**Module-level `final`** — these repository instances are created once when the file is first imported. Since repositories are stateless (they just call `ApiService()`), one instance is enough.

**`_` prefix** — private to this file (library-private). Other files cannot access these directly — they must use the providers.

### Lines 25–28 — `channelsProvider`

```dart
final channelsProvider = FutureProvider<List<ChannelModel>>((ref) async {
  ref.keepAlive();
  return _channelRepo.getMyChannels();
});
```

**`FutureProvider<List<ChannelModel>>`** — an async provider. When first watched, calls the function which fetches channels from the API.

**`ref.keepAlive()`** — normally, Riverpod disposes `FutureProvider` when no widgets are watching it. `keepAlive()` prevents this — the channel list remains cached as long as the app is open. Channels change rarely (admin only), so caching is safe.

**`_channelRepo.getMyChannels()`** — calls `ApiService().getChannels()` and parses the response into `ChannelModel` objects.

### Lines 32–37 — `allAssignmentsProvider` — Provider Dependency

```dart
final allAssignmentsProvider = FutureProvider<List<AssignmentModel>>((ref) async {
  ref.keepAlive();
  final channels = await ref.watch(channelsProvider.future);
  return _assignmentRepo.getAllAssignments(channels.map((c) => c.id).toList());
});
```

**`ref.watch(channelsProvider.future)`** — watches `channelsProvider` AND accesses the underlying `Future` directly. This provider DEPENDS on `channelsProvider`.

**Why `channelsProvider.future`?** — `channelsProvider` returns `AsyncValue<List<ChannelModel>>`. To get the actual list, we access `.future` which returns `Future<List<ChannelModel>>`. Awaiting this waits until channels are loaded.

**`channels.map((c) => c.id).toList()`** — extracts just the ID from each channel:
- `.map((c) => c.id)` — transforms each `ChannelModel` to its `int id`
- `.toList()` — converts the lazy `Iterable<int>` to a `List<int>`

The result is a list of channel IDs passed to `getAllAssignments()`, which fetches assignments for ALL channels in parallel.

### Lines 41–44 — `channelAssignmentsProvider` — Family Provider

```dart
final channelAssignmentsProvider =
    FutureProvider.family<List<AssignmentModel>, int>((ref, channelId) async {
  return _assignmentRepo.getAssignments(channelId);
});
```

**`.family<ReturnType, ArgumentType>`** — creates a "family" of providers, one per unique argument.
- `channelAssignmentsProvider(7)` — a provider for channel 7
- `channelAssignmentsProvider(14)` — a different provider for channel 14

Each has its own state and lifecycle. When `channelId=7` is no longer watched, its provider disposes.

**Used in:**
```dart
ref.watch(channelAssignmentsProvider(channel.id))
```

### Lines 66–75 — `_SelectedChannelNotifier`

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

**`ChannelModel?`** — nullable. `null` means no channel is selected (show empty state on desktop, show channel list on mobile).

**`_SelectedChannelNotifier.new`** — `ClassName.new` is Dart's constructor tearoff. Equivalent to `() => _SelectedChannelNotifier()`. Used as the factory for the provider.

**How it's used:**
```dart
// Read current selection
final selected = ref.watch(selectedChannelProvider);

// Change selection
ref.read(selectedChannelProvider.notifier).select(channelModel);

// Deselect (go back to channel list on mobile)
ref.read(selectedChannelProvider.notifier).select(null);
```

### Lines 105–126 — `dashboardRecentActivityProvider` — Conditional `keepAlive()`

```dart
final dashboardRecentActivityProvider =
    FutureProvider.family<Map<String, dynamic>, bool>((ref, isFaculty) async {
  final api = ApiService();
  try {
    final res = isFaculty
        ? await api.getTeacherRecentActivity()
        : await api.getStudentRecentActivity();
    ...
    ref.keepAlive(); // Only keep alive on SUCCESS
    return result;
  } catch (e) {
    rethrow;
  }
});
```

**`bool isFaculty`** — the family argument. `true` = teacher dashboard, `false` = student dashboard. Avoids importing `authProvider` (circular import prevention).

**`ref.keepAlive()` inside `try`** — brilliant pattern: only cache successful responses. If the fetch fails, the provider remains disposable — calling `ref.invalidate(dashboardRecentActivityProvider(false))` (from a "Retry" button) will re-fetch. If `keepAlive()` were called unconditionally, invalidate wouldn't work.

**`rethrow`** — re-throws the caught exception. The `catch` block only exists to ensure `keepAlive()` isn't called on failure. `rethrow` ensures the error propagates to the `AsyncValue.error` state.

---

## `messages_notifier.dart` — Real-Time Message State

### Lines 7–36 — `MessagesState` Immutable State Object

```dart
class MessagesState {
  final List<ApiMessageModel> messages;
  final bool isLoading;
  final bool hasMore;
  final bool isFetchingMore;
  final String? error;

  const MessagesState({
    this.messages = const [],
    this.isLoading = true,
    this.hasMore = true,
    this.isFetchingMore = false,
    this.error,
  });

  MessagesState copyWith({...}) => MessagesState(
    messages: messages ?? this.messages,
    isLoading: isLoading ?? this.isLoading,
    ...
  );
}
```

**`const MessagesState()`** — `const` constructor: all fields with defaults → compile-time constant. Used as the initial state in `build()`.

**`this.messages = const []`** — `const []` is a compile-time constant empty list. More efficient than `[]` (a new empty list object each time).

**`hasMore = true`** — assume there are more messages until proven otherwise (first fetch result determines reality).

### `copyWith()`

**The immutable update pattern:** Instead of mutating the state object, create a NEW state with one field changed.

```dart
MessagesState copyWith({
  List<ApiMessageModel>? messages,
  bool? isLoading,
  ...
}) => MessagesState(
  messages: messages ?? this.messages,  // use new value OR keep current
  isLoading: isLoading ?? this.isLoading,
  ...
);
```

**`messages ?? this.messages`** — if `messages` parameter is `null` (not provided), keep the existing `this.messages`.

**Usage:**
```dart
state = state.copyWith(isLoading: false); // only changes isLoading, keeps everything else
```

### Lines 40–52 — `MessagesNotifier`

```dart
class MessagesNotifier extends Notifier<MessagesState> {
  MessagesNotifier(this.channelId);
  final int channelId;
  bool _disposed = false;

  @override
  MessagesState build() {
    ref.onDispose(() => _disposed = true);
    Future.microtask(_init);
    return const MessagesState();
  }
}
```

**`MessagesNotifier(this.channelId)`** — the family argument is injected via the constructor. Each channel gets its own `MessagesNotifier` instance.

**`bool _disposed = false`** — tracks whether this notifier has been disposed. The `autoDispose` modifier (line 139) means providers are cleaned up when no widgets watch them. Without this guard, async operations started before disposal could try to set state on a disposed notifier.

**`ref.onDispose(() => _disposed = true)`** — registers a cleanup callback. When this provider is disposed, sets `_disposed = true`.

**`Future.microtask(_init)`** — schedules `_init()` to run asynchronously AFTER `build()` returns. Why? `build()` must return synchronously, but we want to trigger an API fetch. `Future.microtask()` runs in the next event loop iteration — after `build()` has finished and the initial state is set.

**`return const MessagesState()`** — the initial synchronous state (loading=true, empty messages). The widget immediately sees "loading" while `_init()` runs.

### Lines 54–94 — `_init()` — Cache-First Loading

```dart
Future<void> _init() async {
  // 1. Try cache first (instant)
  final prefs = await SharedPreferences.getInstance();
  final cachedStr = prefs.getString('chat_cache_$channelId');
  if (cachedStr != null) {
    final jsonList = jsonDecode(cachedStr);
    cachedMsgs = jsonList.map((e) => ApiMessageModel.fromJson(e)).toList();
    if (_disposed) return;
    state = state.copyWith(messages: cachedMsgs, isLoading: true); // show cache while loading
  }

  // 2. Fetch fresh from API
  try {
    final response = await ApiService().getMessages(channelId, limit: 50);
    final msgs = ...; // parse response
    prefs.setString('chat_cache_$channelId', jsonEncode(msgs.map((m) => m.toJson()).toList()));
    state = state.copyWith(messages: msgs, isLoading: false, hasMore: msgs.length >= 50);
  } catch (e) {
    // 3. If API fails, show cache
    if (cachedMsgs.isNotEmpty) {
      state = state.copyWith(messages: cachedMsgs, isLoading: false);
    } else {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}
```

**Cache-first strategy:**
1. Immediately show cached messages (from last session) while loading
2. Fetch fresh data from API
3. Replace cache with fresh data, update cache
4. If API fails AND cache exists → show stale cache (better than an error screen)
5. If API fails AND no cache → show error

**`'chat_cache_$channelId'`** — the SharedPreferences key. Different for each channel.

**`jsonDecode(cachedStr)`** — converts the stored JSON string to a `List<dynamic>`.

**`if (_disposed) return`** — guard after every `await`. If the user navigated away while the fetch was in progress, `_disposed` is now `true` → don't update state.

**`hasMore: msgs.length >= 50`** — if we received exactly 50 messages, there might be more (the limit). If fewer than 50, we've reached the beginning.

### Lines 110–135 — `loadMore()` — Cursor Pagination

```dart
Future<void> loadMore() async {
  if (!state.hasMore || state.isFetchingMore || state.messages.isEmpty) return;
  state = state.copyWith(isFetchingMore: true);
  final cursorId = state.messages.first.id;  // oldest message in current list
  ...
  state = state.copyWith(
    messages: [...moreMsgs, ...state.messages],  // prepend older messages
    hasMore: moreMsgs.length >= 50,
    isFetchingMore: false,
  );
}
```

**Guard conditions:**
- `!state.hasMore` — no more pages to load
- `state.isFetchingMore` — already fetching (prevents double-fetch)
- `state.messages.isEmpty` — no cursor to use

**`state.messages.first.id`** — the oldest message currently shown (messages are in chronological order — first = oldest). This is the cursor for the previous page.

**`[...moreMsgs, ...state.messages]`** — prepend older messages BEFORE current messages. The scroll view shows chronological order (oldest at top), so older messages go at the beginning of the array.

### Line 138–141 — Provider Declaration

```dart
final messagesNotifierProvider =
    NotifierProvider.autoDispose.family<MessagesNotifier, MessagesState, int>(
  MessagesNotifier.new,
);
```

**`.autoDispose`** — automatically disposes when no widgets watch it. When the user leaves a channel, the messages are cleaned up from memory.

**`.family<MessagesNotifier, MessagesState, int>`** — 3 type parameters:
1. `MessagesNotifier` — the notifier class
2. `MessagesState` — the state type
3. `int` — the family argument type (channel ID)

---

## `task_provider.dart` — Local Task and Navigation State

### `searchQueryProvider`

```dart
final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(() => SearchQueryNotifier());
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String query) => state = query;
}
```

Simple string state — the current search query. Updated on every keystroke in the search bar.

### `filteredTasksProvider` — Derived Provider

```dart
final filteredTasksProvider = Provider<List<TaskModel>>((ref) {
  final tasks = ref.watch(taskProvider);
  final query = ref.watch(searchQueryProvider).toLowerCase();

  if (query.isEmpty) return tasks;

  return tasks.where((task) {
    return task.title.toLowerCase().contains(query) ||
        task.subject.toLowerCase().contains(query) ||
        task.description.toLowerCase().contains(query);
  }).toList();
});
```

**`Provider<T>`** — a synchronous derived provider. Computed from other providers — no async, no `Future`.

**Automatically updates:** When `taskProvider` or `searchQueryProvider` changes, `filteredTasksProvider` recomputes. Widgets watching `filteredTasksProvider` rebuild.

**`.toLowerCase().contains(query)`** — case-insensitive substring search. `'Mobile App'.toLowerCase() = 'mobile app'` → matches query `'mobile'`.

### `navigationProvider`

```dart
class NavigationNotifier extends Notifier<int> {
  @override
  int build() => 0; // Dashboard is first tab
  void navigateTo(int index) => state = index;
}
```

**`int state`** — the currently selected tab/page index. The main dashboard screen uses this to show the corresponding widget.

### `TaskNotifier`

```dart
void updateTaskStatus(String taskId, TaskStatus newStatus) {
  state = [
    for (final task in state)
      if (task.id == taskId) task.copyWith(status: newStatus) else task
  ];
}
```

**Collection for+if pattern** — immutably updates one task's status:
- For each task: if it matches the ID, replace with updated copy; otherwise keep original.
- Creates a new list (immutable update).

---

## Summary Table

| Provider | Type | State Type | Purpose |
|---|---|---|---|
| `channelsProvider` | `FutureProvider` | `AsyncValue<List<ChannelModel>>` | Enrolled channels |
| `allAssignmentsProvider` | `FutureProvider` | `AsyncValue<List<AssignmentModel>>` | All assignments across all channels |
| `channelAssignmentsProvider` | `FutureProvider.family<_, int>` | `AsyncValue<List<AssignmentModel>>` | Assignments for one channel |
| `selectedChannelProvider` | `NotifierProvider` | `ChannelModel?` | Currently open channel |
| `notificationsApiProvider` | `FutureProvider` | `AsyncValue<List<Map>>` | API notifications |
| `messagesNotifierProvider` | `NotifierProvider.autoDispose.family<_, int>` | `MessagesState` | Messages for one channel, paginated |
| `taskProvider` | `NotifierProvider` | `List<TaskModel>` | Personal Kanban tasks |
| `filteredTasksProvider` | `Provider` | `List<TaskModel>` | Search-filtered tasks |
| `navigationProvider` | `NotifierProvider` | `int` | Active page index |
| `searchQueryProvider` | `NotifierProvider` | `String` | Global search text |
