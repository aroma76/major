# 📄 `routes/notificationRoutes.js` — Complete Explanation

**File Path:** `backend/routes/notificationRoutes.js`
**Lines:** 13
**Mounted at:** `app.use('/api/notifications', notificationRoutes)`
**Role:** User notification management — read, mark-read, delete.

---

## 1. Full Source Code

```js
const express = require('express');
const router = express.Router();

const { getNotifications, markRead, markAllRead, deleteNotification, getUnreadCount }
  = require('../controllers/notificationController');
const { protect } = require('../middleware/auth');

router.get('/',              protect, getNotifications);
router.get('/unread-count',  protect, getUnreadCount);
router.put('/read-all',      protect, markAllRead);
router.put('/:id/read',      protect, markRead);
router.delete('/:id',        protect, deleteNotification);
```

---

## 2. Route Table

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/notifications` | Fetch all user notifications (paginated) |
| `GET` | `/api/notifications/unread-count` | Count unread notifications (for badge) |
| `PUT` | `/api/notifications/read-all` | Mark all notifications as read |
| `PUT` | `/api/notifications/:id/read` | Mark one notification as read |
| `DELETE` | `/api/notifications/:id` | Delete a notification |

---

## 3. Route Ordering — Static Routes Before Dynamic

```js
router.get('/unread-count', protect, getUnreadCount); // ← static path first ✅
router.put('/read-all',     protect, markAllRead);    // ← static path first ✅
router.put('/:id/read',     protect, markRead);       // ← wildcard after
router.delete('/:id',       protect, deleteNotification); // ← wildcard after
```

**Why order matters:**
If `/:id/read` were defined before `/read-all`, a `PUT /api/notifications/read-all` request would match `/:id/read` with `id = "read-all"`. The controller would try to find a notification with `id = "read-all"` — which doesn't exist, returning a 404.

Express matches routes **top-to-bottom**, stopping at the first match. Static routes (`/unread-count`, `/read-all`) must always be defined **before** dynamic routes (`/:id`).

---

## 4. No Role Restriction — Users See Only Their Own

```js
router.get('/', protect, getNotifications);  // No authorize() — any authenticated user
```

All 5 routes use only `protect` (no `authorize`). The security is enforced inside the controllers:
```js
// Inside notificationController.js
const result = await db.query(
  'SELECT * FROM notifications WHERE user_id = $1', // ← filtered by req.user.id
  [req.user.id]
);
```

Users can only ever see, mark, or delete their **own** notifications. The database WHERE clause ensures isolation.

---

## 5. `/unread-count` — Lightweight Polling Endpoint

```js
router.get('/unread-count', protect, getUnreadCount);
```

Returns a simple `{ count: 3 }` JSON. Used in `NotificationPanel` to show the badge number. This is a lightweight query (just `COUNT(*)`) rather than fetching full notification objects.

---

## 6. `PUT` vs `DELETE` for Read/Delete

- `PUT /read-all` and `PUT /:id/read` — Update the `is_read` field
- `DELETE /:id` — Remove the row entirely

`PUT` is used for mark-as-read instead of `PATCH` — both are semantically correct since `is_read: true` is a full-field update.

---

## 7. Frontend Connection (Flutter)

```dart
// NotificationPanel — initial load
dio.get('/notifications')

// Badge count in TopBarWidget
dio.get('/notifications/unread-count')

// Tap notification → mark as read
dio.put('/notifications/$notificationId/read')

// Mark all read button
dio.put('/notifications/read-all')

// Dismiss notification
dio.delete('/notifications/$notificationId')
```

---

## 8. Final Summary

`notificationRoutes.js` demonstrates the critical route-ordering rule: **static paths before dynamic wildcards**. All routes use only `protect` (no role checks) because user isolation is enforced at the database query level — not the route level. The dedicated `/unread-count` endpoint optimizes the common "show badge" use case with a COUNT-only query.
