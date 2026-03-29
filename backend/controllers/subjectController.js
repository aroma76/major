const pool = require('../config/db');

const getSubjects = async (req, res) => {
  let result;
  if (req.user.role === 'admin') {
    result = await pool.query(`SELECT s.*, u.name AS faculty_name FROM subjects s LEFT JOIN users u ON s.faculty_id = u.id ORDER BY s.name`);
  } else if (req.user.role === 'faculty') {
    result = await pool.query(`SELECT s.*, u.name AS faculty_name FROM subjects s LEFT JOIN users u ON s.faculty_id = u.id WHERE s.faculty_id = $1 ORDER BY s.name`, [req.user.id]);
  } else {
    result = await pool.query(
      `SELECT s.*, u.name AS faculty_name FROM subjects s LEFT JOIN users u ON s.faculty_id = u.id
       INNER JOIN enrollments e ON e.subject_id = s.id WHERE e.user_id = $1 ORDER BY s.name`, [req.user.id]
    );
  }
  res.json({ success: true, subjects: result.rows });
};

const getSubject = async (req, res) => {
  const result = await pool.query(`SELECT s.*, u.name AS faculty_name FROM subjects s LEFT JOIN users u ON s.faculty_id = u.id WHERE s.id = $1`, [req.params.id]);
  if (!result.rows.length) return res.status(404).json({ success: false, message: 'Subject not found' });
  res.json({ success: true, subject: result.rows[0] });
};

const createSubject = async (req, res) => {
  const { name, code, department, semester, faculty_id } = req.body;
  if (!name || !code || !department || !semester)
    return res.status(400).json({ success: false, message: 'name, code, department and semester required' });
  const result = await pool.query(
    `INSERT INTO subjects (name, code, department, semester, faculty_id) VALUES ($1, $2, $3, $4, $5) RETURNING *`,
    [name, code, department, semester, faculty_id || null]
  );
  res.status(201).json({ success: true, subject: result.rows[0] });
};

const updateSubject = async (req, res) => {
  const { name, code, department, semester, faculty_id } = req.body;
  const result = await pool.query(
    `UPDATE subjects SET name=$1, code=$2, department=$3, semester=$4, faculty_id=$5 WHERE id=$6 RETURNING *`,
    [name, code, department, semester, faculty_id, req.params.id]
  );
  if (!result.rows.length) return res.status(404).json({ success: false, message: 'Subject not found' });
  res.json({ success: true, subject: result.rows[0] });
};

const deleteSubject = async (req, res) => {
  await pool.query('DELETE FROM subjects WHERE id=$1', [req.params.id]);
  res.json({ success: true, message: 'Subject deleted' });
};

const getSubjectMembers = async (req, res) => {
  const result = await pool.query(
    `SELECT u.id, u.name, u.email, u.role, u.department, u.semester, u.avatar_url
     FROM users u INNER JOIN enrollments e ON e.user_id = u.id WHERE e.subject_id = $1 ORDER BY u.name`,
    [req.params.id]
  );
  res.json({ success: true, members: result.rows });
};

module.exports = { getSubjects, getSubject, createSubject, updateSubject, deleteSubject, getSubjectMembers };
