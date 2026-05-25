# Word-by-Word Deep Dive: `backend/controllers/notesController.js`

> This file handles **channel notes** — text notes that users (students and teachers) can create within a subject channel. Notes are different from messages (they're permanent, titled, not real-time) and different from announcements (any enrolled member can create them).

---

## The Full File

```js
const pool = require('../config/db');

const getNotes = async (req, res) => { ... };
const createNote = async (req, res) => { ... };
const deleteNote = async (req, res) => { ... };

module.exports = { getNotes, createNote, deleteNote };
```

---

## Lines 9–19 — `getNotes`

```js
const getNotes = async (req, res) => {
  const result = await pool.query(
    `SELECT n.*, u.name AS author_name
     FROM notes n
     INNER JOIN users u ON n.created_by = u.id
     WHERE n.channel_id = $1
     ORDER BY n.created_at DESC`,
    [req.params.id]
  );
  res.json({ success: true, notes: result.rows });
};
```

### SQL Query Breakdown:

**`SELECT n.*`** — all columns from the `notes` table (aliased as `n`):
- `id`, `channel_id`, `created_by`, `title`, `content`, `created_at`

**`u.name AS author_name`** — also get the creator's name from the `users` table
- `AS author_name` renames it to avoid confusion with any `name` column in notes

**`FROM notes n`** — query `notes` table, alias as `n`

**`INNER JOIN users u ON n.created_by = u.id`**
- Join `users` table (alias `u`) where `notes.created_by` matches `users.id`
- `created_by` stores the user's ID — JOIN resolves it to a name
- INNER JOIN: notes without a valid `created_by` (orphaned notes) are excluded

**`WHERE n.channel_id = $1`** — only notes from this specific channel

**`ORDER BY n.created_at DESC`** — newest notes first

**`[req.params.id]`** — the channel ID from the URL: `/api/channels/5/notes` → `req.params.id = '5'`

---

## Lines 30–43 — `createNote`

```js
const createNote = async (req, res) => {
  const { title, content } = req.body;
  if (!title) return res.status(400).json({ success: false, message: 'Title is required' });

  const result = await pool.query(
    `INSERT INTO notes (channel_id, created_by, title, content)
     VALUES ($1, $2, $3, $4) RETURNING *`,
    [req.params.id, req.user.id, title, content]
  );
  const newNote = result.rows[0];
  newNote.author_name = req.user.name;
  res.status(201).json({ success: true, note: newNote });
};
```

### `const { title, content } = req.body;`

Flutter sends: `{ "title": "Chapter 3 Summary", "content": "Newton's laws..." }`

**`content`** — not validated with `!content` because content is optional. Notes can have a title only (no body text required).

### `if (!title)` — only title is required

**`!title`** — falsy check. Empty string `''`, `undefined`, `null` all trigger this.

### `VALUES ($1, $2, $3, $4)`

Mapped to: `[req.params.id, req.user.id, title, content]`
- `$1` = channel ID from URL path (mergeParams makes this available from parent route)
- `$2` = logged-in user's ID (from JWT — not trusting the client to send this)
- `$3` = note title from body
- `$4` = note content from body (can be `undefined` → stored as NULL in DB)

### The Author Name Trick (Line 41)

```js
const newNote = result.rows[0];
newNote.author_name = req.user.name;
```

**`result.rows[0]`** — the newly inserted note row. It has `created_by` (the user ID) but NOT `author_name` (the user's display name) — because `INSERT ... RETURNING *` only returns the columns in the `notes` table.

**`newNote.author_name = req.user.name`** — manually adds the author's name to the object
- `req.user.name` — available from the JWT (set by `protect` middleware)
- This avoids doing a second `SELECT` query just to get the author's name
- Result: the Flutter app receives a complete note object with `author_name` — ready to display

**Why this matters:** The note list view shows "Created by Alice" under each note. Without this trick, the Flutter app would either:
1. Make a second API call to get the author name, or
2. Not show the author name at all

---

## Lines 51–58 — `deleteNote`

```js
const deleteNote = async (req, res) => {
  const result = await pool.query(
    `DELETE FROM notes WHERE id = $1 AND (created_by = $2 OR $3 = 'faculty' OR $3 = 'admin') RETURNING id`,
    [req.params.noteId, req.user.id, req.user.role]
  );
  if (!result.rows.length) return res.status(403).json({ success: false, message: 'Not authorized or not found' });
  res.json({ success: true, message: 'Note deleted' });
};
```

### The SQL DELETE with Authorization Logic

```sql
DELETE FROM notes
WHERE id = $1
AND (created_by = $2 OR $3 = 'faculty' OR $3 = 'admin')
RETURNING id
```

This is clever — the **authorization check is embedded inside the SQL query itself**.

**`id = $1`** — identifies the specific note to delete (`req.params.noteId`)

**`AND (...)`** — additional condition using parentheses (to control precedence):
- `created_by = $2` — is the logged-in user the creator of this note?
- `OR $3 = 'faculty'` — OR is the logged-in user a faculty member? (`$3 = req.user.role`)
- `OR $3 = 'admin'` — OR is the logged-in user an admin?

**The parentheses matter:**
- `id = $1 AND (created_by = $2 OR $3 = 'faculty' OR $3 = 'admin')`
- Meaning: "note ID matches AND (creator matches OR role is faculty OR role is admin)"
- Without parentheses: `id = $1 AND created_by = $2 OR $3 = 'faculty'` — different precedence, wrong meaning!

**`$3 = 'faculty'`** — comparing the role value to a string literal INSIDE the SQL
- `$3` = `req.user.role` (e.g., `'student'`, `'faculty'`, `'admin'`)
- If `req.user.role` = `'faculty'`, then `$3 = 'faculty'` evaluates to `TRUE` in PostgreSQL
- This is a legal parameterized comparison — `$3` is a safe placeholder, not string interpolation

**`RETURNING id`** — after DELETE, return the `id` of deleted rows
- If the WHERE clause matched a row: `result.rows = [{ id: 42 }]` — deletion happened
- If WHERE clause matched nothing: `result.rows = []` — nothing was deleted

### The Authorization Check After the Query

```js
if (!result.rows.length) return res.status(403).json({...});
```

**`result.rows.length`** — length of the returned rows array
- If > 0: deletion succeeded
- If 0: the note either doesn't exist OR the user isn't authorized to delete it

**Why return 403 instead of 404?** — We combine "not found" and "not authorized" into one response. This prevents information leakage: a student can't tell whether note #999 exists but they can't delete it, or whether it doesn't exist at all. Both cases return the same 403.

**The Elegance:** This approach doesn't require:
1. A SELECT to check if the note exists
2. A separate authorization check
3. A DELETE if authorized

All three are done in ONE query. The DELETE only runs if all conditions are met.

---

## Summary Table

| Function | Method | URL | Key Feature |
|---|---|---|---|
| `getNotes` | GET | `/api/channels/:id/notes` | JOIN to get author names |
| `createNote` | POST | `/api/channels/:id/notes` | Manually attach author_name to avoid extra SELECT |
| `deleteNote` | DELETE | `/api/channels/:id/notes/:noteId` | Authorization logic embedded in SQL WHERE clause |
