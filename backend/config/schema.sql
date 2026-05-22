-- ============================================================
-- ADTU StudyHub - PostgreSQL Schema
-- Hierarchical Structure: Faculty -> Programme -> Batch -> Channel
-- ============================================================

DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS announcements CASCADE;
DROP TABLE IF EXISTS assignment_submissions CASCADE;
DROP TABLE IF EXISTS assignments CASCADE;
DROP TABLE IF EXISTS messages CASCADE;
DROP TABLE IF EXISTS notes CASCADE;
DROP TABLE IF EXISTS enrollments CASCADE;
DROP TABLE IF EXISTS channels CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS batches CASCADE;
DROP TABLE IF EXISTS programmes CASCADE;
DROP TABLE IF EXISTS faculties CASCADE;

CREATE TABLE faculties (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) UNIQUE NOT NULL,
  color_code VARCHAR(50) DEFAULT '#3b82f6',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE programmes (
  id SERIAL PRIMARY KEY,
  faculty_id INT NOT NULL REFERENCES faculties(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  code VARCHAR(50) NOT NULL,
  duration_semesters INT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (faculty_id, code)
);

CREATE TABLE batches (
  id SERIAL PRIMARY KEY,
  programme_id INT NOT NULL REFERENCES programmes(id) ON DELETE CASCADE,
  year INT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (programme_id, year)
);

CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  roll_number VARCHAR(100) UNIQUE,
  dob DATE,
  password VARCHAR(255) NOT NULL, -- Hashed DOB or secure password
  role VARCHAR(50) NOT NULL DEFAULT 'student' CHECK (role IN ('student', 'class_representative', 'faculty', 'admin')),
  programme_id INT REFERENCES programmes(id) ON DELETE SET NULL,
  batch_year INT,
  current_semester INT DEFAULT 1,
  avatar_initials VARCHAR(10),
  avatar_url VARCHAR(500),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE channels (
  id SERIAL PRIMARY KEY,
  batch_id INT NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
  semester_number INT NOT NULL,
  subject_name VARCHAR(255) NOT NULL,
  subject_slug VARCHAR(255) NOT NULL,
  channel_name VARCHAR(255) UNIQUE NOT NULL, -- {programme-code}-{batch-year}-sem{N}-{subject-slug}
  teacher_id INT REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Optional: Explicit enrollments for flexibility (backlogs, electives), 
-- though by default users get access via their programme & batch.
CREATE TABLE enrollments (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  channel_id INT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (user_id, channel_id)
);

CREATE TABLE messages (
  id SERIAL PRIMARY KEY,
  channel_id INT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  sender_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content TEXT,
  file_url VARCHAR(500),
  file_name VARCHAR(255),
  is_pinned BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);


CREATE TABLE notes (
  id SERIAL PRIMARY KEY,
  channel_id INT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  created_by INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  content TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE assignments (
  id SERIAL PRIMARY KEY,
  channel_id INT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  created_by INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  due_date TIMESTAMPTZ NOT NULL,
  max_marks INT DEFAULT 100,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE assignment_submissions (
  id SERIAL PRIMARY KEY,
  assignment_id INT NOT NULL REFERENCES assignments(id) ON DELETE CASCADE,
  student_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  file_url VARCHAR(500),
  file_name VARCHAR(255),
  status VARCHAR(50) DEFAULT 'submitted' CHECK (status IN ('pending', 'submitted', 'late', 'graded')),
  marks INT,
  feedback TEXT,
  submitted_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (assignment_id, student_id)
);

CREATE TABLE announcements (
  id SERIAL PRIMARY KEY,
  channel_id INT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(255),
  content TEXT NOT NULL,
  is_important BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE notifications (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type VARCHAR(100) NOT NULL,
  title VARCHAR(255) NOT NULL,
  message TEXT,
  is_read BOOLEAN DEFAULT FALSE,
  ref_id INT,
  ref_type VARCHAR(50),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Performance Indexes
CREATE INDEX IF NOT EXISTS idx_messages_channel ON messages(channel_id);
CREATE INDEX IF NOT EXISTS idx_notes_channel ON notes(channel_id);
CREATE INDEX IF NOT EXISTS idx_assignments_channel ON assignments(channel_id);
CREATE INDEX IF NOT EXISTS idx_submissions_assignment ON assignment_submissions(assignment_id);
CREATE INDEX IF NOT EXISTS idx_announcements_channel ON announcements(channel_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_user ON enrollments(user_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_channel ON enrollments(channel_id);
