# Word-by-Word Deep Dive: `backend/controllers/submissionController.js`

> This file handles **assignment submissions** — when students upload their work, teachers grade it, and students view their results. The key challenge solved here is the **upsert pattern**: supporting both first-time submissions and resubmissions without creating duplicate rows.

---

## Lines 9–46 — `submitAssignment`

```js
const submitAssignment = async (req, res) => {
  const assignment_id = req.params.assignId;
  const student_id = req.user.id;

  const assign = await pool.query('SELECT due_date FROM assignments WHERE id=$1', [assignment_id]);
  if (!assign.rows.length)
    return res.status(404).json({ success: false, message: 'Assignment not found' });

  const status = new Date() > new Date(assign.rows[0].due_date) ? 'late' : 'submitted';
  const file_url  = req.file?.path         || null;
  const file_name = req.file?.originalname || null;

  const existing = await pool.query(
    'SELECT id FROM assignment_submissions WHERE assignment_id=$1 AND student_id=$2',
    [assignment_id, student_id]
  );

  let result;
  if (existing.rows.length > 0) {
    result = await pool.query(`UPDATE assignment_submissions SET ... WHERE assignment_id=$4 AND student_id=$5 RETURNING *`, [...]);
  } else {
    result = await pool.query(`INSERT INTO assignment_submissions (...) VALUES (...) RETURNING *`, [...]);
  }
  res.status(201).json({ success: true, submission: result.rows[0] });
};
```

### `const assignment_id = req.params.assignId;`

The comment in the source says: "was `req.params.id` (wrong — that's channel ID)." This is a bug fix note:
- Route: `/api/channels/:id/assignments/:assignId/submit`
- `req.params.id` = the channel ID (e.g., `7`)
- `req.params.assignId` = the assignment ID (e.g., `42`)
- Using the channel ID to query assignments would always return wrong results

### `SELECT due_date FROM assignments WHERE id=$1`

Only selects `due_date` — minimum data needed to determine if the submission is late. No need to fetch all columns.

### `const status = new Date() > new Date(assign.rows[0].due_date) ? 'late' : 'submitted';`

**`new Date()`** — creates a Date object for the **current date and time** (right now)

**`new Date(assign.rows[0].due_date)`** — creates a Date object from the assignment's due_date string (e.g., `"2025-05-30T23:59:00Z"`)

**`>`** — when comparing two Date objects with `>`, JavaScript compares their underlying timestamps (milliseconds since epoch). `dateA > dateB` = true if dateA is AFTER dateB.

**Ternary operator:** `condition ? 'late' : 'submitted'`
- If current time is AFTER the due date → `'late'`
- If current time is BEFORE or AT the due date → `'submitted'`

**`'late'`** — stored in the `status` column, visible on the teacher's grading view

### File Handling

```js
const file_url  = req.file?.path         || null;
const file_name = req.file?.originalname || null;
```

**`req.file`** — set by the `upload.single('file')` multer middleware (if a file was attached)
- If no file: `req.file` is `undefined`
- If file uploaded: `req.file.path` = the Supabase public URL

**`?.path`** — optional chaining. If `req.file` is `undefined`, `?.path` returns `undefined` (no crash)

**`|| null`** — convert `undefined` to `null` for PostgreSQL. Assignments can be submitted as text-only (no file).

### The Upsert Logic (Check-then-Insert-or-Update)

```js
const existing = await pool.query(
  'SELECT id FROM assignment_submissions WHERE assignment_id=$1 AND student_id=$2',
  [assignment_id, student_id]
);
```

**Why check first?** — A student might submit multiple times (resubmit). The `assignment_submissions` table has a UNIQUE constraint on `(assignment_id, student_id)` — only one submission per student per assignment. We need to UPDATE if a row already exists, INSERT if it doesn't.

**Alternative:** PostgreSQL `INSERT ... ON CONFLICT DO UPDATE` (upsert in one query). The current approach uses two queries but is clearer and easier to read.

**`SELECT id FROM assignment_submissions`** — only get the `id` column. Just checking if a row exists — don't need other data.

### `if (existing.rows.length > 0)` — Resubmission Path

```js
result = await pool.query(
  `UPDATE assignment_submissions
   SET file_url=$1, file_name=$2, status=$3, submitted_at=NOW()
   WHERE assignment_id=$4 AND student_id=$5 RETURNING *`,
  [file_url, file_name, status, assignment_id, student_id]
);
```

**`submitted_at=NOW()`** — `NOW()` is a PostgreSQL function returning the current timestamp
- Not parameterized (`$N`) — it's a server-side function call in the SQL, not user input
- Updates to the current timestamp, recording when the resubmission happened

**`WHERE assignment_id=$4 AND student_id=$5`** — identifies the specific row to update. Both conditions required (same as why the SELECT needed both).

### First-Time Submission Path

```js
result = await pool.query(
  `INSERT INTO assignment_submissions (assignment_id, student_id, file_url, file_name, status, submitted_at)
   VALUES ($1,$2,$3,$4,$5,NOW()) RETURNING *`,
  [assignment_id, student_id, file_url, file_name, status]
);
```

**`NOW()`** in INSERT — same as in UPDATE, sets `submitted_at` to current server time

Note: `marks` and `feedback` columns are NOT set in the INSERT — they start as NULL and are set later by `gradeSubmission`.

---

## Lines 53–73 — `gradeSubmission`

```js
const gradeSubmission = async (req, res) => {
  const { marks, feedback } = req.body;

  const result = await pool.query(
    `UPDATE assignment_submissions SET marks=$1, feedback=$2 WHERE id=$3 RETURNING *`,
    [marks, feedback, req.params.subId]
  );
  if (!result.rows.length)
    return res.status(404).json({ success: false, message: 'Submission not found' });

  const sub = result.rows[0];

  await pool.query(
    `INSERT INTO notifications (user_id, type, title, message, ref_id, ref_type)
     VALUES ($1,'grade','Assignment Graded',$2,$3,'submission')`,
    [sub.student_id, `You received ${marks} marks. Feedback: ${feedback || 'None'}`, sub.id]
  );

  res.json({ success: true, submission: result.rows[0] });
};
```

### `const { marks, feedback } = req.body;`

Both sent from Flutter's grading form. `marks` = number. `feedback` = string (optional).

### `UPDATE assignment_submissions SET marks=$1, feedback=$2 WHERE id=$3`

Only updates `marks` and `feedback` — doesn't touch `file_url`, `status`, `submitted_at`. A partial update.

**`req.params.subId`** — the submission ID from the URL: `/api/.../submissions/15/grade` → `subId = '15'`

### After Grading — Notification

```js
await pool.query(
  `INSERT INTO notifications ... VALUES ($1,'grade','Assignment Graded',$2,$3,'submission')`,
  [sub.student_id, `You received ${marks} marks. Feedback: ${feedback || 'None'}`, sub.id]
);
```

**`sub.student_id`** — from `result.rows[0]`. After UPDATE, we have the complete submission row including `student_id` — the student who submitted. We notify THEM specifically.

**`'grade'`** — hardcoded notification type. The `type` column categorizes notifications for the bell icon.

**`` `You received ${marks} marks. Feedback: ${feedback || 'None'}` ``**
- Template literal building the notification message
- `feedback || 'None'` — if no feedback was provided, show "None"

**`sub.id`** — `ref_id` — links the notification to this specific submission (for "deep linking" — tapping the notification could navigate to the submission in Flutter)

**`'submission'`** — `ref_type` — tells the Flutter app what kind of entity `ref_id` refers to

---

## Lines 79–85 — `getMySubmission`

```js
const getMySubmission = async (req, res) => {
  const result = await pool.query(
    'SELECT * FROM assignment_submissions WHERE assignment_id=$1 AND student_id=$2',
    [req.params.assignId, req.user.id]
  );
  res.json({ success: true, submission: result.rows[0] || null });
};
```

### `result.rows[0] || null`

**`result.rows[0]`** — if the student has submitted: returns the submission object

**`|| null`** — if `result.rows` is empty (student hasn't submitted yet), `result.rows[0]` is `undefined`, which is falsy → use `null` instead

**Why return `null` instead of 404?** — Not having a submission is a NORMAL state for a student (they just haven't submitted yet). Returning `{ success: true, submission: null }` tells Flutter: "Everything worked, but there's no submission yet." A 404 would suggest something is wrong with the request itself.

The Flutter app checks: `if (submission == null) { showSubmitButton() } else { showSubmissionDetails() }`

---

## Summary Table

| Function | Method | URL | Key Feature |
|---|---|---|---|
| `submitAssignment` | POST | `/api/channels/:id/assignments/:assignId/submit` | Late detection, upsert (UPDATE or INSERT) |
| `gradeSubmission` | PATCH | `.../:assignId/submissions/:subId/grade` | Update marks + auto-notify student |
| `getMySubmission` | GET | `.../:assignId/my-submission` | Returns null (not 404) if not submitted |

| Pattern | Where | Why |
|---|---|---|
| `new Date() > new Date(due_date)` | `submitAssignment` | Server-side late detection |
| `req.file?.path \|\| null` | `submitAssignment` | Optional file upload |
| Check-then-UPDATE/INSERT | `submitAssignment` | Handle resubmissions |
| `NOW()` in SQL | Both submit paths | Server-side timestamp, not from client |
| `result.rows[0] \|\| null` | `getMySubmission` | Null = valid "not submitted yet" state |
