const pool = require('../config/db');

/**
 * GET /api/academic-events
 * Returns academic calendar events. Optionally filterable by month/year and type.
 * Uses complex date overlap logic to ensure events spanning across months show up correctly.
 * 
 * Query: ?month=4&year=2026&type=holiday
 */
const getAcademicEvents = async (req, res) => {
  const { month, year, type } = req.query;

  let where = [];
  let values = [];
  let idx = 1;

  // Find events that overlap with the requested month/year
  if (month && year) {
    where.push(`(
      (EXTRACT(MONTH FROM start_date) = $${idx} AND EXTRACT(YEAR FROM start_date) = $${idx + 1})
      OR (EXTRACT(MONTH FROM end_date) = $${idx} AND EXTRACT(YEAR FROM end_date) = $${idx + 1})
      OR (start_date <= make_date($${idx + 1}::int, $${idx}::int, 1) AND end_date >= make_date($${idx + 1}::int, $${idx}::int, 1))
    )`);
    values.push(parseInt(month), parseInt(year));
    idx += 2;
  } else if (year) {
    where.push(`EXTRACT(YEAR FROM start_date) = $${idx}`);
    values.push(parseInt(year));
    idx += 1;
  }

  // Filter by event type
  if (type && type !== 'all') {
    where.push(`event_type = $${idx}`);
    values.push(type);
    idx += 1;
  }

  const whereClause = where.length ? `WHERE ${where.join(' AND ')}` : '';

  const { rows } = await pool.query(
    `SELECT ae.*, u.name as created_by_name
     FROM academic_events ae
     LEFT JOIN users u ON ae.created_by = u.id
     ${whereClause}
     ORDER BY start_date ASC`,
    values
  );

  res.json({ success: true, events: rows });
};

/**
 * POST /api/academic-events
 * Creates a new academic event. Restricted to Admins.
 * 
 * Body: { title, description?, event_type?, start_date, end_date, colour?, is_important? }
 */
const createAcademicEvent = async (req, res) => {
  const { title, description, event_type, start_date, end_date, colour, is_important } = req.body;
  const created_by = req.user.id;

  const { rows } = await pool.query(
    `INSERT INTO academic_events (title, description, event_type, start_date, end_date, colour, is_important, created_by)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *`,
    [title, description || null, event_type || 'other', start_date, end_date,
     colour || '#3b82f6', is_important || false, created_by]
  );

  res.status(201).json({ success: true, event: rows[0] });
};

/**
 * PATCH /api/academic-events/:id
 * Updates an existing academic event. Restricted to Admins.
 * Uses COALESCE to only update provided fields.
 */
const updateAcademicEvent = async (req, res) => {
  const { id } = req.params;
  const { title, description, event_type, start_date, end_date, colour, is_important } = req.body;

  const { rows } = await pool.query(
    `UPDATE academic_events
     SET title = COALESCE($1, title),
         description = COALESCE($2, description),
         event_type = COALESCE($3, event_type),
         start_date = COALESCE($4, start_date),
         end_date = COALESCE($5, end_date),
         colour = COALESCE($6, colour),
         is_important = COALESCE($7, is_important)
     WHERE id = $8 RETURNING *`,
    [title, description, event_type, start_date, end_date, colour, is_important, id]
  );

  if (!rows.length) return res.status(404).json({ success: false, message: 'Event not found' });
  res.json({ success: true, event: rows[0] });
};

/**
 * DELETE /api/academic-events/:id
 * Deletes an academic event permanently. Restricted to Admins.
 */
const deleteAcademicEvent = async (req, res) => {
  const { id } = req.params;
  const { rowCount } = await pool.query('DELETE FROM academic_events WHERE id = $1', [id]);
  if (!rowCount) return res.status(404).json({ success: false, message: 'Event not found' });
  res.json({ success: true, message: 'Event deleted' });
};

module.exports = { getAcademicEvents, createAcademicEvent, updateAcademicEvent, deleteAcademicEvent };
