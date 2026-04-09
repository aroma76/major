const pool = require('../config/db');
const jwt   = require('jsonwebtoken');

const socketHandler = (io) => {
  const onlineUsers = new Map(); // userId -> socketId

  io.on('connection', async (socket) => {
    console.log('🔌 Socket connected:', socket.id);

    // ── Authenticate via JWT on handshake ────────────────────────────────
    try {
      const token = socket.handshake.auth?.token;
      if (token) {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        const result  = await pool.query(
          'SELECT id, name, role FROM users WHERE id = $1',
          [decoded.id]
        );
        if (result.rows.length) {
          socket.user = result.rows[0];
          onlineUsers.set(String(socket.user.id), socket.id);
          console.log(`✅ Auth: ${socket.user.name} (${socket.user.role})`);
        }
      }
    } catch (_) {
      console.log('⚠️  Socket: unauthenticated connection');
    }

    // ── Channel membership ────────────────────────────────────────────────
    socket.on('channel:join',  (channelId) => socket.join(`channel_${channelId}`));
    socket.on('channel:leave', (channelId) => socket.leave(`channel_${channelId}`));

    // ── Text messages (files go via REST POST to upload Cloudinary first) ─
    socket.on('message:send', async (data) => {
      try {
        // SECURITY: always use authenticated user from JWT — never trust client senderId
        const senderId = socket.user?.id;
        if (!senderId) return socket.emit('error', { message: 'Not authenticated' });

        const { channelId, content, parent_id } = data;
        if (!content?.trim()) return;

        const result = await pool.query(
          `INSERT INTO messages (channel_id, sender_id, content, parent_id)
           VALUES ($1, $2, $3, $4)
           RETURNING *,
             (SELECT name        FROM users WHERE id = $2) AS sender_name,
             (SELECT role        FROM users WHERE id = $2) AS sender_role,
             (SELECT avatar_url  FROM users WHERE id = $2) AS sender_avatar,
             (SELECT p.content   FROM messages p WHERE p.id = $4) AS parent_content,
             (SELECT pu.name     FROM messages p JOIN users pu ON p.sender_id = pu.id WHERE p.id = $4) AS parent_sender_name`,
          [channelId, senderId, content.trim(), parent_id || null]
        );

        io.to(`channel_${channelId}`).emit('message:new', result.rows[0]);
      } catch (err) {
        console.error('message:send error:', err.message);
        socket.emit('error', { message: 'Failed to send message' });
      }
    });

    // ── Typing indicators ─────────────────────────────────────────────────
    socket.on('typing:start', ({ channelId, userName }) =>
      socket.to(`channel_${channelId}`).emit('typing:start', { userName })
    );
    socket.on('typing:stop', ({ channelId }) =>
      socket.to(`channel_${channelId}`).emit('typing:stop')
    );

    // ── Direct notifications to a specific user ───────────────────────────
    socket.on('notification:send', ({ targetUserId, notification }) => {
      const targetSocket = onlineUsers.get(String(targetUserId));
      if (targetSocket) io.to(targetSocket).emit('notification:new', notification);
    });

    socket.on('disconnect', () => {
      if (socket.user) {
        onlineUsers.delete(String(socket.user.id));
        console.log(`🔴 Disconnected: ${socket.user.name}`);
      }
    });
  });
};

module.exports = socketHandler;
