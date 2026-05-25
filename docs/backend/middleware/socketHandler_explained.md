# 📄 `socket/socketHandler.js` — Complete Explanation

**File Path:** `backend/socket/socketHandler.js`
**Lines:** 86
**Role:** Manages all WebSocket (Socket.IO) event handlers for real-time messaging, notifications, and presence.

---

## 1. File Purpose

This file contains all the **real-time communication logic** for the application. It handles:
- Authenticating WebSocket connections via JWT
- Managing channel "rooms" (join/leave)
- Persisting and broadcasting text messages
- Typing indicator broadcasts
- Direct user-to-user notifications
- Online user presence tracking

> **Beginner Analogy:** Socket.IO is like a walkie-talkie system. The `socketHandler` is the base station operator — it connects to each walkie-talkie (client), puts them in the right group channel, and relays messages between them in real time.

---

## 2. Imports

```js
const pool = require('../config/db');
const jwt   = require('jsonwebtoken');
```

---

## 3. Main Structure

```js
const socketHandler = (io) => {
  const onlineUsers = new Map(); // userId -> socketId

  io.on('connection', async (socket) => {
    // ... all event handlers
  });
};

module.exports = socketHandler;
```

- `io` — The Socket.IO server instance (injected from `server.js`).
- `onlineUsers` — An in-memory `Map` tracking which users are currently connected. Key: userId (string), Value: socket ID.
- `io.on('connection', ...)` — Fires for every new WebSocket connection.

> **Note:** `onlineUsers` is stored in JavaScript memory. It resets on server restart. In a multi-server setup, this would need Redis.

---

## 4. Authentication at Connection — Line-by-Line

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
      console.log(`✅ Auth: ${socket.user.name} (${socket.user.role})`);
    }
  }
} catch (_) {
  console.log('⚠️  Socket: unauthenticated connection');
}
```

- `socket.handshake.auth?.token` — The Flutter client sends the JWT in the Socket.IO handshake auth object.
- `jwt.verify(token, JWT_SECRET)` — Verifies the token (same as HTTP middleware).
- DB query — Fetches current user data to get the absolute latest name/role.
- `socket.user = result.rows[0]` — Attaches user data to the socket object. Available in all subsequent event handlers.
- `onlineUsers.set(...)` — Records this user's socket ID for direct messaging.
- The entire block is in `try/catch` — unauthenticated connections are **allowed** (for public features), just without `socket.user`.

---

## 5. Channel Room Management

```js
socket.on('channel:join',  (channelId) => socket.join(`channel_${channelId}`));
socket.on('channel:leave', (channelId) => socket.leave(`channel_${channelId}`));
```

- When Flutter opens the Messages view for channel 42, it emits `channel:join` with `42`.
- Socket.IO's `join()` adds this socket to the room `"channel_42"`.
- Broadcasting to `channel_42` room will reach ALL sockets in that room.
- When navigating away, `channel:leave` removes the socket from the room.

---

## 6. Text Message Handler — Line-by-Line

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
         (SELECT name FROM users WHERE id = $2) AS sender_name,
         ...`,
      [channelId, senderId, content.trim(), parent_id || null]
    );

    io.to(`channel_${channelId}`).emit('message:new', result.rows[0]);
  } catch (err) {
    socket.emit('error', { message: 'Failed to send message' });
  }
});
```

**Key security detail:**
```js
const senderId = socket.user?.id;  // from verified JWT — NOT from client data
```
The sender ID always comes from the authenticated socket user, never from the `data` object sent by the client. This prevents spoofing (a client can't claim to be another user).

**The INSERT query** also uses subqueries in `RETURNING *` to fetch `sender_name`, `sender_role`, `sender_avatar`, `parent_content`, and `parent_sender_name` in a single round-trip, so the emitted `message:new` event has everything the UI needs.

---

## 7. Typing Indicators

```js
socket.on('typing:start', ({ channelId, userName }) =>
  socket.to(`channel_${channelId}`).emit('typing:start', { userName })
);
socket.on('typing:stop', ({ channelId }) =>
  socket.to(`channel_${channelId}`).emit('typing:stop')
);
```

- `socket.to(room)` — Broadcasts to all sockets in the room **except** the sender.
- The client emits `typing:start` when the user starts typing; all other channel members see "X is typing...".
- `typing:stop` clears the indicator.

---

## 8. Direct Notifications

```js
socket.on('notification:send', ({ targetUserId, notification }) => {
  const targetSocket = onlineUsers.get(String(targetUserId));
  if (targetSocket) io.to(targetSocket).emit('notification:new', notification);
});
```

- Looks up the target user's socket ID from `onlineUsers` Map.
- If they're online, sends the notification directly to their socket.
- If offline, no action (they'll see it next time via the REST notifications endpoint).

---

## 9. Disconnect Handler

```js
socket.on('disconnect', () => {
  if (socket.user) {
    onlineUsers.delete(String(socket.user.id));
  }
});
```

Cleans up the `onlineUsers` Map when a connection closes.

---

## 10. Final Summary

`socketHandler.js` implements the entire real-time layer. The security model is sound: all actions use server-verified identity (`socket.user.id`). The `onlineUsers` Map enables direct messaging but won't survive server restarts or horizontal scaling — acceptable for a single-server deployment but would need Redis Pub/Sub for scale.
