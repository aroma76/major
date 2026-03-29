-- ============================================================
-- ADTU Academic Collaboration System - PostgreSQL Schema
-- ============================================================

CREATE TABLE IF NOT EXISTS student_records (
  id           SERIAL PRIMARY KEY,
  roll_number  VARCHAR(100) UNIQUE NOT NULL,
  name         VARCHAR(255) NOT NULL,
  semester     INT NOT NULL,
  department   VARCHAR(255) NOT NULL,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS users (
  id         SERIAL PRIMARY KEY,
  name       VARCHAR(255) NOT NULL,
  email      VARCHAR(255) UNIQUE NOT NULL,
  password   VARCHAR(255) NOT NULL,
  role       VARCHAR(50) NOT NULL DEFAULT 'student' CHECK (role IN ('student', 'faculty', 'admin')),
  roll_number VARCHAR(100) UNIQUE,
  department VARCHAR(255),
  semester   INT,
  avatar_url VARCHAR(500),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS subjects (
  id          SERIAL PRIMARY KEY,
  name        VARCHAR(255) NOT NULL,
  code        VARCHAR(50) UNIQUE NOT NULL,
  department  VARCHAR(255) NOT NULL,
  semester    INT NOT NULL,
  faculty_id  INT REFERENCES users(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS enrollments (
  id         SERIAL PRIMARY KEY,
  user_id    INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subject_id INT NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (user_id, subject_id)
);

CREATE TABLE IF NOT EXISTS messages (
  id         SERIAL PRIMARY KEY,
  subject_id INT NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  sender_id  INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content    TEXT,
  file_url   VARCHAR(500),
  file_name  VARCHAR(255),
  is_pinned  BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS notes (
  id            SERIAL PRIMARY KEY,
  subject_id    INT NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  uploaded_by   INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title         VARCHAR(255) NOT NULL,
  description   TEXT,
  file_url      VARCHAR(500) NOT NULL,
  file_name     VARCHAR(255),
  file_type     VARCHAR(100),
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS assignments (
  id          SERIAL PRIMARY KEY,
  subject_id  INT NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  created_by  INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title       VARCHAR(255) NOT NULL,
  description TEXT,
  deadline    TIMESTAMPTZ NOT NULL,
  max_marks   INT DEFAULT 100,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS submissions (
  id            SERIAL PRIMARY KEY,
  assignment_id INT NOT NULL REFERENCES assignments(id) ON DELETE CASCADE,
  student_id    INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  file_url      VARCHAR(500),
  file_name     VARCHAR(255),
  status        VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'submitted', 'late')),
  marks         INT,
  feedback      TEXT,
  submitted_at  TIMESTAMPTZ,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (assignment_id, student_id)
);

CREATE TABLE IF NOT EXISTS announcements (
  id           SERIAL PRIMARY KEY,
  subject_id   INT NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  created_by   INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title        VARCHAR(255) NOT NULL,
  content      TEXT NOT NULL,
  is_important BOOLEAN DEFAULT FALSE,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS notifications (
  id         SERIAL PRIMARY KEY,
  user_id    INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type       VARCHAR(100) NOT NULL,
  title      VARCHAR(255) NOT NULL,
  message    TEXT,
  is_read    BOOLEAN DEFAULT FALSE,
  ref_id     INT,
  ref_type   VARCHAR(50),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_messages_subject    ON messages(subject_id);
CREATE INDEX IF NOT EXISTS idx_notes_subject       ON notes(subject_id);
CREATE INDEX IF NOT EXISTS idx_assignments_subject ON assignments(subject_id);
CREATE INDEX IF NOT EXISTS idx_submissions_assignment ON submissions(assignment_id);
CREATE INDEX IF NOT EXISTS idx_announcements_subject ON announcements(subject_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user  ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_user    ON enrollments(user_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_subject ON enrollments(subject_id);
