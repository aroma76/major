const pool = require('../config/db');

/**
 * GET /api/channels/:id/notes
 * Returns all notes for a specific channel, newest first.
 * Optionally filter by note_type: ?type=note or ?type=question
 * Joins with users so the author's display name is included.
 */
const getNotes = async (req, res) => {
  const { type } = req.query; // optional: 'note' or 'question'
  let query, values;

  if (type && ['note', 'question'].includes(type)) {
    query = `SELECT n.*, u.name AS author_name
             FROM notes n
             INNER JOIN users u ON n.created_by = u.id
             WHERE n.channel_id = $1 AND n.note_type = $2
             ORDER BY n.created_at DESC`;
    values = [req.params.id, type];
  } else {
    query = `SELECT n.*, u.name AS author_name
             FROM notes n
             INNER JOIN users u ON n.created_by = u.id
             WHERE n.channel_id = $1
             ORDER BY n.created_at DESC`;
    values = [req.params.id];
  }

  const result = await pool.query(query, values);
  res.json({ success: true, notes: result.rows });
};

/**
 * POST /api/channels/:id/notes
 * Creates a new note inside a channel.
 * Body: { title: string, content?: string, note_type?: 'note' | 'question' }
 */
const createNote = async (req, res) => {
  const { title, content, note_type } = req.body;
  if (!title) return res.status(400).json({ success: false, message: 'Title is required' });
  if (title.length > 255) return res.status(400).json({ success: false, message: 'Title too long (max 255 chars)' });

  const validType = ['note', 'question'].includes(note_type) ? note_type : 'note';

  const result = await pool.query(
    `INSERT INTO notes (channel_id, created_by, title, content, note_type)
     VALUES ($1, $2, $3, $4, $5) RETURNING *`,
    [req.params.id, req.user.id, title, content || null, validType]
  );
  const newNote = result.rows[0];
  newNote.author_name = req.user.name;
  res.status(201).json({ success: true, note: newNote });
};

/**
 * DELETE /api/channels/:id/notes/:noteId
 * Deletes a note by ID.
 * Only the note's creator, faculty, or admin may delete it.
 */
const deleteNote = async (req, res) => {
  const result = await pool.query(
    `DELETE FROM notes WHERE id = $1 AND (created_by = $2 OR $3 = 'faculty' OR $3 = 'admin') RETURNING id`,
    [req.params.noteId, req.user.id, req.user.role]
  );
  if (!result.rows.length) return res.status(403).json({ success: false, message: 'Not authorized or not found' });
  res.json({ success: true, message: 'Note deleted' });
};

module.exports = { getNotes, createNote, deleteNote };
