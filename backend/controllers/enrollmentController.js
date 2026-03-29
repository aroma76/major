const pool = require('../config/db');

const enroll = async (req, res) => {
  const { user_id, subject_id } = req.body;
  if (!user_id || !subject_id) return res.status(400).json({ success: false, message: 'user_id and subject_id required' });
  try {
    const result = await pool.query(`INSERT INTO enrollments (user_id, subject_id) VALUES ($1, $2) RETURNING *`, [user_id, subject_id]);
    res.status(201).json({ success: true, enrollment: result.rows[0] });
  } catch (err) {
    if (err.code === '23505') return res.status(400).json({ success: false, message: 'Already enrolled' });
    throw err;
  }
};

const unenroll = async (req, res) => {
  const { user_id, subject_id } = req.body;
  await pool.query('DELETE FROM enrollments WHERE user_id=$1 AND subject_id=$2', [user_id, subject_id]);
  res.json({ success: true, message: 'Unenrolled successfully' });
};

const getMyEnrollments = async (req, res) => {
  const result = await pool.query(
    `SELECT s.* FROM subjects s INNER JOIN enrollments e ON e.subject_id=s.id WHERE e.user_id=$1`, [req.user.id]
  );
  res.json({ success: true, subjects: result.rows });
};

const bulkEnroll = async (req, res) => {
  const { subject_id, department, semester } = req.body;
  const students = await pool.query(`SELECT id FROM users WHERE role='student' AND department=$1 AND semester=$2`, [department, semester]);
  let enrolled = 0;
  for (const s of students.rows) {
    try { await pool.query('INSERT INTO enrollments (user_id, subject_id) VALUES ($1, $2)', [s.id, subject_id]); enrolled++; } catch (_) {}
  }
  res.json({ success: true, message: `Enrolled ${enrolled} students` });
};

module.exports = { enroll, unenroll, getMyEnrollments, bulkEnroll };
