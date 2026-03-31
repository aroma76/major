const pool = require('../config/db');

// GET /api/projects — all projects user is part of
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

// GET /api/projects/:id — single project with tasks
const getProject = async (req, res) => {
  const project = await pool.query(
    `SELECT p.*, u.name AS created_by_name FROM projects p JOIN users u ON p.created_by = u.id WHERE p.id = $1`,
    [req.params.id]
  );
  if (!project.rows.length) return res.status(404).json({ success: false, message: 'Project not found' });

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

// POST /api/projects — create project
const createProject = async (req, res) => {
  const { title, description, deadline, member_ids } = req.body;
  if (!title) return res.status(400).json({ success: false, message: 'title required' });

  const result = await pool.query(
    `INSERT INTO projects (title, description, deadline, created_by, progress) VALUES ($1, $2, $3, $4, 0) RETURNING *`,
    [title, description || null, deadline || null, req.user.id]
  );
  const project = result.rows[0];

  // Auto-add creator as member
  const allMembers = [req.user.id, ...(member_ids || [])].filter((v, i, a) => a.indexOf(v) === i);
  await Promise.all(allMembers.map(uid =>
    pool.query(`INSERT INTO project_members (project_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`, [project.id, uid])
  ));

  res.status(201).json({ success: true, project });
};

// PATCH /api/projects/:id/progress — update progress percentage
const updateProgress = async (req, res) => {
  const { progress } = req.body;
  if (progress === undefined || progress < 0 || progress > 100)
    return res.status(400).json({ success: false, message: 'progress must be 0–100' });
  const result = await pool.query(
    `UPDATE projects SET progress = $1 WHERE id = $2 RETURNING *`, [progress, req.params.id]
  );
  res.json({ success: true, project: result.rows[0] });
};

// DELETE /api/projects/:id
const deleteProject = async (req, res) => {
  await pool.query('DELETE FROM projects WHERE id = $1', [req.params.id]);
  res.json({ success: true, message: 'Project deleted' });
};

// POST /api/projects/:id/tasks — create task in project
const createTask = async (req, res) => {
  const { title, description, assigned_to, due_date, priority } = req.body;
  if (!title) return res.status(400).json({ success: false, message: 'title required' });
  const result = await pool.query(
    `INSERT INTO project_tasks (project_id, title, description, assigned_to, due_date, priority, status, created_by)
     VALUES ($1, $2, $3, $4, $5, $6, 'todo', $7) RETURNING *`,
    [req.params.id, title, description || null, assigned_to || null, due_date || null, priority || 'medium', req.user.id]
  );
  res.status(201).json({ success: true, task: result.rows[0] });
};

// PATCH /api/projects/:id/tasks/:taskId/status — Kanban drag
const updateTaskStatus = async (req, res) => {
  const { status } = req.body;
  const allowed = ['todo', 'in_progress', 'done'];
  if (!allowed.includes(status)) return res.status(400).json({ success: false, message: 'Invalid status' });
  const result = await pool.query(
    `UPDATE project_tasks SET status = $1 WHERE id = $2 AND project_id = $3 RETURNING *`,
    [status, req.params.taskId, req.params.id]
  );
  if (!result.rows.length) return res.status(404).json({ success: false, message: 'Task not found' });

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

module.exports = { getProjects, getProject, createProject, updateProgress, deleteProject, createTask, updateTaskStatus };
