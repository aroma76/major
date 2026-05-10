const pool = require('../config/db');

/**
 * GET /api/channels
 * Returns a list of channels based on the user's role:
 * - Admin: All channels in the system
 * - Faculty: Channels where they are assigned as the teacher
 * - Student: Channels they are actively enrolled in
 * Includes joined data for teacher name and programme name.
 */
const getChannels = async (req, res) => {
  let result;
  if (req.user.role === 'admin') {
    result = await pool.query(
      `SELECT c.*, u.name AS teacher_name, p.name AS programme_name 
       FROM channels c 
       LEFT JOIN users u ON c.teacher_id = u.id 
       LEFT JOIN batches b ON c.batch_id = b.id
       LEFT JOIN programmes p ON b.programme_id = p.id
       ORDER BY c.subject_name`
    );
  } else if (req.user.role === 'faculty') {
    result = await pool.query(
      `SELECT c.*, u.name AS teacher_name, p.name AS programme_name 
       FROM channels c 
       LEFT JOIN users u ON c.teacher_id = u.id 
       LEFT JOIN batches b ON c.batch_id = b.id
       LEFT JOIN programmes p ON b.programme_id = p.id
       WHERE c.teacher_id = $1 ORDER BY c.subject_name`, 
      [req.user.id]
    );
  } else {
    // For students and CRs, show channels they are enrolled in
    result = await pool.query(
      `SELECT c.*, u.name AS teacher_name, p.name AS programme_name 
       FROM channels c 
       LEFT JOIN users u ON c.teacher_id = u.id 
       LEFT JOIN batches b ON c.batch_id = b.id
       LEFT JOIN programmes p ON b.programme_id = p.id
       INNER JOIN enrollments e ON e.channel_id = c.id 
       WHERE e.user_id = $1 ORDER BY c.subject_name`, 
      [req.user.id]
    );
  }
  res.json({ success: true, channels: result.rows });
};

/**
 * GET /api/channels/:id
 * Fetches detailed metadata for a single channel by ID.
 * Returns 404 if the channel does not exist.
 */
const getChannel = async (req, res) => {
  const result = await pool.query(
    `SELECT c.*, u.name AS teacher_name, p.name AS programme_name 
     FROM channels c 
     LEFT JOIN users u ON c.teacher_id = u.id 
     LEFT JOIN batches b ON c.batch_id = b.id
     LEFT JOIN programmes p ON b.programme_id = p.id
     WHERE c.id = $1`, 
    [req.params.id]
  );
  if (!result.rows.length) return res.status(404).json({ success: false, message: 'Channel not found' });
  res.json({ success: true, channel: result.rows[0] });
};

/**
 * POST /api/channels
 * Creates a new channel. Restricted to Admin role.
 * 
 * Body: { batch_id, semester_number, subject_name, subject_slug, channel_name, teacher_id? }
 */
const createChannel = async (req, res) => {
  const { batch_id, semester_number, subject_name, subject_slug, channel_name, teacher_id } = req.body;
  
  if (!batch_id || !semester_number || !subject_name || !subject_slug || !channel_name)
    return res.status(400).json({ success: false, message: 'Missing required channel information' });
    
  const result = await pool.query(
    `INSERT INTO channels (batch_id, semester_number, subject_name, subject_slug, channel_name, teacher_id) 
     VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
    [batch_id, semester_number, subject_name, subject_slug, channel_name, teacher_id || null]
  );
  res.status(201).json({ success: true, channel: result.rows[0] });
};

/**
 * PUT /api/channels/:id
 * Updates an existing channel's metadata. Restricted to Admin role.
 * 
 * Body: { subject_name, subject_slug, channel_name, teacher_id }
 */
const updateChannel = async (req, res) => {
  const { subject_name, subject_slug, channel_name, teacher_id } = req.body;
  const result = await pool.query(
    `UPDATE channels SET subject_name=$1, subject_slug=$2, channel_name=$3, teacher_id=$4 WHERE id=$5 RETURNING *`,
    [subject_name, subject_slug, channel_name, teacher_id, req.params.id]
  );
  if (!result.rows.length) return res.status(404).json({ success: false, message: 'Channel not found' });
  res.json({ success: true, channel: result.rows[0] });
};

/**
 * DELETE /api/channels/:id
 * Permanently deletes a channel. Restricted to Admin role.
 */
const deleteChannel = async (req, res) => {
  await pool.query('DELETE FROM channels WHERE id=$1', [req.params.id]);
  res.json({ success: true, message: 'Channel deleted' });
};

/**
 * GET /api/channels/:id/members
 * Returns a list of all users currently enrolled in the specified channel.
 * Orders by role first (teachers/admins top) then name.
 */
const getChannelMembers = async (req, res) => {
  const result = await pool.query(
    `SELECT u.id, u.name, u.email, u.role, u.roll_number, u.avatar_initials, u.avatar_url
     FROM users u 
     INNER JOIN enrollments e ON e.user_id = u.id 
     WHERE e.channel_id = $1 ORDER BY u.role, u.name`,
    [req.params.id]
  );
  res.json({ success: true, members: result.rows });
};

module.exports = { getChannels, getChannel, createChannel, updateChannel, deleteChannel, getChannelMembers };
