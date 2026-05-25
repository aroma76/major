# Word-by-Word Deep Dive: `backend/controllers/announcementController.js`

> This file handles everything related to **announcements** — the posts teachers make in subject channels (like "Exam next Monday"). It can read all announcements, create new ones (faculty only), and delete them. It also broadcasts real-time updates via Socket.IO and sends notifications to enrolled students.

---

## Before Reading — Key Concepts

### What is a Controller?
A controller is a JavaScript file containing functions that handle HTTP requests. When the Flutter app calls `GET /api/channels/5/announcements`, Express routes that request to `getAnnouncements` in this file.

### What is `req` and `res`?
- `req` (request) — the incoming HTTP request. Contains: URL params, query string, body, headers, logged-in user info
- `res` (response) — the outgoing HTTP response. You call methods on it to send data back

### What is `async/await`?
JavaScript is single-threaded — it can only do one thing at a time. When you talk to a database, it takes time. `async/await` lets JavaScript **pause** at a specific line and do other work while waiting, then resume when the result is ready. Without it, your server would freeze for every user while waiting for any single DB query.

### What is Socket.IO?
A library for **real-time bidirectional communication** between the server and connected clients. When a teacher posts an announcement, instead of every student having to manually refresh, Socket.IO **pushes** the new announcement to all connected students instantly.

---

## The Full File

```js
const pool    = require('../config/db');
const { getIO } = require('./messageController');

const getAnnouncements = async (req, res) => { ... };
const createAnnouncement = async (req, res) => { ... };
const deleteAnnouncement = async (req, res) => { ... };

module.exports = { getAnnouncements, createAnnouncement, deleteAnnouncement };
```

---

## Line 1 — `const pool = require('../config/db');`

**`const`** — declares a constant variable (cannot be reassigned)

**`pool`** — the name we give to what we import. We name it `pool` because that's what `db.js` exports — a PostgreSQL connection pool

**`=`** — assignment operator

**`require('../config/db')`**
- `require` — Node.js built-in function to import a module
- `'../config/db'` — a **relative path** to the file:
  - `..` = go UP one folder (from `controllers/` to `backend/`)
  - `/config/db` = then into `config/db.js`
- Node.js automatically adds `.js` extension
- Returns the `pool` object exported from `db.js`
- Because Node.js caches modules, this is the **same pool** every controller shares

---

## Line 2 — `const { getIO } = require('./messageController');`

**`{ getIO }`** — destructuring: pulls only `getIO` from whatever `messageController.js` exports

**`require('./messageController')`**
- `'./messageController'` — same folder (`controllers/messageController.js`)
- `./` means "same directory as this file"

**`getIO`** — a function from `messageController.js` that returns the Socket.IO server instance (`io`)
- The Socket.IO server lives in `messageController.js` because messages were set up there first
- Other controllers (like this one) call `getIO()` to get that instance and broadcast events
- This is a pattern called **dependency sharing** — the `io` object is created once and shared

---

## Lines 10–18 — `getAnnouncements` function

```js
const getAnnouncements = async (req, res) => {
  const result = await pool.query(
    `SELECT a.*, u.name AS created_by_name, u.role AS creator_role
     FROM announcements a INNER JOIN users u ON a.user_id = u.id
     WHERE a.channel_id = $1 ORDER BY a.created_at DESC`,
    [req.params.id]
  );
  res.json({ success: true, announcements: result.rows });
};
```

### `const getAnnouncements`
- Declares a constant named `getAnnouncements`
- This function will be called by Express whenever a GET request hits `/api/channels/:id/announcements`

### `async`
- Marks the function as **asynchronous**
- Allows `await` to be used inside it
- When the function hits an `await`, it pauses (releases the thread) until the awaited operation finishes

### `(req, res) =>`
- Arrow function with two parameters: `req` and `res`
- `=>` separates parameters from the function body
- Express automatically passes these two objects when routing to this handler

### `await pool.query(...)`
- `await` — pause here and wait for `pool.query()` to finish
- `pool.query()` sends a SQL query to PostgreSQL and returns a Promise
- A **Promise** is an object representing a future value
- `await` unwraps the Promise — instead of getting a Promise, we get the actual result

### The SQL Query (backtick template literal)

```sql
SELECT a.*, u.name AS created_by_name, u.role AS creator_role
FROM announcements a INNER JOIN users u ON a.user_id = u.id
WHERE a.channel_id = $1 ORDER BY a.created_at DESC
```

**Backtick `` ` `` string (template literal)**
- Allows multi-line strings without needing `+` concatenation
- Also allows `${variable}` interpolation (not used here, but that's what it's for)
- Regular strings use `'` or `"` and cannot span multiple lines

**`SELECT a.*`**
- `SELECT` — tell PostgreSQL which columns to return
- `a.*` — the `a` is an alias for the `announcements` table (set by `FROM announcements a`)
- `*` means "all columns from that table" — id, channel_id, user_id, title, content, is_important, created_at

**`u.name AS created_by_name`**
- `u.name` — the `name` column from the `users` table (alias `u`)
- `AS created_by_name` — rename this column in the result to `created_by_name`
- Without `AS`, both tables might have a column called `name` which would be confusing

**`u.role AS creator_role`**
- Same pattern — get the user's role and call it `creator_role` in the result
- This tells the Flutter app if the poster was faculty/admin (to show the right badge)

**`FROM announcements a`**
- `FROM` — which table to query
- `announcements` — the table name in PostgreSQL
- `a` — a short **alias** for this table. Used so we can write `a.*` instead of `announcements.*`

**`INNER JOIN users u ON a.user_id = u.id`**
- `INNER JOIN` — combine rows from two tables where a condition matches
- `users u` — join with the `users` table, alias it as `u`
- `ON a.user_id = u.id` — the join condition: the `user_id` in announcements must match the `id` in users
- Result: each announcement row gets the matching user's name and role added to it
- **INNER JOIN** vs **LEFT JOIN**: INNER JOIN only returns rows where BOTH sides match. If an announcement has a `user_id` that doesn't exist in `users`, it's dropped. LEFT JOIN would still return the announcement (with NULLs for user fields).

**`WHERE a.channel_id = $1`**
- `WHERE` — filter which rows to return
- `a.channel_id = $1` — only return announcements for a specific channel
- `$1` — a **parameterized placeholder**. PostgreSQL replaces `$1` with the first value from the values array `[req.params.id]`
- This is how **SQL injection** is prevented — the value never gets concatenated into the SQL string directly

**`ORDER BY a.created_at DESC`**
- `ORDER BY` — sort the results
- `a.created_at` — sort by the creation timestamp column
- `DESC` — descending order (newest first). `ASC` would be oldest first.

### `[req.params.id]`
- Second argument to `pool.query()` — the values array that replaces `$1`, `$2`, etc.
- `req.params` — parameters from the URL path. For URL `/api/channels/7/announcements`, `req.params.id = '7'`
- `[req.params.id]` — wraps `'7'` in an array. `$1` in the SQL gets replaced with `'7'`

### `result.rows`
- `pool.query()` returns an object with several properties
- `.rows` — array of result rows. Each row is a plain JavaScript object
- Example: `[{ id: 1, title: "Exam Next Week", created_by_name: "Dr. Smith", ... }, ...]`

### `res.json({...})`
- `res` — the response object
- `.json()` — serializes the argument to JSON and sends it as the HTTP response
- Automatically sets `Content-Type: application/json` header
- `{ success: true, announcements: result.rows }` — the response body
  - `success: true` — convention to tell the client the request worked
  - `announcements: result.rows` — the array of announcement objects

---

## Lines 27–79 — `createAnnouncement` function

```js
const createAnnouncement = async (req, res) => {
  const { title, content, is_important = false } = req.body;
  if (!title || !content) {
    return res.status(400).json({ success: false, message: 'title and content required' });
  }
  ...
};
```

### `const { title, content, is_important = false } = req.body;`

**`{ title, content, is_important = false }`** — destructuring `req.body` with a **default value**:
- `title` — pulled from `req.body.title`
- `content` — pulled from `req.body.content`
- `is_important = false` — pulled from `req.body.is_important`, but if it's `undefined` (not sent), defaults to `false`
- The `= false` part is a **default parameter** in destructuring syntax

**`req.body`**
- The JSON body of the POST request sent by Flutter
- Example body: `{ "title": "Exam Monday", "content": "Chapter 3-5", "is_important": true }`
- `express.json()` middleware (in server.js) parses the JSON string into a JS object, making it available as `req.body`

### `if (!title || !content)`

**`if`** — conditional statement. If the condition is true, execute the block.

**`!title`** — the `!` (logical NOT) operator. `!title` is `true` when `title` is **falsy** (undefined, null, empty string `''`, `0`, `false`)

**`||`** — logical OR. The condition is true if EITHER side is true. So: "if title is missing OR content is missing"

**Why check this?** — The database has `NOT NULL` constraints on these columns. If we try to insert without them, PostgreSQL would throw an error. It's better to catch it here and send a clear message.

### `return res.status(400).json({...})`

**`return`** — exits the function immediately. Nothing below this line runs if we return early.

**`res.status(400)`** — sets the HTTP status code to `400 Bad Request`
- `400` means the client sent invalid/incomplete data
- HTTP status codes: 2xx = success, 4xx = client error, 5xx = server error

**`.json({...})`** — chained on `.status()`. Sends the JSON response with the 400 status.

**`{ success: false, message: 'title and content required' }`**
- `success: false` — tells the Flutter app the request failed
- `message: '...'` — human-readable error to show in the UI

---

### Lines 34–38 — The INSERT Query

```js
const result = await pool.query(
  `INSERT INTO announcements (channel_id, user_id, title, content, is_important)
   VALUES ($1,$2,$3,$4,$5) RETURNING *`,
  [req.params.id, req.user.id, title, content, is_important]
);
```

**`INSERT INTO announcements (...) VALUES (...)`**
- `INSERT INTO` — SQL command to add a new row to a table
- `announcements` — the table name
- `(channel_id, user_id, title, content, is_important)` — the columns we're filling
- `VALUES ($1,$2,$3,$4,$5)` — five placeholders, one for each column

**`$1,$2,$3,$4,$5`** mapped to the array:
- `$1` = `req.params.id` — the channel ID from the URL path
- `$2` = `req.user.id` — the logged-in user's ID (set by auth middleware, not from the request body — this prevents spoofing)
- `$3` = `title` — from req.body
- `$4` = `content` — from req.body
- `$5` = `is_important` — from req.body (defaults to `false`)

**`RETURNING *`**
- After inserting, PostgreSQL immediately returns the newly created row
- Without this, you'd have to do a second `SELECT` query to get the new row's `id` and `created_at`
- `*` means return all columns

**`const announcement = result.rows[0]`**
- `result.rows` — array of returned rows
- `[0]` — first (and only) element. We inserted exactly 1 row, so we get 1 row back.
- `announcement` now holds the full row object with the auto-generated `id`, `created_at`, etc.

---

### Lines 42–45 — Fetching Creator Info

```js
const creatorRes = await pool.query(
  'SELECT name, role FROM users WHERE id = $1', [req.user.id]
);
const creator = creatorRes.rows[0] ?? {};
```

**Why a second query?** — The INSERT only returned the announcement row. That row has `user_id` but not `name` or `role`. We need the name and role to include in the real-time Socket.IO event payload.

**`creatorRes.rows[0] ?? {}`**
- `??` — the **nullish coalescing operator** (ES2020)
- Returns the left side if it's NOT `null`/`undefined`, otherwise returns the right side
- If no user was found (`rows[0]` is `undefined`), use `{}` (empty object) as fallback
- This prevents errors when accessing `creator.name` later — instead of crashing, it returns `undefined`
- Different from `||`: `||` also catches `false`, `0`, `''`. `??` only catches `null` and `undefined`

---

### Lines 50–61 — Real-Time Socket.IO Broadcast

```js
try {
  const io = getIO();
  if (io) {
    io.to(`channel_${req.params.id}`).emit('announcement:new', {
      ...announcement,
      created_by_name : creator.name  ?? 'Faculty',
      creator_role    : creator.role  ?? 'faculty',
    });
  }
} catch (err) {
  console.error('[Socket] Failed to emit announcement:new:', err.message);
}
```

**`try { ... } catch (err) { ... }`**
- A **try-catch block** — runs the code in `try`. If any error is thrown, `catch` handles it instead of crashing
- Used here because Socket.IO might not be initialized yet, or `getIO()` might return null

**`const io = getIO()`**
- `getIO()` — a function from `messageController.js`
- Returns the Socket.IO server instance (`io`), or `null` if it hasn't been set up yet

**`if (io)`**
- Only proceeds if `io` is truthy (not null/undefined)
- Defensive check — if Socket.IO isn't running, we skip the broadcast gracefully

**`io.to(`channel_${req.params.id}`)`**
- `io.to('room_name')` — targets a specific Socket.IO **room**
- `` `channel_${req.params.id}` `` — template literal that creates a string like `"channel_7"`
- `${req.params.id}` — the channel ID is embedded in the string using `${}` syntax
- A room is like a group chat — all clients who joined this room receive the event
- Students join `channel_7` when they open that channel in Flutter

**`.emit('announcement:new', {...})`**
- `.emit(eventName, data)` — sends an event to all clients in the targeted room
- `'announcement:new'` — the event name. Flutter listens for this exact name via Socket.IO client
- `{...announcement, created_by_name: ..., creator_role: ...}` — the event payload (data sent to clients)

**`...announcement`**
- The **spread operator** `...` — expands all key-value pairs from the `announcement` object into this new object
- Like copying all properties: `id, channel_id, user_id, title, content, is_important, created_at`

**`created_by_name: creator.name ?? 'Faculty'`**
- Adds the creator's name to the payload (it's not in the announcement table itself)
- `?? 'Faculty'` — if `creator.name` is null/undefined, use the string `'Faculty'` as fallback

---

### Lines 66–76 — Notifications (Fire-and-Forget)

```js
pool.query(`SELECT user_id FROM enrollments WHERE channel_id=$1`, [req.params.id])
  .then(({ rows }) =>
    Promise.all(rows.map(s =>
      pool.query(
        `INSERT INTO notifications (user_id, type, title, message, ref_id, ref_type)
         VALUES ($1,'announcement',$2,$3,$4,'announcement')`,
        [s.user_id, `📢 ${title}`, content.substring(0, 120), announcement.id]
      )
    ))
  )
  .catch(err => console.error('[Notifications] Announcement notify error:', err.message));
```

**Notice: NO `await` here!**
- This is intentional — **fire-and-forget**
- We don't `await` this chain because notification failures should NEVER block the `201` response to the teacher
- The announcement is already created and broadcast. Notifications are best-effort.

**`pool.query(...).then(...).catch(...)`**
- This is **Promise chaining** — the old way (before async/await) of handling async operations
- `.then(callback)` — runs `callback` when the query succeeds
- `.catch(callback)` — runs `callback` if any step in the chain throws an error

**`{ rows }` in `.then(({ rows }) => ...)`**
- Destructures the query result object inside the `.then` callback parameter
- Same as writing `.then(result => { const rows = result.rows; ... })`

**`rows.map(s => pool.query(...))`**
- `rows` — array of enrolled users: `[{ user_id: 1 }, { user_id: 2 }, ...]`
- `.map()` — array method. Transforms each element using a callback. Returns a new array.
- `s => pool.query(...)` — for each enrolled user `s`, run a query to insert a notification
- Result: an array of Promises (one per user)

**`Promise.all([...])`**
- Takes an array of Promises and runs them **in parallel**
- Returns a single Promise that resolves when ALL inner Promises resolve
- Much faster than awaiting each one sequentially

**`content.substring(0, 120)`**
- `substring(start, end)` — extracts a portion of a string
- `0` — start at index 0 (first character)
- `120` — stop at index 120
- Truncates the content to max 120 characters for the notification preview

---

## Line 86–89 — `deleteAnnouncement`

```js
const deleteAnnouncement = async (req, res) => {
  await pool.query('DELETE FROM announcements WHERE id=$1', [req.params.announcementId]);
  res.json({ success: true, message: 'Announcement deleted' });
};
```

**`req.params.announcementId`**
- The URL for deletion is `/api/channels/:id/announcements/:announcementId`
- Express parses the `:announcementId` part and puts it in `req.params.announcementId`
- Example URL: `/api/channels/7/announcements/42` → `req.params.announcementId = '42'`

**No `rowCount` check here** — if the ID doesn't exist, the DELETE just affects 0 rows and the function still responds with `success: true`. This is a minor issue (could return 404 if nothing was deleted) but harmless for this use case.

---

## Line 91 — `module.exports = { getAnnouncements, createAnnouncement, deleteAnnouncement };`

**`module.exports = {...}`**
- Exports an **object** containing three functions
- This is called a **named exports** pattern
- The routes file does: `const { getAnnouncements, createAnnouncement, deleteAnnouncement } = require('./announcementController');`
- Each name in the object becomes importable via destructuring

**Why not `module.exports = getAnnouncements` (single export)?**
- This file has 3 functions, so we export all 3 as an object
- If we exported just one, the others would be inaccessible

---

## Complete Request Flow Example

```
Teacher posts announcement in Flutter app
        │
        │  POST /api/channels/7/announcements
        │  Body: { title: "Exam Monday", content: "Chapter 3-5", is_important: true }
        │  Header: Authorization: Bearer <jwt_token>
        ▼
Express Router → protect middleware (validates JWT, sets req.user)
        │
        ▼
createAnnouncement(req, res)
        │
        ├─ Validate title & content ✅
        │
        ├─ INSERT into announcements table → gets back announcement object with new id
        │
        ├─ SELECT user name & role (for socket payload)
        │
        ├─ io.to('channel_7').emit('announcement:new', {...})
        │       │
        │       └─ All Flutter clients in channel 7 receive event INSTANTLY
        │
        ├─ Fire-and-forget: INSERT notifications for all enrolled students
        │
        └─ res.status(201).json({ success: true, announcement })
                │
                ▼
        Flutter app receives the new announcement
```
