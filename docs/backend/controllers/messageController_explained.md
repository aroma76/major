# Word-by-Word Deep Dive: `backend/controllers/messageController.js`

> This file handles all **REST API operations for messages** — loading history (with pagination), sending file-attached messages, pinning, deleting, and getting pinned messages. Text-only messages go through Socket.IO directly (`socketHandler.js`), but file messages must use REST because the file binary needs to be processed by multer first, then the saved message is broadcast via Socket.IO.

---

## Lines 3–9 — The `_io` Module-Level Variable

```js
let _io;

const setIO = (io) => { _io = io; };
```

**`let _io;`** — a module-level variable (not inside any function). It persists between requests.
- `let` — can be reassigned (it starts as `undefined`, gets set by `setIO`)
- `_io` — the `_` prefix is a convention for "private" (not enforced by JS, just a signal)

**`const setIO = (io) => { _io = io; }`** — a function that STORES the Socket.IO instance
- Called once from `server.js`: `setIO(io)`
- After this call, `_io` holds the `io` server object for the lifetime of the process

**`module.exports = { ..., setIO, getIO: () => _io }`** — both `setIO` (setter) and `getIO` (getter) are exported
- `getIO: () => _io` — an arrow function that returns the current value of `_io`
- `announcementController.js` calls `getIO()` to get `_io` and emit socket events

**The pattern:** `_io` acts like a module-level singleton. Node.js caches modules, so every require of `messageController` gets the same `_io`.

---

## Lines 18–41 — `getMessages` — Cursor-Based Pagination

```js
const getMessages = async (req, res) => {
  const { cursor } = req.query;
  const limit = parseInt(req.query.limit) || 50;

  let result;
  const query = `
    SELECT m.*, u.name AS sender_name, u.role AS sender_role, u.avatar_url AS sender_avatar,
           p.content AS parent_content, pu.name AS parent_sender_name
    FROM messages m
    INNER JOIN users u ON m.sender_id = u.id
    LEFT JOIN messages p ON m.parent_id = p.id
    LEFT JOIN users pu ON p.sender_id = pu.id
    WHERE m.channel_id = $1 ${cursor ? 'AND m.id < $2' : ''}
    ORDER BY m.id DESC LIMIT $${cursor ? '3' : '2'}
  `;

  if (cursor) {
    result = await pool.query(query, [req.params.id, cursor, limit]);
  } else {
    result = await pool.query(query, [req.params.id, limit]);
  }

  res.json({ success: true, messages: result.rows.reverse() });
};
```

### `req.query`

**`req.query`** — URL query parameters. For `GET /api/channels/7/messages?cursor=150&limit=30`:
- `req.query.cursor = '150'`
- `req.query.limit = '30'` (always a string)

### Cursor-Based Pagination Explained

**Problem:** A channel might have 10,000 messages. Returning all at once would be slow and waste bandwidth.

**Offset pagination (naive):** `LIMIT 50 OFFSET 100` — skip 100 rows, return next 50. Problem: if new messages arrive while you're paginating, the offset shifts and you might skip or duplicate rows.

**Cursor-based pagination (used here):** Use the message `id` as a stable cursor:
- First request (no cursor): `WHERE channel_id = $1 ORDER BY id DESC LIMIT 50` → get newest 50 messages
- User scrolls up → last visible message has `id = 150` → next request: `WHERE channel_id = $1 AND id < 150 ORDER BY id DESC LIMIT 50` → get 50 messages older than id 150

`id` is a sequential integer — `id < 150` reliably means "older than message 150."

### Dynamic SQL Construction

```js
const query = `
  WHERE m.channel_id = $1 ${cursor ? 'AND m.id < $2' : ''}
  ORDER BY m.id DESC LIMIT $${cursor ? '3' : '2'}
`;
```

**`${cursor ? 'AND m.id < $2' : ''}`** — template literal with ternary:
- With cursor: adds `AND m.id < $2` to the WHERE clause
- Without cursor: adds nothing (empty string)

**`LIMIT $${cursor ? '3' : '2'}`**
- `$${}` — note the DOUBLE dollar sign. The outer `$` is the parameterized placeholder marker, the inner `${}` is template literal interpolation
- With cursor: `LIMIT $3` (limit is the 3rd parameter because `$1=channelId, $2=cursor, $3=limit`)
- Without cursor: `LIMIT $2` (limit is the 2nd parameter: `$1=channelId, $2=limit`)

**Why dynamic SQL?** — We can't write a single query that handles both cases cleanly. This is acceptable because the dynamic part (`'AND m.id < $2'`) is NOT user input — it's our own string. No injection risk. The actual user input (cursor value) is still parameterized as `$2`.

### The JOIN Structure

```sql
FROM messages m
INNER JOIN users u ON m.sender_id = u.id
LEFT JOIN messages p ON m.parent_id = p.id
LEFT JOIN users pu ON p.sender_id = pu.id
```

**Four tables:**
1. `messages m` — the messages themselves
2. `INNER JOIN users u` — the sender (required — every message has a sender)
3. `LEFT JOIN messages p` — the parent message (for replies) — NULL if not a reply
4. `LEFT JOIN users pu` — the parent message's sender — NULL if not a reply

**Result columns include:** `sender_name`, `sender_role`, `sender_avatar`, `parent_content`, `parent_sender_name` — everything Flutter needs to render a message with reply preview.

### `result.rows.reverse()`

**`ORDER BY m.id DESC`** — fetches newest messages first (descending ID). If the user is at the bottom, they want to see new messages first in the API response (so they appear at the bottom of the chat).

**`.reverse()`** — but Flutter renders messages top-to-bottom in chronological order (oldest at top). Reversing the array puts the oldest message first in the batch.

So: DB returns `[msg150, msg149, msg148, ...]` → `.reverse()` → `[msg148, msg149, msg150, ...]` → Flutter renders oldest at top.

---

## Lines 52–89 — `sendMessage` — File Upload + Real-Time Broadcast

```js
const sendMessage = async (req, res) => {
  const { content, parent_id } = req.body;
  const file_url  = req.file?.path         || null;
  const file_name = req.file?.originalname || null;

  if (!content && !file_url)
    return res.status(400).json({...});

  if (content && content.length > 5000)
    return res.status(400).json({...});

  if (parent_id) {
    const parent = await pool.query('SELECT channel_id FROM messages WHERE id = $1', [parent_id]);
    if (!parent.rows.length || String(parent.rows[0].channel_id) !== String(req.params.id))
      return res.status(400).json({ success: false, message: 'Invalid parent message' });
  }

  const result = await pool.query(/* INSERT with subqueries */ ...);
  const saved = result.rows[0];

  if (_io) _io.to(`channel_${req.params.id}`).emit('message:new', saved);

  res.status(201).json({ success: true, message: saved });
};
```

### `if (!content && !file_url)` — Must have at least one

**Both `&&`** — BOTH must be falsy to trigger this error. A message can have:
- Text only
- File only
- Both text and file

### Cross-Channel Reply Validation

```js
if (parent_id) {
  const parent = await pool.query('SELECT channel_id FROM messages WHERE id = $1', [parent_id]);
  if (!parent.rows.length || String(parent.rows[0].channel_id) !== String(req.params.id))
    return res.status(400).json({ success: false, message: 'Invalid parent message' });
}
```

**Why?** — Without this, a user in channel 7 could send `parent_id = 999` (a message in channel 8). The reply would appear in channel 7 but reference a message from channel 8 that other channel-7 users can't see. This validates that the parent message actually belongs to the same channel.

**`String(...) !== String(...)`** — same type-coercion guard as in `assignmentController`

### The INSERT with Subqueries in RETURNING

```sql
INSERT INTO messages (channel_id, sender_id, content, file_url, file_name, parent_id)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING *,
  (SELECT name       FROM users WHERE id=$2) AS sender_name,
  (SELECT role       FROM users WHERE id=$2) AS sender_role,
  (SELECT avatar_url FROM users WHERE id=$2) AS sender_avatar,
  (SELECT p.content  FROM messages p WHERE p.id=$6) AS parent_content,
  (SELECT pu.name    FROM messages p JOIN users pu ON p.sender_id = pu.id WHERE p.id=$6) AS parent_sender_name
```

Same technique as `socketHandler.js`. The `RETURNING *` plus subqueries gives us a fully-enriched message object in ONE query, ready to broadcast.

**`$6` (parent_id) in subqueries:** If `parent_id` is NULL, `WHERE p.id = NULL` matches nothing → subqueries return NULL → `parent_content = null`, `parent_sender_name = null`. Flutter shows no reply preview.

### `if (_io) _io.to(...).emit('message:new', saved);`

**`if (_io)`** — guard. `_io` might be null if called before `setIO()` (extremely unlikely but safe).

**File messages go through REST (not Socket.IO directly) because:**
1. Socket.IO events are limited to small JSON data — can't stream binary files
2. The file needs multer to process it → multer only works in Express middleware
3. After the file is uploaded to Supabase and the URL is obtained, THEN we broadcast

The saved message (with the Supabase file URL) is broadcast in real-time so everyone sees the file attachment appear instantly.

---

## Lines 95–103 — `pinMessage`

```js
const pinMessage = async (req, res) => {
  const result = await pool.query(
    `UPDATE messages SET is_pinned = NOT is_pinned WHERE id=$1 RETURNING *`,
    [req.params.msgId]
  );
  ...
};
```

### `is_pinned = NOT is_pinned`

**`NOT`** — SQL logical negation. This is a **toggle**:
- If `is_pinned = TRUE` → `NOT TRUE = FALSE` (unpin)
- If `is_pinned = FALSE` → `NOT FALSE = TRUE` (pin)

One query handles both pin and unpin. No need to check the current state first.

---

## Lines 110–118 — `deleteMessage` — Role-Based Authorization

```js
const deleteMessage = async (req, res) => {
  const msg = await pool.query('SELECT sender_id FROM messages WHERE id=$1', [req.params.msgId]);
  if (!msg.rows.length)
    return res.status(404).json({...});
  if (msg.rows[0].sender_id !== req.user.id && req.user.role !== 'admin' && req.user.role !== 'faculty')
    return res.status(403).json({...});
  await pool.query('DELETE FROM messages WHERE id=$1', [req.params.msgId]);
  res.json({ success: true, message: 'Deleted' });
};
```

### Authorization Logic

```js
if (msg.rows[0].sender_id !== req.user.id && req.user.role !== 'admin' && req.user.role !== 'faculty')
```

**De Morgan's Law view:** "Block if ALL of: not the sender AND not admin AND not faculty"

Equivalent: "Allow if: IS the sender OR IS admin OR IS faculty"

`&&` (AND) between three conditions with `!==` — ALL three must be true to block.

This means faculty/admin can moderate (delete any message). Students can only delete their own messages.

---

## Line 134 — `module.exports`

```js
module.exports = { getMessages, sendMessage, pinMessage, deleteMessage, getPinnedMessages, setIO, getIO: () => _io };
```

**`getIO: () => _io`** — a getter function. Unlike exporting `_io` directly (which would export its value at time of export), exporting `() => _io` always returns the CURRENT value of `_io` when called.

---

## Summary Table

| Function | Method | URL | Key Feature |
|---|---|---|---|
| `setIO` | — | — | Stores Socket.IO instance for broadcasting |
| `getMessages` | GET | `/api/channels/:id/messages` | Cursor pagination, 4-table JOIN, `.reverse()` |
| `sendMessage` | POST | `/api/channels/:id/messages` | File upload + REST broadcast + cross-channel reply check |
| `pinMessage` | PATCH | `.../:msgId/pin` | Toggle with `NOT is_pinned` |
| `deleteMessage` | DELETE | `.../:msgId` | Role-based: sender OR faculty/admin |
| `getPinnedMessages` | GET | `...messages/pinned` | Filter `is_pinned = TRUE` |

| Pattern | Why |
|---|---|
| Cursor (`id < $2`) instead of OFFSET | Stable pagination without row-skip bugs |
| Dynamic SQL for optional cursor | Cleanly handles with/without cursor case |
| `result.rows.reverse()` | DB returns newest-first; Flutter needs oldest-first |
| `RETURNING * + subqueries` | Enrich INSERT result without extra SELECT |
| `NOT is_pinned` in UPDATE | Single query toggle (no pre-check needed) |
