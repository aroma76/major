# Word-by-Word Deep Dive: `backend/controllers/teacherController.js`

> This file powers the **faculty dashboard** — the first screen teachers see after logging in. It delivers real-time stats (total students, pending reviews, active projects, subjects taught) and a recent activity feed. It also includes a student dashboard activity feed. The key technique here is **parallel query execution** using `Promise.all` to make multiple DB queries at the same time.

---

## Before Reading — What is Promise.all?

Normally with `await`, queries run sequentially:
```js
const a = await query1(); // wait 50ms
const b = await query2(); // wait 50ms  → total: 100ms
const c = await query3(); // wait 50ms  → total: 150ms
```

`Promise.all` runs them **in parallel** (at the same time):
```js
const [a, b, c] = await Promise.all([query1(), query2(), query3()]);
// All three run simultaneously → total: ~50ms (the slowest one)
```

This is a critical performance optimization when queries are independent of each other.

---

## Lines 12–65 — `getTeacherStats`

```js
const getTeacherStats = async (req, res) => {
  const teacherId = req.user.id;

  const channelRes = await pool.query(
    `SELECT id FROM channels WHERE teacher_id = $1`,
    [teacherId]
  );
  const channelIds = channelRes.rows.map(r => r.id);

  if (channelIds.length === 0) {
    return res.json({ success: true, stats: { totalStudents: 0, pendingReviews: 0, activeProjects: 0, totalSubjects: 0 } });
  }

  const [studentRes, pendingRes, projectRes] = await Promise.all([...]);

  res.json({ success: true, stats: { ... } });
};
```

### `const teacherId = req.user.id;`

Extracts the teacher's ID from the JWT payload (set by `protect` middleware). All queries filter by this ID — teachers only see data for their own channels.

### First Query — Get Channel IDs

```js
const channelRes = await pool.query(
  `SELECT id FROM channels WHERE teacher_id = $1`,
  [teacherId]
);
const channelIds = channelRes.rows.map(r => r.id);
```

**`SELECT id FROM channels WHERE teacher_id = $1`** — get only the `id` column (not `*`) — we just need the IDs to use as filters in subsequent queries.

**`channelRes.rows.map(r => r.id)`**
- `channelRes.rows` — array of row objects: `[{ id: 1 }, { id: 5 }, { id: 8 }]`
- `.map(r => r.id)` — transforms each row object into just its `id` value
- Result: `channelIds = [1, 5, 8]`
- `r => r.id` — arrow function: for each row `r`, return `r.id`

### Early Return for No Channels

```js
if (channelIds.length === 0) {
  return res.json({ success: true, stats: { totalStudents: 0, ... } });
}
```

**Why?** — If the teacher has no channels, the `ANY($1::int[])` queries below would receive an empty array. While PostgreSQL can handle `ANY('{}')` (returns no rows), it's cleaner and more explicit to short-circuit here. Prevents unnecessary DB round-trips.

---

### The Parallel Queries — `Promise.all`

```js
const [studentRes, pendingRes, projectRes] = await Promise.all([
  pool.query(
    `SELECT COUNT(DISTINCT user_id) AS total FROM enrollments WHERE channel_id = ANY($1::int[])`,
    [channelIds]
  ),
  pool.query(
    `SELECT COUNT(*) AS total FROM assignment_submissions sub
     INNER JOIN assignments a ON sub.assignment_id = a.id
     WHERE a.channel_id = ANY($1::int[]) AND sub.marks IS NULL`,
    [channelIds]
  ),
  pool.query(
    `SELECT COUNT(*) AS total FROM projects WHERE created_by = $1`,
    [teacherId]
  ),
]);
```

**`await Promise.all([...])`**
- `Promise.all` takes an array of Promises
- All three `pool.query(...)` calls are fired **simultaneously** (not awaited individually)
- `Promise.all` returns a Promise that resolves when ALL inner Promises resolve
- Destructuring `[studentRes, pendingRes, projectRes]` unpacks the results in order

**Why not just `await` each one?**
- These three queries are completely independent — none needs the result of another
- Sequential: 3 × ~30ms = ~90ms total
- Parallel: max(30ms, 30ms, 30ms) = ~30ms total → **3× faster**

---

### Query 1 — Total Students

```sql
SELECT COUNT(DISTINCT user_id) AS total
FROM enrollments
WHERE channel_id = ANY($1::int[])
```

**`COUNT(DISTINCT user_id)`**
- `COUNT(column)` — count non-NULL values in that column
- `DISTINCT` — count each unique `user_id` only once
- Why `DISTINCT`? A student enrolled in 3 of the teacher's channels appears 3 times in `enrollments`. Without `DISTINCT`, they'd be counted 3 times. `DISTINCT` counts them once.
- **Example**: 30 students in 3 channels → 90 total enrollments → but `COUNT(DISTINCT user_id)` = 30

**`ANY($1::int[])`**
- `ANY(array)` — PostgreSQL operator meaning "matches ANY value in the array"
- `channel_id = ANY('{1,5,8}')` — equivalent to `channel_id IN (1, 5, 8)`
- `$1` is the `channelIds` array passed from JavaScript: `[1, 5, 8]`
- `::int[]` — **type cast**: tells PostgreSQL to treat the parameter as an integer array
- Without `::int[]`, PostgreSQL might receive it as a text value and fail to compare to integer IDs

---

### Query 2 — Pending Submissions

```sql
SELECT COUNT(*) AS total
FROM assignment_submissions sub
INNER JOIN assignments a ON sub.assignment_id = a.id
WHERE a.channel_id = ANY($1::int[]) AND sub.marks IS NULL
```

**`INNER JOIN assignments a ON sub.assignment_id = a.id`**
- `assignment_submissions` doesn't have `channel_id` directly — it has `assignment_id`
- We join `assignments` to get the `channel_id` for filtering
- INNER JOIN ensures only submissions that have a matching assignment are counted

**`sub.marks IS NULL`**
- `IS NULL` — SQL way to check for NULL values (NOT `= NULL` — `NULL = NULL` is `NULL` in SQL, not `TRUE`!)
- `marks IS NULL` means the submission hasn't been graded yet
- This counts only UNGRADED submissions — the "pending reviews" count for the teacher

---

### Query 3 — Active Projects

```sql
SELECT COUNT(*) AS total FROM projects WHERE created_by = $1
```

Simple count of all projects created by this teacher. No join needed.

---

### Building the Response

```js
res.json({
  success: true,
  stats: {
    totalStudents: parseInt(studentRes.rows[0]?.total ?? 0),
    pendingReviews: parseInt(pendingRes.rows[0]?.total ?? 0),
    activeProjects: parseInt(projectRes.rows[0]?.total ?? 0),
    totalSubjects: channelIds.length,
  },
});
```

**`studentRes.rows[0]?.total`**
- `?.total` — optional chaining. If `rows[0]` is undefined (shouldn't happen with COUNT, but defensive), returns `undefined` instead of crashing
- `COUNT(*)` always returns exactly one row, but `?.` is a safety net

**`?? 0`** — nullish coalescing: if `?.total` is `undefined` or `null`, use `0`

**`parseInt(...)`** — COUNT returns strings from PostgreSQL (bigint type), parse to number

**`totalSubjects: channelIds.length`** — no query needed! We already have the channel IDs array from the first query. Its `.length` is the number of subjects.

---

## Lines 72–103 — `getTeacherRecentActivity`

```js
const getTeacherRecentActivity = async (req, res) => {
  const teacherId = req.user.id;
  const channelRes = await pool.query(
    `SELECT id, subject_name FROM channels WHERE teacher_id = $1`, [teacherId]
  );
  const channels = channelRes.rows;
  const channelIds = channels.map(r => r.id);

  if (channelIds.length === 0) {
    return res.json({ success: true, announcements: [], recentMessages: [] });
  }

  const annRes = await pool.query(
    `SELECT ann.*, u.name AS created_by_name, ch.subject_name
     FROM announcements ann
     INNER JOIN users u ON ann.user_id = u.id
     INNER JOIN channels ch ON ann.channel_id = ch.id
     WHERE ann.channel_id = ANY($1::int[])
     ORDER BY ann.created_at DESC
     LIMIT 5`,
    [channelIds]
  );

  res.json({ success: true, announcements: annRes.rows, recentMessages: [] });
};
```

### Two JOINs in One Query

```sql
FROM announcements ann
INNER JOIN users u ON ann.user_id = u.id
INNER JOIN channels ch ON ann.channel_id = ch.id
```

**Three tables joined:**
1. `announcements ann` — the base table
2. `INNER JOIN users u` — to get the poster's name (`u.name AS created_by_name`)
3. `INNER JOIN channels ch` — to get the subject name (`ch.subject_name`)

This gives the dashboard enough info to display:
```
"Dr. Smith posted in CS101: Exam next Monday"
```

**`LIMIT 5`** — only the 5 most recent announcements for the activity feed

**`recentMessages: []`** — hardcoded empty array. Real-time recent messages would require more complex logic (or a separate endpoint). This is a planned feature placeholder.

---

## Lines 110–145 — `getStudentRecentActivity`

```js
const getStudentRecentActivity = async (req, res) => {
  const studentId = req.user.id;

  const enrollRes = await pool.query(
    `SELECT e.channel_id, ch.subject_name
     FROM enrollments e
     INNER JOIN channels ch ON ch.id = e.channel_id
     WHERE e.user_id = $1`,
    [studentId]
  );

  const channelIds = enrollRes.rows.map(r => parseInt(r.channel_id));
  ...
};
```

### `parseInt(r.channel_id)` vs `.id` in teacher function

In `getTeacherStats`, we use `.map(r => r.id)` — the `channels` table's `id` is an integer in PostgreSQL, returned as a JavaScript number.

Here, `channelIds = enrollRes.rows.map(r => parseInt(r.channel_id))` — `enrollments.channel_id` is a foreign key, and the `pg` driver sometimes returns it as a string. `parseInt` ensures it's a number before being used in `ANY($1::int[])`.

**The rest of `getStudentRecentActivity` is identical to `getTeacherRecentActivity`** — same announcement query, same response shape. The difference is WHERE the channel IDs come from:
- **Teacher**: `WHERE teacher_id = $1` (channels they teach)
- **Student**: `WHERE e.user_id = $1` (channels they're enrolled in)

---

## Summary Table

| Function | Method | URL | Key Technique |
|---|---|---|---|
| `getTeacherStats` | GET | `/api/teacher/stats` | `Promise.all` for parallel queries, `ANY($1::int[])` for array filtering |
| `getTeacherRecentActivity` | GET | `/api/teacher/recent-activity` | Double JOIN (announcements + users + channels), LIMIT 5 |
| `getStudentRecentActivity` | GET | `/api/teacher/student-activity` | Same query pattern but filtered by enrollments |

| SQL Technique | Where Used | Why |
|---|---|---|
| `COUNT(DISTINCT column)` | Total students | Prevent double-counting enrolled in multiple channels |
| `= ANY($1::int[])` | Channel ID filtering | Match multiple IDs without IN clause |
| `IS NULL` | Pending submissions | NULL check for ungraded assignments |
| `Promise.all` | Stats queries | Run 3 queries simultaneously instead of sequentially |
