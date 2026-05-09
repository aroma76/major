const pool = require('../config/db');

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

const getAssignment = async (req, res) => {
  const result = await pool.query(`SELECT a.*, u.name AS created_by_name FROM assignments a INNER JOIN users u ON a.created_by = u.id WHERE a.id=$1`, [req.params.assignId]);
  if (!result.rows.length) return res.status(404).json({ success: false, message: 'Assignment not found' });
  res.json({ success: true, assignment: result.rows[0] });
};

const createAssignment = async (req, res) => {
  const { title, description, due_date, max_marks, priority } = req.body;
  if (!title || !due_date) return res.status(400).json({ success: false, message: 'title and due_date required' });
  // [M3] Input length limits
  if (title.length > 255) return res.status(400).json({ success: false, message: 'title too long (max 255 chars)' });
  if (description && description.length > 3000) return res.status(400).json({ success: false, message: 'description too long (max 3000 chars)' });
  const result = await pool.query(
    `INSERT INTO assignments (channel_id, created_by, title, description, due_date, max_marks, priority, status)
     VALUES ($1,$2,$3,$4,$5,$6,$7,'todo') RETURNING *`,
    [req.params.id, req.user.id, title, description, due_date, max_marks || 100, priority || 'medium']
  );
  const students = await pool.query(`SELECT user_id FROM enrollments WHERE channel_id=$1`, [req.params.id]);
  await Promise.all(students.rows.map(s =>
    pool.query(`INSERT INTO notifications (user_id, type, title, message, ref_id, ref_type) VALUES ($1,'assignment',$2,$3,$4,'assignment')`,
      [s.user_id, `New Assignment: ${title}`, `Due: ${new Date(due_date).toLocaleDateString()}`, result.rows[0].id])
  ));
  res.status(201).json({ success: true, assignment: result.rows[0] });
};

// PATCH /api/channels/:id/assignments/:assignId/status  — for Kanban drag-drop
const updateAssignmentStatus = async (req, res) => {
  const { status } = req.body;
  const allowed = ['todo', 'in_progress', 'done'];
  if (!allowed.includes(status)) return res.status(400).json({ success: false, message: 'Invalid status' });
  const result = await pool.query(
    `UPDATE assignments SET status=$1 WHERE id=$2 RETURNING *`,
    [status, req.params.assignId]
  );
  if (!result.rows.length) return res.status(404).json({ success: false, message: 'Assignment not found' });
  res.json({ success: true, assignment: result.rows[0] });
};

const updateAssignment = async (req, res) => {
  const { title, description, due_date, max_marks } = req.body;
  // [C3] Verify assignment belongs to this channel to prevent cross-channel edits
  const check = await pool.query('SELECT channel_id FROM assignments WHERE id=$1', [req.params.assignId]);
  if (!check.rows.length) return res.status(404).json({ success: false, message: 'Not found' });
  if (String(check.rows[0].channel_id) !== String(req.params.id))
    return res.status(403).json({ success: false, message: 'Assignment does not belong to this channel' });
  const result = await pool.query(`UPDATE assignments SET title=$1,description=$2,due_date=$3,max_marks=$4 WHERE id=$5 RETURNING *`, [title, description, due_date, max_marks, req.params.assignId]);
  if (!result.rows.length) return res.status(404).json({ success: false, message: 'Not found' });
  res.json({ success: true, assignment: result.rows[0] });
};

const deleteAssignment = async (req, res) => {
  // [C3] Verify assignment belongs to this channel before deleting
  const check = await pool.query('SELECT channel_id FROM assignments WHERE id=$1', [req.params.assignId]);
  if (!check.rows.length) return res.status(404).json({ success: false, message: 'Assignment not found' });
  if (String(check.rows[0].channel_id) !== String(req.params.id))
    return res.status(403).json({ success: false, message: 'Assignment does not belong to this channel' });
  await pool.query('DELETE FROM assignments WHERE id=$1', [req.params.assignId]);
  res.json({ success: true, message: 'Assignment deleted' });
};

const getSubmissions = async (req, res) => {
  const result = await pool.query(
    `SELECT sub.*, u.name AS student_name, u.email AS student_email FROM assignment_submissions sub INNER JOIN users u ON sub.student_id = u.id WHERE sub.assignment_id = $1 ORDER BY sub.submitted_at DESC`,
    [req.params.id]
  );
  res.json({ success: true, submissions: result.rows });
};

module.exports = { getAssignments, getAssignment, createAssignment, updateAssignment, updateAssignmentStatus, deleteAssignment, getSubmissions };
