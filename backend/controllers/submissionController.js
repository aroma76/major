const pool = require('../config/db');

/**
 * POST /api/channels/:id/assignments/:assignId/submit
 * Submits or resubmits an assignment for a student.
 * If submitted past the due date, it is marked as 'late', otherwise 'submitted'.
 * Supports optional file attachments via Multer.
 */
const submitAssignment = async (req, res) => {
  const assignment_id = req.params.assignId;  // was req.params.id (wrong — that's channel ID)
  const student_id = req.user.id;

  // Verify assignment exists and get due date
  const assign = await pool.query('SELECT due_date FROM assignments WHERE id=$1', [assignment_id]);
  if (!assign.rows.length)
    return res.status(404).json({ success: false, message: 'Assignment not found' });

  // Compare dates to assign status
  const status = new Date() > new Date(assign.rows[0].due_date) ? 'late' : 'submitted';
  const file_url  = req.file?.path         || null;
  const file_name = req.file?.originalname || null;

  const existing = await pool.query(
    'SELECT id FROM assignment_submissions WHERE assignment_id=$1 AND student_id=$2',
    [assignment_id, student_id]
  );

  let result;
  if (existing.rows.length > 0) {
    // Resubmission (Update)
    result = await pool.query(
      `UPDATE assignment_submissions
       SET file_url=$1, file_name=$2, status=$3, submitted_at=NOW()
       WHERE assignment_id=$4 AND student_id=$5 RETURNING *`,
      [file_url, file_name, status, assignment_id, student_id]
    );
  } else {
    // First-time submission (Insert)
    result = await pool.query(
      `INSERT INTO assignment_submissions (assignment_id, student_id, file_url, file_name, status, submitted_at)
       VALUES ($1,$2,$3,$4,$5,NOW()) RETURNING *`,
      [assignment_id, student_id, file_url, file_name, status]
    );
  }
  res.status(201).json({ success: true, submission: result.rows[0] });
};

/**
 * PATCH /api/channels/:id/assignments/:assignId/submissions/:subId/grade
 * Grades a student's submission. Usually invoked by Faculty/Admins.
 * Sends a real-time notification to the student with their grade and feedback.
 */
const gradeSubmission = async (req, res) => {
  const { marks, feedback } = req.body;
  
  const result = await pool.query(
    `UPDATE assignment_submissions SET marks=$1, feedback=$2 WHERE id=$3 RETURNING *`,
    [marks, feedback, req.params.subId]  // was req.params.id (wrong — that's channel ID)
  );
  if (!result.rows.length)
    return res.status(404).json({ success: false, message: 'Submission not found' });

  const sub = result.rows[0];
  
  // Notify the student that they received a grade
  await pool.query(
    `INSERT INTO notifications (user_id, type, title, message, ref_id, ref_type)
     VALUES ($1,'grade','Assignment Graded',$2,$3,'submission')`,
    [sub.student_id, `You received ${marks} marks. Feedback: ${feedback || 'None'}`, sub.id]
  );
  
  res.json({ success: true, submission: result.rows[0] });
};

/**
 * GET /api/channels/:id/assignments/:assignId/my-submission
 * Retrieves the currently logged-in student's submission for a specific assignment.
 */
const getMySubmission = async (req, res) => {
  const result = await pool.query(
    'SELECT * FROM assignment_submissions WHERE assignment_id=$1 AND student_id=$2',
    [req.params.assignId, req.user.id]  // was req.params.id (wrong — that's channel ID)
  );
  res.json({ success: true, submission: result.rows[0] || null });
};

module.exports = { submitAssignment, gradeSubmission, getMySubmission };
