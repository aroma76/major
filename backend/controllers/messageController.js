const pool = require('../config/db');

// io injected from server.js so REST file uploads can broadcast in real-time
let _io;

/**
 * Injects the Socket.io instance so the REST controller can emit events.
 */
const setIO = (io) => { _io = io; };

/**
 * GET /api/channels/:id/messages
 * Fetches paginated chat history for a channel.
 * Pass a 'cursor' (message ID) to fetch older messages before that ID.
 * Defaults to 50 messages per request.
 * Results are reversed so the oldest in the batch comes first (for UI rendering).
 */
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

/**
 * POST /api/channels/:id/messages
 * Sends a new message to the channel. Can include a text content, a file attachment, or both.
 * Validates message length and ensures any replied-to message belongs to the same channel.
 * Broadcasts the newly saved message in real-time to all connected users in the channel.
 * 
 * Body: { content?: string, parent_id?: number }
 * File: Multipart file upload mapping to req.file
 */
const sendMessage = async (req, res) => {
  const { content, parent_id } = req.body;
  const file_url  = req.file?.path         || null;
  const file_name = req.file?.originalname || null;

  if (!content && !file_url)
    return res.status(400).json({ success: false, message: 'Message content or file required' });

  // [M3] Cap message length to prevent DB bloat/spam
  if (content && content.length > 5000)
    return res.status(400).json({ success: false, message: 'Message too long (max 5000 characters)' });

  // [H3] Validate parent_id belongs to the same channel (prevents cross-channel data leak)
  if (parent_id) {
    const parent = await pool.query('SELECT channel_id FROM messages WHERE id = $1', [parent_id]);
    if (!parent.rows.length || String(parent.rows[0].channel_id) !== String(req.params.id))
      return res.status(400).json({ success: false, message: 'Invalid parent message' });
  }

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

  // Broadcast to all channel members so they see the text/file in real-time
  if (_io) _io.to(`channel_${req.params.id}`).emit('message:new', saved);

  res.status(201).json({ success: true, message: saved });
};

/**
 * PATCH /api/channels/:id/messages/:msgId/pin
 * Toggles the pinned status of a specific message.
 */
const pinMessage = async (req, res) => {
  const result = await pool.query(
    `UPDATE messages SET is_pinned = NOT is_pinned WHERE id=$1 RETURNING *`,
    [req.params.msgId]
  );
  if (!result.rows.length)
    return res.status(404).json({ success: false, message: 'Message not found' });
  res.json({ success: true, message: result.rows[0] });
};

/**
 * DELETE /api/channels/:id/messages/:msgId
 * Deletes a chat message. Users can only delete their own messages.
 * Faculty and Admins can delete any message in the channel.
 */
const deleteMessage = async (req, res) => {
  const msg = await pool.query('SELECT sender_id FROM messages WHERE id=$1', [req.params.msgId]);
  if (!msg.rows.length)
    return res.status(404).json({ success: false, message: 'Message not found' });
  if (msg.rows[0].sender_id !== req.user.id && req.user.role !== 'admin' && req.user.role !== 'faculty')
    return res.status(403).json({ success: false, message: 'Not authorized' });
  await pool.query('DELETE FROM messages WHERE id=$1', [req.params.msgId]);
  res.json({ success: true, message: 'Deleted' });
};

/**
 * GET /api/channels/:id/messages/pinned
 * Returns a list of all currently pinned messages in the channel.
 */
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
