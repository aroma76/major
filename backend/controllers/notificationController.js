const pool = require('../config/db');

/**
 * GET /api/notifications
 * Returns the 50 most recent notifications for the authenticated user,
 * ordered newest-first. Includes both read and unread notifications.
 */
const getNotifications = async (req, res) => {
  const result = await pool.query(
    `SELECT * FROM notifications WHERE user_id=$1 ORDER BY created_at DESC LIMIT 50`,
    [req.user.id]
  );
  res.json({ success: true, notifications: result.rows });
};

/**
 * PATCH /api/notifications/:id/read
 * Marks a single notification as read.
 * The user_id check ensures users cannot mark other people's notifications.
 */
const markRead = async (req, res) => {
  await pool.query(
    'UPDATE notifications SET is_read=TRUE WHERE id=$1 AND user_id=$2',
    [req.params.id, req.user.id]
  );
  res.json({ success: true });
};

/**
 * PATCH /api/notifications/read-all
 * Marks ALL unread notifications as read for the authenticated user.
 * Useful for the "Mark all as read" button in the notification panel.
 */
const markAllRead = async (req, res) => {
  await pool.query(
    'UPDATE notifications SET is_read=TRUE WHERE user_id=$1',
    [req.user.id]
  );
  res.json({ success: true });
};

/**
 * DELETE /api/notifications/:id
 * Permanently deletes a single notification.
 * The user_id check ensures users cannot delete other people's notifications.
 */
const deleteNotification = async (req, res) => {
  await pool.query(
    'DELETE FROM notifications WHERE id=$1 AND user_id=$2',
    [req.params.id, req.user.id]
  );
  res.json({ success: true });
};

/**
 * GET /api/notifications/unread-count
 * Returns the count of unread notifications for the authenticated user.
 * Used to display the badge number on the notification bell icon.
 */
const getUnreadCount = async (req, res) => {
  const result = await pool.query(
    `SELECT COUNT(*) FROM notifications WHERE user_id=$1 AND is_read=FALSE`,
    [req.user.id]
  );
  res.json({ success: true, count: parseInt(result.rows[0].count) });
};

module.exports = { getNotifications, markRead, markAllRead, deleteNotification, getUnreadCount };
