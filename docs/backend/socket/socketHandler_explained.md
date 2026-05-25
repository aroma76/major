# Word-by-Word Deep Dive: `backend/socket/socketHandler.js`

> This file is the **real-time engine** — it sets up all Socket.IO event listeners that enable instant messaging, typing indicators, and direct notifications. Every WebSocket interaction in the app flows through this file. It also handles JWT authentication at the socket level, so the server always knows which user owns which socket connection.

---

## Before Reading — WebSocket vs HTTP

**HTTP (REST API):** Client sends a request → server responds → connection closes. One-directional request/response cycle. To get new data, client must ask again.

**WebSocket (Socket.IO):** Client connects → persistent two-way connection stays open → server can push data to the client at any time without the client asking. Perfect for chat.

Socket.IO builds on top of WebSocket and adds: rooms, automatic reconnection, event names, acknowledgements, and fallback to HTTP long-polling.

### Rooms
A **room** is a named group of socket connections. When you call `socket.join('channel_7')`, that socket is added to the group named `'channel_7'`. Any event emitted to `channel_7` is received by ALL sockets in that room.

---

## Line 4 — `const socketHandler = (io) => {`

**`socketHandler`** — a function exported from this file

**`(io)`** — takes the Socket.IO server instance as parameter. Called once from `server.js`:
```js
socketHandler(io);
```

**Everything inside this function has closure access to `io`** — this is important because the inner `socket.on(...)` event handlers can call `io.to(...)` to emit to rooms.

---

## Line 5 — `const onlineUsers = new Map();`

**`Map`** — a JavaScript built-in data structure for key-value pairs (like an object, but with any type as key and with guaranteed insertion order).

**`new Map()`** — creates an empty Map

**`onlineUsers`** — maps `userId → socketId`
- Key: `userId` (as a string)
- Value: `socket.id` (the unique ID Socket.IO assigns to each connection)

**Purpose:** Allows sending direct messages to a specific user. Without this map, you can only broadcast to rooms. With it, you can look up "what socket ID does user #5 have?" and emit directly to them.

---

## Lines 7–27 — `io.on('connection', async (socket) => {...})`

**`io.on('connection', callback)`** — the master event listener. Fires every time a new client connects.

**`async (socket) =>`** — the callback is async (needs `await` for DB query during auth)

**`socket`** — the individual connection object for THIS client. Each connected Flutter app gets its own `socket`. Properties:
- `socket.id` — a random unique string (e.g., `"aB3xQ9..."`) assigned to this connection
- `socket.handshake` — the initial connection info (headers, auth data, query params)
- `socket.join(room)` — adds this socket to a room
- `socket.on(event, handler)` — listens for events from THIS client
- `socket.emit(event, data)` — sends an event to THIS client only
- `socket.to(room).emit(event, data)` — sends to all in room EXCEPT this client

---

## Lines 11–27 — JWT Authentication on Connect

```js
try {
  const token = socket.handshake.auth?.token;
  if (token) {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const result  = await pool.query(
      'SELECT id, name, role FROM users WHERE id = $1',
      [decoded.id]
    );
    if (result.rows.length) {
      socket.user = result.rows[0];
      onlineUsers.set(String(socket.user.id), socket.id);
    }
  }
} catch (_) {
  console.log('⚠️  Socket: unauthenticated connection');
}
```

### `socket.handshake.auth?.token`

**`socket.handshake`** — the data from the WebSocket handshake (the initial HTTP upgrade request)

**`.auth`** — the `auth` object sent by the Socket.IO client during connection. The Flutter Socket.IO client sends:
```dart
socket = io('https://api.example.com', {
  auth: { token: jwtToken }
});
```

**`?.token`** — optional chaining. If `.auth` is undefined, returns `undefined` instead of crashing.

### Why Authenticate at Socket Level?

HTTP routes are protected by `protect` middleware (JWT in Authorization header). But Socket.IO events don't have HTTP headers after the initial connection. We authenticate ONCE at connection time and store the user on the `socket` object for all subsequent events.

**`socket.user = result.rows[0]`** — attaches the user object to the socket. Persists for the lifetime of the connection. Later events use `socket.user?.id` instead of re-verifying the JWT.

### `onlineUsers.set(String(socket.user.id), socket.id)`

**`String(socket.user.id)`** — converts the integer user ID to a string (Maps work with any key type but consistent typing prevents subtle bugs)

Stores: `{ "5": "aB3xQ9..." }` — user 5 is connected with this socket ID

### `catch (_)` — no auth is okay

An unauthenticated socket connection is allowed (not rejected). The Flutter app might connect before the user logs in. Events that require authentication check `socket.user?.id` and return early if undefined.

---

## Line 30–31 — Channel Membership

```js
socket.on('channel:join',  (channelId) => socket.join(`channel_${channelId}`));
socket.on('channel:leave', (channelId) => socket.leave(`channel_${channelId}`));
```

**`socket.on('channel:join', callback)`** — listens for the `'channel:join'` event from this client

**`(channelId) =>`** — the callback receives whatever data the client sent with the event

**`socket.join('channel_7')`** — adds this socket to the Socket.IO room named `'channel_7'`

When Flutter opens a channel screen, it emits `channel:join` with the channel ID:
```dart
socket.emit('channel:join', '7');
```
Now this socket receives all events emitted to `io.to('channel_7')`.

**`socket.leave('channel_7')`** — removes from the room. Called when Flutter navigates away from the channel.

---

## Lines 34–60 — Real-Time Text Message Sending

```js
socket.on('message:send', async (data) => {
  try {
    const senderId = socket.user?.id;
    if (!senderId) return socket.emit('error', { message: 'Not authenticated' });

    const { channelId, content, parent_id } = data;
    if (!content?.trim()) return;

    const result = await pool.query(
      `INSERT INTO messages (channel_id, sender_id, content, parent_id)
       VALUES ($1, $2, $3, $4)
       RETURNING *,
         (SELECT name        FROM users WHERE id = $2) AS sender_name,
         (SELECT role        FROM users WHERE id = $2) AS sender_role,
         (SELECT avatar_url  FROM users WHERE id = $2) AS sender_avatar,
         (SELECT p.content   FROM messages p WHERE p.id = $4) AS parent_content,
         (SELECT pu.name     FROM messages p JOIN users pu ON p.sender_id = pu.id WHERE p.id = $4) AS parent_sender_name`,
      [channelId, senderId, content.trim(), parent_id || null]
    );

    io.to(`channel_${channelId}`).emit('message:new', result.rows[0]);
  } catch (err) {
    console.error('message:send error:', err.message);
    socket.emit('error', { message: 'Failed to send message' });
  }
});
```

### `const senderId = socket.user?.id;`

**CRITICAL SECURITY:** The sender ID comes from the authenticated socket user — NOT from the client's data object. Without this, a client could send `{ senderId: 1 }` (admin ID) and impersonate the admin. By always using `socket.user.id`, we trust only the server-verified identity.

### `if (!content?.trim()) return;`

**`content?.trim()`** — optional chaining + `trim()` (removes leading/trailing whitespace)
- `'  '?.trim() = ''` — empty string is falsy → `!''` = `true` → return (don't send blank messages)
- `undefined?.trim() = undefined` — falsy → return

### The INSERT with Inline Subqueries

```sql
INSERT INTO messages (channel_id, sender_id, content, parent_id)
VALUES ($1, $2, $3, $4)
RETURNING *,
  (SELECT name FROM users WHERE id = $2) AS sender_name,
  (SELECT role FROM users WHERE id = $2) AS sender_role,
  (SELECT avatar_url FROM users WHERE id = $2) AS sender_avatar,
  (SELECT p.content FROM messages p WHERE p.id = $4) AS parent_content,
  (SELECT pu.name FROM messages p JOIN users pu ON p.sender_id = pu.id WHERE p.id = $4) AS parent_sender_name
```

**`RETURNING *`** — returns all inserted columns. Then ADDITIONAL columns are added via subqueries.

**Subqueries in RETURNING:** PostgreSQL allows including subqueries in `RETURNING` — this is an advanced feature. Each subquery runs against the parameter values (`$2` = senderId, `$4` = parent_id) from the INSERT.

**Why not a JOIN?** — `INSERT ... RETURNING` can't do JOINs directly. Subqueries are the workaround to enrich the returned row with data from other tables.

**`$4` for `parent_id`** — the reply message's ID. If `parent_id = NULL`, the parent subqueries return NULL (replying is optional).

### `io.to('channel_7').emit('message:new', result.rows[0])`

**`io.to(room)`** — targets a specific room (ALL sockets in that room, including the sender)
- Note: `socket.to(room)` would EXCLUDE the sender. `io.to(room)` INCLUDES everyone.
- Here we want the sender to also see the confirmed message in the chat, so `io.to(...)` is correct.

The complete saved message with `sender_name`, `sender_role`, `sender_avatar`, etc. is broadcast so all connected Flutter apps can render it immediately.

---

## Lines 63–68 — Typing Indicators

```js
socket.on('typing:start', ({ channelId, userName }) =>
  socket.to(`channel_${channelId}`).emit('typing:start', { userName })
);
socket.on('typing:stop', ({ channelId }) =>
  socket.to(`channel_${channelId}`).emit('typing:stop')
);
```

**`socket.to(room)`** — emits to everyone in the room EXCEPT the sender. You don't show "You are typing" to yourself.

**`({ channelId, userName })`** — destructuring the event data object in the parameter

**Typing flow:**
1. Flutter: user starts typing → emit `'typing:start'` with channelId and userName
2. Server: forward to all OTHER users in the channel
3. Other Flutter clients: receive `'typing:start'` → show "Alice is typing..."
4. Flutter: user stops typing → emit `'typing:stop'`
5. Server: forward to others → hide typing indicator

---

## Lines 71–74 — Direct User Notifications

```js
socket.on('notification:send', ({ targetUserId, notification }) => {
  const targetSocket = onlineUsers.get(String(targetUserId));
  if (targetSocket) io.to(targetSocket).emit('notification:new', notification);
});
```

**`onlineUsers.get(String(targetUserId))`** — look up which socket ID the target user has
- If user is online: returns their socket ID string
- If user is offline: returns `undefined`

**`io.to(targetSocket).emit('notification:new', notification)`**
- `io.to(socketId)` — when given a socket ID (not a room name), emits to just that one socket
- This sends a notification directly to that specific user only

**If offline:** `if (targetSocket)` — the notification is simply not sent via socket (it's already in the DB from the REST endpoint, so the user will see it next time they load notifications).

---

## Lines 76–81 — Disconnect

```js
socket.on('disconnect', () => {
  if (socket.user) {
    onlineUsers.delete(String(socket.user.id));
    console.log(`🔴 Disconnected: ${socket.user.name}`);
  }
});
```

**`'disconnect'`** — built-in Socket.IO event. Fires when the client disconnects (app closed, network lost, timeout).

**`onlineUsers.delete(userId)`** — removes the user from the online map. They can no longer receive direct socket notifications.

**`if (socket.user)`** — guard: unauthenticated sockets (that failed JWT verification) don't have `socket.user`, so nothing to clean up.

---

## Full Socket Event Map

| Client → Server Event | Server Action | Server → Client Event |
|---|---|---|
| `channel:join` with channelId | `socket.join('channel_N')` | — |
| `channel:leave` with channelId | `socket.leave('channel_N')` | — |
| `message:send` with {channelId, content, parent_id} | INSERT to DB | `message:new` to channel room |
| `typing:start` with {channelId, userName} | Forward | `typing:start` to channel room (excluding sender) |
| `typing:stop` with {channelId} | Forward | `typing:stop` to channel room (excluding sender) |
| `notification:send` with {targetUserId, notification} | Look up socket ID | `notification:new` to target socket |
| `disconnect` (automatic) | Clean up onlineUsers | — |

| REST Event | Socket Broadcast |
|---|---|
| POST /messages (file upload) | `message:new` to channel room (via `_io` in messageController) |
| POST /announcements | `announcement:new` to channel room (via `getIO()` in announcementController) |
