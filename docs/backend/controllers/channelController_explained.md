# Word-by-Word Deep Dive: `backend/controllers/channelController.js`

> This file manages **channels** — the subject rooms that are the core organizing structure of the app. Every message, announcement, assignment, and note belongs to a channel. This controller handles listing, creating, updating, deleting channels, and fetching their members. The most interesting part is how the same `getChannels` endpoint returns different data depending on the user's role.

---

## Before Reading — What is a Channel?

A channel is a subject classroom in the app. For example:
- "CS301 - Data Structures" taught by Dr. Smith to Batch 2022 Semester 3

The `channels` table stores: `id, batch_id, semester_number, subject_name, subject_slug, channel_name, teacher_id`

Related tables (JOINed in queries):
- `users` — to get the teacher's name
- `batches` — to get the batch's `programme_id`
- `programmes` — to get the programme's name
- `enrollments` — to filter channels a student is enrolled in

---

## Lines 11–46 — `getChannels` — Role-Based Data Access

```js
const getChannels = async (req, res) => {
  let result;
  if (req.user.role === 'admin') {
    result = await pool.query(`SELECT c.*, ...`);
  } else if (req.user.role === 'faculty') {
    result = await pool.query(`SELECT c.*, ... WHERE c.teacher_id = $1`, [req.user.id]);
  } else {
    result = await pool.query(`SELECT c.*, ... INNER JOIN enrollments e ... WHERE e.user_id = $1`, [req.user.id]);
  }
  res.json({ success: true, channels: result.rows });
};
```

### `let result;`

**`let`** not `const` — because `result` is assigned inside different `if/else` branches. `const` requires assignment at declaration; `let` allows assigning later.

### Three Different Queries for Three Roles

**Admin path:**
```sql
SELECT c.*, u.name AS teacher_name, p.name AS programme_name
FROM channels c
LEFT JOIN users u ON c.teacher_id = u.id
LEFT JOIN batches b ON c.batch_id = b.id
LEFT JOIN programmes p ON b.programme_id = p.id
ORDER BY c.subject_name
```
No `WHERE` clause — admins see ALL channels in the system.

**Faculty path:**
```sql
... WHERE c.teacher_id = $1 ORDER BY c.subject_name
```
`$1 = req.user.id` — only channels where THIS teacher is assigned.

**Student path (the `else` branch):**
```sql
... INNER JOIN enrollments e ON e.channel_id = c.id WHERE e.user_id = $1
```
Adds an `INNER JOIN enrollments` — only channels this student is enrolled in.

---

### The JOIN Chain Explained (all three paths share this)

```sql
FROM channels c
LEFT JOIN users u ON c.teacher_id = u.id
LEFT JOIN batches b ON c.batch_id = b.id
LEFT JOIN programmes p ON b.programme_id = p.id
```

**`c`** — alias for `channels` table

**`LEFT JOIN users u ON c.teacher_id = u.id`**
- `c.teacher_id` — the ID of the teacher assigned to this channel
- Match it to `users.id` to get their name
- **LEFT JOIN** (not INNER JOIN) — if a channel has no teacher assigned (`teacher_id = NULL`), it still appears in results. With INNER JOIN, un-assigned channels would be excluded.
- Result column: `u.name AS teacher_name`

**`LEFT JOIN batches b ON c.batch_id = b.id`**
- `batches` stores student batches (e.g., "2022 batch")
- `c.batch_id` links a channel to its batch
- **LEFT JOIN** — a channel might not have a batch assigned

**`LEFT JOIN programmes p ON b.programme_id = p.id`**
- `programmes` stores degree programmes (e.g., "B.Tech Computer Science")
- `b.programme_id` links the batch to its programme
- Chained LEFT JOIN — go from batch → programme
- Result column: `p.name AS programme_name`

**Why three JOINs to get programme_name?**
- `channels` doesn't directly have `programme_id`
- The chain is: `channel.batch_id` → `batch.programme_id` → `programme.name`

**`ORDER BY c.subject_name`**
- Alphabetical ordering so the UI shows subjects in a consistent order

---

## Lines 53–65 — `getChannel` (Single Channel)

```js
const getChannel = async (req, res) => {
  const result = await pool.query(
    `SELECT c.*, u.name AS teacher_name, p.name AS programme_name
     FROM channels c
     LEFT JOIN users u ON c.teacher_id = u.id
     LEFT JOIN batches b ON c.batch_id = b.id
     LEFT JOIN programmes p ON b.programme_id = p.id
     WHERE c.id = $1`,
    [req.params.id]
  );
  if (!result.rows.length) return res.status(404).json({ success: false, message: 'Channel not found' });
  res.json({ success: true, channel: result.rows[0] });
};
```

Same JOIN structure as `getChannels` but filtered to `WHERE c.id = $1` (one specific channel).

**`if (!result.rows.length)`** — if no rows returned, the channel ID doesn't exist → 404 Not Found.

**`result.rows[0]`** — since we query by `id` (unique), at most one row. Take the first (and only) element.

---

## Lines 73–85 — `createChannel`

```js
const createChannel = async (req, res) => {
  const { batch_id, semester_number, subject_name, subject_slug, channel_name, teacher_id } = req.body;

  if (!batch_id || !semester_number || !subject_name || !subject_slug || !channel_name)
    return res.status(400).json({ success: false, message: 'Missing required channel information' });

  const result = await pool.query(
    `INSERT INTO channels (batch_id, semester_number, subject_name, subject_slug, channel_name, teacher_id)
     VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
    [batch_id, semester_number, subject_name, subject_slug, channel_name, teacher_id || null]
  );
  res.status(201).json({ success: true, channel: result.rows[0] });
};
```

### `teacher_id || null`

`teacher_id` is optional — a channel can be created without a teacher assigned yet. `|| null` ensures that if `teacher_id` is `undefined` or `0` or empty, PostgreSQL stores `NULL` (not an empty string or 0 which would be a foreign key violation).

### Validation: 5 required fields

`teacher_id` is NOT in the validation check — it's optional. All 5 others are required to define a valid channel.

---

## Lines 93–101 — `updateChannel`

```js
const updateChannel = async (req, res) => {
  const { subject_name, subject_slug, channel_name, teacher_id } = req.body;
  const result = await pool.query(
    `UPDATE channels SET subject_name=$1, subject_slug=$2, channel_name=$3, teacher_id=$4 WHERE id=$5 RETURNING *`,
    [subject_name, subject_slug, channel_name, teacher_id, req.params.id]
  );
  if (!result.rows.length) return res.status(404).json({ success: false, message: 'Channel not found' });
  res.json({ success: true, channel: result.rows[0] });
};
```

**Unlike `academicEventController.updateAcademicEvent`, this does NOT use `COALESCE`** — it requires the full set of fields to be sent. This is a **full replacement** PUT (not a partial PATCH). The caller must send all four fields even if only one changed.

**`WHERE id=$5 RETURNING *`** — the 5th placeholder (`$5`) is `req.params.id` (from the URL `/api/channels/7`). `RETURNING *` gives back the updated row.

---

## Lines 107–110 — `deleteChannel`

```js
const deleteChannel = async (req, res) => {
  await pool.query('DELETE FROM channels WHERE id=$1', [req.params.id]);
  res.json({ success: true, message: 'Channel deleted' });
};
```

**No `rowCount` check** — deleting a non-existent channel ID silently succeeds. For an admin operation, this is acceptable (idempotent).

**Cascading deletes** — the database schema uses `ON DELETE CASCADE` on foreign keys. When a channel is deleted, PostgreSQL automatically deletes:
- All messages in that channel
- All assignments, notes, announcements
- All enrollments
- All submissions for assignments in that channel

One `DELETE FROM channels WHERE id=$1` triggers all of this at the database level.

---

## Lines 117–126 — `getChannelMembers`

```js
const getChannelMembers = async (req, res) => {
  const result = await pool.query(
    `SELECT u.id, u.name, u.email, u.role, u.roll_number, u.avatar_initials, u.avatar_url
     FROM users u
     INNER JOIN enrollments e ON e.user_id = u.id
     WHERE e.channel_id = $1 ORDER BY u.role, u.name`,
    [req.params.id]
  );
  res.json({ success: true, members: result.rows });
};
```

### `SELECT u.id, u.name, u.email, ...`

Explicit column list (not `u.*`) — excludes `password` (security) and other irrelevant internal fields. Only fields the Flutter UI needs for the member list.

### `INNER JOIN enrollments e ON e.user_id = u.id`

Joins in reverse from `getChannels` — starts from `users`, joins `enrollments` where `users.id = enrollments.user_id`, then filters by `channel_id`.

### `ORDER BY u.role, u.name`

**Multi-column ORDER BY** — sorts by two columns:
1. First by `role` alphabetically: `admin` → `faculty` → `student` (alphabetically, a < f < s)
2. Within the same role, sort by `name` alphabetically

This puts faculty and admins at the top of the members list.

---

## Summary Table

| Function | Method | URL | Access | Key Feature |
|---|---|---|---|---|
| `getChannels` | GET | `/api/channels` | All roles | Returns different data per role (admin/faculty/student) |
| `getChannel` | GET | `/api/channels/:id` | All roles | Single channel with full JOIN data |
| `createChannel` | POST | `/api/channels` | Admin only | Creates with optional teacher assignment |
| `updateChannel` | PUT | `/api/channels/:id` | Admin only | Full replacement (no COALESCE) |
| `deleteChannel` | DELETE | `/api/channels/:id` | Admin only | Cascades to all related data |
| `getChannelMembers` | GET | `/api/channels/:id/members` | All roles | Lists enrolled users, faculty first |

| SQL Pattern | Used In | Why |
|---|---|---|
| `LEFT JOIN` | All SELECT queries | Don't exclude channels with no teacher/batch |
| `INNER JOIN enrollments` | Student's `getChannels`, `getChannelMembers` | Only enrolled channels / members |
| Chain of JOINs (channels→batches→programmes) | All SELECT queries | Navigate foreign key relationships |
| `ORDER BY u.role, u.name` | `getChannelMembers` | Multi-sort: role priority then alpha |
