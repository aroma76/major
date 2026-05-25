# Word-by-Word Deep Dive: `backend/controllers/enrollmentController.js`

> This file manages **enrollments** — the relationship between users and channels (subjects). When a student joins a subject, a row is added to the `enrollments` table. This file handles: join one channel, leave a channel, get your channels, and bulk-enroll an entire class.

---

## The Full File

```js
const pool = require('../config/db');

const enroll = async (req, res) => { ... };
const unenroll = async (req, res) => { ... };
const getMyEnrollments = async (req, res) => { ... };
const bulkEnroll = async (req, res) => { ... };

module.exports = { enroll, unenroll, getMyEnrollments, bulkEnroll };
```

---

## Lines 10–25 — `enroll` function

```js
const enroll = async (req, res) => {
  const { user_id, channel_id } = req.body;
  if (!user_id || !channel_id)
    return res.status(400).json({ success: false, message: 'user_id and channel_id required' });
  try {
    const result = await pool.query(
      `INSERT INTO enrollments (user_id, channel_id) VALUES ($1, $2) RETURNING *`,
      [user_id, channel_id]
    );
    res.status(201).json({ success: true, enrollment: result.rows[0] });
  } catch (err) {
    if (err.code === '23505') return res.status(400).json({ success: false, message: 'Already enrolled' });
    throw err;
  }
};
```

### `const { user_id, channel_id } = req.body;`

Both IDs come from the request body. The admin/teacher sends:
```json
{ "user_id": 5, "channel_id": 3 }
```

### `if (!user_id || !channel_id)` — Validation Guard

If either is missing (undefined, 0, null), return 400 immediately. Both are required for an enrollment record.

### The INSERT with `try/catch` for Duplicate Detection

```js
try {
  const result = await pool.query(
    `INSERT INTO enrollments (user_id, channel_id) VALUES ($1, $2) RETURNING *`,
    [user_id, channel_id]
  );
  res.status(201).json({ success: true, enrollment: result.rows[0] });
} catch (err) {
  if (err.code === '23505') return res.status(400).json({ success: false, message: 'Already enrolled' });
  throw err;
}
```

**Why use `try/catch` instead of checking for duplicates with a SELECT first?**

Two options:
1. **SELECT then INSERT** (check-then-act): `SELECT COUNT(*) ... WHERE user_id=$1 AND channel_id=$2` → if 0, then INSERT
2. **INSERT and catch the error** (ask-forgiveness): INSERT directly, catch the constraint violation

Option 2 is better because:
- **Race condition**: between your SELECT and INSERT, another request might INSERT the same row → both succeed → duplicate
- **Performance**: one DB round-trip instead of two
- PostgreSQL's unique constraint is the authoritative check

**`err.code === '23505'`**
- PostgreSQL error codes are 5-character strings
- `'23505'` — the official code for **unique_violation** (inserting a duplicate that violates a UNIQUE or PRIMARY KEY constraint)
- The `enrollments` table has `UNIQUE(user_id, channel_id)` — a user can't be enrolled in the same channel twice
- Other error codes: `'23502'` = not_null_violation, `'23503'` = foreign_key_violation

**`throw err;`**
- For ANY other error (connection failure, syntax error, etc.), rethrow it
- `express-async-errors` catches it and passes it to `errorHandler.js`
- We only handle the "already enrolled" case — other errors are unexpected and should be logged

---

## Lines 34–41 — `unenroll` function

```js
const unenroll = async (req, res) => {
  const { user_id, channel_id } = req.body;
  await pool.query(
    'DELETE FROM enrollments WHERE user_id=$1 AND channel_id=$2',
    [user_id, channel_id]
  );
  res.json({ success: true, message: 'Unenrolled successfully' });
};
```

### `WHERE user_id=$1 AND channel_id=$2`

**`AND`** — SQL logical AND. Both conditions must match. This deletes the specific enrollment row for this exact user+channel combination. Without `AND channel_id=$2`, you'd unenroll the user from ALL channels.

### No `rowCount` check — intentional

Even if `(user_id, channel_id)` didn't exist in the table (already unenrolled), DELETE affects 0 rows and we still respond with `success: true`. The comment says: "Silently succeeds even if the enrollment did not exist." This is **idempotent design** — calling unenroll multiple times has the same effect as calling it once.

---

## Lines 48–54 — `getMyEnrollments` function

```js
const getMyEnrollments = async (req, res) => {
  const result = await pool.query(
    `SELECT c.* FROM channels c INNER JOIN enrollments e ON e.channel_id=c.id WHERE e.user_id=$1`,
    [req.user.id]
  );
  res.json({ success: true, channels: result.rows });
};
```

### `req.user.id`
- Set by the `protect` middleware from the JWT
- We use the authenticated user's own ID — they can only see THEIR enrollments
- Unlike `enroll` (which takes `user_id` from body for admin use), this uses `req.user.id` for self-service

### The SQL Query:

```sql
SELECT c.* FROM channels c
INNER JOIN enrollments e ON e.channel_id = c.id
WHERE e.user_id = $1
```

**`FROM channels c`** — query the `channels` table, alias as `c`

**`INNER JOIN enrollments e ON e.channel_id = c.id`**
- Join the `enrollments` table (alias `e`) where the channel IDs match
- This connects: "what channels are this user enrolled in?"
- INNER JOIN = only return channels that have a matching enrollment row for this user

**`WHERE e.user_id = $1`** — filter to only enrollments belonging to the logged-in user

**Result**: A list of full `channels` objects (all columns) for every channel the user is enrolled in — ready to display as "My Subjects" in the Flutter app.

---

## Lines 64–83 — `bulkEnroll` function

```js
const bulkEnroll = async (req, res) => {
  const { channel_id, programme_id, current_semester } = req.body;
  const students = await pool.query(
    `SELECT id FROM users WHERE role='student' AND programme_id=$1 AND current_semester=$2`,
    [programme_id, current_semester]
  );
  let enrolled = 0;
  for (const s of students.rows) {
    try {
      await pool.query(
        'INSERT INTO enrollments (user_id, channel_id) VALUES ($1, $2)',
        [s.id, channel_id]
      );
      enrolled++;
    } catch (_) {
      // Skip already-enrolled students silently
    }
  }
  res.json({ success: true, message: `Enrolled ${enrolled} students` });
};
```

### Purpose

When a teacher creates a new subject channel, they want to automatically enroll all students in that programme and semester. Instead of enrolling students one by one, this bulk operation does it in one API call.

### `const { channel_id, programme_id, current_semester } = req.body;`

Three identifiers:
- `channel_id` — the target channel to enroll students into
- `programme_id` — filter students by programme (e.g., Computer Science = programme 1)
- `current_semester` — filter by semester (e.g., semester 3)

### First Query — Find Eligible Students

```js
const students = await pool.query(
  `SELECT id FROM users WHERE role='student' AND programme_id=$1 AND current_semester=$2`,
  [programme_id, current_semester]
);
```

**`role='student'`** — hardcoded in SQL (not parameterized — that's fine, it's a constant string we control, not user input)

**`AND programme_id=$1 AND current_semester=$2`** — both must match

Result: `students.rows = [{ id: 1 }, { id: 5 }, { id: 8 }, ...]` — only the `id` column (all we need)

### `let enrolled = 0;`

**`let`** — `let` not `const` because this variable changes (incremented in the loop)

A counter to track how many students were newly enrolled (excluding skipped duplicates).

### `for (const s of students.rows)`

**`for...of`** — modern JavaScript loop that iterates over an **iterable** (array, string, Map, etc.)
- `s` — each element of `students.rows` (an object like `{ id: 5 }`)
- `const s` — `const` works inside `for...of` (new binding each iteration)
- Alternative (old style): `for (let i = 0; i < students.rows.length; i++) { const s = students.rows[i]; }`

### `try { ... } catch (_) { }`

**`_`** — by convention, `_` as a variable name means "I receive this parameter but intentionally don't use it"
- The `catch` block receives the error but we don't need to examine it — we just skip
- Any error during INSERT (including `23505` duplicate key) is silently ignored

**`enrolled++`** — post-increment. Only runs if the INSERT succeeded (no error). Counts newly enrolled students.

### `` `Enrolled ${enrolled} students` ``

Template literal. If 45 students were enrolled: `"Enrolled 45 students"`.

### Performance Note

This runs N sequential `await pool.query(...)` calls — one per student. For a class of 60 students, that's 60 sequential DB round-trips (~60 × 5ms = 300ms+).

A more efficient approach would use a batch INSERT:
```sql
INSERT INTO enrollments (user_id, channel_id) VALUES ($1, $2), ($3, $2), ($5, $2)...
ON CONFLICT DO NOTHING;
```
But the current approach is simpler and acceptable for class sizes.

---

## Summary Table

| Function | Method | URL | What it does |
|---|---|---|---|
| `enroll` | POST | `/api/enrollments` | Enroll one user in one channel |
| `unenroll` | DELETE | `/api/enrollments` | Remove enrollment (idempotent) |
| `getMyEnrollments` | GET | `/api/enrollments/me` | Get logged-in user's channels |
| `bulkEnroll` | POST | `/api/enrollments/bulk` | Enroll all students in a programme/semester |

| PostgreSQL Error Code | Meaning |
|---|---|
| `23505` | Unique constraint violation — duplicate enrollment |
| `23502` | NOT NULL violation |
| `23503` | Foreign key violation (user_id or channel_id doesn't exist) |
