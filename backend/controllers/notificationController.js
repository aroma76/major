const pool = require('../config/db');

const getNotifications = async (req, res) => {
  const result = await pool.query(`SELECT * FROM notifications WHERE user_id=$1 ORDER BY created_at DESC LIMIT 50`, [req.user.id]);
  res.json({ success: true, notifications: result.rows });
};
const markRead = async (req, res) => {
  await pool.query('UPDATE notifications SET is_read=TRUE WHERE id=$1 AND user_id=$2', [req.params.id, req.user.id]);
  res.json({ success: true });
};
const markAllRead = async (req, res) => {
  await pool.query('UPDATE notifications SET is_read=TRUE WHERE user_id=$1', [req.user.id]);
  res.json({ success: true });
};
const deleteNotification = async (req, res) => {
  await pool.query('DELETE FROM notifications WHERE id=$1 AND user_id=$2', [req.params.id, req.user.id]);
  res.json({ success: true });
};
const getUnreadCount = async (req, res) => {
  const result = await pool.query(`SELECT COUNT(*) FROM notifications WHERE user_id=$1 AND is_read=FALSE`, [req.user.id]);
  res.json({ success: true, count: parseInt(result.rows[0].count) });
};

module.exports = { getNotifications, markRead, markAllRead, deleteNotification, getUnreadCount };
