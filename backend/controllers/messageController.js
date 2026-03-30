const pool = require('../config/db');

const getMessages = async (req, res) => {
  const result = await pool.query(
    `SELECT m.*, u.name AS sender_name, u.role AS sender_role, u.avatar_url AS sender_avatar
     FROM messages m INNER JOIN users u ON m.sender_id = u.id
     WHERE m.channel_id = $1 ORDER BY m.created_at ASC LIMIT 100`,
    [req.params.id]
  );
  res.json({ success: true, messages: result.rows });
};

const sendMessage = async (req, res) => {
  const { content } = req.body;
  const file_url = req.file?.path || null;
  const file_name = req.file?.originalname || null;
  if (!content && !file_url) return res.status(400).json({ success: false, message: 'Message or file required' });
  const result = await pool.query(
    `INSERT INTO messages (channel_id, sender_id, content, file_url, file_name)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING *, (SELECT name FROM users WHERE id=$2) AS sender_name,
                  (SELECT role FROM users WHERE id=$2) AS sender_role,
                  (SELECT avatar_url FROM users WHERE id=$2) AS sender_avatar`,
    [req.params.id, req.user.id, content, file_url, file_name]
  );
  res.status(201).json({ success: true, message: result.rows[0] });
};

const pinMessage = async (req, res) => {
  const result = await pool.query(`UPDATE messages SET is_pinned = NOT is_pinned WHERE id=$1 RETURNING *`, [req.params.id]);
  if (!result.rows.length) return res.status(404).json({ success: false, message: 'Message not found' });
  res.json({ success: true, message: result.rows[0] });
};

const deleteMessage = async (req, res) => {
  const msg = await pool.query('SELECT sender_id FROM messages WHERE id=$1', [req.params.id]);
  if (!msg.rows.length) return res.status(404).json({ success: false, message: 'Message not found' });
  if (msg.rows[0].sender_id !== req.user.id && req.user.role !== 'admin')
    return res.status(403).json({ success: false, message: 'Not authorized' });
  await pool.query('DELETE FROM messages WHERE id=$1', [req.params.id]);
  res.json({ success: true, message: 'Deleted' });
};

const getPinnedMessages = async (req, res) => {
  const result = await pool.query(
    `SELECT m.*, u.name AS sender_name, u.role AS sender_role
     FROM messages m INNER JOIN users u ON m.sender_id = u.id
     WHERE m.channel_id = $1 AND m.is_pinned = TRUE ORDER BY m.created_at DESC`,
    [req.params.id]
  );
  res.json({ success: true, messages: result.rows });
};

module.exports = { getMessages, sendMessage, pinMessage, deleteMessage, getPinnedMessages };
