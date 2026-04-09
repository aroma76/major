/**
 * Seeds realistic AdtU Academic Calendar events for AY 2025-26
 * Run: node seed_academic_events.js
 */
const pool = require('./config/db');
const fs   = require('fs');

const events = [
  // ── Semester Timeline ────────────────────────────────────────────
  { title: 'Odd Semester Begins (Sem 1, 3, 5, 7)', event_type: 'semester', start_date: '2025-08-01', end_date: '2025-08-01', colour: '#3b82f6', is_important: true, description: 'Beginning of odd semester classes for all programmes.' },
  { title: 'Odd Semester Ends', event_type: 'semester', start_date: '2025-11-30', end_date: '2025-11-30', colour: '#3b82f6', is_important: true, description: 'Last day of odd semester classes.' },
  { title: 'Even Semester Begins (Sem 2, 4, 6, 8)', event_type: 'semester', start_date: '2026-01-06', end_date: '2026-01-06', colour: '#8b5cf6', is_important: true, description: 'Beginning of even semester classes for all programmes.' },
  { title: 'Even Semester Ends', event_type: 'semester', start_date: '2026-05-31', end_date: '2026-05-31', colour: '#8b5cf6', is_important: true, description: 'Last day of even semester classes.' },

  // ── Internal Assessments ─────────────────────────────────────────
  { title: '1st Internal Assessment (Odd Sem)', event_type: 'exam', start_date: '2025-09-08', end_date: '2025-09-13', colour: '#f59e0b', is_important: true, description: 'First internal assessment for all odd semester subjects. 30 marks each.' },
  { title: '2nd Internal Assessment (Odd Sem)', event_type: 'exam', start_date: '2025-10-20', end_date: '2025-10-25', colour: '#f59e0b', is_important: true, description: 'Second internal assessment for all odd semester subjects.' },
  { title: '1st Internal Assessment (Even Sem)', event_type: 'exam', start_date: '2026-02-16', end_date: '2026-02-21', colour: '#f59e0b', is_important: true, description: 'First internal assessment for all even semester subjects.' },
  { title: '2nd Internal Assessment (Even Sem)', event_type: 'exam', start_date: '2026-04-06', end_date: '2026-04-11', colour: '#f59e0b', is_important: true, description: 'Second internal assessment for all even semester subjects.' },

  // ── End Semester Exams ───────────────────────────────────────────
  { title: 'Odd Semester End Exams', event_type: 'exam', start_date: '2025-12-08', end_date: '2025-12-22', colour: '#ef4444', is_important: true, description: 'End semester university examinations for all odd semester programmes.' },
  { title: 'Even Semester End Exams', event_type: 'exam', start_date: '2026-06-08', end_date: '2026-06-22', colour: '#ef4444', is_important: true, description: 'End semester university examinations for all even semester programmes.' },

  // ── Result / Registration ────────────────────────────────────────
  { title: 'Odd Semester Result Declaration', event_type: 'deadline', start_date: '2026-01-15', end_date: '2026-01-15', colour: '#14b8a6', is_important: false, description: 'Expected result declaration date for odd semester examinations.' },
  { title: 'Even Semester Result Declaration', event_type: 'deadline', start_date: '2026-07-10', end_date: '2026-07-10', colour: '#14b8a6', is_important: false, description: 'Expected result declaration date for even semester examinations.' },
  { title: 'Subject Registration Deadline (Even Sem)', event_type: 'deadline', start_date: '2025-12-20', end_date: '2025-12-20', colour: '#f97316', is_important: true, description: 'Last date to complete even semester subject registration.' },

  // ── National / Gazetted Holidays ─────────────────────────────────
  { title: 'Republic Day', event_type: 'holiday', start_date: '2026-01-26', end_date: '2026-01-26', colour: '#22c55e', is_important: false, description: 'National holiday — Republic Day of India.' },
  { title: 'Holi', event_type: 'holiday', start_date: '2026-03-04', end_date: '2026-03-04', colour: '#22c55e', is_important: false, description: 'Festival of Colours. University closed.' },
  { title: 'Bohag Bihu (Assamese New Year)', event_type: 'holiday', start_date: '2026-04-14', end_date: '2026-04-16', colour: '#22c55e', is_important: true, description: 'Bihu festival holidays. University closed.' },
  { title: 'Good Friday', event_type: 'holiday', start_date: '2026-04-03', end_date: '2026-04-03', colour: '#22c55e', is_important: false, description: 'Good Friday national holiday.' },
  { title: 'Eid ul-Fitr', event_type: 'holiday', start_date: '2026-03-31', end_date: '2026-03-31', colour: '#22c55e', is_important: false, description: 'Eid ul-Fitr holiday. University closed.' },
  { title: 'Independence Day', event_type: 'holiday', start_date: '2026-08-15', end_date: '2026-08-15', colour: '#22c55e', is_important: false, description: 'National holiday — Independence Day of India.' },
  { title: 'Gandhi Jayanti', event_type: 'holiday', start_date: '2025-10-02', end_date: '2025-10-02', colour: '#22c55e', is_important: false, description: 'Gandhi Jayanti — National holiday.' },
  { title: 'Diwali Holidays', event_type: 'holiday', start_date: '2025-10-20', end_date: '2025-10-22', colour: '#22c55e', is_important: false, description: 'Diwali festival holidays. University closed.' },
  { title: 'Christmas', event_type: 'holiday', start_date: '2025-12-25', end_date: '2025-12-25', colour: '#22c55e', is_important: false, description: 'Christmas Day. University closed.' },
  { title: 'Winter Break', event_type: 'holiday', start_date: '2025-12-25', end_date: '2026-01-05', colour: '#22c55e', is_important: true, description: 'University winter break. Classes resume January 6, 2026.' },

  // ── Fests & Events ───────────────────────────────────────────────
  { title: 'Pragyan — Annual Tech Fest', event_type: 'fest', start_date: '2026-02-07', end_date: '2026-02-09', colour: '#ec4899', is_important: true, description: 'AdtU annual technology and innovation festival. Hackathons, competitions, workshops.' },
  { title: 'Cultural Fest — Utsav', event_type: 'fest', start_date: '2025-11-14', end_date: '2025-11-15', colour: '#ec4899', is_important: true, description: 'Annual cultural extravaganza featuring music, dance, drama, and art.' },
  { title: 'Sports Week', event_type: 'fest', start_date: '2026-01-19', end_date: '2026-01-24', colour: '#ec4899', is_important: false, description: 'Inter-department sports competition week.' },
  { title: 'Freshers Welcome Party', event_type: 'fest', start_date: '2025-08-20', end_date: '2025-08-20', colour: '#ec4899', is_important: false, description: 'Welcome event for new batch students.' },

  // ── Workshops & Seminars ─────────────────────────────────────────
  { title: 'Industry Connect Seminar — CSE', event_type: 'workshop', start_date: '2026-03-15', end_date: '2026-03-15', colour: '#06b6d4', is_important: false, description: 'Guest lectures from industry professionals for B.Tech CSE students.' },
  { title: 'Research Methodology Workshop', event_type: 'workshop', start_date: '2026-01-28', end_date: '2026-01-30', colour: '#06b6d4', is_important: false, description: 'Three-day workshop on academic research and paper writing. Open to all PG students.' },
  { title: 'Placement Orientation & Training', event_type: 'workshop', start_date: '2026-02-02', end_date: '2026-02-06', colour: '#06b6d4', is_important: true, description: 'Campus placement preparation — aptitude, GD, HR interview sessions.' },
];

async function seedAcademicEvents() {
  console.log('\n📅  Seeding Academic Calendar Events…');
  const client = await pool.connect();
  try {
    // Create table if not exists
    const migration = fs.readFileSync('./config/academic_events_migration.sql', 'utf8');
    await client.query(migration);

    // Find admin user id
    const { rows: adminRows } = await client.query("SELECT id FROM users WHERE role = 'admin' LIMIT 1");
    const adminId = adminRows[0]?.id || null;

    // Clear existing and reinsert
    await client.query('DELETE FROM academic_events');

    for (const e of events) {
      await client.query(
        `INSERT INTO academic_events (title, description, event_type, start_date, end_date, colour, is_important, created_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
        [e.title, e.description, e.event_type, e.start_date, e.end_date, e.colour, e.is_important, adminId]
      );
    }

    console.log(`✅  Seeded ${events.length} academic events successfully.\n`);
    process.exit(0);
  } catch (err) {
    console.error('❌  Seed failed:', err.message);
    process.exit(1);
  } finally {
    client.release();
  }
}

seedAcademicEvents();
