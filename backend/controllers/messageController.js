const pool = require('../config/db');

// io injected from server.js so REST file uploads can broadcast in real-time
let _io;
const setIO = (io) => { _io = io; };

const getMessages = async (req, res) => {
  const { cursor } = req.query;
  const limit = parseInt(req.query.limit) || 50;
  
  let result;
  const query = `
    SELECT m.*, u.name AS sender_name, u.role AS sender_role, u.avatar_url AS sender_avatar,
           p.content AS parent_content, pu.name AS parent_sender_name
    FROM messages m 
    INNER JOIN users u ON m.sender_id = u.id
    LEFT JOIN messages p ON m.parent_id = p.id
    LEFT JOIN users pu ON p.sender_id = pu.id
    WHERE m.channel_id = $1 ${cursor ? 'AND m.id < $2' : ''}
    ORDER BY m.id DESC LIMIT $${cursor ? '3' : '2'}
  `;

  if (cursor) {
    result = await pool.query(query, [req.params.id, cursor, limit]);
  } else {
    result = await pool.query(query, [req.params.id, limit]);
  }

  res.json({ success: true, messages: result.rows.reverse() });
};

const sendMessage = async (req, res) => {
  const { content, parent_id } = req.body;
  const file_url  = req.file?.path         || null;
  const file_name = req.file?.originalname || null;

  if (!content && !file_url)
    return res.status(400).json({ success: false, message: 'Message content or file required' });

  const result = await pool.query(
    `INSERT INTO messages (channel_id, sender_id, content, file_url, file_name, parent_id)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING *,
       (SELECT name       FROM users WHERE id=$2) AS sender_name,
       (SELECT role       FROM users WHERE id=$2) AS sender_role,
       (SELECT avatar_url FROM users WHERE id=$2) AS sender_avatar,
       (SELECT p.content  FROM messages p WHERE p.id=$6) AS parent_content,
       (SELECT pu.name    FROM messages p JOIN users pu ON p.sender_id = pu.id WHERE p.id=$6) AS parent_sender_name`,
    [req.params.id, req.user.id, content || null, file_url, file_name, parent_id || null]
  );

  const saved = result.rows[0];

  // Broadcast to all channel members so they see the file in real-time
  if (_io) _io.to(`channel_${req.params.id}`).emit('message:new', saved);

  res.status(201).json({ success: true, message: saved });
};

const pinMessage = async (req, res) => {
  const result = await pool.query(
    `UPDATE messages SET is_pinned = NOT is_pinned WHERE id=$1 RETURNING *`,
    [req.params.msgId]
  );
  if (!result.rows.length)
    return res.status(404).json({ success: false, message: 'Message not found' });
  res.json({ success: true, message: result.rows[0] });
};

const deleteMessage = async (req, res) => {
  const msg = await pool.query('SELECT sender_id FROM messages WHERE id=$1', [req.params.msgId]);
  if (!msg.rows.length)
    return res.status(404).json({ success: false, message: 'Message not found' });
  if (msg.rows[0].sender_id !== req.user.id && req.user.role !== 'admin' && req.user.role !== 'faculty')
    return res.status(403).json({ success: false, message: 'Not authorized' });
  await pool.query('DELETE FROM messages WHERE id=$1', [req.params.msgId]);
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

module.exports = { getMessages, sendMessage, pinMessage, deleteMessage, getPinnedMessages, setIO };
