/**
 * ADTU StudyHub — Optimised Database Seed  (Batch-Insert Edition)
 *
 * Strategy: collect ALL rows in memory first, then write each table in one
 * bulk INSERT inside a single transaction.  Round-trips to the DB drop from
 * ~thousands → ~15, cutting seed time from 6 min → under 30 s.
 *
 * Batch map (AY 2025-26):
 *   Batch 2022 → Sem 7   Batch 2023 → Sem 5
 *   Batch 2024 → Sem 3   Batch 2025 → Sem 1
 *
 * Roll-number: ADTU/{batchYear}-{gradYear}/{PROG-CODE}/{NNN}
 */

const pool = require('./config/db');
const bcrypt = require('bcryptjs');
const fs = require('fs');

// ─────────────────────────────────────────────────────────────
// Static data
// ─────────────────────────────────────────────────────────────
const facultiesData = [
  {
    name: 'Faculty of Computer Technology', color: '#3b82f6',
    programmes: [
      { name: 'B.Tech CSE',                code: 'BTECH-CSE',      duration: 8 },
      { name: 'B.Tech CSE - Data Science', code: 'BTECH-CSE-DS',   duration: 8 },
      { name: 'B.Tech CSE - AI & ML',      code: 'BTECH-CSE-AIML', duration: 8 },
      { name: 'BCA',                        code: 'BCA',            duration: 6 },
      { name: 'MCA',                        code: 'MCA',            duration: 4 },
    ],
  },
  {
    name: 'Faculty of Engineering', color: '#64748b',
    programmes: [
      { name: 'B.Tech Civil Engineering',     code: 'BTECH-CE',  duration: 8 },
      { name: 'B.Tech Electronics & Telecom', code: 'BTECH-ECE', duration: 8 },
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
    programmes: [{ name: 'B.Sc Nursing', code: 'BSC-NURSING', duration: 8 }],
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
    programmes: [{ name: 'B.Sc Medical Laboratory Technology', code: 'BSC-MLT', duration: 6 }],
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
    programmes: [{ name: 'Bachelor of Physiotherapy BPT', code: 'BPT', duration: 9 }],
  },
  {
    name: 'Faculty of Agricultural Sciences & Technology', color: '#84cc16',
    programmes: [{ name: 'B.Sc Agriculture', code: 'BSC-AGRI', duration: 8 }],
  },
  {
    name: 'Faculty of Humanities & Social Sciences', color: '#f97316',
    programmes: [{ name: 'B.Sc Hotel Management', code: 'BSC-HM', duration: 6 }],
  },
];

const batchSemesterMap = [
  { batchYear: 2022, currentSem: 7 },
  { batchYear: 2023, currentSem: 5 },
  { batchYear: 2024, currentSem: 3 },
  { batchYear: 2025, currentSem: 1 },
];

const programmeSubjects = {
  'BTECH-CSE': {
    1: [{ name: 'Engineering Mathematics I', slug: 'math-1' }, { name: 'Programming Fundamentals (C)', slug: 'prog-c' }, { name: 'Physics for Engineers', slug: 'physics' }, { name: 'English Communication', slug: 'english' }],
    3: [{ name: 'Data Structures & Algorithms', slug: 'dsa' }, { name: 'Operating Systems', slug: 'os' }, { name: 'Database Management Systems', slug: 'dbms' }, { name: 'Computer Networks', slug: 'cn' }, { name: 'Software Engineering', slug: 'se' }],
    5: [{ name: 'Compiler Design', slug: 'cd' }, { name: 'Web Technologies', slug: 'web' }, { name: 'Theory of Computation', slug: 'toc' }, { name: 'Machine Learning Basics', slug: 'ml' }, { name: 'Mobile App Development', slug: 'mob-dev' }],
    7: [{ name: 'Cloud Computing', slug: 'cloud' }, { name: 'Information Security', slug: 'infosec' }, { name: 'Project Work (Major)', slug: 'major-project' }, { name: 'Entrepreneurship & Innovation', slug: 'entrepreneurship' }],
  },
  'BTECH-CSE-DS': {
    1: [{ name: 'Engineering Mathematics I', slug: 'math-1' }, { name: 'Introduction to Data Science', slug: 'intro-ds' }, { name: 'Python Programming', slug: 'python' }],
    3: [{ name: 'Statistical Methods', slug: 'stats' }, { name: 'Data Wrangling & EDA', slug: 'eda' }, { name: 'Database for Data Science', slug: 'db-ds' }],
    5: [{ name: 'Big Data Analytics', slug: 'bigdata' }, { name: 'Deep Learning', slug: 'deep-learning' }, { name: 'Data Visualization', slug: 'data-viz' }],
    7: [{ name: 'Advanced ML Pipelines', slug: 'adv-ml' }, { name: 'Data Science Capstone', slug: 'ds-capstone' }],
  },
  'BTECH-CSE-AIML': {
    1: [{ name: 'Engineering Mathematics I', slug: 'math-1' }, { name: 'Introduction to AI', slug: 'intro-ai' }, { name: 'Python for AI', slug: 'python-ai' }],
    3: [{ name: 'Machine Learning', slug: 'ml' }, { name: 'Computer Vision Basics', slug: 'cv' }, { name: 'Natural Language Processing', slug: 'nlp' }],
    5: [{ name: 'Reinforcement Learning', slug: 'rl' }, { name: 'AI Ethics & Governance', slug: 'ai-ethics' }, { name: 'Deep Neural Networks', slug: 'dnn' }],
    7: [{ name: 'Generative AI & LLMs', slug: 'gen-ai' }, { name: 'AI Project', slug: 'ai-project' }],
  },
  'BCA': {
    1: [{ name: 'Fundamentals of Computing', slug: 'fund-comp' }, { name: 'Mathematics for Computing', slug: 'math-comp' }],
    3: [{ name: 'Data Structures', slug: 'dsa' }, { name: 'Object Oriented Programming', slug: 'oop' }],
    5: [{ name: 'Web Development', slug: 'web-dev' }, { name: 'Mobile App Development', slug: 'mob-dev' }],
  },
  'MCA': {
    1: [{ name: 'Advanced Programming', slug: 'adv-prog' }, { name: 'Discrete Mathematics', slug: 'disc-math' }],
    3: [{ name: 'Software Project Management', slug: 'spm' }, { name: 'Cloud Computing', slug: 'cloud' }],
  },
  'BTECH-CE': {
    1: [{ name: 'Engineering Mechanics', slug: 'eng-mech' }, { name: 'Engineering Drawing', slug: 'eng-draw' }],
    3: [{ name: 'Structural Analysis', slug: 'struct-analysis' }, { name: 'Fluid Mechanics', slug: 'fluid-mech' }],
    5: [{ name: 'Geotechnical Engineering', slug: 'geotech' }, { name: 'Construction Technology', slug: 'const-tech' }],
    7: [{ name: 'Transportation Engineering', slug: 'transport-eng' }, { name: 'Civil Engineering Project', slug: 'civil-project' }],
  },
  'BTECH-ECE': {
    1: [{ name: 'Basic Electronics', slug: 'basic-elec' }, { name: 'Circuit Theory', slug: 'circuit-theory' }],
    3: [{ name: 'Analog Circuits', slug: 'analog' }, { name: 'Digital Signal Processing', slug: 'dsp' }],
    5: [{ name: 'VLSI Design', slug: 'vlsi' }, { name: 'Wireless Communication', slug: 'wireless' }],
    7: [{ name: 'Embedded Systems', slug: 'embedded' }, { name: 'ECE Final Project', slug: 'ece-project' }],
  },
  'BBA': {
    1: [{ name: 'Principles of Management', slug: 'mgmt' }, { name: 'Business Communication', slug: 'biz-comm' }],
    3: [{ name: 'Marketing Management', slug: 'marketing' }, { name: 'Financial Accounting', slug: 'fin-acc' }],
    5: [{ name: 'Strategic Management', slug: 'strategic-mgmt' }, { name: 'Entrepreneurship', slug: 'entrepreneurship' }],
  },
  'MBA': {
    1: [{ name: 'Organizational Behaviour', slug: 'org-behav' }, { name: 'Business Economics', slug: 'biz-econ' }],
    3: [{ name: 'Operations Management', slug: 'ops-mgmt' }, { name: 'Research Methodology', slug: 'research-meth' }],
  },
  'BSC-NURSING': {
    1: [{ name: 'Anatomy & Physiology', slug: 'anatomy' }, { name: 'Nutrition & Biochemistry', slug: 'nutrition' }],
    3: [{ name: 'Medical-Surgical Nursing', slug: 'med-surg' }, { name: 'Pharmacology', slug: 'pharmacology' }],
    5: [{ name: 'Community Health Nursing', slug: 'community-health' }, { name: 'Mental Health Nursing', slug: 'mental-health' }],
    7: [{ name: 'Nursing Research', slug: 'nursing-research' }, { name: 'Clinical Practicum', slug: 'clinical' }],
  },
  'BPHARM': {
    1: [{ name: 'Human Anatomy & Physiology', slug: 'anatomy' }, { name: 'Pharmaceutical Chemistry', slug: 'pharma-chem' }],
    3: [{ name: 'Pharmacognosy', slug: 'pharmacognosy' }, { name: 'Pharmaceutical Engineering', slug: 'pharma-eng' }],
    5: [{ name: 'Pharmacology II', slug: 'pharmacology-2' }, { name: 'Biopharmaceutics', slug: 'biopharm' }],
    7: [{ name: 'Clinical Pharmacy', slug: 'clinical-pharmacy' }, { name: 'Pharmacy Project', slug: 'pharmacy-project' }],
  },
  'DPHARM': {
    1: [{ name: 'Pharmacognosy & Phytochemistry', slug: 'pharmacognosy' }, { name: 'Pharmaceutical Chemistry', slug: 'pharma-chem' }],
    3: [{ name: 'Pharmacology', slug: 'pharmacology' }, { name: 'Community Pharmacy', slug: 'community-pharm' }],
  },
  'BSC-MLT': {
    1: [{ name: 'Medical Biochemistry', slug: 'biochem' }, { name: 'Anatomy & Physiology', slug: 'anatomy' }],
    3: [{ name: 'Hematology', slug: 'hematology' }, { name: 'Microbiology', slug: 'microbiology' }],
    5: [{ name: 'Clinical Biochemistry', slug: 'clinical-biochem' }, { name: 'Immunology', slug: 'immunology' }],
  },
  'BSC-BIOTECH': {
    1: [{ name: 'Cell Biology', slug: 'cell-bio' }, { name: 'Biochemistry', slug: 'biochemistry' }],
    3: [{ name: 'Molecular Biology', slug: 'mol-bio' }, { name: 'Genetics', slug: 'genetics' }],
    5: [{ name: 'Genetic Engineering', slug: 'genetic-eng' }, { name: 'Bioinformatics', slug: 'bioinformatics' }],
  },
  'BSC-MICRO': {
    1: [{ name: 'General Microbiology', slug: 'gen-micro' }, { name: 'Biochemistry', slug: 'biochemistry' }],
    3: [{ name: 'Immunology', slug: 'immunology' }, { name: 'Medical Microbiology', slug: 'med-micro' }],
    5: [{ name: 'Environmental Microbiology', slug: 'env-micro' }, { name: 'Industrial Microbiology', slug: 'ind-micro' }],
  },
  'BPT': {
    1: [{ name: 'Anatomy', slug: 'anatomy' }, { name: 'Physiology', slug: 'physiology' }],
    3: [{ name: 'Physiotherapy in Orthopaedics', slug: 'ortho-physio' }, { name: 'Exercise Therapy', slug: 'exercise-therapy' }],
    5: [{ name: 'Physiotherapy in Neurology', slug: 'neuro-physio' }, { name: 'Sports Physiotherapy', slug: 'sports-physio' }],
    7: [{ name: 'Cardiopulmonary Physiotherapy', slug: 'cardio-physio' }, { name: 'BPT Clinical Project', slug: 'bpt-project' }],
  },
  'BSC-AGRI': {
    1: [{ name: 'Fundamentals of Agronomy', slug: 'agronomy' }, { name: 'Agricultural Botany', slug: 'agri-botany' }],
    3: [{ name: 'Soil Science', slug: 'soil-science' }, { name: 'Plant Pathology', slug: 'plant-pathology' }],
    5: [{ name: 'Farm Management', slug: 'farm-mgmt' }, { name: 'Agricultural Economics', slug: 'agri-econ' }],
    7: [{ name: 'Agricultural Biotechnology', slug: 'agri-biotech' }, { name: 'Agri Project', slug: 'agri-project' }],
  },
  'BSC-HM': {
    1: [{ name: 'Fundamentals of Food Production', slug: 'food-prod' }, { name: 'Front Office Operations', slug: 'front-office' }],
    3: [{ name: 'Food & Beverage Service', slug: 'fb-service' }, { name: 'Hospitality Marketing', slug: 'hosp-marketing' }],
    5: [{ name: 'Resort & Spa Management', slug: 'resort-mgmt' }, { name: 'Tourism Management', slug: 'tourism-mgmt' }],
  },
};

const namePools = {
  2022: ['Saurabh Borthakur', 'Lakhimi Borah',   'Nayan Moni Saikia', 'Supriya Phukan', 'Parinita Gogoi', 'Abhijit Dey',    'Trideep Sarmah',  'Chandana Bhuyan'],
  2023: ['Riya Talukdar',    'Manash Pratim',    'Sangeeta Barman',   'Nirab Mahanta',  'Jahnabi Goswami','Bikash Saikia',  'Kangana Roy',     'Bedanta Chaliha'],
  2024: ['Priyanka Deka',    'Rahul Bora',       'Ankita Das',        'Dipjyoti Kalita','Rimjhim Hazarika','Bhaskar Nath',  'Puja Sharma',     'Himanshu Gogoi'],
  2025: ['Anup Baruah',      'Deepika Chetia',   'Rupam Rajkhowa',    'Junu Rabha',     'Nilufar Begum',  'Anurag Baruah', 'Karishma Bhuyan', 'Sourav Dutta'],
};

const chatTemplates = [
  (s) => `Welcome everyone to ${s}! Please read the syllabus carefully.`,
  ()  => `When will the first internal exam be held?`,
  ()  => `Has anyone done the assignment? I need help with the last question.`,
  ()  => `Check the Files section — notes from last class are uploaded.`,
  ()  => `Lab session tomorrow at 9 AM sharp. Be on time!`,
];

// ─────────────────────────────────────────────────────────────
// Bulk insert helper — chunks rows to stay under 65 535 params
// Returns array of { id } objects when `returning` is set.
// ─────────────────────────────────────────────────────────────
async function bulkInsert(client, table, columns, rows, { returning = null, conflict = '' } = {}) {
  if (rows.length === 0) return [];
  const CHUNK = Math.floor(60000 / columns.length);
  const results = [];

  for (let offset = 0; offset < rows.length; offset += CHUNK) {
    const chunk = rows.slice(offset, offset + CHUNK);
    const placeholders = chunk
      .map((_, ri) =>
        `(${columns.map((_, ci) => `$${ri * columns.length + ci + 1}`).join(', ')})`
      )
      .join(', ');
    const values = chunk.flat();
    let sql = `INSERT INTO ${table} (${columns.join(', ')}) VALUES ${placeholders}`;
    if (conflict) sql += ` ${conflict}`;
    if (returning)  sql += ` RETURNING ${returning}`;

    const { rows: returned } = await client.query(sql, values);
    if (returning) results.push(...returned);
  }
  return results;
}

// ─────────────────────────────────────────────────────────────
// MAIN SEED
// ─────────────────────────────────────────────────────────────
async function seed() {
  const t0 = Date.now();
  console.log('\n🌱  ADTU StudyHub — Optimised Batch Seed');
  console.log('══════════════════════════════════════════\n');

  const defaultDob = '2004-05-15';
  console.log('🔒  Hashing password…');
  const hashedPwd = await bcrypt.hash(defaultDob, 10);

  const client = await pool.connect();
  try {
    // ── Schema ──────────────────────────────────────────────────
    console.log('📄  Applying schema…');
    const schemaSql = fs.readFileSync('./config/schema.sql', 'utf8');
    await client.query(schemaSql);

    await client.query('BEGIN');

    // ── Clear ────────────────────────────────────────────────────
    console.log('🗑️   Clearing previous data…');
    await client.query(`
      TRUNCATE TABLE
        assignment_submissions, assignments, announcements, messages, notes,
        files, enrollments, channels, batches, users, programmes, faculties
      RESTART IDENTITY CASCADE
    `);

    // ════════════════════════════════════════════════════════════
    // PHASE 1 — collect all row data in JS memory
    // ════════════════════════════════════════════════════════════
    console.log('🧠  Building data in memory…');

    // Faculties
    const facultyRows = facultiesData.map(f => [f.name, f.color]);

    // System users: admin + 2 teachers per faculty
    const sysUserRows = [
      ['Admin ADTU', 'admin@gmail.com', 'ADMIN001', hashedPwd, 'admin', null, null, null, 'AA'],
    ];
    // teacher slot index → [t1idx, t2idx] per faculty
    const teacherSlots = []; // teacherSlots[fi] = [idxInSysUsers for t1, idxInSysUsers for t2]
    facultiesData.forEach((_, fi) => {
      const tag = `F${String(fi + 1).padStart(2, '0')}`;
      teacherSlots.push([sysUserRows.length, sysUserRows.length + 1]);
      sysUserRows.push(['Dr. Manoj Sarma',   `manoj.sarma.${tag}@gmail.com`,  `TCH-${tag}-01`, hashedPwd, 'faculty', null, null, null, 'MS']);
      sysUserRows.push(['Prof. Anita Gogoi', `anita.gogoi.${tag}@gmail.com`, `TCH-${tag}-02`, hashedPwd, 'faculty', null, null, null, 'AG']);
    });

    // Programmes — build as flat list with back-reference to faculty index
    const progRows   = []; // [faculty_id_placeholder, name, code, duration] — faculty_id filled after insert
    const progMeta   = []; // { fi, progCode, duration }
    facultiesData.forEach((fac, fi) => {
      fac.programmes.forEach(prog => {
        progRows.push([fi, prog.name, prog.code, prog.duration]); // fi = placeholder; replaced below
        progMeta.push({ fi, progCode: prog.code, duration: prog.duration });
      });
    });

    // Batches — flat list with back-ref to progIndex
    const batchRows = []; // [prog_id_placeholder, batchYear]
    const batchMeta = []; // { pi, progCode, batchYear, currentSem, fi }
    progMeta.forEach((pm, pi) => {
      batchSemesterMap.forEach(({ batchYear, currentSem }) => {
        if (currentSem > pm.duration) return;
        batchRows.push([pi, batchYear]); // pi = placeholder
        batchMeta.push({ pi, progCode: pm.progCode, batchYear, currentSem, fi: pm.fi, duration: pm.duration });
      });
    });

    // Students — flat list with back-ref to batchIndex
    const studentRows = []; // [name, email, roll, pwd, role, prog_id_placeholder, batchYear, currentSem, initials]
    const studentMeta = []; // { bi, nameStr, email, roll }
    batchMeta.forEach((bm, bi) => {
      const gradYear = bm.batchYear + Math.floor(bm.duration / 2);
      const names    = namePools[bm.batchYear] || namePools[2024];
      names.forEach((name, idx) => {
        const role     = idx === 0 ? 'class_representative' : 'student';
        const initials = name.split(' ').map(n => n[0]).join('').substring(0, 2).toUpperCase();
        const roll     = `ADTU/${bm.batchYear}-${gradYear}/${bm.progCode}/${String(idx + 1).padStart(3, '0')}`;
        const parts    = name.toLowerCase().split(' ');
        const email    = `${parts[0]}.${parts[parts.length - 1]}.${bm.progCode.toLowerCase()}.${bm.batchYear}@gmail.com`;
        studentRows.push([name, email, roll, hashedPwd, role, bm.pi, bm.batchYear, bm.currentSem, initials]);
        studentMeta.push({ bi, name, email, roll });
      });
    });

    // Channels
    const channelRows = []; // [batch_id_placeholder, sem, subjectName, slug, channelName, teacher_id_placeholder]
    const channelMeta = []; // { bi, teacherSlotIdx, subName }
    const seenNames   = new Set();
    batchMeta.forEach((bm, bi) => {
      const subjects = (programmeSubjects[bm.progCode] || {})[bm.currentSem] || [];
      subjects.forEach((sub, si) => {
        const cname = `${bm.progCode.toLowerCase()}-${bm.batchYear}-sem${bm.currentSem}-${sub.slug}`;
        if (seenNames.has(cname)) return;
        seenNames.add(cname);
        const teacherSysIdx = teacherSlots[bm.fi][si % 2]; // index in sysUserRows
        channelRows.push([bi, bm.currentSem, sub.name, sub.slug, cname, teacherSysIdx]);
        channelMeta.push({ bi, teacherSysIdx, subName: sub.name });
      });
    });

    // ════════════════════════════════════════════════════════════
    // PHASE 2 — bulk insert, resolve real IDs, repeat
    // ════════════════════════════════════════════════════════════
    console.log('⚡  Inserting faculties…');
    const facResults = await bulkInsert(client, 'faculties', ['name', 'color_code'], facultyRows, { returning: 'id' });
    const facultyIds = facResults.map(r => r.id);

    console.log('⚡  Inserting system users (admin + teachers)…');
    const sysUserResults = await bulkInsert(client, 'users',
      ['name', 'email', 'roll_number', 'password', 'role', 'programme_id', 'batch_year', 'current_semester', 'avatar_initials'],
      sysUserRows, { returning: 'id' }
    );
    const sysUserIds = sysUserResults.map(r => r.id);
    // teacherIds[fi] = [t1id, t2id]
    const teacherIds = teacherSlots.map(([i1, i2]) => [sysUserIds[i1], sysUserIds[i2]]);

    console.log('⚡  Inserting programmes…');
    const progInsertRows = progRows.map(([fi, name, code, dur]) => [facultyIds[fi], name, code, dur]);
    const progResults = await bulkInsert(client, 'programmes',
      ['faculty_id', 'name', 'code', 'duration_semesters'], progInsertRows, { returning: 'id' }
    );
    const programmeIds = progResults.map(r => r.id);

    console.log('⚡  Inserting batches…');
    const batchInsertRows = batchRows.map(([pi, yr]) => [programmeIds[pi], yr]);
    const batchResults = await bulkInsert(client, 'batches', ['programme_id', 'year'], batchInsertRows, { returning: 'id' });
    const batchIds = batchResults.map(r => r.id);

    console.log('⚡  Inserting students…');
    const studentInsertRows = studentRows.map(([name, email, roll, pwd, role, pi, by, cs, init]) =>
      [name, email, roll, pwd, role, programmeIds[pi], by, cs, init]
    );
    const studentResults = await bulkInsert(client, 'users',
      ['name', 'email', 'roll_number', 'password', 'role', 'programme_id', 'batch_year', 'current_semester', 'avatar_initials'],
      studentInsertRows, { returning: 'id' }
    );
    const studentIds = studentResults.map(r => r.id);

    // Group student IDs by batchIndex
    const studentsByBatch = {}; // bi → [{id, name, email, roll}]
    studentMeta.forEach((sm, idx) => {
      if (!studentsByBatch[sm.bi]) studentsByBatch[sm.bi] = [];
      studentsByBatch[sm.bi].push({ id: studentIds[idx], ...sm });
    });

    console.log('⚡  Inserting channels…');
    const channelInsertRows = channelRows.map(([bi, sem, subName, slug, cname, tIdx]) =>
      [batchIds[bi], sem, subName, slug, cname, sysUserIds[tIdx]]
    );
    const channelResults = await bulkInsert(client, 'channels',
      ['batch_id', 'semester_number', 'subject_name', 'subject_slug', 'channel_name', 'teacher_id'],
      channelInsertRows, { returning: 'id' }
    );
    const channelIds = channelResults.map(r => r.id);

    // ── Enrollments ──────────────────────────────────────────────
    console.log('⚡  Inserting enrollments…');
    const enrollRows = [];
    channelMeta.forEach((cm, ci) => {
      (studentsByBatch[cm.bi] || []).forEach(s => {
        enrollRows.push([s.id, channelIds[ci]]);
      });
    });
    await bulkInsert(client, 'enrollments', ['user_id', 'channel_id'], enrollRows,
      { conflict: 'ON CONFLICT DO NOTHING' }
    );

    // ── Channel content ──────────────────────────────────────────
    console.log('⚡  Inserting announcements, messages, assignments, files, notes…');
    const dueDate     = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
    const annoRows    = [];
    const msgRows     = [];
    const assignRows  = [];
    const fileRows    = [];
    const noteRows    = [];
    const assignMeta  = []; // { channelIdx, students[] } — for submissions

    channelMeta.forEach((cm, ci) => {
      const students  = studentsByBatch[cm.bi] || [];
      const teacherId = sysUserIds[cm.teacherSysIdx];
      const cid       = channelIds[ci];
      const sn        = cm.subName;

      annoRows.push([cid, teacherId,
        `Mid-semester Syllabus — ${sn}`,
        `Units 1–4 are covered in this internal. 30 marks are for internal assessment. Attendance is mandatory.`,
        true]);

      msgRows.push([cid, teacherId, chatTemplates[0](sn)]);
      for (let i = 1; i < Math.min(5, students.length); i++) {
        msgRows.push([cid, students[i].id, chatTemplates[i % chatTemplates.length]()]);
      }

      assignRows.push([cid, teacherId,
        `Assignment 1 — ${sn}`,
        `Submit a PDF or Word document covering Unit 1 key concepts. Max 10 pages.`,
        dueDate]);

      assignMeta.push({ ci, students: students.slice(0, 2) });

      fileRows.push([cid, teacherId,
        `Unit1_${sn.replace(/\s+/g, '_')}.pdf`,
        `https://example.com/files/unit1.pdf`,
        `application/pdf`, 1024000,
        `Complete Unit 1 notes for ${sn}`]);

      if (students.length > 0) {
        noteRows.push([cid, students[0].id,
          `Quick Tips — ${sn}`,
          `Focus on lecture slides + practice past papers. Group study before internal.`]);
      }
    });

    await bulkInsert(client, 'announcements',
      ['channel_id', 'user_id', 'title', 'content', 'is_important'], annoRows);

    await bulkInsert(client, 'messages',
      ['channel_id', 'sender_id', 'content'], msgRows);

    const assignResults = await bulkInsert(client, 'assignments',
      ['channel_id', 'created_by', 'title', 'description', 'due_date'], assignRows, { returning: 'id' });

    const subRows = [];
    assignMeta.forEach((am, ai) => {
      const assignId = assignResults[ai]?.id;
      if (!assignId) return;
      am.students.forEach(s => subRows.push([assignId, s.id, 'submitted']));
    });
    await bulkInsert(client, 'assignment_submissions',
      ['assignment_id', 'student_id', 'status'], subRows,
      { conflict: 'ON CONFLICT DO NOTHING' });

    await bulkInsert(client, 'files',
      ['channel_id', 'uploaded_by', 'file_name', 'file_url', 'file_type', 'file_size', 'description'], fileRows);

    await bulkInsert(client, 'notes',
      ['channel_id', 'created_by', 'title', 'content'], noteRows);

    await client.query('COMMIT');

    // ── Summary ──────────────────────────────────────────────────
    const elapsed = ((Date.now() - t0) / 1000).toFixed(1);
    console.log('\n══════════════════════════════════════════');
    console.log(`🎉  SEED COMPLETED in ${elapsed}s`);
    console.log('══════════════════════════════════════════');
    console.log(`   Faculties  : ${facultyIds.length}`);
    console.log(`   Programmes : ${programmeIds.length}`);
    console.log(`   Batches    : ${batchIds.length}`);
    console.log(`   Channels   : ${channelIds.length}`);
    console.log(`   Students   : ${studentIds.length}`);
    console.log(`   Enrollments: ${enrollRows.length}`);
    console.log('\n🔐  ALL accounts password: 2004-05-15\n');
    console.log('📌  B.Tech CSE test accounts:');
    console.log('   Sem 7  Roll: ADTU/2022-26/BTECH-CSE/001  (Saurabh Borthakur)');
    console.log('   Sem 5  Roll: ADTU/2023-27/BTECH-CSE/001  (Riya Talukdar)');
    console.log('   Sem 3  Roll: ADTU/2024-28/BTECH-CSE/001  (Priyanka Deka)');
    console.log('   Sem 1  Roll: ADTU/2025-29/BTECH-CSE/001  (Anup Baruah)');
    console.log('══════════════════════════════════════════\n');
    process.exit(0);
  } catch (err) {
    await client.query('ROLLBACK').catch(() => {});
    console.error('\n❌  SEED FAILED:', err.message);
    console.error(err);
    process.exit(1);
  } finally {
    client.release();
  }
}

seed();
