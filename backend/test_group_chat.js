const pool = require('./config/db');

async function test() {
  try {
    const users = await pool.query(`SELECT * FROM users WHERE role = 'student' LIMIT 1`);
    if (users.rows.length === 0) {
      console.log('No student found in DB.');
      process.exit(0);
    }
    const student = users.rows[0];
    console.log('Student:', student.roll_number, student.name);

    const enrollments = await pool.query(`
      SELECT c.channel_name, c.subject_name 
      FROM enrollments e 
      JOIN channels c ON e.channel_id = c.id 
      WHERE e.user_id = $1
    `, [student.id]);
    
    console.log('Group chats enrolled:', enrollments.rows.length);
    console.log(enrollments.rows);
  } catch (err) {
    console.error(err);
  } finally {
    process.exit(0);
  }
}
test();
