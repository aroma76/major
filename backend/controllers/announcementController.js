const pool = require('../config/db');

/**
 * GET /api/channels/:id/announcements
 * Returns all announcements for a channel, newest first.
 * Joins with users to include the poster's name and role.
 * Accessible by any authenticated user enrolled in the channel.
 */
const getAnnouncements = async (req, res) => {
  const result = await pool.query(
    // schema uses 'user_id' not 'created_by'
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
 * Also inserts a notification row for every enrolled student so they
 * see an in-app alert even if they are offline at time of posting.
 *
 * Body: { title: string, content: string, is_important?: boolean }
 */
const createAnnouncement = async (req, res) => {
  const { title, content, is_important = false } = req.body;
  if (!title || !content)
    return res.status(400).json({ success: false, message: 'title and content required' });

  // schema column is 'user_id' not 'created_by'
  const result = await pool.query(
    `INSERT INTO announcements (channel_id, user_id, title, content, is_important)
     VALUES ($1,$2,$3,$4,$5) RETURNING *`,
    [req.params.id, req.user.id, title, content, is_important]
  );

  // Notify all enrolled students
  const students = await pool.query(
    `SELECT user_id FROM enrollments WHERE channel_id=$1`, [req.params.id]
  );
  await Promise.all(students.rows.map(s =>
    pool.query(
      `INSERT INTO notifications (user_id, type, title, message, ref_id, ref_type)
       VALUES ($1,'announcement',$2,$3,$4,'announcement')`,
      [s.user_id, `📢 ${title}`, content.substring(0, 120), result.rows[0].id]
    )
  ));

  res.status(201).json({ success: true, announcement: result.rows[0] });
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
