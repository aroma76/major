const pool = require('../config/db');

/**
 * Auto-migration: ensure assigned_to_name column exists on project_tasks.
 * custom_members is no longer used — members now live in project_members table.
 */
pool.query(`ALTER TABLE project_tasks ADD COLUMN IF NOT EXISTS assigned_to_name TEXT DEFAULT NULL`)
  .catch(err => console.warn('Migration warning (assigned_to_name):', err.message));

// ─── Controllers ──────────────────────────────────────────────────────────────

/**
 * GET /api/projects
 * Retrieves all projects that the logged-in user is a member of.
 * Members are read from project_members JOIN users (real accounts).
 */
const getProjects = async (req, res) => {
  const result = await pool.query(
    `SELECT p.*,
            u.name AS created_by_name,
            (SELECT COUNT(*) FROM project_tasks pt WHERE pt.project_id = p.id) AS task_count,
            (SELECT COUNT(*) FROM project_tasks pt WHERE pt.project_id = p.id AND pt.status = 'done') AS done_count,
            COALESCE(
              (SELECT json_agg(json_build_object('id', mu.id, 'name', mu.name))
               FROM project_members pm
               JOIN users mu ON pm.user_id = mu.id
               WHERE pm.project_id = p.id),
              '[]'
            ) AS members
     FROM projects p
     JOIN users u ON p.created_by = u.id
     WHERE p.id IN (
       SELECT project_id FROM project_members WHERE user_id = $1
     )
     ORDER BY p.created_at DESC`,
    [req.user.id]
  );

  const projects = result.rows.map(p => ({
    ...p,
    member_names: (p.members || []).map(m => m.name),
  }));

  res.json({ success: true, projects });
};

/**
 * GET /api/projects/:id
 * Retrieves detailed information for a specific project.
 * Returns real member list from project_members + all tasks.
 */
const getProject = async (req, res) => {
  const project = await pool.query(
    `SELECT p.*, u.name AS created_by_name,
            COALESCE(
              (SELECT json_agg(json_build_object('id', mu.id, 'name', mu.name))
               FROM project_members pm
               JOIN users mu ON pm.user_id = mu.id
               WHERE pm.project_id = p.id),
              '[]'
            ) AS members
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
  const members = p.members || [];
  const memberNames = members.map(m => m.name);

  res.json({
    success: true,
    project: {
      ...p,
      member_names: memberNames,
      members,
      tasks: tasks.rows,
    }
  });
};

/**
 * POST /api/projects
 * Creates a new project. Creator is automatically added as a member.
 * Body: { title, description?, deadline? }
 */
const createProject = async (req, res) => {
  const { title, description, deadline } = req.body;
  if (!title)
    return res.status(400).json({ success: false, message: 'title required' });
  if (title.length > 255)
    return res.status(400).json({ success: false, message: 'title too long (max 255 chars)' });
  if (description && description.length > 2000)
    return res.status(400).json({ success: false, message: 'description too long (max 2000 chars)' });

  const result = await pool.query(
    `INSERT INTO projects (title, description, deadline, created_by, progress)
     VALUES ($1, $2, $3, $4, 0) RETURNING *`,
    [title, description || null, deadline || null, req.user.id]
  );
  const project = result.rows[0];

  // Always add the creator as a member
  await pool.query(
    `INSERT INTO project_members (project_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
    [project.id, req.user.id]
  );

  res.status(201).json({ success: true, project });
};

/**
 * GET /api/projects/:id/students
 * Returns students who can be added to this project.
 *
 * Priority 1: Students enrolled in the same channels as the project creator.
 * Fallback (if 0 results): Students with the same programme_id + semester as creator.
 * Always excludes existing project members and the creator themselves.
 */
const getClassroomStudents = async (req, res) => {
  // Find the project and creator info
  const proj = await pool.query(
    `SELECT p.created_by, u.programme_id, u.current_semester
     FROM projects p
     JOIN users u ON p.created_by = u.id
     WHERE p.id = $1`,
    [req.params.id]
  );
  if (!proj.rows.length)
    return res.status(404).json({ success: false, message: 'Project not found' });

  const { created_by: creatorId, programme_id, current_semester } = proj.rows[0];

  // Priority 1: same enrolled channels
  const byEnrollment = await pool.query(
    `SELECT DISTINCT u.id, u.name, u.roll_number
     FROM users u
     JOIN enrollments e ON e.user_id = u.id
     WHERE u.role = 'student'
       AND e.channel_id IN (
         SELECT channel_id FROM enrollments WHERE user_id = $1
       )
       AND u.id NOT IN (
         SELECT user_id FROM project_members WHERE project_id = $2
       )
       AND u.id != $1
     ORDER BY u.name`,
    [creatorId, req.params.id]
  );

  if (byEnrollment.rows.length > 0) {
    return res.json({ success: true, students: byEnrollment.rows });
  }

  // Fallback: same programme + semester (even if not enrolled in any channel yet)
  const byCohort = await pool.query(
    `SELECT id, name, roll_number
     FROM users
     WHERE role = 'student'
       AND programme_id = $1
       AND current_semester = $2
       AND id != $3
       AND id NOT IN (
         SELECT user_id FROM project_members WHERE project_id = $4
       )
     ORDER BY name`,
    [programme_id, current_semester, creatorId, req.params.id]
  );

  res.json({ success: true, students: byCohort.rows });
};

/**
 * POST /api/projects/:id/members
 * Adds a student (by user_id) to a project.
 * Body: { user_id: number }
 */
const addMember = async (req, res) => {
  const { user_id } = req.body;
  if (!user_id)
    return res.status(400).json({ success: false, message: 'user_id required' });

  // Verify the project exists and request comes from the creator
  const proj = await pool.query('SELECT created_by FROM projects WHERE id = $1', [req.params.id]);
  if (!proj.rows.length)
    return res.status(404).json({ success: false, message: 'Project not found' });
  if (proj.rows[0].created_by !== req.user.id)
    return res.status(403).json({ success: false, message: 'Only the project creator can add members' });

  await pool.query(
    `INSERT INTO project_members (project_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
    [req.params.id, user_id]
  );

  // Return the added member's info
  const user = await pool.query('SELECT id, name FROM users WHERE id = $1', [user_id]);
  res.status(201).json({ success: true, member: user.rows[0] });
};

/**
 * DELETE /api/projects/:id/members/:userId
 * Removes a member from a project.
 * Only the project creator can remove members. Creator cannot remove themselves.
 */
const removeMember = async (req, res) => {
  const proj = await pool.query('SELECT created_by FROM projects WHERE id = $1', [req.params.id]);
  if (!proj.rows.length)
    return res.status(404).json({ success: false, message: 'Project not found' });
  if (proj.rows[0].created_by !== req.user.id)
    return res.status(403).json({ success: false, message: 'Only the project creator can remove members' });

  const targetUserId = parseInt(req.params.userId);
  if (targetUserId === proj.rows[0].created_by)
    return res.status(400).json({ success: false, message: 'Cannot remove the project creator' });

  await pool.query(
    'DELETE FROM project_members WHERE project_id = $1 AND user_id = $2',
    [req.params.id, targetUserId]
  );

  res.json({ success: true, message: 'Member removed' });
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
 * Body: { title, description?, assigned_to_name?, assigned_to_id?, due_date?, priority? }
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
 * PATCH /api/projects/:id/tasks/:taskId
 * Full edit of a task: title, description, priority, due_date, assigned_to_name.
 */
const updateTask = async (req, res) => {
  const { title, description, priority, due_date, assigned_to_name } = req.body;
  if (!title)
    return res.status(400).json({ success: false, message: 'title required' });

  const result = await pool.query(
    `UPDATE project_tasks
     SET title = $1, description = $2, priority = $3, due_date = $4, assigned_to_name = $5
     WHERE id = $6 AND project_id = $7
     RETURNING *`,
    [title, description || null, priority || 'medium',
     due_date || null, assigned_to_name || null,
     req.params.taskId, req.params.id]
  );
  if (!result.rows.length)
    return res.status(404).json({ success: false, message: 'Task not found' });

  res.json({ success: true, task: result.rows[0] });
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
  getProjects, getProject, createProject,
  getClassroomStudents, addMember, removeMember,
  updateProgress, deleteProject,
  createTask, updateTask, updateTaskStatus, deleteTask,
};
