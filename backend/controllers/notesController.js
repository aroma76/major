const pool = require('../config/db');

/**
 * GET /api/channels/:id/notes
 * Returns all notes for a specific channel, newest first.
 * Joins with users so the author's display name is included in each row.
 * Accessible to any authenticated member of the channel.
 */
const getNotes = async (req, res) => {
  const result = await pool.query(
    `SELECT n.*, u.name AS author_name 
     FROM notes n 
     INNER JOIN users u ON n.created_by = u.id 
     WHERE n.channel_id = $1 
     ORDER BY n.created_at DESC`,
    [req.params.id]
  );
  res.json({ success: true, notes: result.rows });
};

/**
 * POST /api/channels/:id/notes
 * Creates a new note inside a channel.
 * The note is owned by the authenticated user making the request.
 * Appends the author's display name to the response so the client
 * can show it immediately without a follow-up fetch.
 *
 * Body: { title: string, content?: string }
 */
const createNote = async (req, res) => {
  const { title, content } = req.body;
  if (!title) return res.status(400).json({ success: false, message: 'Title is required' });

  const result = await pool.query(
    `INSERT INTO notes (channel_id, created_by, title, content) 
     VALUES ($1, $2, $3, $4) RETURNING *`,
    [req.params.id, req.user.id, title, content]
  );
  const newNote = result.rows[0];
  // Attach author name so the client can render immediately without a refetch
  newNote.author_name = req.user.name;
  res.status(201).json({ success: true, note: newNote });
};

/**
 * DELETE /api/channels/:id/notes/:noteId
 * Deletes a note by ID.
 * Only the note's creator, faculty, or admin may delete it.
 * Returns 403 if the requester is neither the owner nor a privileged role.
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
