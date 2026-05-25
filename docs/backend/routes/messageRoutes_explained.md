# 📄 `routes/messageRoutes.js` — Complete Explanation

**File Path:** `backend/routes/messageRoutes.js`
**Lines:** 14
**Mounted at:** `app.use('/api/channels/:id/messages', messageRoutes)` (nested under channel)
**Role:** Defines all chat message endpoints — fetch history, send (with optional file), pin/unpin, and delete.

---

## 1. File Purpose

`messageRoutes.js` handles channel-scoped messages. Every route path here is relative to a specific channel — e.g., `GET /api/channels/5/messages` fetches messages for channel 5.

---

## 2. Full Source Code

```js
const express = require('express');
const router = express.Router({ mergeParams: true }); // ← inherit :id from parent

const { getMessages, sendMessage, pinMessage, deleteMessage, getPinnedMessages }
  = require('../controllers/messageController');
const { protect, authorize } = require('../middleware/auth');
const upload = require('../middleware/upload');

router.get('/',              protect, getMessages);
router.post('/',             protect, upload.single('file'), sendMessage);
router.get('/pinned',        protect, getPinnedMessages);
router.put('/:msgId/pin',    protect, authorize('admin', 'faculty'), pinMessage);
router.delete('/:msgId',     protect, deleteMessage);
```

---

## 3. `{ mergeParams: true }` — Deep Explanation

```js
const router = express.Router({ mergeParams: true });
```

This router is **nested** under `/api/channels/:id`. Express route params work per-router by default. Without `mergeParams`:
- Inside this router, `req.params` = `{ msgId: '42' }` (only its own params)
- The parent's `:id` (channel ID) is **invisible**

With `mergeParams: true`:
- `req.params` = `{ id: '5', msgId: '42' }` — both channel ID and message ID are accessible

This is critical because `getMessages`, `sendMessage`, and all other handlers need `req.params.id` to know which channel they're operating on.

---

## 4. Route Table

| Method | Path | Middleware | Controller | Purpose |
|---|---|---|---|---|
| `GET` | `/api/channels/:id/messages` | `protect` | `getMessages` | Fetch paginated message history |
| `POST` | `/api/channels/:id/messages` | `protect` + `upload` | `sendMessage` | Send text or file message |
| `GET` | `/api/channels/:id/messages/pinned` | `protect` | `getPinnedMessages` | Get all pinned messages |
| `PUT` | `/api/channels/:id/messages/:msgId/pin` | `protect` + `authorize` | `pinMessage` | Pin/unpin a message (faculty/admin) |
| `DELETE` | `/api/channels/:id/messages/:msgId` | `protect` | `deleteMessage` | Delete a message (own or admin) |

---

## 5. File Upload in `POST /`

```js
router.post('/', protect, upload.single('file'), sendMessage);
```

**Middleware chain:**
1. `protect` — Verify JWT, set `req.user`
2. `upload.single('file')` — If the request body is `multipart/form-data` and contains a `file` field, upload it to Supabase Storage. Sets `req.file` with `{ path: 'https://...supabase.co/...' }`
3. `sendMessage` — Reads `req.body.content` (text) and optionally `req.file.path` (file URL)

**For text-only messages:** `Content-Type: application/json`, no file field → `upload.single` is a no-op, `req.file` is `undefined`. `sendMessage` stores only text.

**For file messages:** `Content-Type: multipart/form-data` with a `file` field → Multer processes the file, `req.file.path` = public Supabase URL. `sendMessage` stores both text and file URL.

---

## 6. Pin Route — Role Restriction

```js
router.put('/:msgId/pin', protect, authorize('admin', 'faculty'), pinMessage);
```

Only faculty and admins can pin/unpin messages. Students cannot pin. This prevents students from pinning their own messages to manipulate the channel's pinned list.

**`authorize('admin', 'faculty')`** checks `req.user.role` (set by `protect`):
```js
const authorize = (...roles) => (req, res, next) => {
  if (!roles.includes(req.user.role)) return res.status(403).json({ message: 'Forbidden' });
  next();
};
```

---

## 7. Delete Route — No Role Restriction (Handled in Controller)

```js
router.delete('/:msgId', protect, deleteMessage);
```

No `authorize()` here — deletion is open to any authenticated user. But the `deleteMessage` controller enforces:
- Students can only delete **their own** messages
- Admins/faculty can delete **any** message

This logic belongs in the controller (not the route) because it requires checking the message's `sender_id` against `req.user.id`.

---

## 8. Route Order — `/pinned` Must Come Before `/:msgId`

```js
router.get('/pinned', protect, getPinnedMessages);  // specific — defined first ✅
router.delete('/:msgId', protect, deleteMessage);   // wildcard — defined after
```

If `/:msgId` were defined first, a `GET /api/channels/5/messages/pinned` request would match with `msgId = "pinned"` — and try to fetch a message with ID "pinned" (which doesn't exist). Defining the specific path first prevents this.

---

## 9. Frontend Connection (Flutter)

```dart
// Fetch messages (with optional cursor for pagination)
dio.get('/channels/$channelId/messages?cursor=$cursorId&limit=50')

// Send text message (Socket.IO used for real-time — this is the REST fallback for files)
dio.post('/channels/$channelId/messages', data: FormData({
  'content': 'Hello',
  'file': MultipartFile.fromBytes(bytes, filename: 'doc.pdf'),
}))

// Get pinned messages
dio.get('/channels/$channelId/messages/pinned')

// Pin a message (faculty only)
dio.put('/channels/$channelId/messages/$msgId/pin')

// Delete a message
dio.delete('/channels/$channelId/messages/$msgId')
```

---

## 10. Final Summary

`messageRoutes.js` is the most technically interesting route file because of `mergeParams: true`. The 5 routes implement CRUD for messages with nuanced access control: file upload middleware on POST, role-restrict on pin, and controller-level ownership checks on delete. The `/pinned` specific route must come before `/:msgId` to avoid wildcard collision.
