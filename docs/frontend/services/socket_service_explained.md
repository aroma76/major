# Word-by-Word Deep Dive: `frontend/lib/core/services/socket_service.dart`

> This file is the **Flutter side of real-time communication**. It wraps the `socket_io_client` package into a clean singleton service, handling connection, room management, event emission, and event listening. Every real-time feature in the app — instant messages, typing indicators, live notifications — uses this service.

---

## Before Reading — WebSocket and Socket.IO Review

**HTTP:** One request → one response → connection closes. The server cannot send data without the client asking.

**WebSocket:** Persistent, bidirectional, low-latency connection. The server CAN push data to the client at any time. Stays open until explicitly closed.

**Socket.IO:** A library built on top of WebSocket that adds:
- **Events** — named signals (`'message:new'`, `'typing:start'`, etc.) instead of raw data
- **Rooms** — groups of connections that receive the same events
- **Automatic reconnection** — if the connection drops, Socket.IO tries to reconnect
- **Fallback** — if WebSocket isn't available, falls back to HTTP long-polling

---

## Lines 6–13 — Singleton Pattern (Same as ApiService)

```dart
class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  final _storage = StorageService();
```

**`io.Socket? _socket`** — the Socket.IO client connection object
- `io.Socket` — the type from the `socket_io_client` package (imported as `io`)
- `?` — nullable. Before `connect()` is called, `_socket` is `null`

**`final _storage = StorageService()`** — gets the singleton StorageService for reading the JWT token

---

## Line 14 — `bool get isConnected`

```dart
bool get isConnected => _socket?.connected ?? false;
```

**`bool get isConnected`** — a **computed property** (getter). No parentheses when accessed: `socketService.isConnected`

**`_socket?.connected`** — optional chaining on `_socket`
- If `_socket` is `null`: returns `null`
- If `_socket` is not null: returns `_socket.connected` (a bool from Socket.IO)

**`?? false`** — nullish coalescing. If the result is `null`, return `false`

Complete logic: "If not yet connected (socket is null), not connected. If socket exists, check its `.connected` property."

---

## Lines 16–42 — `connect()` method

```dart
Future<void> connect() async {
  if (isConnected) return;
  final token = await _storage.read('adtu_token');

  _socket = io.io(
    AppConfig.baseUrl,
    io.OptionBuilder()
        .setTransports(['websocket'])
        .setAuth({'token': token ?? ''})
        .disableAutoConnect()
        .build(),
  );

  _socket!.connect();

  _socket!.onConnect((_) {
    debugPrint('✅ Socket connected: ${_socket!.id}');
  });

  _socket!.onDisconnect((_) {
    debugPrint('❌ Socket disconnected');
  });

  _socket!.onConnectError((data) {
    debugPrint('⚠️ Socket connect error: $data');
  });
}
```

### `if (isConnected) return;`

**Guard clause** — prevents creating a second socket if already connected. Idempotent: calling `connect()` multiple times is safe.

### `final token = await _storage.read('adtu_token');`

Reads the JWT asynchronously. This token is sent during the WebSocket handshake so `socketHandler.js` can authenticate the connection.

### `io.io(url, options)` — Creating the Socket

```dart
_socket = io.io(
  AppConfig.baseUrl,
  io.OptionBuilder()
      .setTransports(['websocket'])
      .setAuth({'token': token ?? ''})
      .disableAutoConnect()
      .build(),
);
```

**`io.io(url, options)`** — creates a Socket.IO client (but doesn't connect yet — see `.disableAutoConnect()`)

**`AppConfig.baseUrl`** — the server URL (without `/api` — Socket.IO connects to the root)
- e.g., `'http://localhost:5000'` or `'https://myapp.onrender.com'`

**`io.OptionBuilder()`** — a builder pattern for Socket.IO options:
- `.setTransports(['websocket'])` — ONLY use WebSocket transport. Without this, Socket.IO first tries HTTP long-polling (fallback), then upgrades to WebSocket — adding a ~100ms delay. Setting `['websocket']` directly goes to WebSocket immediately.
- `.setAuth({'token': token ?? ''})` — sends authentication data in the handshake. The `socketHandler.js` reads this as `socket.handshake.auth.token`.
  - `token ?? ''` — if token is null (not logged in yet), send empty string
- `.disableAutoConnect()` — don't connect immediately when the socket is created. We call `.connect()` explicitly on the next line. This gives us control over WHEN the connection happens.
- `.build()` — returns the completed options `Map<String, dynamic>`

### `_socket!.connect()`

**`!`** — the **null assertion operator** in Dart. We just assigned `_socket`, so we know it's not null. `!` tells Dart "trust me, this is not null."

**`.connect()`** — starts the WebSocket connection to the server.

### Event Listeners for Connection State

```dart
_socket!.onConnect((_) {
  debugPrint('✅ Socket connected: ${_socket!.id}');
});
```

**`_socket!.onConnect(callback)`** — fires when the connection is successfully established

**`(_)`** — the callback receives a parameter (usually empty for connection events) that we ignore with `_`

**`debugPrint`** — like `print()` but only outputs in debug mode. In production (release build), `debugPrint` calls are removed.

**`${_socket!.id}`** — each Socket.IO connection gets a unique ID (e.g., `'aB3xQ9...'`). Printed for debugging.

---

## Lines 44–70 — Emitting Events (Client → Server)

### `joinChannel` and `leaveChannel`

```dart
void joinChannel(int channelId) {
  _socket?.emit('channel:join', channelId);
}
void leaveChannel(int channelId) {
  _socket?.emit('channel:leave', channelId);
}
```

**`_socket?.emit(eventName, data)`** — optional chaining: if `_socket` is null, do nothing

**`'channel:join'`** — the event name. Must match exactly what `socketHandler.js` listens for:
```js
socket.on('channel:join', (channelId) => socket.join(`channel_${channelId}`));
```

**`channelId`** — sent as the event payload. Received by the server as the first argument to the event handler.

### `sendMessage`

```dart
void sendMessage({
  required int channelId,
  required String content,
  int? parentId,
}) {
  _socket?.emit('message:send', {
    'channelId': channelId,
    'content': content,
    if (parentId != null) 'parent_id': parentId,
  });
}
```

**Named parameters** with curly braces `{...}`:
- `required int channelId` — must be provided (Dart null safety)
- `required String content` — must be provided
- `int? parentId` — optional (null if not a reply)

**`if (parentId != null) 'parent_id': parentId`** — collection if inside a Map literal. Only includes `parent_id` when there's a reply.

### `emitTypingStart` and `emitTypingStop`

```dart
void emitTypingStart(int channelId, String userName) {
  _socket?.emit('typing:start', {'channelId': channelId, 'userName': userName});
}
void emitTypingStop(int channelId) {
  _socket?.emit('typing:stop', {'channelId': channelId});
}
```

Called when the user starts/stops typing in the message input field. The server broadcasts these to others in the channel room.

---

## Lines 73–104 — Listening for Events (Server → Client)

### The Pattern: `off` then `on`

```dart
void onNewMessage(void Function(Map<String, dynamic>) callback) {
  _socket?.off('message:new');
  _socket?.on('message:new', (data) => callback(Map<String, dynamic>.from(data)));
}
```

**`void Function(Map<String, dynamic>) callback`** — a function type parameter:
- `void Function(...)` — the callback returns nothing
- `Map<String, dynamic>` — the callback receives a map (the event data)

**`_socket?.off('message:new')`** — removes any existing listener for this event. Prevents stacking duplicate listeners when the widget rebuilds (which would cause the callback to fire multiple times for each message).

**`_socket?.on('message:new', handler)`** — registers a new listener

**`(data) => callback(Map<String, dynamic>.from(data))`**
- `data` — the raw event payload from Socket.IO (comes as `dynamic`)
- `Map<String, dynamic>.from(data)` — creates a properly typed Dart Map from the dynamic data. This is necessary because Socket.IO receives data as `dynamic` and Dart's type system needs an explicit conversion.

### All Event Listeners

| Method | Socket Event | When Fired |
|---|---|---|
| `onNewMessage(callback)` | `'message:new'` | New text or file message arrives |
| `onTypingStart(callback)` | `'typing:start'` | Another user starts typing |
| `onTypingStop(callback)` | `'typing:stop'` | Another user stops typing |
| `onNewNotification(callback)` | `'notification:new'` | Direct notification sent to this user |
| `onNewAnnouncement(callback)` | `'announcement:new'` | Teacher posts an announcement |

### `onTypingStart` callback type

```dart
void onTypingStart(void Function(String userName) callback) {
  _socket?.off('typing:start');
  _socket?.on('typing:start', (data) => callback(data['userName'] ?? ''));
}
```

**`void Function(String userName)`** — callback receives a String (not the full Map). The handler extracts `data['userName']` and passes just the name string.

**`data['userName'] ?? ''`** — fallback to empty string if `userName` is somehow null.

---

## Lines 107–112 — Cleanup

```dart
void off(String event) => _socket?.off(event);

void disconnect() {
  _socket?.disconnect();
  _socket = null;
}
```

**`off(event)`** — remove a specific event listener. Called when widgets are disposed so they stop receiving events they no longer care about.

**`disconnect()`** — gracefully closes the WebSocket connection
- `_socket?.disconnect()` — sends a disconnect signal to the server (triggers `socketHandler.js`'s `'disconnect'` event → removes from `onlineUsers` map)
- `_socket = null` — frees the reference so `isConnected` returns `false`

Called when the user logs out.

---

## Full Event Flow: Sending a Message

```
User types in Flutter text field
      │
      ▼
MessagesViewWidget calls:
  SocketService().sendMessage(channelId: 7, content: 'Hello', parentId: null)
      │
      ▼
_socket?.emit('message:send', { 'channelId': 7, 'content': 'Hello' })
      │  (over WebSocket)
      ▼
socketHandler.js: socket.on('message:send', async (data) => {
  const result = await pool.query('INSERT INTO messages ...');
  io.to('channel_7').emit('message:new', result.rows[0]);
})
      │  (broadcast to ALL sockets in channel_7 room)
      ▼
All Flutter clients in channel 7 receive 'message:new'
  → callback in MessagesViewWidget fires
  → new message appended to UI
```
