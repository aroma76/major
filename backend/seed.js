const pool = require('./config/db');
const bcrypt = require('bcryptjs');
const fs = require('fs');

const facultiesData = [
  {
    name: 'Faculty of Computer Technology', color: '#3b82f6',
    programmes: [
      { name: 'B.Tech CSE', code: 'btech-cse', duration: 8 },
      { name: 'B.Tech CSE - Data Science', code: 'btech-cse-ds', duration: 8 },
      { name: 'B.Tech CSE - AI & ML', code: 'btech-cse-aiml', duration: 8 },
      { name: 'BCA', code: 'bca', duration: 6 },
      { name: 'MCA', code: 'mca', duration: 4 }
    ]
  },
  {
    name: 'Faculty of Engineering', color: '#64748b',
    programmes: [
      { name: 'B.Tech Civil Engineering', code: 'btech-ce', duration: 8 },
      { name: 'B.Tech Electronics & Telecom', code: 'btech-ece', duration: 8 }
    ]
  },
  {
    name: 'Faculty of Commerce & Management', color: '#eab308',
    programmes: [
      { name: 'BBA', code: 'bba', duration: 6 },
      { name: 'MBA', code: 'mba', duration: 4 }
    ]
  },
  {
    name: 'Faculty of Nursing', color: '#ec4899',
    programmes: [
      { name: 'B.Sc Nursing', code: 'bsc-nursing', duration: 8 }
    ]
  },
  {
    name: 'Faculty of Pharmaceutical Sciences', color: '#22c55e',
    programmes: [
      { name: 'B.Pharm', code: 'bpharm', duration: 8 },
      { name: 'D.Pharm', code: 'dpharm', duration: 4 }
    ]
  },
  {
    name: 'Faculty of Paramedical Sciences', color: '#8b5cf6',
    programmes: [
      { name: 'B.Sc Medical Laboratory Technology', code: 'bsc-mlt', duration: 6 }
    ]
  },
  {
    name: 'Faculty of Science', color: '#06b6d4',
    programmes: [
      { name: 'B.Sc Biotechnology', code: 'bsc-biotech', duration: 6 },
      { name: 'B.Sc Microbiology', code: 'bsc-micro', duration: 6 }
    ]
  },
  {
    name: 'Faculty of Physiotherapy & Rehabilitation', color: '#14b8a6',
    programmes: [
      { name: 'Bachelor of Physiotherapy BPT', code: 'bpt', duration: 9 }
    ]
  },
  {
    name: 'Faculty of Agricultural Sciences & Technology', color: '#84cc16',
    programmes: [
      { name: 'B.Sc Agriculture', code: 'bsc-agri', duration: 8 }
    ]
  },
  {
    name: 'Faculty of Humanities & Social Sciences', color: '#f97316',
    programmes: [
      { name: 'B.Sc Hotel Management', code: 'bsc-hm', duration: 6 }
    ]
  }
];

const assameseNames = [
  'Priyanka Deka', 'Rahul Bora', 'Ankita Das', 'Dipjyoti Kalita', 'Rimjhim Hazarika', 
  'Bhaskar Nath', 'Puja Sharma', 'Nilufar Begum', 'Himanshu Gogoi', 'Anurag Baruah',
  'Karishma Bhuyan', 'Sourav Dutta', 'Riya Talukdar', 'Manash Pratim', 'Sangeeta Barman',
  'Nirab Mahanta', 'Jahnabi Goswami', 'Bikash Saikia', 'Kangana Roy', 'Bedanta Chaliha'
];

async function seed() {
  console.log('🌱 Starting database seed...');
  const defaultDob = '2004-05-15';
  const hashedDob = await bcrypt.hash(defaultDob, 10);
  
  try {
    // Execute Schema
    const schemaSql = fs.readFileSync('./config/schema.sql', 'utf8');
    await pool.query(schemaSql);
    console.log('✅ Schema executed successfully');

    // Wipe existing data cleanly (so seed can be re-run any time)
    await pool.query(`
      TRUNCATE TABLE 
        assignment_submissions, assignments, announcements, messages, notes,
        files, enrollments, channels, batches, users, programmes, faculties
      RESTART IDENTITY CASCADE
    `);
    console.log('🗑️  Cleared existing data');

    // 1. Admin setup
    const adminQuery = `INSERT INTO users (name, email, roll_number, password, role) VALUES ($1, $2, $3, $4, $5) RETURNING id`;
    const adminRes = await pool.query(adminQuery, ['Admin ADTU', 'admin@adtu.in', 'ADMIN001', hashedDob, 'admin']);
    console.log('✅ Admin created');

    let cseProgrammeId = null;
    let btechCseBatchId = null;
    let csTeacher1 = null;
    let csTeacher2 = null;

    // 2. Faculties & Programmes
    let facIndex = 0;
    for (const fac of facultiesData) {
      facIndex++;
      const { rows: fRows } = await pool.query(`INSERT INTO faculties (name, color_code) VALUES ($1, $2) RETURNING id`, [fac.name, fac.color]);
      const facultyId = fRows[0].id;

      let facultyTeacherCreated = false;

      for (const prog of fac.programmes) {
        const { rows: pRows } = await pool.query(`INSERT INTO programmes (faculty_id, name, code, duration_semesters) VALUES ($1, $2, $3, $4) RETURNING id`, [facultyId, prog.name, prog.code, prog.duration]);
        const progId = pRows[0].id;

        if (prog.code === 'btech-cse') cseProgrammeId = progId;

        // Create batches (e.g. 2024)
        const { rows: bRows } = await pool.query(`INSERT INTO batches (programme_id, year) VALUES ($1, $2) RETURNING id`, [progId, 2024]);
        
        if (prog.code === 'btech-cse') btechCseBatchId = bRows[0].id;

        // Generate 2 teachers per faculty (to save on seed time just generating once per faculty)
        if (!facultyTeacherCreated) {
          const facAcronym = fac.name.split(' ').map(w => w[0]).join('').substring(0, 4) + facIndex;
          const t1 = await pool.query(`INSERT INTO users (name, email, roll_number, password, role, programme_id) VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`, [`Dr. Manoj Sarma`, `manoj.sarma.${facAcronym}@adtu.in`, `TCH-${facAcronym}-01`, hashedDob, 'faculty', progId]);
          const t2 = await pool.query(`INSERT INTO users (name, email, roll_number, password, role, programme_id) VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`, [`Prof. Anita Gogoi`, `anita.gogoi.${facAcronym}@adtu.in`, `TCH-${facAcronym}-02`, hashedDob, 'faculty', progId]);
          if(prog.code === 'btech-cse') { csTeacher1 = t1.rows[0].id; csTeacher2 = t2.rows[0].id; }
          facultyTeacherCreated = true;
        }

        // Generate 10 students for this programme
        const shuffled = [...assameseNames].sort(() => 0.5 - Math.random()).slice(0, 10);
        for (let count = 1; count <= 10; count++) {
          const name = shuffled[count - 1];
          let role = count === 1 ? 'class_representative' : 'student';
          let initials = name.split(' ').map(n => n[0]).join('').substring(0,2);
          let roll = `ADTU/2024/${prog.code.toUpperCase()}/${String(count).padStart(3,'0')}`;
          let email = `${name.split(' ')[0].toLowerCase()}.${name.split(' ')[1].toLowerCase()}.${prog.code}@adtu.in`;
          
          await pool.query(
            `INSERT INTO users (name, email, roll_number, password, role, programme_id, current_semester, avatar_initials) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
            [name, email, roll, hashedDob, role, progId, 3, initials]
          );
        }
      }
    }
    console.log('✅ Faculties, Programmes, Batches, Teachers & Students created');

    // 3. Channels & Content for B.Tech CSE 2024 Sem 3
    if (btechCseBatchId && csTeacher1) {
      const subjects = [
        { name: 'Data Structures & Algorithms', slug: 'data-structures' },
        { name: 'Operating Systems', slug: 'operating-systems' },
        { name: 'Database Management Systems', slug: 'dbms' },
        { name: 'Computer Networks', slug: 'computer-networks' },
        { name: 'Software Engineering', slug: 'software-engineering' },
        { name: 'Discrete Mathematics', slug: 'discrete-math' },
        { name: 'Life Skills', slug: 'life-skills' }
      ];

      // Get CSE students to enroll
      const cseStudents = await pool.query(`SELECT id FROM users WHERE programme_id=$1 AND batch_year=2024 AND role IN ('student', 'class_representative')`, [cseProgrammeId]);

      for (let i=0; i<subjects.length; i++) {
        const sub = subjects[i];
        const teacherId = i % 2 === 0 ? csTeacher1 : csTeacher2;
        const channelName = `btech-cse-2024-sem3-${sub.slug}`;

        const { rows: cRows } = await pool.query(
          `INSERT INTO channels (batch_id, semester_number, subject_name, subject_slug, channel_name, teacher_id) VALUES ($1,$2,$3,$4,$5,$6) RETURNING id`,
          [btechCseBatchId, 3, sub.name, sub.slug, channelName, teacherId]
        );
        const channelId = cRows[0].id;

        // Enroll students in this channel
        for (const student of cseStudents.rows) {
          await pool.query(`INSERT INTO enrollments (user_id, channel_id) VALUES ($1,$2)`, [student.id, channelId]);
        }

        // Add 1 Announcement
        await pool.query(`INSERT INTO announcements (channel_id, user_id, title, content, is_important) VALUES ($1,$2,$3,$4,$5)`,
          [channelId, teacherId, `Mid-semester Syllabus for ${sub.name}`, `The syllabus is units 1 to 4. Please prepare accordingly.`, true]
        );

        // Add 3-5 Chat Messages
        await pool.query(`INSERT INTO messages (channel_id, sender_id, content) VALUES ($1,$2,$3)`, [channelId, teacherId, `Welcome to ${sub.name}. Check the announcements.`]);
        await pool.query(`INSERT INTO messages (channel_id, sender_id, content) VALUES ($1,$2,$3)`, [channelId, cseStudents.rows[0].id, `Thank you sir, understood.`]);
        await pool.query(`INSERT INTO messages (channel_id, sender_id, content) VALUES ($1,$2,$3)`, [channelId, cseStudents.rows[1].id, `Are we having lab for this today?`]);

        // Add Assignment
        const rAssign = await pool.query(`INSERT INTO assignments (channel_id, created_by, title, description, due_date) VALUES ($1,$2,$3,$4, NOW() + INTERVAL '7 days') RETURNING id`,
          [channelId, teacherId, `Assignment 1: Introduction`, `Please submit your PDF assignment detailing concepts from Unit 1.`]
        );
        const assignId = rAssign.rows[0].id;

        // Mock Submission for the first student
        await pool.query(`INSERT INTO assignment_submissions (assignment_id, student_id, status) VALUES ($1,$2,'submitted')`,
          [assignId, cseStudents.rows[0].id]
        );

        // Add Mock File with description
        await pool.query(`INSERT INTO files (channel_id, uploaded_by, title, description, file_name, file_url, file_type, file_size) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
          [channelId, teacherId, `Unit 1 Notes`, `Complete PDF for Unit 1.`, `Unit_1_Notes.pdf`, `https://example.com/notes.pdf`, `application/pdf`, 1024000]
        );

        // Add Mock Note
        await pool.query(`INSERT INTO notes (channel_id, created_by, title, content) VALUES ($1,$2,$3,$4)`,
          [channelId, cseStudents.rows[0].id, `Exam Prep Tips`, `Focus on trees, graphs, and the latest algorithms covered in class.`]
        );
      }
      console.log('✅ Seeded CSE Channels, Enrollments, Messages, Announcements, Assignments, Files, Notes');
    }

    console.log('🎉 SEED COMPLETED SUCCESSFULLY');
    process.exit(0);
  } catch (err) {
    console.error('❌ SEED FAILED:', err);
    process.exit(1);
  }
}

seed();
