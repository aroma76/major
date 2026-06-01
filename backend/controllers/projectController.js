const pool = require('../config/db');

/**
 * Auto-migration: ensure custom_members column exists on the projects table.
 * Runs once on first import — safe to run repeatedly (IF NOT EXISTS).
 */
pool.query(`ALTER TABLE projects ADD COLUMN IF NOT EXISTS custom_members TEXT DEFAULT ''`)
  .catch(err => console.warn('Migration warning (custom_members):', err.message));

pool.query(`ALTER TABLE project_tasks ADD COLUMN IF NOT EXISTS assigned_to_name TEXT DEFAULT NULL`)
  .catch(err => console.warn('Migration warning (assigned_to_name):', err.message));

// ─── Helpers ──────────────────────────────────────────────────────────────────

/** Parse "Alice, Bob, Charlie" → ["Alice", "Bob", "Charlie"] */
const parseMembers = (raw) =>
  (raw || '').split(',').map(n => n.trim()).filter(Boolean);

/** ["Alice", "Bob"] → "Alice, Bob" */
const joinMembers = (arr) => (arr || []).filter(Boolean).join(', ');

// ─── Controllers ──────────────────────────────────────────────────────────────

/**
 * GET /api/projects
 * Retrieves all projects that the logged-in user is a member of (either via
 * project_members table OR listed in custom_members by the creator).
 */
const getProjects = async (req, res) => {
  const result = await pool.query(
    `SELECT p.*,
            u.name AS created_by_name,
            (SELECT COUNT(*) FROM project_tasks pt WHERE pt.project_id = p.id) AS task_count,
            (SELECT COUNT(*) FROM project_tasks pt WHERE pt.project_id = p.id AND pt.status = 'done') AS done_count
     FROM projects p
     JOIN users u ON p.created_by = u.id
     WHERE p.id IN (
       SELECT project_id FROM project_members WHERE user_id = $1
     )
     ORDER BY p.created_at DESC`,
    [req.user.id]
  );

  // Parse custom_members for each project
  const projects = result.rows.map(p => ({
    ...p,
    member_names: parseMembers(p.custom_members),
  }));

  res.json({ success: true, projects });
};

/**
 * GET /api/projects/:id
 * Retrieves detailed information for a specific project.
 * Returns custom_members as a parsed array + all project tasks.
 */
const getProject = async (req, res) => {
  const project = await pool.query(
    `SELECT p.*, u.name AS created_by_name
     FROM projects p
     JOIN users u ON p.created_by = u.id
     WHERE p.id = $1`,
    [req.params.id]
  );
  if (!project.rows.length)
    return res.status(404).json({ success: false, message: 'Project not found' });

  const tasks = await pool.query(
    `SELECT pt.* FROM project_tasks pt WHERE pt.project_id = $1 ORDER BY pt.created_at DESC`,
    [req.params.id]
  );

  const p = project.rows[0];
  const memberNames = parseMembers(p.custom_members);

  // Attach assigned_to_name from custom_members for each task
  const tasksWithNames = tasks.rows.map(t => ({
    ...t,
    assigned_to_name: t.assigned_to_name || null,
  }));

  res.json({
    success: true,
    project: {
      ...p,
      member_names: memberNames,
      // Keep members as array of {id, name} for backwards compat
      members: memberNames.map((name, i) => ({ id: i, name })),
      tasks: tasksWithNames,
    }
  });
};

/**
 * POST /api/projects
 * Creates a new project. Accepts member_names as array of strings.
 * Body: { title, description?, deadline?, member_names? }
 */
const createProject = async (req, res) => {
  const { title, description, deadline, member_names } = req.body;
  if (!title)
    return res.status(400).json({ success: false, message: 'title required' });

  if (title.length > 255)
    return res.status(400).json({ success: false, message: 'title too long (max 255 chars)' });
  if (description && description.length > 2000)
    return res.status(400).json({ success: false, message: 'description too long (max 2000 chars)' });

  const customMembers = joinMembers(Array.isArray(member_names) ? member_names : []);

  const result = await pool.query(
    `INSERT INTO projects (title, description, deadline, created_by, progress, custom_members)
     VALUES ($1, $2, $3, $4, 0, $5) RETURNING *`,
    [title, description || null, deadline || null, req.user.id, customMembers]
  );
  const project = result.rows[0];

  // Always add the creator as a system member so they can see the project
  await pool.query(
    `INSERT INTO project_members (project_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
    [project.id, req.user.id]
  );

  res.status(201).json({ success: true, project });
};

/**
 * PATCH /api/projects/:id/members
 * Replaces the custom member names list for a project.
 * Body: { member_names: ["Alice", "Bob", ...] }
 */
const updateMembers = async (req, res) => {
  const { member_names } = req.body;
  if (!Array.isArray(member_names))
    return res.status(400).json({ success: false, message: 'member_names must be an array' });

  const custom = joinMembers(member_names);
  const result = await pool.query(
    `UPDATE projects SET custom_members = $1 WHERE id = $2 RETURNING *`,
    [custom, req.params.id]
  );
  if (!result.rows.length)
    return res.status(404).json({ success: false, message: 'Project not found' });

  res.json({ success: true, member_names: parseMembers(custom) });
};

/**
 * PATCH /api/projects/:id/progress
 * Updates the overall progress percentage (0-100) of a project.
 */
const updateProgress = async (req, res) => {
  const { progress } = req.body;
  if (progress == null || progress < 0 || progress > 100)
    return res.status(400).json({ success: false, message: 'progress must be 0-100' });

  const result = await pool.query(
    `UPDATE projects SET progress = $1 WHERE id = $2 RETURNING *`, [progress, req.params.id]
  );
  res.json({ success: true, project: result.rows[0] });
};

/**
 * DELETE /api/projects/:id
 * Permanently deletes a project. Restricted to the creator.
 */
const deleteProject = async (req, res) => {
  const check = await pool.query('SELECT created_by FROM projects WHERE id = $1', [req.params.id]);
  if (!check.rows.length)
    return res.status(404).json({ success: false, message: 'Project not found' });
  if (check.rows[0].created_by !== req.user.id)
    return res.status(403).json({ success: false, message: 'Not authorized to delete this project' });

  await pool.query('DELETE FROM projects WHERE id = $1', [req.params.id]);
  res.json({ success: true, message: 'Project deleted' });
};

/**
 * POST /api/projects/:id/tasks
 * Adds a new task to a project.
 * Body: { title, description?, assigned_to_name?, due_date?, priority? }
 */
const createTask = async (req, res) => {
  const { title, description, assigned_to_name, due_date, priority } = req.body;
  if (!title)
    return res.status(400).json({ success: false, message: 'title required' });

  const result = await pool.query(
    `INSERT INTO project_tasks
       (project_id, title, description, assigned_to_name, due_date, priority, status, created_by)
     VALUES ($1, $2, $3, $4, $5, $6, 'todo', $7) RETURNING *`,
    [req.params.id, title, description || null, assigned_to_name || null,
     due_date || null, priority || 'medium', req.user.id]
  );
  res.status(201).json({ success: true, task: result.rows[0] });
};

/**
 * PATCH /api/projects/:id/tasks/:taskId/status
 * Updates a task's status. Recalculates project progress.
 */
const updateTaskStatus = async (req, res) => {
  const { status } = req.body;
  const allowed = ['todo', 'in_progress', 'done'];
  if (!allowed.includes(status))
    return res.status(400).json({ success: false, message: 'Invalid status' });

  const result = await pool.query(
    `UPDATE project_tasks SET status = $1 WHERE id = $2 AND project_id = $3 RETURNING *`,
    [status, req.params.taskId, req.params.id]
  );
  if (!result.rows.length)
    return res.status(404).json({ success: false, message: 'Task not found' });

  const counts = await pool.query(
    `SELECT COUNT(*) AS total, COUNT(*) FILTER (WHERE status = 'done') AS done
     FROM project_tasks WHERE project_id = $1`,
    [req.params.id]
  );
  const { total, done } = counts.rows[0];
  const progress = total > 0 ? Math.round((done / total) * 100) : 0;
  await pool.query(`UPDATE projects SET progress = $1 WHERE id = $2`, [progress, req.params.id]);

  res.json({ success: true, task: result.rows[0], progress });
};

/**
 * DELETE /api/projects/:id/tasks/:taskId
 * Permanently deletes a task. Recalculates project progress.
 */
const deleteTask = async (req, res) => {
  const result = await pool.query(
    `DELETE FROM project_tasks WHERE id = $1 AND project_id = $2 RETURNING *`,
    [req.params.taskId, req.params.id]
  );
  if (!result.rows.length)
    return res.status(404).json({ success: false, message: 'Task not found' });

  const counts = await pool.query(
    `SELECT COUNT(*) AS total, COUNT(*) FILTER (WHERE status = 'done') AS done
     FROM project_tasks WHERE project_id = $1`,
    [req.params.id]
  );
  const { total, done } = counts.rows[0];
  const progress = total > 0 ? Math.round((done / total) * 100) : 0;
  await pool.query(`UPDATE projects SET progress = $1 WHERE id = $2`, [progress, req.params.id]);

  res.json({ success: true, message: 'Task deleted', progress });
};

module.exports = {
  getProjects, getProject, createProject, updateProgress, updateMembers,
  deleteProject, createTask, updateTaskStatus, deleteTask
};
