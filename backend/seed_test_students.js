const bcrypt = require('bcryptjs');
const pool = require('./config/db.js');

async function setup() {
  const hash = bcrypt.hashSync('password123', 10);

  // Get batch 1 (BTech CSE 2022) info
  const batch = await pool.query("SELECT id FROM batches WHERE year = 2022 AND programme_id = 1 LIMIT 1");
  const batchId = batch.rows[0]?.id;
  if (!batchId) { console.error('Batch not found'); process.exit(1); }

  const programme = await pool.query("SELECT id FROM programmes WHERE id = 1 LIMIT 1");
  const programmeId = programme.rows[0]?.id;

  // Upsert Aryan
  const aryan = await pool.query(`
    INSERT INTO users (name, email, roll_number, password, role, avatar_initials, programme_id, batch_year, current_semester)
    VALUES ('Aryan Sharma', 'aryan@adtu.in', 'ADTU/2022-2026/BTECH-CSE/501', $1, 'student', 'AS', $2, 2022, 7)
    ON CONFLICT (email) DO UPDATE SET
      password = EXCLUDED.password, name = EXCLUDED.name,
      programme_id = EXCLUDED.programme_id, batch_year = EXCLUDED.batch_year,
      current_semester = EXCLUDED.current_semester
    RETURNING id
  `, [hash, programmeId]);

  // Upsert Priya
  const priya = await pool.query(`
    INSERT INTO users (name, email, roll_number, password, role, avatar_initials, programme_id, batch_year, current_semester)
    VALUES ('Priya Bora', 'priya@adtu.in', 'ADTU/2022-2026/BTECH-CSE/502', $1, 'student', 'PB', $2, 2022, 7)
    ON CONFLICT (email) DO UPDATE SET
      password = EXCLUDED.password, name = EXCLUDED.name,
      programme_id = EXCLUDED.programme_id, batch_year = EXCLUDED.batch_year,
      current_semester = EXCLUDED.current_semester
    RETURNING id
  `, [hash, programmeId]);

  const aryanId = aryan.rows[0].id;
  const priyaId = priya.rows[0].id;
  console.log(`Aryan ID: ${aryanId}, Priya ID: ${priyaId}`);

  // Get all channels in batch 1
  const channels = await pool.query("SELECT id FROM channels WHERE batch_id = $1", [batchId]);
  console.log(`Enrolling in ${channels.rows.length} channels of batch ${batchId}...`);

  for (const ch of channels.rows) {
    await pool.query(
      "INSERT INTO enrollments (user_id, channel_id) VALUES ($1, $2) ON CONFLICT DO NOTHING",
      [aryanId, ch.id]
    );
    await pool.query(
      "INSERT INTO enrollments (user_id, channel_id) VALUES ($1, $2) ON CONFLICT DO NOTHING",
      [priyaId, ch.id]
    );
  }

  console.log('✅ Both students enrolled in all batch 1 channels!');
  console.log('   aryan@adtu.in  / password123');
  console.log('   priya@adtu.in  / password123');
  process.exit(0);
}

setup().catch(e => { console.error(e.message); process.exit(1); });
