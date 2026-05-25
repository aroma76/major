# Word-by-Word Deep Dive: `backend/controllers/notificationController.js`

> This file manages the **notification system** — the bell icon in the Flutter app that shows alerts like "New announcement in CS101" or "Your assignment was graded." It handles fetching, marking as read, and deleting notifications. Every function is simple and short — the complexity is in HOW notifications are created (in other controllers, fire-and-forget style).

---

## The Full File

```js
const pool = require('../config/db');

const getNotifications = async (req, res) => { ... };
const markRead = async (req, res) => { ... };
const markAllRead = async (req, res) => { ... };
const deleteNotification = async (req, res) => { ... };
const getUnreadCount = async (req, res) => { ... };

module.exports = { getNotifications, markRead, markAllRead, deleteNotification, getUnreadCount };
```

---

## Lines 8–14 — `getNotifications`

```js
const getNotifications = async (req, res) => {
  const result = await pool.query(
    `SELECT * FROM notifications WHERE user_id=$1 ORDER BY created_at DESC LIMIT 50`,
    [req.user.id]
  );
  res.json({ success: true, notifications: result.rows });
};
```

### The SQL: `SELECT * FROM notifications WHERE user_id=$1 ORDER BY created_at DESC LIMIT 50`

**`SELECT *`** — returns all columns: `id, user_id, type, title, message, ref_id, ref_type, is_read, created_at`

**`WHERE user_id=$1`** — critical security filter. Users only see THEIR OWN notifications.
- `$1` = `req.user.id` — the ID from the verified JWT
- Even if a user tampers with their request, `req.user.id` always comes from the server-verified JWT — impossible to spoof

**`ORDER BY created_at DESC`** — newest notifications first. `DESC` = descending (largest timestamp = most recent = first).

**`LIMIT 50`** — return at most 50 rows
- Without LIMIT, if a user has 5000 notifications (months of activity), the query returns 5000 rows — wasting bandwidth and memory
- 50 is enough to show in the notification panel without pagination
- A production app might implement cursor-based pagination here

---

## Lines 21–27 — `markRead`

```js
const markRead = async (req, res) => {
  await pool.query(
    'UPDATE notifications SET is_read=TRUE WHERE id=$1 AND user_id=$2',
    [req.params.id, req.user.id]
  );
  res.json({ success: true });
};
```

### `UPDATE notifications SET is_read=TRUE`

**`UPDATE`** — SQL command to modify existing rows (no INSERT, no DELETE — just change a value)

**`SET is_read=TRUE`** — sets the `is_read` column to `TRUE` (PostgreSQL boolean literal)

### `WHERE id=$1 AND user_id=$2`

**Two conditions with AND** — this is a security pattern:
- `id=$1` — identifies the specific notification
- `AND user_id=$2` — ensures the notification belongs to the requesting user

**Why the `user_id` check?** — Without it, a user could send `PATCH /api/notifications/999/read` to mark notification #999 as read — even if it belongs to another user. Adding `AND user_id=$2` means the UPDATE only affects rows where BOTH the notification ID matches AND the user owns it. If a user tries to mark someone else's notification, the WHERE clause matches 0 rows — the UPDATE silently does nothing (not an error, but also not a problem).

### `req.params.id`

**`req.params`** — URL path parameters. For `PATCH /api/notifications/42/read`:
- `req.params.id = '42'`

### No rowCount check

If the notification didn't exist or didn't belong to the user, `rowCount = 0` and we still respond `{ success: true }`. This is intentional — marking a non-existent notification as read is harmless.

---

## Lines 34–40 — `markAllRead`

```js
const markAllRead = async (req, res) => {
  await pool.query(
    'UPDATE notifications SET is_read=TRUE WHERE user_id=$1',
    [req.user.id]
  );
  res.json({ success: true });
};
```

### Difference from `markRead`

- `markRead`: marks ONE specific notification (by ID)
- `markAllRead`: marks ALL unread notifications for the user

### `WHERE user_id=$1`

No `id` filter here — updates ALL rows belonging to this user. The `AND is_read=FALSE` filter isn't strictly necessary (setting TRUE where already TRUE does nothing harmful), but could be added as an optimization.

**What happens internally in PostgreSQL:**
- Locks the matching rows
- Changes `is_read` from `FALSE` to `TRUE` on all of them
- Commits

The Flutter "Mark all as read" button calls this endpoint.

---

## Lines 47–53 — `deleteNotification`

```js
const deleteNotification = async (req, res) => {
  await pool.query(
    'DELETE FROM notifications WHERE id=$1 AND user_id=$2',
    [req.params.id, req.user.id]
  );
  res.json({ success: true });
};
```

### `DELETE FROM notifications WHERE id=$1 AND user_id=$2`

Same security pattern as `markRead` — the `AND user_id=$2` prevents users from deleting others' notifications. A user can only delete notifications they own.

**`req.params.id`** — the notification ID from `DELETE /api/notifications/42`

---

## Lines 60–66 — `getUnreadCount`

```js
const getUnreadCount = async (req, res) => {
  const result = await pool.query(
    `SELECT COUNT(*) FROM notifications WHERE user_id=$1 AND is_read=FALSE`,
    [req.user.id]
  );
  res.json({ success: true, count: parseInt(result.rows[0].count) });
};
```

### `SELECT COUNT(*) FROM notifications WHERE user_id=$1 AND is_read=FALSE`

**`COUNT(*)`** — an SQL **aggregate function** that counts the number of rows matching the WHERE clause
- Returns a single row with a single column also called `count`
- Example result: `[{ count: '7' }]` (always a string from PostgreSQL)

**`AND is_read=FALSE`** — only count unread notifications

### `result.rows[0].count`

**`result.rows`** — always returns an array, even for aggregate queries
- For `SELECT COUNT(*)`, the array always has exactly 1 element: `[{ count: '7' }]`
- `result.rows[0]` — the first (and only) row
- `.count` — the count value as a string: `'7'`

### `parseInt(result.rows[0].count)`

**`parseInt(string)`** — JavaScript built-in function that converts a string to an integer
- `parseInt('7')` → `7`
- `parseInt('0')` → `0`
- `parseInt('abc')` → `NaN`
- **Why is it a string from PostgreSQL?** — PostgreSQL's `COUNT(*)` returns a `bigint` type. The `pg` driver converts bigint to a JavaScript string to avoid precision loss (JavaScript's `number` type can't represent very large integers precisely). For counts up to millions, `parseInt` is safe.

**What this is used for:** The Flutter app calls this to show the unread count badge on the notification bell icon:
```
🔔 7
```

---

## Security Pattern Summary

Every function in this controller uses `req.user.id` as a filter:

| Function | Security Filter | Effect |
|---|---|---|
| `getNotifications` | `WHERE user_id=$1` | Only see your own notifications |
| `markRead` | `WHERE id=$1 AND user_id=$2` | Only mark your own notifications |
| `markAllRead` | `WHERE user_id=$1` | Only mark all of your own |
| `deleteNotification` | `WHERE id=$1 AND user_id=$2` | Only delete your own |
| `getUnreadCount` | `WHERE user_id=$1 AND is_read=FALSE` | Only count your own unread |

This is called **row-level security** implemented in application code. A user physically cannot access another user's notifications.

---

## Where Notifications Are Created

This controller only READS and MANAGES notifications. They are CREATED elsewhere:

| Event | Created in |
|---|---|
| New announcement | `announcementController.js` (fire-and-forget) |
| New assignment | `assignmentController.js` (fire-and-forget) |
| Assignment graded | `submissionController.js` |
| New message mention | `messageController.js` |

The creation pattern:
```js
pool.query(
  `INSERT INTO notifications (user_id, type, title, message, ref_id, ref_type)
   VALUES ($1, $2, $3, $4, $5, $6)`,
  [userId, 'announcement', '📢 Exam Monday', 'Chapter 3-5', announcementId, 'announcement']
)
  .then(...)
  .catch(err => console.error(...)); // fire-and-forget
```

---

## Summary Table

| Function | Method | URL | SQL Operation |
|---|---|---|---|
| `getNotifications` | GET | `/api/notifications` | SELECT with LIMIT 50 |
| `markRead` | PATCH | `/api/notifications/:id/read` | UPDATE one row |
| `markAllRead` | PATCH | `/api/notifications/read-all` | UPDATE all rows |
| `deleteNotification` | DELETE | `/api/notifications/:id` | DELETE one row |
| `getUnreadCount` | GET | `/api/notifications/unread-count` | SELECT COUNT(*) |
