# Word-by-Word Deep Dive: `backend/controllers/projectController.js`

> This file manages **personal projects** — the collaborative workspace feature where faculty or students can create projects, add team members, manage tasks on a Kanban board, and track progress automatically. It introduces several advanced SQL techniques: `array_agg`, subqueries in SELECT, `COUNT(*) FILTER`, and automatic progress recalculation.

---

## Lines 8–26 — `getProjects` — The Most Complex Query

```js
const getProjects = async (req, res) => {
  const result = await pool.query(
    `SELECT p.*,
            u.name AS created_by_name,
            array_agg(DISTINCT m.user_id) AS member_ids,
            array_agg(DISTINCT mu.name) AS member_names,
            (SELECT COUNT(*) FROM project_tasks pt WHERE pt.project_id = p.id) AS task_count,
            (SELECT COUNT(*) FROM project_tasks pt WHERE pt.project_id = p.id AND pt.status = 'done') AS done_count
     FROM projects p
     JOIN project_members pm ON pm.project_id = p.id AND pm.user_id = $1
     JOIN users u ON p.created_by = u.id
     LEFT JOIN project_members m ON m.project_id = p.id
     LEFT JOIN users mu ON mu.id = m.user_id
     GROUP BY p.id, u.name
     ORDER BY p.created_at DESC`,
    [req.user.id]
  );
  res.json({ success: true, projects: result.rows });
};
```

### `JOIN project_members pm ON pm.project_id = p.id AND pm.user_id = $1`

**`JOIN`** (without LEFT) — this is an **INNER JOIN**. It FILTERS results:
- Only projects where the logged-in user is a member appear
- `AND pm.user_id = $1` — the user must be in `project_members` for this project
- This is the access control: you only see projects you're part of

This is different from the next LEFT JOINs which collect ALL members.

### `LEFT JOIN project_members m ON m.project_id = p.id`

A SECOND join on `project_members` (alias `m`) — but this one is LEFT JOIN (no user filter):
- Gets ALL members of each project (not just the logged-in user)
- Combined with `array_agg(DISTINCT m.user_id)` to build a list

### `array_agg(DISTINCT m.user_id) AS member_ids`

**`array_agg(column)`** — PostgreSQL aggregate function. Collects all values of `column` across the GROUP into a PostgreSQL array.
- `array_agg(m.user_id)` for a project with members 1, 2, 3 → `{1, 2, 3}`
- This array is returned to JavaScript as `[1, 2, 3]`

**`DISTINCT`** — deduplicate. Without it, if multiple LEFT JOIN rows produce the same user_id, it would appear multiple times in the array.

**`array_agg(DISTINCT mu.name) AS member_names`** — same but for names: `['Alice', 'Bob', 'Dr. Smith']`

### Correlated Subqueries in SELECT

```sql
(SELECT COUNT(*) FROM project_tasks pt WHERE pt.project_id = p.id) AS task_count,
(SELECT COUNT(*) FROM project_tasks pt WHERE pt.project_id = p.id AND pt.status = 'done') AS done_count
```

**A subquery in SELECT** — a complete SQL query inside `(...)` used as a column value.
- Runs ONCE FOR EACH ROW in the outer query (called a **correlated subquery**)
- `pt.project_id = p.id` — the `p.id` refers to the OUTER query's current project row
- For each project, it counts total tasks and done tasks separately

**`AS task_count`** and **`AS done_count`** — alias these subquery results as columns

**Why not another LEFT JOIN + GROUP BY for tasks?** — Adding tasks to the JOIN would require another `array_agg` and complex GROUP BY. Subqueries are cleaner here.

### `GROUP BY p.id, u.name`

Required because we use aggregate functions (`array_agg`, subqueries). All non-aggregate SELECT columns must appear in GROUP BY. `p.*` → needs `p.id` (PostgreSQL accepts this as the primary key grouping).

---

## Lines 33–53 — `getProject` — Building a Nested Object

```js
const getProject = async (req, res) => {
  const project = await pool.query(
    `SELECT p.*, u.name AS created_by_name FROM projects p JOIN users u ON p.created_by = u.id WHERE p.id = $1`,
    [req.params.id]
  );
  if (!project.rows.length) return res.status(404).json({...});

  const members = await pool.query(
    `SELECT u.id, u.name, u.email, u.role, pm.joined_at FROM project_members pm JOIN users u ON u.id = pm.user_id WHERE pm.project_id = $1`,
    [req.params.id]
  );
  const tasks = await pool.query(
    `SELECT pt.*, u.name AS assigned_to_name FROM project_tasks pt LEFT JOIN users u ON u.id = pt.assigned_to WHERE pt.project_id = $1 ORDER BY pt.created_at DESC`,
    [req.params.id]
  );

  res.json({
    success: true,
    project: { ...project.rows[0], members: members.rows, tasks: tasks.rows }
  });
};
```

### Three Sequential Queries

Unlike `getProjects` (one complex query), `getProject` uses three separate simpler queries. This is a valid tradeoff when the data is needed in nested form (project + its members array + its tasks array).

### `{ ...project.rows[0], members: members.rows, tasks: tasks.rows }`

**Spread operator** — merges the project object with two new properties:
- `...project.rows[0]` — spreads all project columns: `id, title, description, progress, created_by, ...`
- `members: members.rows` — adds a `members` key with the array of member objects
- `tasks: tasks.rows` — adds a `tasks` key with the array of task objects

Result is ONE nested object — Flutter receives a single, complete project object.

### `LEFT JOIN users u ON u.id = pt.assigned_to`

**LEFT JOIN** for tasks — because `assigned_to` can be NULL (task not assigned to anyone). INNER JOIN would exclude unassigned tasks.

---

## Lines 61–82 — `createProject`

```js
const createProject = async (req, res) => {
  ...
  const result = await pool.query(
    `INSERT INTO projects (title, description, deadline, created_by, progress) VALUES ($1, $2, $3, $4, 0) RETURNING *`,
    [title, description || null, deadline || null, req.user.id]
  );
  const project = result.rows[0];

  const allMembers = [req.user.id, ...(member_ids || [])].filter((v, i, a) => a.indexOf(v) === i);
  await Promise.all(allMembers.map(uid =>
    pool.query(`INSERT INTO project_members (project_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`, [project.id, uid])
  ));

  res.status(201).json({ success: true, project });
};
```

### `progress: 0` — hardcoded

New projects start at 0% progress. Not user-settable at creation.

### Building the Members Array — Deduplication

```js
const allMembers = [req.user.id, ...(member_ids || [])].filter((v, i, a) => a.indexOf(v) === i);
```

**`[req.user.id, ...(member_ids || [])]`**
- `req.user.id` — the creator, always added as first element
- `...(member_ids || [])` — spread the provided member IDs array (or empty array if none)
- Result: `[1, 2, 3, 1]` (if user 1 is the creator AND also in the `member_ids` list)

**`.filter((v, i, a) => a.indexOf(v) === i)`** — deduplication using filter:
- `v` = current value, `i` = current index, `a` = the full array
- `a.indexOf(v)` — finds the FIRST occurrence of `v` in `a`
- `=== i` — if the first occurrence equals the current index, this is the first occurrence → keep it
- If `i !== a.indexOf(v)` → this is a duplicate → filter it out
- Example: `[1, 2, 3, 1]` → `[1, 2, 3]` (duplicate 1 removed)

### `INSERT INTO project_members ... ON CONFLICT DO NOTHING`

**`ON CONFLICT DO NOTHING`** — PostgreSQL upsert syntax:
- If a row with the same `(project_id, user_id)` already exists (violates UNIQUE constraint), skip silently instead of throwing an error
- Safer than wrapping each INSERT in try/catch

---

## Lines 89–104 — `updateProgress`

```js
const updateProgress = async (req, res) => {
  const { progress } = req.body;
  if (progress === undefined || progress < 0 || progress > 100)
    return res.status(400).json({...});

  const check = await pool.query('SELECT created_by FROM projects WHERE id = $1', [req.params.id]);
  if (!check.rows.length) return res.status(404).json({...});
  if (check.rows[0].created_by !== req.user.id)
    return res.status(403).json({...});
  ...
};
```

### `progress === undefined`

**`===`** — strict equality. `progress` could be `0` (valid) — `if (!progress)` would incorrectly reject 0. `=== undefined` correctly checks only for missing.

### `check.rows[0].created_by !== req.user.id`

**Authorization check at the data level** — only the creator can change the manual progress.
- `!==` — strict inequality
- Both are numbers (integer user IDs) — strict comparison is safe here

---

## Lines 142–163 — `updateTaskStatus` — Auto-Progress Calculation

```js
const updateTaskStatus = async (req, res) => {
  const { status } = req.body;
  const allowed = ['todo', 'in_progress', 'done'];
  if (!allowed.includes(status)) return res.status(400).json({...});

  const result = await pool.query(
    `UPDATE project_tasks SET status = $1 WHERE id = $2 AND project_id = $3 RETURNING *`,
    [status, req.params.taskId, req.params.id]
  );
  if (!result.rows.length) return res.status(404).json({...});

  // Auto-update project progress
  const counts = await pool.query(
    `SELECT COUNT(*) AS total, COUNT(*) FILTER (WHERE status = 'done') AS done FROM project_tasks WHERE project_id = $1`,
    [req.params.id]
  );
  const { total, done } = counts.rows[0];
  const progress = total > 0 ? Math.round((done / total) * 100) : 0;
  await pool.query(`UPDATE projects SET progress = $1 WHERE id = $2`, [progress, req.params.id]);

  res.json({ success: true, task: result.rows[0], progress });
};
```

### `WHERE id = $2 AND project_id = $3`

**Double condition** — ensures the task actually belongs to this project. Prevents editing tasks from other projects by guessing the task ID.

### `COUNT(*) FILTER (WHERE status = 'done') AS done`

**`FILTER (WHERE condition)`** — PostgreSQL extension to aggregate functions. Counts only rows matching the filter condition.

```sql
SELECT COUNT(*) AS total,
       COUNT(*) FILTER (WHERE status = 'done') AS done
FROM project_tasks WHERE project_id = $1
```

In one query, gets both:
- `total` = all tasks in the project
- `done` = only tasks with `status = 'done'`

Alternative (less elegant): two separate COUNT queries.

### `const { total, done } = counts.rows[0];`

Destructures the single result row. `total` and `done` are strings (PostgreSQL bigint → JS string).

### `const progress = total > 0 ? Math.round((done / total) * 100) : 0;`

**`total > 0`** — guard against division by zero. If no tasks exist, progress = 0.

**`(done / total) * 100`** — `done` and `total` are strings. JavaScript **coerces** strings to numbers in arithmetic:
- `'3' / '5'` → `0.6` (JS converts strings to numbers automatically in division)
- `0.6 * 100 = 60`

**`Math.round(...)`** — rounds to nearest integer. `60.666...` → `61`.

**Result**: If 3 of 5 tasks are done → `progress = 60` (%). Automatically stored and returned.

---

## Summary Table

| Function | Method | URL | Key Feature |
|---|---|---|---|
| `getProjects` | GET | `/api/projects` | `array_agg`, correlated subqueries, member filtering via JOIN |
| `getProject` | GET | `/api/projects/:id` | Three queries merged into nested object with spread |
| `createProject` | POST | `/api/projects` | Creator auto-added, deduplication, `ON CONFLICT DO NOTHING` |
| `updateProgress` | PATCH | `/api/projects/:id/progress` | Creator-only authorization |
| `deleteProject` | DELETE | `/api/projects/:id` | Creator-only authorization |
| `createTask` | POST | `/api/projects/:id/tasks` | Simple task creation with defaults |
| `updateTaskStatus` | PATCH | `.../:taskId/status` | Auto-recalculates project % using `FILTER` aggregate |

| SQL Technique | Where | What It Does |
|---|---|---|
| `array_agg(DISTINCT ...)` | `getProjects` | Collect all member IDs/names into array |
| Correlated subqueries in SELECT | `getProjects` | Count tasks per project inline |
| `INNER JOIN` for filtering | `getProjects` | Only projects the user is a member of |
| `ON CONFLICT DO NOTHING` | `createProject` | Safe INSERT ignoring duplicates |
| `COUNT(*) FILTER (WHERE ...)` | `updateTaskStatus` | Count done tasks in same query as total |
