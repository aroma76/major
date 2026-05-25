# 📄 `providers/messages_notifier.dart` — Complete Explanation

**File Path:** `frontend/lib/.../providers/messages_notifier.dart`
**Lines:** 142
**Role:** Riverpod family `Notifier` for per-channel message state — handles initial load, `SharedPreferences` caching, optimistic append/remove, and cursor-based pagination (load-older-messages).

---

## 1. `MessagesState` — Immutable State Object

```dart
class MessagesState {
  final List<ApiMessageModel> messages;
  final bool isLoading;
  final bool hasMore;
  final bool isFetchingMore;
  final String? error;
}
```

**`copyWith`** — Returns a new `MessagesState` with only specified fields changed. This immutable pattern ensures Riverpod detects state changes correctly.

---

## 2. `MessagesNotifier` — Family Notifier

```dart
class MessagesNotifier extends Notifier<MessagesState> {
  MessagesNotifier(this.channelId);
  final int channelId;
  bool _disposed = false;

  @override
  MessagesState build() {
    ref.onDispose(() => _disposed = true);  // Mark disposed
    Future.microtask(_init);                // Async init without blocking build
    return const MessagesState();           // Synchronous empty state
  }
}

final messagesNotifierProvider =
    NotifierProvider.autoDispose.family<MessagesNotifier, MessagesState, int>(
  MessagesNotifier.new,
);
```

**`NotifierProvider.autoDispose.family`** — Three modifiers:
- `autoDispose`: Destroys the notifier when no widget watches it (prevents memory leaks from abandoned channels)
- `family`: Creates a separate instance per `channelId` argument
- The constructor `MessagesNotifier.new` passes `channelId` directly to the constructor (Riverpod v3 family pattern)

**`Future.microtask(_init)`** — Schedules async work after the synchronous `build()` returns. The initial state is empty/loading, then `_init` populates it.

---

## 3. `_init()` — Cache-then-Fetch Pattern

```dart
Future<void> _init() async {
  // Step 1: Load from SharedPreferences cache
  final cachedStr = prefs.getString('chat_cache_$channelId');
  if (cachedStr != null) {
    final cachedMsgs = jsonDecode(cachedStr).map(ApiMessageModel.fromJson);
    state = state.copyWith(messages: cachedMsgs, isLoading: true); // Show cached, still loading
  }

  // Step 2: Fetch from API
  try {
    final msgs = await ApiService().getMessages(channelId, limit: 50);
    prefs.setString('chat_cache_$channelId', jsonEncode(msgs.map((m) => m.toJson())));
    state = state.copyWith(messages: msgs, isLoading: false, hasMore: msgs.length >= 50);
  } catch (e) {
    if (cachedMsgs.isNotEmpty) {
      state = state.copyWith(messages: cachedMsgs, isLoading: false); // Offline fallback
    } else {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}
```

**Two-phase loading:**
1. Shows cached messages instantly (no blank screen on revisit)
2. Fetches fresh from API and updates cache

**Offline support:** If the API fails but cache exists, show cached messages without error.

**`_disposed` guard:** After every `await`, checks `if (_disposed) return` — prevents setting state after the notifier was disposed (would crash the app).

---

## 4. `loadMore()` — Cursor-Based Pagination

```dart
Future<void> loadMore() async {
  if (!state.hasMore || state.isFetchingMore || state.messages.isEmpty) return;
  state = state.copyWith(isFetchingMore: true);
  final cursorId = state.messages.first.id;  // Oldest visible message
  final moreMsgs = await ApiService().getMessages(channelId, cursor: cursorId, limit: 50);
  state = state.copyWith(
    messages: [...moreMsgs, ...state.messages],  // Prepend older messages
    hasMore: moreMsgs.length >= 50,              // Stop if < 50 returned
    isFetchingMore: false,
  );
}
```

**Cursor = first message ID** — The API returns messages **older than** the cursor. `state.messages.first.id` is the oldest visible message.

**Prepend:** `[...moreMsgs, ...state.messages]` — Old messages at the beginning, new at the end.

**Stop condition:** If fewer than 50 are returned, there are no more older messages.

---

## 5. Final Summary

`MessagesNotifier` implements the "stale-while-revalidate" pattern (show cache, then update with fresh data). The `autoDispose.family` pattern ensures each channel has its own isolated state that's cleaned up when not viewed, preventing unbounded memory growth in apps with many channels.

---

# 📄 `providers/saved_files_provider.dart` — Complete Explanation

**File Path:** `frontend/lib/.../providers/saved_files_provider.dart`
**Lines:** 83
**Role:** In-memory Riverpod `NotifierProvider` for files "saved" from chat messages — enables the Notes and Question Papers views.

---

## 1. `SavedFile` — Data Model

```dart
class SavedFile {
  final String id;           // Composite key: '${msgId}_${type.name}'
  final int channelId;
  final String subjectName;
  final String fileName;
  final String fileUrl;
  final SavedFileType type;  // note | questionPaper
  final String sharedBy;     // Sender's name
  final DateTime savedAt;    // Timestamp of save action
}
```

**Composite ID** — `'${msgId}_${type.name}'` means the same file can be saved as both a Note AND a Question Paper independently.

---

## 2. `SavedFilesNotifier`

```dart
class SavedFilesNotifier extends Notifier<List<SavedFile>> {
  @override
  List<SavedFile> build() => [];  // Starts empty
  
  String _key(String msgId, SavedFileType type) => '${msgId}_${type.name}';

  bool isSaved(String msgId, SavedFileType type) =>
      state.any((f) => f.id == _key(msgId, type));

  void save({...}) {
    final key = _key(msgId, type);
    if (isSaved(msgId, type)) return;  // Idempotent — no duplicate saves
    state = [...state, SavedFile(id: key, ...)];
  }

  void remove(String id) => state = state.where((f) => f.id != id).toList();

  Map<String, List<SavedFile>> groupedBySubject(SavedFileType type) {
    final files = byType(type);
    final map = <String, List<SavedFile>>{};
    for (final f in files) {
      map.putIfAbsent(f.subjectName, () => []).add(f);
    }
    return map;
  }
}
```

**Idempotent `save()`** — Checks `isSaved` before adding. The UI can show a "saved" state without worrying about duplicate entries.

**`groupedBySubject()`** — Called by `SubjectFilesView`. Returns a `Map<String, List<SavedFile>>` (subject name → files), which the view renders as collapsible groups.

**Ephemeral state** — No persistence (no `SharedPreferences`, no database). All saved files are lost on app restart. This is an intentional design decision — saves are session-scoped.

---

## 3. `SavedFileType` Enum

```dart
enum SavedFileType { note, questionPaper }
```

Determines which view the file appears in:
- `note` → `NotesViewWidget` (displayed via `SubjectFilesView`)
- `questionPaper` → `QuestionPapersViewWidget` (displayed via `SubjectFilesView`)

---

## 4. Final Summary

`saved_files_provider.dart` is the simplest provider in the project — a pure in-memory list with idempotent save/remove operations. The composite ID design allows the same file to appear in both Notes and Question Papers. The `groupedBySubject` method bridges this provider directly to `SubjectFilesView`.
