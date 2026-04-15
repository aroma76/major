const pool = require('./config/db.js');

async function check() {
  // Check all tables
  const tables = await pool.query(
    "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name"
  );
  console.log('All tables:', tables.rows.map(r => r.table_name).join(', '));

  // Check how channels query works (via subjectRoutes)
  const channels = await pool.query("SELECT id, batch_id, subject_name FROM channels LIMIT 5");
  console.log('Channels:', channels.rows);

  // Check batches
  const batches = await pool.query("SELECT * FROM batches LIMIT 5");
  console.log('Batches:', batches.rows);

  // Check how students are linked to batches
  const aryan = await pool.query("SELECT id, programme_id, batch_year, current_semester FROM users WHERE email = 'aryan@adtu.in'");
  console.log('Aryan user:', aryan.rows[0]);

  process.exit(0);
}

check().catch(e => { console.error(e.message); process.exit(1); });
