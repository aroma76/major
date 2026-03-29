const pool = require('../config/db');

const getAnnouncements = async (req, res) => {
  const result = await pool.query(
    `SELECT a.*, u.name AS created_by_name, u.role AS creator_role FROM announcements a INNER JOIN users u ON a.created_by = u.id WHERE a.subject_id = $1 ORDER BY a.created_at DESC`,
    [req.params.id]
  );
  res.json({ success: true, announcements: result.rows });
};

const createAnnouncement = async (req, res) => {
  const { title, content, is_important = false } = req.body;
  if (!title || !content) return res.status(400).json({ success: false, message: 'title and content required' });
  const result = await pool.query(
    `INSERT INTO announcements (subject_id,created_by,title,content,is_important) VALUES ($1,$2,$3,$4,$5) RETURNING *`,
    [req.params.id, req.user.id, title, content, is_important]
  );
  const students = await pool.query(`SELECT user_id FROM enrollments WHERE subject_id=$1`, [req.params.id]);
  await Promise.all(students.rows.map(s =>
    pool.query(`INSERT INTO notifications (user_id,type,title,message,ref_id,ref_type) VALUES ($1,'announcement',$2,$3,$4,'announcement')`,
      [s.user_id, `📢 ${title}`, content.substring(0, 120), result.rows[0].id])
  ));
  res.status(201).json({ success: true, announcement: result.rows[0] });
};

const deleteAnnouncement = async (req, res) => {
  await pool.query('DELETE FROM announcements WHERE id=$1', [req.params.id]);
  res.json({ success: true, message: 'Announcement deleted' });
};

module.exports = { getAnnouncements, createAnnouncement, deleteAnnouncement };
