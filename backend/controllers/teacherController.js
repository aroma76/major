const pool = require('../config/db');

/**
 * GET /api/teacher/stats
 * Returns live overview statistics for the logged-in faculty member's dashboard.
 * Parallelizes three database queries to calculate:
 * - Total students enrolled across all their channels
 * - Total pending assignment submissions needing grading
 * - Total active personal projects
 * - Total number of subjects/channels taught
 */
const getTeacherStats = async (req, res) => {
  const teacherId = req.user.id;

  // All channels taught by this teacher
  const channelRes = await pool.query(
    `SELECT id FROM channels WHERE teacher_id = $1`,
    [teacherId]
  );
  const channelIds = channelRes.rows.map(r => r.id);

  if (channelIds.length === 0) {
    return res.json({
      success: true,
      stats: {
        totalStudents: 0,
        pendingReviews: 0,
        activeProjects: 0,
        totalSubjects: 0,
      },
    });
  }

  // Run all three stat queries in parallel — 3× faster than sequential awaits
  const [studentRes, pendingRes, projectRes] = await Promise.all([
    pool.query(
      `SELECT COUNT(DISTINCT user_id) AS total
       FROM enrollments
       WHERE channel_id = ANY($1::int[])`,
      [channelIds]
    ),
    pool.query(
      `SELECT COUNT(*) AS total
       FROM assignment_submissions sub
       INNER JOIN assignments a ON sub.assignment_id = a.id
       WHERE a.channel_id = ANY($1::int[])
         AND sub.marks IS NULL`,
      [channelIds]
    ),
    pool.query(
      `SELECT COUNT(*) AS total FROM projects WHERE created_by = $1`,
      [teacherId]
    ),
  ]);

  res.json({
    success: true,
    stats: {
      totalStudents: parseInt(studentRes.rows[0]?.total ?? 0),
      pendingReviews: parseInt(pendingRes.rows[0]?.total ?? 0),
      activeProjects: parseInt(projectRes.rows[0]?.total ?? 0),
      totalSubjects: channelIds.length,
    },
  });
};

/**
 * GET /api/teacher/recent-activity
 * Returns the latest feed data for the faculty dashboard.
 * Fetches the 5 most recent announcements across all channels taught by this teacher.
 */
const getTeacherRecentActivity = async (req, res) => {
  const teacherId = req.user.id;

  const channelRes = await pool.query(
    `SELECT id, subject_name FROM channels WHERE teacher_id = $1`,
    [teacherId]
  );
  const channels = channelRes.rows;
  const channelIds = channels.map(r => r.id);

  if (channelIds.length === 0) {
    return res.json({ success: true, announcements: [], recentMessages: [] });
  }

  // Latest 5 announcements across all teacher's channels
  const annRes = await pool.query(
    `SELECT ann.*, u.name AS created_by_name, ch.subject_name
     FROM announcements ann
     INNER JOIN users u ON ann.user_id = u.id
     INNER JOIN channels ch ON ann.channel_id = ch.id
     WHERE ann.channel_id = ANY($1::int[])
     ORDER BY ann.created_at DESC
     LIMIT 5`,
    [channelIds]
  );

  res.json({
    success: true,
    announcements: annRes.rows,
    recentMessages: [],
  });
};

/**
 * GET /api/student/recent-activity
 * Returns the latest feed data for the student dashboard.
 * Fetches the 5 most recent announcements from all channels the student is currently enrolled in.
 */
const getStudentRecentActivity = async (req, res) => {
  const studentId = req.user.id;

  // Channels this student is enrolled in
  const enrollRes = await pool.query(
    `SELECT e.channel_id, ch.subject_name
     FROM enrollments e
     INNER JOIN channels ch ON ch.id = e.channel_id
     WHERE e.user_id = $1`,
    [studentId]
  );

  const channelIds = enrollRes.rows.map(r => parseInt(r.channel_id));

  if (channelIds.length === 0) {
    return res.json({ success: true, announcements: [], recentMessages: [] });
  }

  // Latest 5 announcements from enrolled channels
  const annRes = await pool.query(
    `SELECT ann.*, u.name AS created_by_name, ch.subject_name
     FROM announcements ann
     INNER JOIN users u ON ann.user_id = u.id
     INNER JOIN channels ch ON ann.channel_id = ch.id
     WHERE ann.channel_id = ANY($1::int[])
     ORDER BY ann.created_at DESC
     LIMIT 5`,
    [channelIds]
  );

  res.json({
    success: true,
    announcements: annRes.rows,
    recentMessages: [],
  });
};

module.exports = { getTeacherStats, getTeacherRecentActivity, getStudentRecentActivity };
