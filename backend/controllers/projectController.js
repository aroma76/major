const pool = require('../config/db');

/**
 * GET /api/projects
 * Retrieves all projects that the logged-in user is a member of.
 * Groups by project and aggregates all members and task completion stats into arrays/counts.
 */
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

/**
 * GET /api/projects/:id
 * Retrieves detailed information for a specific project.
 * Includes all associated members and project tasks.
 */
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

/**
 * POST /api/projects
 * Creates a new project and automatically adds the creator and specified members to it.
 * 
 * Body: { title, description?, deadline?, member_ids? }
 */
const createProject = async (req, res) => {
  const { title, description, deadline, member_ids } = req.body;
  if (!title) return res.status(400).json({ success: false, message: 'title required' });
  
  // [M3] Input length limits
  if (title.length > 255) return res.status(400).json({ success: false, message: 'title too long (max 255 chars)' });
  if (description && description.length > 2000) return res.status(400).json({ success: false, message: 'description too long (max 2000 chars)' });

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

/**
 * PATCH /api/projects/:id/progress
 * Manually updates the progress percentage of a project.
 * Restricted to the user who created the project.
 */
const updateProgress = async (req, res) => {
  const { progress } = req.body;
  if (progress === undefined || progress < 0 || progress > 100)
    return res.status(400).json({ success: false, message: 'progress must be 0–100' });
    
  // [C2] Only the project creator can manually set progress
  const check = await pool.query('SELECT created_by FROM projects WHERE id = $1', [req.params.id]);
  if (!check.rows.length) return res.status(404).json({ success: false, message: 'Project not found' });
  if (check.rows[0].created_by !== req.user.id)
    return res.status(403).json({ success: false, message: 'Not authorized to update this project' });
    
  const result = await pool.query(
    `UPDATE projects SET progress = $1 WHERE id = $2 RETURNING *`, [progress, req.params.id]
  );
  res.json({ success: true, project: result.rows[0] });
};

/**
 * DELETE /api/projects/:id
 * Permanently deletes a project. Restricted to the user who created the project.
 */
const deleteProject = async (req, res) => {
  // [C2] Only the creator can delete a project
  const check = await pool.query('SELECT created_by FROM projects WHERE id = $1', [req.params.id]);
  if (!check.rows.length) return res.status(404).json({ success: false, message: 'Project not found' });
  if (check.rows[0].created_by !== req.user.id)
    return res.status(403).json({ success: false, message: 'Not authorized to delete this project' });
    
  await pool.query('DELETE FROM projects WHERE id = $1', [req.params.id]);
  res.json({ success: true, message: 'Project deleted' });
};

/**
 * POST /api/projects/:id/tasks
 * Adds a new task to a project's Kanban board.
 */
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

/**
 * PATCH /api/projects/:id/tasks/:taskId/status
 * Updates a task's status on the Kanban board (todo, in_progress, done).
 * Automatically recalculates and updates the overall project progress based on completed tasks.
 */
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

/**
 * DELETE /api/projects/:id/tasks/:taskId
 * Permanently deletes a task from a project.
 * Automatically recalculates project progress after deletion.
 */
const deleteTask = async (req, res) => {
  const result = await pool.query(
    `DELETE FROM project_tasks WHERE id = $1 AND project_id = $2 RETURNING *`,
    [req.params.taskId, req.params.id]
  );
  if (!result.rows.length)
    return res.status(404).json({ success: false, message: 'Task not found' });

  // Recalculate project progress
  const counts = await pool.query(
    `SELECT COUNT(*) AS total, COUNT(*) FILTER (WHERE status = 'done') AS done FROM project_tasks WHERE project_id = $1`,
    [req.params.id]
  );
  const { total, done } = counts.rows[0];
  const progress = total > 0 ? Math.round((done / total) * 100) : 0;
  await pool.query(`UPDATE projects SET progress = $1 WHERE id = $2`, [progress, req.params.id]);

  res.json({ success: true, message: 'Task deleted', progress });
};

module.exports = { getProjects, getProject, createProject, updateProgress, deleteProject, createTask, updateTaskStatus, deleteTask };
