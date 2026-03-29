const pool = require('../config/db');

const socketHandler = (io) => {
  const onlineUsers = new Map();

  io.on('connection', (socket) => {
    console.log('🔌 Socket connected:', socket.id);

    socket.on('user:join', (userId) => {
      onlineUsers.set(userId, socket.id);
      socket.userId = userId;
    });

    socket.on('subject:join', (subjectId) => socket.join(`subject_${subjectId}`));
    socket.on('subject:leave', (subjectId) => socket.leave(`subject_${subjectId}`));

    socket.on('message:send', async (data) => {
      try {
        const { subjectId, senderId, content, file_url, file_name } = data;
        const result = await pool.query(
          `INSERT INTO messages (subject_id, sender_id, content, file_url, file_name)
           VALUES ($1, $2, $3, $4, $5)
           RETURNING *, (SELECT name FROM users WHERE id=$2) AS sender_name,
                        (SELECT role FROM users WHERE id=$2) AS sender_role,
                        (SELECT avatar_url FROM users WHERE id=$2) AS sender_avatar`,
          [subjectId, senderId, content, file_url || null, file_name || null]
        );
        io.to(`subject_${subjectId}`).emit('message:new', result.rows[0]);
      } catch (err) {
        socket.emit('error', { message: 'Failed to send message' });
      }
    });

    socket.on('typing:start', ({ subjectId, userName }) => socket.to(`subject_${subjectId}`).emit('typing:start', { userName }));
    socket.on('typing:stop', ({ subjectId }) => socket.to(`subject_${subjectId}`).emit('typing:stop'));

    socket.on('notification:send', ({ targetUserId, notification }) => {
      const targetSocket = onlineUsers.get(String(targetUserId));
      if (targetSocket) io.to(targetSocket).emit('notification:new', notification);
    });

    socket.on('disconnect', () => {
      if (socket.userId) onlineUsers.delete(socket.userId);
    });
  });
};

module.exports = socketHandler;
