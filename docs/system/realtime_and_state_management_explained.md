# System Deep Dive: `realtime_and_state_management_explained.md`

> This document explains how the entire app state flows — from real-time socket events to Riverpod providers to widgets. It covers: the socket lifecycle, the provider graph, `FutureProvider` vs `NotifierProvider`, cache strategies, and how a single socket event triggers exactly the right UI update.

---

## Part 1: Real-Time with Socket.IO

### The Socket Lifecycle

```
App Startup (main.dart)
  └─ ApiService().init()  ← Dio configured, interceptors attached

_AuthGate sees authenticated state
  └─ SocketService().connect()  ← FIRST socket connection

      ┌─ socket.io connects to ws://api-server:5000
      ├─ Emits: authenticate { token: "eyJ..." }
      └─ Backend verifies token, adds socket to user's "rooms"

User opens a channel (MessagesViewWidget)
  └─ SocketService().joinChannel(channelId)
      └─ Emits: join_channel { channelId }
      └─ Backend: socket.join(`channel_${channelId}`)

User leaves the channel
  └─ SocketService().leaveChannel(channelId)
      └─ Emits: leave_channel { channelId }
```

### Event Taxonomy

| Event | Direction | Trigger |
|---|---|---|
| `authenticate` | Client → Server | After connect, sends JWT |
| `join_channel` | Client → Server | User opens a channel |
| `leave_channel` | Client → Server | User leaves a channel |
| `send_message` | Client → Server | User sends a message (via socket not REST) |
| `typing_start` / `typing_stop` | Client → Server | User starts/stops typing |
| `new_message` | Server → Client | New message in a joined channel |
| `typing` | Server → Client | Another user is typing |
| `announcement:new` | Server → Client | Teacher posted announcement |

### Singleton Pattern

```dart
class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  late IO.Socket socket;
```

**`static final _instance`** — created exactly once when the class is first used.

**`factory SocketService() => _instance`** — `factory` constructor always returns the SAME instance. `SocketService()` anywhere in the codebase returns the single socket.

**Why singleton?** — WebSocket connections are expensive (TCP handshake, authentication). A singleton ensures only ONE connection exists, shared across all widgets.

---

## Part 2: The Provider Graph

```
authProvider (AsyncNotifier)
    │
    ├─ read by: channelsProvider, dashboardRecentActivityProvider
    ├─ watch by: _AuthGate, SidebarWidget, TopBarWidget, AnnouncementsPanel
    └─ notifier methods: login(), logout(), updateProfile()

channelsProvider (FutureProvider, keepAlive)
    │
    ├─ depends on: nothing (just ApiService)
    ├─ depended on by: allAssignmentsProvider
    └─ watch by: SubjectsViewWidget

allAssignmentsProvider (FutureProvider, keepAlive)
    │
    ├─ depends on: channelsProvider.future
    └─ watch by: TodayOverviewWidget (for progress bars)

channelAssignmentsProvider.family(channelId) (FutureProvider.family)
    │
    ├─ depends on: nothing
    └─ watch by: SubjectHubSheet (per-channel view)

messagesNotifierProvider.family(channelId) (NotifierProvider.autoDispose.family)
    │
    ├─ loads from: SharedPreferences cache + ApiService
    ├─ receives socket events: new_message
    └─ watch by: MessagesViewWidget

navigationProvider (NotifierProvider)
    │
    └─ watch by: MainDashboardScreen, TopBarWidget, SidebarWidget

taskProvider (NotifierProvider)
    │
    └─ derived: filteredTasksProvider (Provider)
    └─ watch by: AssignmentsViewWidget, KanbanBoardWidget, TaskDetailsDialog

searchQueryProvider (NotifierProvider)
    │
    └─ consumed by: filteredTasksProvider, TopBarWidget

selectedChannelProvider (NotifierProvider)
    │
    └─ watch by: MessagesViewWidget

themeModeProvider (NotifierProvider)
    │
    └─ watch by: MyApp → MaterialApp.themeMode

notificationsApiProvider (FutureProvider, keepAlive)
    └─ watch by: NotificationPanel, TopBarWidget (badge count)
```

---

## Part 3: FutureProvider — One-Shot Async Data

**When to use:** Data that is fetched once per session (or on demand via `invalidate`).

```dart
final channelsProvider = FutureProvider<List<ChannelModel>>((ref) async {
  ref.keepAlive();
  return ChannelRepository().getMyChannels();
});
```

**Lifecycle:**
1. First `ref.watch(channelsProvider)` → provider created, returns `AsyncLoading`
2. `getMyChannels()` runs → returns `AsyncData<List<ChannelModel>>`
3. `ref.keepAlive()` called → provider stays alive
4. All subsequent `ref.watch` calls → immediately return `AsyncData` (cached)
5. `ref.invalidate(channelsProvider)` → disposed, re-fetches on next watch

**In widgets:**
```dart
channelsAsync.when(
  loading: () => CircularProgressIndicator(),
  error: (e, _) => ErrorState(retry: () => ref.invalidate(channelsProvider)),
  data: (channels) => ChannelGrid(channels),
)
```

---

## Part 4: NotifierProvider — Mutable State

**When to use:** State that changes in response to user actions (navigation, task creation, theme toggle).

```dart
class NavigationNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void navigateTo(int index) => state = index;
}
```

**Pattern:**
```dart
// Read + subscribe (widget rebuilds on change):
final index = ref.watch(navigationProvider);

// Write (from event handlers, NOT in build):
ref.read(navigationProvider.notifier).navigateTo(2);
```

**Why `ref.read` in handlers?** — `ref.watch` in `onTap` would cause the widget to rebuild on every navigation change (subscribing unnecessarily). `ref.read` only reads ONCE without subscribing.

---

## Part 5: The Real-Time Update Flow

### Scenario: Teacher Posts Announcement

```
[Teacher's Device]
Teacher presses "Post Announcement"
  └─ API call: POST /api/channels/:id/announcements
      └─ backend saves to DB
      └─ backend emits: socket.to(`channel_${channelId}`).emit('announcement:new', data)

[Student's Device — connected to same channel]
SocketService receives 'announcement:new'
  └─ onNewAnnouncement callback fires (registered in AnnouncementsPanel.initState)
      └─ ref.invalidate(dashboardRecentActivityProvider(false))
          └─ provider discards cache
          └─ next ref.watch triggers re-fetch
          └─ AnnouncementsPanel rebuilds with new announcement ✓
```

### Scenario: User Sends a Message

```
[Sender's Device]
User types and presses Send
  └─ SocketService().sendMessage({ channelId, content, ... })
      └─ socket.emit('send_message', data)

[Backend]
Receives 'send_message'
  └─ Saves to DB
  └─ Broadcasts to channel room: io.to(`channel_${id}`).emit('new_message', savedMessage)

[All Devices in channel — including sender]
SocketService receives 'new_message'
  └─ MessagesViewWidget listener: SocketService().onNewMessage(callback)
      └─ ref.read(messagesNotifierProvider(channelId).notifier).append(msg)
          └─ state = state.copyWith(messages: [...state.messages, msg])
          └─ MessagesViewWidget rebuilds → new message appears ✓
          └─ List scrolls to bottom
```

### Scenario: Typing Indicator

```
User starts typing
  └─ TextField.onChanged
      └─ SocketService().startTyping(channelId, userName)
          └─ socket.emit('typing_start', { channelId, userName })

[Other users in channel]
SocketService receives 'typing'
  └─ typingUsersProvider updated (or local state in MessagesViewWidget)
      └─ "Rahul is typing..." banner appears ✓

User stops typing (1.5 second debounce)
  └─ SocketService().stopTyping(channelId)
      └─ socket.emit('typing_stop', { channelId })
          └─ 'typing' event with empty typingUsers
              └─ typing indicator disappears ✓
```

---

## Part 6: Cache Strategies

| Provider | Cache Strategy | Eviction |
|---|---|---|
| `channelsProvider` | `keepAlive()` — session-level | `ref.invalidate` on logout |
| `allAssignmentsProvider` | `keepAlive()` — session-level | `ref.invalidate` on logout |
| `notificationsApiProvider` | `keepAlive()` — session-level | `ref.invalidate` on refresh button |
| `dashboardRecentActivityProvider` | `keepAlive()` on success only | `ref.invalidate` on socket event or error-retry |
| `messagesNotifierProvider` | `autoDispose` — alive only while viewing | Disposed when user leaves channel |
| `channelAssignmentsProvider` | No `keepAlive` — refetches each visit | Disposed after each view |
| `taskProvider` | In-memory only — no persistence | Never (local Kanban state) |

### SharedPreferences Cache (Messages)

```dart
// On load: cache → API
final cachedStr = prefs.getString('chat_cache_$channelId');
if (cachedStr != null) {
  // Show cached messages immediately while API fetches
  state = state.copyWith(messages: cachedMsgs, isLoading: true);
}
// Then: real API data replaces cache
state = state.copyWith(messages: freshMsgs, isLoading: false);

// Save fresh data for next session
prefs.setString('chat_cache_$channelId', jsonEncode(msgs.map((m) => m.toJson()).toList()));
```

**User experience:** Opening a channel previously visited shows messages INSTANTLY (from cache) while fresh data loads in background. No blank loading screen.

---

## Part 7: Preventing Common Mistakes

### 1. Calling `ref.watch` in Event Handlers (Wrong)

```dart
// WRONG — watch in onTap causes subscription in build context:
onTap: () {
  final tasks = ref.watch(taskProvider);  // BAD — causes rebuild subscription
  ...
}

// CORRECT — use ref.read in callbacks:
onTap: () {
  final tasks = ref.read(taskProvider);  // Reads once, no subscription
  ref.read(taskProvider.notifier).removeTask(id);
}
```

### 2. Not Checking `mounted` After `await` (Wrong)

```dart
// WRONG — widget may be disposed between the await and the setState:
Future<void> _load() async {
  await ApiService().getData();
  setState(() { ... });  // might crash if widget disposed
}

// CORRECT:
Future<void> _load() async {
  final data = await ApiService().getData();
  if (!mounted) return;  // guard
  setState(() { ... });
}
```

### 3. Mutating State Directly (Wrong)

```dart
// WRONG — mutating list directly doesn't notify Riverpod:
state.add(newTask);  // BAD

// CORRECT — create new list:
state = [...state, newTask];  // triggers rebuild
```
