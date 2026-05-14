const pool    = require('../config/db');
const { getIO } = require('./messageController');

/**
 * GET /api/channels/:id/announcements
 * Returns all announcements for a channel, newest first.
 * Joins with users to include the poster's name and role.
 * Accessible by any authenticated user enrolled in the channel.
 */
const getAnnouncements = async (req, res) => {
  const result = await pool.query(
    `SELECT a.*, u.name AS created_by_name, u.role AS creator_role
     FROM announcements a INNER JOIN users u ON a.user_id = u.id
     WHERE a.channel_id = $1 ORDER BY a.created_at DESC`,
    [req.params.id]
  );
  res.json({ success: true, announcements: result.rows });
};

/**
 * POST /api/channels/:id/announcements
 * Creates a new announcement in a channel.
 * Restricted to faculty and admin roles only.
 *
 * Body: { title: string, content: string, is_important?: boolean }
 */
const createAnnouncement = async (req, res) => {
  const { title, content, is_important = false } = req.body;
  if (!title || !content) {
    return res.status(400).json({ success: false, message: 'title and content required' });
  }

  // Insert the announcement
  const result = await pool.query(
    `INSERT INTO announcements (channel_id, user_id, title, content, is_important)
     VALUES ($1,$2,$3,$4,$5) RETURNING *`,
    [req.params.id, req.user.id, title, content, is_important]
  );
  const announcement = result.rows[0];

  // Fetch creator name for the real-time event payload
  const creatorRes = await pool.query(
    'SELECT name, role FROM users WHERE id = $1', [req.user.id]
  );
  const creator = creatorRes.rows[0] ?? {};

  // ── Real-time broadcast to all channel members ──────────────────────────
  // All users who joined this channel's socket room see the new announcement
  // immediately without needing to refresh.
  try {
    const io = getIO();
    if (io) {
      io.to(`channel_${req.params.id}`).emit('announcement:new', {
        ...announcement,
        created_by_name : creator.name  ?? 'Faculty',
        creator_role    : creator.role  ?? 'faculty',
      });
    }
  } catch (err) {
    console.error('[Socket] Failed to emit announcement:new:', err.message);
  }

  // ── Persist notifications for enrolled students (fire-and-forget) ───────
  // We do NOT await this — notification failures should never block the 201
  // response. Use .catch() to log errors silently.
  pool.query(`SELECT user_id FROM enrollments WHERE channel_id=$1`, [req.params.id])
    .then(({ rows }) =>
      Promise.all(rows.map(s =>
        pool.query(
          `INSERT INTO notifications (user_id, type, title, message, ref_id, ref_type)
           VALUES ($1,'announcement',$2,$3,$4,'announcement')`,
          [s.user_id, `📢 ${title}`, content.substring(0, 120), announcement.id]
        )
      ))
    )
    .catch(err => console.error('[Notifications] Announcement notify error:', err.message));

  res.status(201).json({ success: true, announcement });
};

/**
 * DELETE /api/channels/:id/announcements/:announcementId
 * Permanently deletes a single announcement by its ID.
 * Restricted to faculty and admin roles only.
 */
const deleteAnnouncement = async (req, res) => {
  await pool.query('DELETE FROM announcements WHERE id=$1', [req.params.announcementId]);
  res.json({ success: true, message: 'Announcement deleted' });
};

module.exports = { getAnnouncements, createAnnouncement, deleteAnnouncement };
