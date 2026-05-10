const pool = require('../config/db');

/**
 * POST /api/enrollments
 * Enrolls a single user into a channel.
 * Returns 400 if the user is already enrolled (unique constraint violation, pg code 23505).
 *
 * Body: { user_id: number, channel_id: number }
 */
const enroll = async (req, res) => {
  const { user_id, channel_id } = req.body;
  if (!user_id || !channel_id)
    return res.status(400).json({ success: false, message: 'user_id and channel_id required' });
  try {
    const result = await pool.query(
      `INSERT INTO enrollments (user_id, channel_id) VALUES ($1, $2) RETURNING *`,
      [user_id, channel_id]
    );
    res.status(201).json({ success: true, enrollment: result.rows[0] });
  } catch (err) {
    // Unique constraint violation — user is already enrolled in this channel
    if (err.code === '23505') return res.status(400).json({ success: false, message: 'Already enrolled' });
    throw err;
  }
};

/**
 * DELETE /api/enrollments
 * Removes a user from a channel (unenroll).
 * Silently succeeds even if the enrollment did not exist.
 *
 * Body: { user_id: number, channel_id: number }
 */
const unenroll = async (req, res) => {
  const { user_id, channel_id } = req.body;
  await pool.query(
    'DELETE FROM enrollments WHERE user_id=$1 AND channel_id=$2',
    [user_id, channel_id]
  );
  res.json({ success: true, message: 'Unenrolled successfully' });
};

/**
 * GET /api/enrollments/me
 * Returns all channels the currently authenticated user is enrolled in.
 * Equivalent to "my subjects" from the student's perspective.
 */
const getMyEnrollments = async (req, res) => {
  const result = await pool.query(
    `SELECT c.* FROM channels c INNER JOIN enrollments e ON e.channel_id=c.id WHERE e.user_id=$1`,
    [req.user.id]
  );
  res.json({ success: true, channels: result.rows });
};

/**
 * POST /api/enrollments/bulk
 * Bulk-enrolls all students of a given programme and semester into a channel.
 * Skips any student who is already enrolled (silent ignore via try/catch).
 * Returns the count of newly enrolled students.
 *
 * Body: { channel_id: number, programme_id: number, current_semester: number }
 */
const bulkEnroll = async (req, res) => {
  const { channel_id, programme_id, current_semester } = req.body;
  const students = await pool.query(
    `SELECT id FROM users WHERE role='student' AND programme_id=$1 AND current_semester=$2`,
    [programme_id, current_semester]
  );
  let enrolled = 0;
  for (const s of students.rows) {
    try {
      await pool.query(
        'INSERT INTO enrollments (user_id, channel_id) VALUES ($1, $2)',
        [s.id, channel_id]
      );
      enrolled++;
    } catch (_) {
      // Skip already-enrolled students silently
    }
  }
  res.json({ success: true, message: `Enrolled ${enrolled} students` });
};

module.exports = { enroll, unenroll, getMyEnrollments, bulkEnroll };
