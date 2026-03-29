const pool = require('../config/db');

const submitAssignment = async (req, res) => {
  const assignment_id = req.params.id;
  const student_id = req.user.id;
  const assign = await pool.query('SELECT deadline FROM assignments WHERE id=$1', [assignment_id]);
  if (!assign.rows.length) return res.status(404).json({ success: false, message: 'Assignment not found' });
  const status = new Date() > new Date(assign.rows[0].deadline) ? 'late' : 'submitted';
  const file_url = req.file?.path || null;
  const file_name = req.file?.originalname || null;
  const existing = await pool.query('SELECT id FROM submissions WHERE assignment_id=$1 AND student_id=$2', [assignment_id, student_id]);
  let result;
  if (existing.rows.length > 0) {
    result = await pool.query(
      `UPDATE submissions SET file_url=$1,file_name=$2,status=$3,submitted_at=NOW() WHERE assignment_id=$4 AND student_id=$5 RETURNING *`,
      [file_url, file_name, status, assignment_id, student_id]
    );
  } else {
    result = await pool.query(
      `INSERT INTO submissions (assignment_id,student_id,file_url,file_name,status,submitted_at) VALUES ($1,$2,$3,$4,$5,NOW()) RETURNING *`,
      [assignment_id, student_id, file_url, file_name, status]
    );
  }
  res.status(201).json({ success: true, submission: result.rows[0] });
};

const gradeSubmission = async (req, res) => {
  const { marks, feedback } = req.body;
  const result = await pool.query(`UPDATE submissions SET marks=$1,feedback=$2 WHERE id=$3 RETURNING *`, [marks, feedback, req.params.id]);
  if (!result.rows.length) return res.status(404).json({ success: false, message: 'Submission not found' });
  const sub = result.rows[0];
  await pool.query(
    `INSERT INTO notifications (user_id,type,title,message,ref_id,ref_type) VALUES ($1,'grade','Assignment Graded',$2,$3,'submission')`,
    [sub.student_id, `You received ${marks} marks. Feedback: ${feedback || 'None'}`, sub.id]
  );
  res.json({ success: true, submission: result.rows[0] });
};

const getMySubmission = async (req, res) => {
  const result = await pool.query('SELECT * FROM submissions WHERE assignment_id=$1 AND student_id=$2', [req.params.id, req.user.id]);
  res.json({ success: true, submission: result.rows[0] || null });
};

module.exports = { submitAssignment, gradeSubmission, getMySubmission };
