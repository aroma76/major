const pool = require('../config/db');

const getNotes = async (req, res) => {
  const { search } = req.query;
  let query = `SELECT n.*, u.name AS uploaded_by_name FROM files n INNER JOIN users u ON n.uploaded_by = u.id WHERE n.channel_id = $1`;
  const values = [req.params.id];
  if (search) { query += ` AND (n.title ILIKE $2 OR n.description ILIKE $2)`; values.push(`%${search}%`); }
  query += ' ORDER BY n.created_at DESC';
  const result = await pool.query(query, values);
  res.json({ success: true, files: result.rows });
};

const uploadNote = async (req, res) => {
  const { title, description } = req.body;
  if (!req.file) return res.status(400).json({ success: false, message: 'File is required' });
  if (!title) return res.status(400).json({ success: false, message: 'Title is required' });
  const result = await pool.query(
    `INSERT INTO files (channel_id, uploaded_by, title, description, file_url, file_name, file_type)
     VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
    [req.params.id, req.user.id, title, description, req.file.path, req.file.originalname, req.file.mimetype]
  );
  res.status(201).json({ success: true, note: result.rows[0] });
};

const deleteNote = async (req, res) => {
  const note = await pool.query('SELECT uploaded_by FROM files WHERE id=$1', [req.params.id]);
  if (!note.rows.length) return res.status(404).json({ success: false, message: 'Note not found' });
  if (note.rows[0].uploaded_by !== req.user.id && req.user.role !== 'admin')
    return res.status(403).json({ success: false, message: 'Not authorized' });
  await pool.query('DELETE FROM files WHERE id=$1', [req.params.id]);
  res.json({ success: true, message: 'Note deleted' });
};

module.exports = { getNotes, uploadNote, deleteNote };
