/**
 * ADTU StudyHub — Database Seed
 *
 * Real-world model:
 *   Each programme has MULTIPLE batches (intake years).
 *   Each batch is currently in a different semester.
 *   Students are enrolled ONLY in their own batch's channels.
 *   → A 2022-batch (Sem 7) student CANNOT see a 2024-batch (Sem 3) channel.
 *
 * Batch map (as of Academic Year 2025-26):
 *   Batch 2022  →  Sem 7   (4th year, final year for 8-sem programmes)
 *   Batch 2023  →  Sem 5   (3rd year)
 *   Batch 2024  →  Sem 3   (2nd year)
 *   Batch 2025  →  Sem 1   (1st year, freshers)
 *
 * Roll-number format mirrors real ADTU pattern:
 *   ADTU/{batchYear}-{batchYear+duration}/{PROG-CODE}/{NNN}
 *   e.g.  ADTU/2022-26/BTECH-CSE/039
 */

const pool = require('./config/db');
const bcrypt = require('bcryptjs');
const fs   = require('fs');

// ─────────────────────────────────────────────────────────────
// Faculty & Programme definitions
// ─────────────────────────────────────────────────────────────
const facultiesData = [
  {
    name: 'Faculty of Computer Technology', color: '#3b82f6',
    programmes: [
      { name: 'B.Tech CSE',                   code: 'BTECH-CSE',    duration: 8 },
      { name: 'B.Tech CSE - Data Science',    code: 'BTECH-CSE-DS', duration: 8 },
      { name: 'B.Tech CSE - AI & ML',         code: 'BTECH-CSE-AIML', duration: 8 },
      { name: 'BCA',                           code: 'BCA',          duration: 6 },
      { name: 'MCA',                           code: 'MCA',          duration: 4 },
    ],
  },
  {
    name: 'Faculty of Engineering', color: '#64748b',
    programmes: [
      { name: 'B.Tech Civil Engineering',       code: 'BTECH-CE',  duration: 8 },
      { name: 'B.Tech Electronics & Telecom',   code: 'BTECH-ECE', duration: 8 },
    ],
  },
  {
    name: 'Faculty of Commerce & Management', color: '#eab308',
    programmes: [
      { name: 'BBA', code: 'BBA', duration: 6 },
      { name: 'MBA', code: 'MBA', duration: 4 },
    ],
  },
  {
    name: 'Faculty of Nursing', color: '#ec4899',
    programmes: [
      { name: 'B.Sc Nursing', code: 'BSC-NURSING', duration: 8 },
    ],
  },
  {
    name: 'Faculty of Pharmaceutical Sciences', color: '#22c55e',
    programmes: [
      { name: 'B.Pharm', code: 'BPHARM', duration: 8 },
      { name: 'D.Pharm', code: 'DPHARM', duration: 4 },
    ],
  },
  {
    name: 'Faculty of Paramedical Sciences', color: '#8b5cf6',
    programmes: [
      { name: 'B.Sc Medical Laboratory Technology', code: 'BSC-MLT', duration: 6 },
    ],
  },
  {
    name: 'Faculty of Science', color: '#06b6d4',
    programmes: [
      { name: 'B.Sc Biotechnology', code: 'BSC-BIOTECH', duration: 6 },
      { name: 'B.Sc Microbiology',  code: 'BSC-MICRO',   duration: 6 },
    ],
  },
  {
    name: 'Faculty of Physiotherapy & Rehabilitation', color: '#14b8a6',
    programmes: [
      { name: 'Bachelor of Physiotherapy BPT', code: 'BPT', duration: 9 },
    ],
  },
  {
    name: 'Faculty of Agricultural Sciences & Technology', color: '#84cc16',
    programmes: [
      { name: 'B.Sc Agriculture', code: 'BSC-AGRI', duration: 8 },
    ],
  },
  {
    name: 'Faculty of Humanities & Social Sciences', color: '#f97316',
    programmes: [
      { name: 'B.Sc Hotel Management', code: 'BSC-HM', duration: 6 },
    ],
  },
];

// ─────────────────────────────────────────────────────────────
// Which batch-year maps to which current semester
//   (as of AY 2025-26, Jan–June term = odd semesters starting Jan)
//   Adjust if your university runs Jul-start.
// ─────────────────────────────────────────────────────────────
const batchSemesterMap = [
  { batchYear: 2022, currentSem: 7 },  // 4th year
  { batchYear: 2023, currentSem: 5 },  // 3rd year
  { batchYear: 2024, currentSem: 3 },  // 2nd year
  { batchYear: 2025, currentSem: 1 },  // 1st year (freshers)
];

// ─────────────────────────────────────────────────────────────
// Subjects per programme per semester
// ─────────────────────────────────────────────────────────────
const programmeSubjects = {
  'BTECH-CSE': {
    1: [
      { name: 'Engineering Mathematics I',      slug: 'math-1' },
      { name: 'Programming Fundamentals (C)',   slug: 'prog-c' },
      { name: 'Physics for Engineers',          slug: 'physics' },
      { name: 'English Communication',          slug: 'english' },
    ],
    3: [
      { name: 'Data Structures & Algorithms',   slug: 'dsa' },
      { name: 'Operating Systems',              slug: 'os' },
      { name: 'Database Management Systems',    slug: 'dbms' },
      { name: 'Computer Networks',              slug: 'cn' },
      { name: 'Software Engineering',           slug: 'se' },
    ],
    5: [
      { name: 'Compiler Design',                slug: 'cd' },
      { name: 'Web Technologies',               slug: 'web' },
      { name: 'Theory of Computation',          slug: 'toc' },
      { name: 'Machine Learning Basics',        slug: 'ml' },
      { name: 'Mobile App Development',         slug: 'mob-dev' },
    ],
    7: [
      { name: 'Cloud Computing',                slug: 'cloud' },
      { name: 'Information Security',           slug: 'infosec' },
      { name: 'Project Work (Major)',           slug: 'major-project' },
      { name: 'Entrepreneurship & Innovation',  slug: 'entrepreneurship' },
    ],
  },
  'BTECH-CSE-DS': {
    1: [
      { name: 'Engineering Mathematics I',      slug: 'math-1' },
      { name: 'Introduction to Data Science',   slug: 'intro-ds' },
      { name: 'Python Programming',             slug: 'python' },
    ],
    3: [
      { name: 'Statistical Methods',            slug: 'stats' },
      { name: 'Data Wrangling & EDA',           slug: 'eda' },
      { name: 'Database for Data Science',      slug: 'db-ds' },
    ],
    5: [
      { name: 'Big Data Analytics',             slug: 'bigdata' },
      { name: 'Deep Learning',                  slug: 'deep-learning' },
      { name: 'Data Visualization',             slug: 'data-viz' },
    ],
    7: [
      { name: 'Advanced ML Pipelines',          slug: 'adv-ml' },
      { name: 'Data Science Capstone',          slug: 'ds-capstone' },
    ],
  },
  'BTECH-CSE-AIML': {
    1: [
      { name: 'Engineering Mathematics I',      slug: 'math-1' },
      { name: 'Introduction to AI',             slug: 'intro-ai' },
      { name: 'Python for AI',                  slug: 'python-ai' },
    ],
    3: [
      { name: 'Machine Learning',               slug: 'ml' },
      { name: 'Computer Vision Basics',         slug: 'cv' },
      { name: 'Natural Language Processing',    slug: 'nlp' },
    ],
    5: [
      { name: 'Reinforcement Learning',         slug: 'rl' },
      { name: 'AI Ethics & Governance',         slug: 'ai-ethics' },
      { name: 'Deep Neural Networks',           slug: 'dnn' },
    ],
    7: [
      { name: 'Generative AI & LLMs',           slug: 'gen-ai' },
      { name: 'AI Project',                     slug: 'ai-project' },
    ],
  },
  'BCA': {
    1: [
      { name: 'Fundamentals of Computing',      slug: 'fund-comp' },
      { name: 'Mathematics for Computing',      slug: 'math-comp' },
    ],
    3: [
      { name: 'Data Structures',                slug: 'dsa' },
      { name: 'Object Oriented Programming',    slug: 'oop' },
    ],
    5: [
      { name: 'Web Development',                slug: 'web-dev' },
      { name: 'Mobile App Development',         slug: 'mob-dev' },
    ],
  },
  'MCA': {
    1: [
      { name: 'Advanced Programming',           slug: 'adv-prog' },
      { name: 'Discrete Mathematics',           slug: 'disc-math' },
    ],
    3: [
      { name: 'Software Project Management',    slug: 'spm' },
      { name: 'Cloud Computing',                slug: 'cloud' },
    ],
  },
  'BTECH-CE': {
    1: [
      { name: 'Engineering Mechanics',          slug: 'eng-mech' },
      { name: 'Engineering Drawing',            slug: 'eng-draw' },
    ],
    3: [
      { name: 'Structural Analysis',            slug: 'struct-analysis' },
      { name: 'Fluid Mechanics',                slug: 'fluid-mech' },
    ],
    5: [
      { name: 'Geotechnical Engineering',       slug: 'geotech' },
      { name: 'Construction Technology',        slug: 'const-tech' },
    ],
    7: [
      { name: 'Transportation Engineering',     slug: 'transport-eng' },
      { name: 'Civil Engineering Project',      slug: 'civil-project' },
    ],
  },
  'BTECH-ECE': {
    1: [
      { name: 'Basic Electronics',              slug: 'basic-elec' },
      { name: 'Circuit Theory',                 slug: 'circuit-theory' },
    ],
    3: [
      { name: 'Analog Circuits',                slug: 'analog' },
      { name: 'Digital Signal Processing',      slug: 'dsp' },
    ],
    5: [
      { name: 'VLSI Design',                    slug: 'vlsi' },
      { name: 'Wireless Communication',         slug: 'wireless' },
    ],
    7: [
      { name: 'Embedded Systems',               slug: 'embedded' },
      { name: 'ECE Final Project',              slug: 'ece-project' },
    ],
  },
  'BBA': {
    1: [
      { name: 'Principles of Management',       slug: 'mgmt' },
      { name: 'Business Communication',         slug: 'biz-comm' },
    ],
    3: [
      { name: 'Marketing Management',           slug: 'marketing' },
      { name: 'Financial Accounting',           slug: 'fin-acc' },
    ],
    5: [
      { name: 'Strategic Management',           slug: 'strategic-mgmt' },
      { name: 'Entrepreneurship',               slug: 'entrepreneurship' },
    ],
  },
  'MBA': {
    1: [
      { name: 'Organizational Behaviour',       slug: 'org-behav' },
      { name: 'Business Economics',             slug: 'biz-econ' },
    ],
    3: [
      { name: 'Operations Management',          slug: 'ops-mgmt' },
      { name: 'Research Methodology',           slug: 'research-meth' },
    ],
  },
  'BSC-NURSING': {
    1: [
      { name: 'Anatomy & Physiology',           slug: 'anatomy' },
      { name: 'Nutrition & Biochemistry',       slug: 'nutrition' },
    ],
    3: [
      { name: 'Medical-Surgical Nursing',       slug: 'med-surg' },
      { name: 'Pharmacology',                   slug: 'pharmacology' },
    ],
    5: [
      { name: 'Community Health Nursing',       slug: 'community-health' },
      { name: 'Mental Health Nursing',          slug: 'mental-health' },
    ],
    7: [
      { name: 'Nursing Research',               slug: 'nursing-research' },
      { name: 'Clinical Practicum',             slug: 'clinical' },
    ],
  },
  'BPHARM': {
    1: [
      { name: 'Human Anatomy & Physiology',     slug: 'anatomy' },
      { name: 'Pharmaceutical Chemistry',       slug: 'pharma-chem' },
    ],
    3: [
      { name: 'Pharmacognosy',                  slug: 'pharmacognosy' },
      { name: 'Pharmaceutical Engineering',     slug: 'pharma-eng' },
    ],
    5: [
      { name: 'Pharmacology II',               slug: 'pharmacology-2' },
      { name: 'Biopharmaceutics',               slug: 'biopharm' },
    ],
    7: [
      { name: 'Clinical Pharmacy',              slug: 'clinical-pharmacy' },
      { name: 'Pharmacy Project',               slug: 'pharmacy-project' },
    ],
  },
  'DPHARM': {
    1: [
      { name: 'Pharmacognosy & Phytochemistry', slug: 'pharmacognosy' },
      { name: 'Pharmaceutical Chemistry',       slug: 'pharma-chem' },
    ],
    3: [
      { name: 'Pharmacology',                   slug: 'pharmacology' },
      { name: 'Community Pharmacy',             slug: 'community-pharm' },
    ],
  },
  'BSC-MLT': {
    1: [
      { name: 'Medical Biochemistry',           slug: 'biochem' },
      { name: 'Anatomy & Physiology',           slug: 'anatomy' },
    ],
    3: [
      { name: 'Hematology',                     slug: 'hematology' },
      { name: 'Microbiology',                   slug: 'microbiology' },
    ],
    5: [
      { name: 'Clinical Biochemistry',          slug: 'clinical-biochem' },
      { name: 'Immunology',                     slug: 'immunology' },
    ],
  },
  'BSC-BIOTECH': {
    1: [
      { name: 'Cell Biology',                   slug: 'cell-bio' },
      { name: 'Biochemistry',                   slug: 'biochemistry' },
    ],
    3: [
      { name: 'Molecular Biology',              slug: 'mol-bio' },
      { name: 'Genetics',                       slug: 'genetics' },
    ],
    5: [
      { name: 'Genetic Engineering',            slug: 'genetic-eng' },
      { name: 'Bioinformatics',                 slug: 'bioinformatics' },
    ],
  },
  'BSC-MICRO': {
    1: [
      { name: 'General Microbiology',           slug: 'gen-micro' },
      { name: 'Biochemistry',                   slug: 'biochemistry' },
    ],
    3: [
      { name: 'Immunology',                     slug: 'immunology' },
      { name: 'Medical Microbiology',           slug: 'med-micro' },
    ],
    5: [
      { name: 'Environmental Microbiology',     slug: 'env-micro' },
      { name: 'Industrial Microbiology',        slug: 'ind-micro' },
    ],
  },
  'BPT': {
    1: [
      { name: 'Anatomy',                        slug: 'anatomy' },
      { name: 'Physiology',                     slug: 'physiology' },
    ],
    3: [
      { name: 'Physiotherapy in Orthopaedics',  slug: 'ortho-physio' },
      { name: 'Exercise Therapy',               slug: 'exercise-therapy' },
    ],
    5: [
      { name: 'Physiotherapy in Neurology',     slug: 'neuro-physio' },
      { name: 'Sports Physiotherapy',           slug: 'sports-physio' },
    ],
    7: [
      { name: 'Cardiopulmonary Physiotherapy',  slug: 'cardio-physio' },
      { name: 'BPT Clinical Project',           slug: 'bpt-project' },
    ],
  },
  'BSC-AGRI': {
    1: [
      { name: 'Fundamentals of Agronomy',       slug: 'agronomy' },
      { name: 'Agricultural Botany',            slug: 'agri-botany' },
    ],
    3: [
      { name: 'Soil Science',                   slug: 'soil-science' },
      { name: 'Plant Pathology',                slug: 'plant-pathology' },
    ],
    5: [
      { name: 'Farm Management',                slug: 'farm-mgmt' },
      { name: 'Agricultural Economics',         slug: 'agri-econ' },
    ],
    7: [
      { name: 'Agricultural Biotechnology',     slug: 'agri-biotech' },
      { name: 'Agri Project',                   slug: 'agri-project' },
    ],
  },
  'BSC-HM': {
    1: [
      { name: 'Fundamentals of Food Production', slug: 'food-prod' },
      { name: 'Front Office Operations',         slug: 'front-office' },
    ],
    3: [
      { name: 'Food & Beverage Service',         slug: 'fb-service' },
      { name: 'Hospitality Marketing',           slug: 'hosp-marketing' },
    ],
    5: [
      { name: 'Resort & Spa Management',         slug: 'resort-mgmt' },
      { name: 'Tourism Management',              slug: 'tourism-mgmt' },
    ],
  },
};

// ─────────────────────────────────────────────────────────────
// Name pools — realistic Assamese student names
// Separated by batch so each batch gets distinct students
// ─────────────────────────────────────────────────────────────
const namePools = {
  2022: [
    'Saurabh Borthakur', 'Lakhimi Borah', 'Nayan Moni Saikia', 'Supriya Phukan',
    'Parinita Gogoi',    'Abhijit Dey',   'Trideep Sarmah',     'Chandana Bhuyan',
  ],
  2023: [
    'Riya Talukdar',  'Manash Pratim', 'Sangeeta Barman', 'Nirab Mahanta',
    'Jahnabi Goswami','Bikash Saikia', 'Kangana Roy',     'Bedanta Chaliha',
  ],
  2024: [
    'Priyanka Deka', 'Rahul Bora',     'Ankita Das',    'Dipjyoti Kalita',
    'Rimjhim Hazarika', 'Bhaskar Nath','Puja Sharma',   'Himanshu Gogoi',
  ],
  2025: [
    'Anup Baruah',   'Deepika Chetia', 'Rupam Rajkhowa', 'Junu Rabha',
    'Nilufar Begum', 'Anurag Baruah',  'Karishma Bhuyan','Sourav Dutta',
  ],
};

// ─────────────────────────────────────────────────────────────
// Chat message templates
// ─────────────────────────────────────────────────────────────
const chatMessages = [
  (s) => `Welcome everyone to ${s}! Please read the syllabus carefully.`,
  ()  => `When will the first internal exam be held?`,
  ()  => `Has anyone done the assignment? I need help with the last question.`,
  ()  => `Check the Files section — notes from last class are uploaded.`,
  ()  => `Lab session tomorrow at 9 AM sharp. Be on time!`,
  ()  => `Can someone share the reference book name for Unit 2?`,
  ()  => `Sir, will the internal be objective or subjective format?`,
  ()  => `I missed last class. Can anyone share the notes?`,
];

async function seedChannelContent(channelId, teacherId, students, subName) {
  // Announcement
  await pool.query(
    `INSERT INTO announcements (channel_id, user_id, title, content, is_important)
     VALUES ($1,$2,$3,$4,$5)`,
    [channelId, teacherId,
      `Mid-semester Syllabus — ${subName}`,
      `Units 1–4 are covered in this internal. 30 marks are for internal assessment. Attendance is mandatory.`,
      true]
  );

  // Chat messages
  await pool.query(`INSERT INTO messages (channel_id, sender_id, content) VALUES ($1,$2,$3)`,
    [channelId, teacherId, chatMessages[0](subName)]);
  for (let i = 1; i < Math.min(5, students.length); i++) {
    await pool.query(`INSERT INTO messages (channel_id, sender_id, content) VALUES ($1,$2,$3)`,
      [channelId, students[i].id, chatMessages[i % chatMessages.length]()]);
  }

  // Assignment
  const { rows: aRows } = await pool.query(
    `INSERT INTO assignments (channel_id, created_by, title, description, due_date)
     VALUES ($1,$2,$3,$4, NOW() + INTERVAL '7 days') RETURNING id`,
    [channelId, teacherId,
      `Assignment 1 — ${subName}`,
      `Submit a PDF or Word document covering Unit 1 key concepts. Max 10 pages.`]
  );
  const assignId = aRows[0].id;

  // Submissions by first 2 students
  for (let i = 0; i < Math.min(2, students.length); i++) {
    await pool.query(
      `INSERT INTO assignment_submissions (assignment_id, student_id, status)
       VALUES ($1,$2,'submitted') ON CONFLICT DO NOTHING`,
      [assignId, students[i].id]
    );
  }

  // File (note: no 'title' column in schema, using description)
  await pool.query(
    `INSERT INTO files (channel_id, uploaded_by, file_name, file_url, file_type, file_size, description)
     VALUES ($1,$2,$3,$4,$5,$6,$7)`,
    [channelId, teacherId,
      `Unit1_${subName.replace(/\s+/g, '_')}.pdf`,
      `https://example.com/files/unit1.pdf`,
      `application/pdf`, 1024000,
      `Complete Unit 1 notes for ${subName}`]
  );

  // Note by first student
  if (students.length > 0) {
    await pool.query(
      `INSERT INTO notes (channel_id, created_by, title, content) VALUES ($1,$2,$3,$4)`,
      [channelId, students[0].id,
        `Quick Tips — ${subName}`,
        `Focus on lecture slides + practice past papers. Group study before internal.`]
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MAIN SEED
// ─────────────────────────────────────────────────────────────
async function seed() {
  console.log('\n🌱  ADTU StudyHub — Multi-Batch, Multi-Semester Seed');
  console.log('═══════════════════════════════════════════════════\n');

  const defaultDob   = '2004-05-15';
  const hashedPwd    = await bcrypt.hash(defaultDob, 10);

  try {
    // Execute schema
    const schemaSql = fs.readFileSync('./config/schema.sql', 'utf8');
    await pool.query(schemaSql);
    console.log('✅ Schema applied');

    // Wipe all existing records (safe to re-run)
    await pool.query(`
      TRUNCATE TABLE
        assignment_submissions, assignments, announcements, messages, notes,
        files, enrollments, channels, batches, users, programmes, faculties
      RESTART IDENTITY CASCADE
    `);
    console.log('🗑️  Cleared previous data\n');

    // ── Admin ──────────────────────────────────────────────
    await pool.query(
      `INSERT INTO users (name, email, roll_number, password, role)
       VALUES ($1,$2,$3,$4,$5)`,
      ['Admin ADTU', 'admin@adtu.in', 'ADMIN001', hashedPwd, 'admin']
    );
    console.log('👤  Admin created: admin@adtu.in\n');

    let facIndex = 0;

    for (const fac of facultiesData) {
      facIndex++;
      const { rows: fRows } = await pool.query(
        `INSERT INTO faculties (name, color_code) VALUES ($1,$2) RETURNING id`,
        [fac.name, fac.color]
      );
      const facultyId = fRows[0].id;

      console.log(`📚  ${fac.name}`);

      // Teachers (2 per faculty, created once)
      const facTag = `F${String(facIndex).padStart(2,'0')}`;
      const { rows: t1Rows } = await pool.query(
        `INSERT INTO users (name, email, roll_number, password, role)
         VALUES ($1,$2,$3,$4,$5) RETURNING id`,
        ['Dr. Manoj Sarma',   `manoj.sarma.${facTag}@adtu.in`,  `TCH-${facTag}-01`, hashedPwd, 'faculty']
      );
      const { rows: t2Rows } = await pool.query(
        `INSERT INTO users (name, email, roll_number, password, role)
         VALUES ($1,$2,$3,$4,$5) RETURNING id`,
        ['Prof. Anita Gogoi', `anita.gogoi.${facTag}@adtu.in`, `TCH-${facTag}-02`, hashedPwd, 'faculty']
      );
      const teacher1Id = t1Rows[0].id;
      const teacher2Id = t2Rows[0].id;

      for (const prog of fac.programmes) {
        const progCode = prog.code; // e.g. BTECH-CSE
        const { rows: pRows } = await pool.query(
          `INSERT INTO programmes (faculty_id, name, code, duration_semesters)
           VALUES ($1,$2,$3,$4) RETURNING id`,
          [facultyId, prog.name, progCode, prog.duration]
        );
        const progId = pRows[0].id;

        console.log(`   └─ ${prog.name} (${progCode}, ${prog.duration} sems)`);

        // ── Create one BATCH per intake year ──────────────
        for (const { batchYear, currentSem } of batchSemesterMap) {

          // Skip  semesters that exceed programme duration
          if (currentSem > prog.duration) continue;

          const graduationYear = batchYear + Math.floor(prog.duration / 2);
          const { rows: bRows } = await pool.query(
            `INSERT INTO batches (programme_id, year) VALUES ($1,$2) RETURNING id`,
            [progId, batchYear]
          );
          const batchId = bRows[0].id;

          // ── Students for this batch ────────────────────
          const names = namePools[batchYear] || namePools[2024];
          const batchStudentIds = [];

          for (let idx = 0; idx < names.length; idx++) {
            const name      = names[idx];
            const role      = idx === 0 ? 'class_representative' : 'student';
            const initials  = name.split(' ').map(n => n[0]).join('').substring(0, 2).toUpperCase();
            // Roll number mirrors ADTU pattern: ADTU/2022-26/BTECH-CSE/039
            const roll      = `ADTU/${batchYear}-${graduationYear}/${progCode}/${String(idx + 1).padStart(3, '0')}`;
            // Email: firstname.lastname.progcode.batchyear@adtu.in
            const parts     = name.toLowerCase().split(' ');
            const email     = `${parts[0]}.${parts[parts.length-1]}.${progCode.toLowerCase()}.${batchYear}@adtu.in`;

            const { rows: uRows } = await pool.query(
              `INSERT INTO users
                 (name, email, roll_number, password, role, programme_id, batch_year, current_semester, avatar_initials)
               VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING id`,
              [name, email, roll, hashedPwd, role, progId, batchYear, currentSem, initials]
            );
            batchStudentIds.push({ id: uRows[0].id, name, email, roll });
          }

          // ── Channels & Enrollments for this batch+sem ──
          const subjects = (programmeSubjects[progCode] || {})[currentSem] || [];
          let channelCount = 0;

          for (let si = 0; si < subjects.length; si++) {
            const sub       = subjects[si];
            const teacherId = si % 2 === 0 ? teacher1Id : teacher2Id;
            // Unique channel name guarantees no cross-batch collision
            const channelName = `${progCode.toLowerCase()}-${batchYear}-sem${currentSem}-${sub.slug}`;

            let channelId;
            try {
              const { rows: cRows } = await pool.query(
                `INSERT INTO channels
                   (batch_id, semester_number, subject_name, subject_slug, channel_name, teacher_id)
                 VALUES ($1,$2,$3,$4,$5,$6) RETURNING id`,
                [batchId, currentSem, sub.name, sub.slug, channelName, teacherId]
              );
              channelId = cRows[0].id;
              channelCount++;
            } catch {
              console.warn(`      ⚠️  Skipping duplicate channel: ${channelName}`);
              continue;
            }

            // Enroll only THIS batch's students (key isolation point!)
            for (const s of batchStudentIds) {
              await pool.query(
                `INSERT INTO enrollments (user_id, channel_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`,
                [s.id, channelId]
              );
            }

            // Seed sample content
            await seedChannelContent(channelId, teacherId, batchStudentIds, sub.name);
          }

          console.log(`      ✅ Batch ${batchYear} (Sem ${currentSem}) — ${batchStudentIds.length} students, ${channelCount} channels`);
        }
      }
      console.log('');
    }

    // ─────────────────────────────────────────────────────
    // Print test credentials
    // ─────────────────────────────────────────────────────
    console.log('═══════════════════════════════════════════════════');
    console.log('🎉  SEED COMPLETED SUCCESSFULLY');
    console.log('═══════════════════════════════════════════════════');
    console.log('🔐  ALL accounts use password: 2004-05-15 (DOB)\n');

    console.log('📌  ISOLATION TEST ACCOUNTS (B.Tech CSE)\n');
    console.log('  Batch 2022 | Sem 7  (your batch / senior)');
    console.log('    CR:  saurabh.borthakur.btech-cse.2022@adtu.in');
    console.log('    Roll: ADTU/2022-26/BTECH-CSE/001\n');

    console.log('  Batch 2023 | Sem 5  (1 year junior)');
    console.log('    CR:  riya.talukdar.btech-cse.2023@adtu.in');
    console.log('    Roll: ADTU/2023-27/BTECH-CSE/001\n');

    console.log('  Batch 2024 | Sem 3  (2 years junior)');
    console.log('    CR:  priyanka.deka.btech-cse.2024@adtu.in');
    console.log('    Roll: ADTU/2024-28/BTECH-CSE/001\n');

    console.log('  Batch 2025 | Sem 1  (freshers)');
    console.log('    CR:  anup.baruah.btech-cse.2025@adtu.in');
    console.log('    Roll: ADTU/2025-29/BTECH-CSE/001\n');

    console.log('  👉 Each batch can ONLY see their own semester channels.');
    console.log('  👉 A Sem 7 student CANNOT access Sem 3 channels & vice versa.');
    console.log('═══════════════════════════════════════════════════\n');

    process.exit(0);
  } catch (err) {
    console.error('\n❌  SEED FAILED:', err.message);
    console.error(err);
    process.exit(1);
  }
}

seed();
