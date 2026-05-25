# Word-by-Word Deep Dive: `backend/controllers/assignmentController.js`

> This file handles the full lifecycle of **assignments** — creating them, viewing them (differently for students vs faculty), editing, deleting, and viewing submissions. The two most interesting techniques here are the **role-based dual query** (same endpoint, different SQL) and the **cross-channel boundary check** that prevents faculty from editing each other's assignments.

---

## Lines 10–27 — `getAssignments` — Same Endpoint, Two Queries

```js
const getAssignments = async (req, res) => {
  let query, values;
  if (req.user.role === 'student') {
    query = `SELECT a.*, u.name AS created_by_name, s.status AS submission_status, s.submitted_at, s.marks, s.feedback, s.id AS submission_id
             FROM assignments a INNER JOIN users u ON a.created_by = u.id
             LEFT JOIN assignment_submissions s ON s.assignment_id = a.id AND s.student_id = $2
             WHERE a.channel_id = $1 ORDER BY a.due_date ASC`;
    values = [req.params.id, req.user.id];
  } else {
    query = `SELECT a.*, u.name AS created_by_name, COUNT(s.id) AS submission_count
             FROM assignments a INNER JOIN users u ON a.created_by = u.id
             LEFT JOIN assignment_submissions s ON s.assignment_id = a.id
             WHERE a.channel_id = $1 GROUP BY a.id, u.name ORDER BY a.due_date ASC`;
    values = [req.params.id];
  }
  const result = await pool.query(query, values);
  res.json({ success: true, assignments: result.rows });
};
```

### `let query, values;`

Declares two variables without initializing them (they'll be assigned inside the `if/else`). `let` allows this; `const` would require immediate assignment.

### Student Query — LEFT JOIN with student filter

```sql
LEFT JOIN assignment_submissions s ON s.assignment_id = a.id AND s.student_id = $2
```

**`LEFT JOIN assignment_submissions s`** — join the submissions table (alias `s`)

**`ON s.assignment_id = a.id AND s.student_id = $2`** — TWO conditions in the JOIN:
- `s.assignment_id = a.id` — link submission to the assignment
- `AND s.student_id = $2` — **only** join THIS student's submission

**Why is this condition in the JOIN, not the WHERE?** — Critical SQL distinction:
- If it were `WHERE s.student_id = $2`: assignments the student HASN'T submitted would be excluded (because `s.student_id` would be NULL, failing the WHERE)
- In the JOIN `ON` clause: assignments without a submission by this student return `s.*` columns as NULL — the assignment still appears in results, but with NULL submission fields

**`s.status AS submission_status`** — the student's submission status
- If submitted: `'submitted'` or `'graded'`
- If not submitted: `NULL` (the LEFT JOIN returned nothing)

**`values = [req.params.id, req.user.id]`** — TWO values: `$1` = channel ID, `$2` = student's user ID

### Faculty/Admin Query — COUNT submissions

```sql
LEFT JOIN assignment_submissions s ON s.assignment_id = a.id
WHERE a.channel_id = $1 GROUP BY a.id, u.name ORDER BY a.due_date ASC
```

**`COUNT(s.id) AS submission_count`** — counts how many students submitted this assignment
- `s.id` is NULL when LEFT JOIN finds no submission — `COUNT(NULL)` = 0 (COUNT ignores NULLs)
- So unsubmitted assignments show `submission_count = 0`

**`GROUP BY a.id, u.name`** — required when using aggregate functions (COUNT)
- Every column in SELECT that's NOT inside an aggregate function must appear in GROUP BY
- `a.*` covers `a.id`, `a.channel_id`, etc. → PostgreSQL requires `a.id` in GROUP BY
- `u.name AS created_by_name` → requires `u.name` in GROUP BY

**`ORDER BY a.due_date ASC`** — assignments sorted by due date, earliest first

---

## Lines 46–68 — `createAssignment`

```js
const createAssignment = async (req, res) => {
  const { title, description, due_date, max_marks, priority } = req.body;
  if (!title || !due_date) return res.status(400).json({...});

  if (title.length > 255) return res.status(400).json({...});
  if (description && description.length > 3000) return res.status(400).json({...});

  const result = await pool.query(
    `INSERT INTO assignments (..., status) VALUES ($1,$2,$3,$4,$5,$6,$7,'todo') RETURNING *`,
    [req.params.id, req.user.id, title, description, due_date, max_marks || 100, priority || 'medium']
  );

  const students = await pool.query(`SELECT user_id FROM enrollments WHERE channel_id=$1`, [req.params.id]);
  await Promise.all(students.rows.map(s =>
    pool.query(`INSERT INTO notifications ...`, [...])
  ));

  res.status(201).json({ success: true, assignment: result.rows[0] });
};
```

### Length Validation

```js
if (title.length > 255) return res.status(400).json({...});
if (description && description.length > 3000) return res.status(400).json({...});
```

**`title.length`** — String property. The number of characters in the string.
- `'Hello'.length = 5`
- `255` — matches the VARCHAR(255) column constraint in PostgreSQL. Catching this here gives a better error than letting PostgreSQL throw it.

**`description && description.length > 3000`**
- `description &&` — first check if `description` is truthy (not empty/undefined)
- Only then check its length — avoids `undefined.length` TypeError
- `description` is optional, so this guard is necessary

### `max_marks || 100`

**`||`** — logical OR. Returns left side if truthy, right side if left is falsy.
- If `max_marks` is undefined or 0 → use 100 as default
- `0` is falsy in JS — `0 || 100 = 100`. This means you can't pass 0 max_marks (rare edge case but acceptable here)

### `priority || 'medium'`

Same pattern. Accepted values: `'low'`, `'medium'`, `'high'`. Defaults to `'medium'`.

### `'todo'` — hardcoded

The status is hardcoded as `'todo'` in the INSERT — newly created assignments always start as "to do." Not trusting the client to set the correct initial status.

### Notification to All Students

```js
const students = await pool.query(`SELECT user_id FROM enrollments WHERE channel_id=$1`, [req.params.id]);
await Promise.all(students.rows.map(s =>
  pool.query(`INSERT INTO notifications (user_id, type, title, message, ref_id, ref_type) VALUES ($1,'assignment',$2,$3,$4,'assignment')`,
    [s.user_id, `New Assignment: ${title}`, `Due: ${new Date(due_date).toLocaleDateString()}`, result.rows[0].id])
));
```

**`new Date(due_date)`** — creates a JavaScript `Date` object from the due_date string

**`.toLocaleDateString()`** — formats the date as a locale-appropriate string (e.g., `"5/30/2025"` or `"30/05/2025"`)

**`await Promise.all(...)`** — unlike `announcementController` which used fire-and-forget, here we `await` the notifications. This means the 201 response waits for ALL notifications to be inserted. For a large class (60+ students), this adds latency. A trade-off: the `announcementController` chose fire-and-forget; this chose reliability.

---

## Lines 75–86 — `updateAssignmentStatus`

```js
const updateAssignmentStatus = async (req, res) => {
  const { status } = req.body;
  const allowed = ['todo', 'in_progress', 'done'];
  if (!allowed.includes(status)) return res.status(400).json({ success: false, message: 'Invalid status' });

  const result = await pool.query(
    `UPDATE assignments SET status=$1 WHERE id=$2 RETURNING *`,
    [status, req.params.assignId]
  );
  ...
};
```

**`const allowed = ['todo', 'in_progress', 'done']`** — whitelist of valid statuses

**`if (!allowed.includes(status))`** — validate the status is one of the three allowed values. Without this, a client could set `status = "DELETE FROM assignments"` (an injection attempt — though parameterized queries prevent SQL injection, we still want to restrict to valid enum values).

**`RETURNING *`** — returns the updated assignment so the Flutter Kanban board can update immediately without a refetch.

---

## Lines 93–104 — `updateAssignment` — Cross-Channel Security Check

```js
const updateAssignment = async (req, res) => {
  ...
  const check = await pool.query('SELECT channel_id FROM assignments WHERE id=$1', [req.params.assignId]);
  if (!check.rows.length) return res.status(404).json({...});
  if (String(check.rows[0].channel_id) !== String(req.params.id))
    return res.status(403).json({ success: false, message: 'Assignment does not belong to this channel' });
  ...
};
```

### Why This Check Exists

URL: `PUT /api/channels/7/assignments/42` means "update assignment #42 in channel #7."

Without the check, a faculty member could:
1. Note that assignment #100 belongs to another teacher's channel
2. Send `PUT /api/channels/7/assignments/100` (using their own channel 7 but targeting assignment 100)
3. Modify assignment 100 (another teacher's assignment!) because the UPDATE only filters by `id`

**The fix:** Before updating, verify that `assignment.channel_id` matches the `channel_id` from the URL.

### `String(check.rows[0].channel_id) !== String(req.params.id)`

**`String(...)`** — converts value to string. Used because:
- `check.rows[0].channel_id` — might be a number (integer from PostgreSQL)
- `req.params.id` — is always a string (URL parameters are strings)
- `7 !== '7'` → `true` (strict inequality, different types!) — would always fail
- `String(7) !== String('7')` → `'7' !== '7'` → `false` — correct comparison

This is a type coercion guard to avoid false mismatches.

---

## Lines 127–136 — `getSubmissions`

```js
const getSubmissions = async (req, res) => {
  const result = await pool.query(
    `SELECT sub.*, u.name AS student_name, u.email AS student_email
     FROM assignment_submissions sub
     INNER JOIN users u ON sub.student_id = u.id
     WHERE sub.assignment_id = $1 ORDER BY sub.submitted_at DESC`,
    [req.params.id]  // ← NOTE: uses req.params.id not req.params.assignId!
  );
  res.json({ success: true, submissions: result.rows });
};
```

**Wait — `req.params.id` here refers to `:assignId` not `:id` (the channel).** This is because the route is nested as `GET /api/channels/:id/assignments/:assignId/submissions` but the value at `$1` is `req.params.id`. Double-check the route definition — this may be a parameter name collision where `:assignId` is accessible via a different param name. Looking at the route: this is the assignment ID position in `req.params`.

**`sub.*`** — all submission columns: `id, assignment_id, student_id, file_url, file_name, submitted_at, marks, feedback, status`

**`u.name AS student_name, u.email AS student_email`** — teacher needs to know which student submitted

**`ORDER BY sub.submitted_at DESC`** — most recently submitted first

---

## Summary Table

| Function | Method | URL | Key Feature |
|---|---|---|---|
| `getAssignments` | GET | `/api/channels/:id/assignments` | Role-based dual query (student vs faculty SQL) |
| `getAssignment` | GET | `/api/channels/:id/assignments/:assignId` | Single assignment with creator name |
| `createAssignment` | POST | `/api/channels/:id/assignments` | Creates + notifies all enrolled students |
| `updateAssignmentStatus` | PATCH | `.../:assignId/status` | Kanban status whitelist validation |
| `updateAssignment` | PUT | `.../:assignId` | Cross-channel boundary check before update |
| `deleteAssignment` | DELETE | `.../:assignId` | Cross-channel boundary check before delete |
| `getSubmissions` | GET | `.../:assignId/submissions` | Faculty view all student submissions |

| SQL Pattern | Purpose |
|---|---|
| `LEFT JOIN ... ON condition AND s.student_id = $2` | Filter the JOIN, not the result set |
| `COUNT(s.id) ... GROUP BY a.id, u.name` | Count submissions per assignment |
| `String(...) !== String(...)` | Safe cross-type comparison for security check |
