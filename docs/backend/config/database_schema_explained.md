# 📄 Database Schema & RDBMS Architecture — Complete Explanation

**Source File:** `backend/config/schema.sql`
**Type:** PostgreSQL Database Design Documentation

---

## 1. 📌 Database Overview

The database is a **normalized relational PostgreSQL database** hosted on Neon.tech (serverless PostgreSQL). It contains **13 tables** organized around a strict academic hierarchy.

> **Beginner Analogy:** The database is like a university's administrative system. Just as a university has Faculties → Departments → Programmes → Batches → Classes, this database mirrors that exact hierarchy. Every piece of data (messages, assignments, submissions) hangs off this tree.

---

## 2. 🗃️ Complete Table Reference

| Table | Rows (approx.) | Primary Purpose |
|---|---|---|
| `faculties` | 5-10 | University faculties (Engineering, Science, etc.) |
| `programmes` | 10-30 | Degree programmes (B.Tech CSE, BCA, etc.) |
| `batches` | 20-80 | Academic year batches (CSE 2022, CSE 2023, etc.) |
| `users` | 100-1000 | Students and faculty accounts |
| `channels` | 50-200 | Subject rooms (Data Structures Sem 3, etc.) |
| `enrollments` | 1000-5000 | Student-to-channel M2M relationship |
| `messages` | 10,000+ | Chat messages with thread support |
| `assignments` | 100-500 | Assignment definitions |
| `assignment_submissions` | 500-2000 | Student submissions with grading |
| `announcements` | 200-1000 | Teacher announcements per channel |
| `notes` | 500-2000 | Student notes per channel |
| `notifications` | 1000-10000 | System notifications per user |
| `projects` | 50-200 | Kanban project boards |
| `project_members` | 200-500 | Project membership M2M |
| `project_tasks` | 200-1000 | Individual tasks within projects |
| `academic_events` | 50-200 | Calendar events (exams, holidays) |

---

## 3. 🌳 Academic Hierarchy

```
faculties
  └── programmes (faculty_id FK)
       └── batches (programme_id FK)
            └── channels (batch_id FK)
                 ├── messages
                 ├── assignments
                 │    └── assignment_submissions
                 ├── announcements
                 └── notes

users (programme_id FK, batch_year)
  └── enrollments (user_id FK, channel_id FK) — M2M bridge
       └── channels
```

---

## 4. 📋 Table-by-Table Analysis

### `faculties`
```sql
CREATE TABLE faculties (
  id   SERIAL PRIMARY KEY,
  name VARCHAR(200) NOT NULL UNIQUE
);
```
- `SERIAL` — Auto-incrementing integer PK (PostgreSQL shorthand for `INT GENERATED ALWAYS AS IDENTITY`).
- `UNIQUE` on `name` — No duplicate faculty names.
- Simple lookup table. Example: `{ id: 1, name: 'Faculty of Engineering and Technology' }`.

---

### `programmes`
```sql
CREATE TABLE programmes (
  id          SERIAL PRIMARY KEY,
  faculty_id  INT NOT NULL REFERENCES faculties(id) ON DELETE CASCADE,
  name        VARCHAR(200) NOT NULL,
  short_name  VARCHAR(20),
  duration_years INT DEFAULT 4,
  UNIQUE (faculty_id, name)
);
```

- `REFERENCES faculties(id) ON DELETE CASCADE` — If a faculty is deleted, all its programmes are deleted too. This is the referential integrity "cascade" strategy.
- `UNIQUE (faculty_id, name)` — A **composite unique constraint**. The same programme name can exist in different faculties (e.g., "MBA" in both Engineering and Management faculties), but not twice in the same faculty.
- `duration_years DEFAULT 4` — Most engineering programs are 4 years; BCA is 3; can be overridden.

---

### `batches`
```sql
CREATE TABLE batches (
  id           SERIAL PRIMARY KEY,
  programme_id INT NOT NULL REFERENCES programmes(id) ON DELETE CASCADE,
  year         INT NOT NULL,
  section      CHAR(1) DEFAULT 'A',
  UNIQUE (programme_id, year, section)
);
```

- `CHAR(1)` — Exactly 1 character for section (A, B, C, etc.).
- `UNIQUE (programme_id, year, section)` — Only one "CSE 2022 Section A" batch can exist.
- Example: `{ id: 5, programme_id: 1, year: 2022, section: 'A' }` = B.Tech CSE 2022 Section A.

---

### `users` — The Central Table
```sql
CREATE TABLE users (
  id                SERIAL PRIMARY KEY,
  name              VARCHAR(100) NOT NULL,
  email             VARCHAR(150) NOT NULL UNIQUE,
  password          VARCHAR(255) NOT NULL,        -- bcrypt hash
  role              VARCHAR(20) NOT NULL DEFAULT 'student',
  roll_number       VARCHAR(50) UNIQUE,           -- nullable for faculty
  dob               DATE,                         -- also used as default password
  programme_id      INT REFERENCES programmes(id),
  batch_year        INT,
  current_semester  INT DEFAULT 1,
  avatar_initials   VARCHAR(4),
  avatar_url        TEXT,                         -- Supabase URL
  created_at        TIMESTAMPTZ DEFAULT NOW()
);
```

**Key design decisions:**
- `email UNIQUE` + `roll_number UNIQUE` — Two separate identity fields. Students login with roll_number, faculty with email.
- `role` in `('student', 'faculty', 'admin')` — Single-column role. Simpler than a roles table for this use case.
- `password VARCHAR(255)` — bcrypt hashes are always 60 characters, but 255 gives room for algorithm changes.
- `dob DATE` — Stored as SQL DATE. Also used as the default password (`YYYY-MM-DD` format).
- `programme_id` nullable — Faculty members don't belong to a programme.
- `batch_year` denormalized — Not a FK to `batches.year`. This means if batch data changes, `users.batch_year` doesn't auto-update. Acceptable for an academic system.

---

### `channels` — Subject Rooms
```sql
CREATE TABLE channels (
  id              SERIAL PRIMARY KEY,
  batch_id        INT NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
  subject_name    VARCHAR(200) NOT NULL,
  channel_name    VARCHAR(250) NOT NULL,
  description     TEXT,
  semester_number INT,
  created_by      INT REFERENCES users(id),       -- faculty who created it
  created_at      TIMESTAMPTZ DEFAULT NOW()
);
```

- `batch_id FK` → `batches.id` — A channel belongs to one batch (e.g., CSE 2022 A).
- `subject_name` — The academic subject (e.g., "Data Structures").
- `channel_name` — Full display name (e.g., "Data Structures - Sem 3 B.Tech CSE 2022 A").
- `created_by` — The faculty member who created this channel. Nullable (can be created by admin directly in DB).

---

### `enrollments` — Many-to-Many Bridge
```sql
CREATE TABLE enrollments (
  id          SERIAL PRIMARY KEY,
  user_id     INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  channel_id  INT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  enrolled_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (user_id, channel_id)         -- no duplicate enrollments
);
```

This is the **heart of access control**. A student can only see a channel's messages and assignments if they have an enrollment record here.

**UNIQUE (user_id, channel_id):** Prevents enrolling the same student twice in the same channel.

**`ON DELETE CASCADE` on both FKs:** If a user is deleted OR a channel is deleted, the enrollment records are automatically removed.

---

### `messages` — Chat Messages
```sql
CREATE TABLE messages (
  id          SERIAL PRIMARY KEY,
  channel_id  INT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  sender_id   INT NOT NULL REFERENCES users(id),
  content     TEXT,
  file_url    TEXT,                    -- Supabase Storage URL
  file_name   VARCHAR(500),
  is_pinned   BOOLEAN DEFAULT FALSE,
  parent_id   INT REFERENCES messages(id),  -- self-referencing FK for threads
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_messages_channel ON messages(channel_id);
CREATE INDEX idx_messages_created ON messages(channel_id, created_at DESC);
```

**Self-referencing FK for threads:**
`parent_id REFERENCES messages(id)` — A message can reply to another message in the same table. This enables Discord-style thread replies without a separate `thread_messages` table.

**Indexes:**
- `idx_messages_channel` — Speeds up `WHERE channel_id = $1` queries.
- `idx_messages_created` — Composite index on `(channel_id, created_at DESC)` — optimizes the primary query pattern: "get latest 50 messages for channel X".

**No `ON DELETE CASCADE` on `sender_id`:**
If a user is deleted, their messages remain (sender_id becomes a dangling FK). The SQL JOIN uses `LEFT JOIN users` to handle this.

---

### `assignments`
```sql
CREATE TABLE assignments (
  id            SERIAL PRIMARY KEY,
  channel_id    INT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  created_by    INT REFERENCES users(id),
  title         VARCHAR(500) NOT NULL,
  description   TEXT,
  due_date      TIMESTAMPTZ NOT NULL,
  max_marks     INT DEFAULT 100,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);
```

---

### `assignment_submissions`
```sql
CREATE TABLE assignment_submissions (
  id            SERIAL PRIMARY KEY,
  assignment_id INT NOT NULL REFERENCES assignments(id) ON DELETE CASCADE,
  student_id    INT NOT NULL REFERENCES users(id),
  file_url      TEXT,                   -- Supabase URL
  submitted_at  TIMESTAMPTZ DEFAULT NOW(),
  marks         INT,                    -- null until graded
  feedback      TEXT,                   -- null until graded
  graded_by     INT REFERENCES users(id),
  graded_at     TIMESTAMPTZ,
  UNIQUE (assignment_id, student_id)    -- one submission per student per assignment
);
```

**UNIQUE (assignment_id, student_id):** A student can't submit twice. The backend uses this to detect "already submitted" state.

**`marks` and `feedback` nullable:** Both are null until a faculty member grades the submission. The JOIN in `getAssignments` checks `s.marks` to determine if feedback is available.

---

### `announcements`
```sql
CREATE TABLE announcements (
  id          SERIAL PRIMARY KEY,
  channel_id  INT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  author_id   INT NOT NULL REFERENCES users(id),
  title       VARCHAR(500) NOT NULL,
  content     TEXT NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
```

---

### `notifications`
```sql
CREATE TABLE notifications (
  id          SERIAL PRIMARY KEY,
  user_id     INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title       VARCHAR(500) NOT NULL,
  message     TEXT NOT NULL,
  type        VARCHAR(50) DEFAULT 'general',
  is_read     BOOLEAN DEFAULT FALSE,
  related_id  INT,                    -- optional reference to related entity
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_notifications_user ON notifications(user_id, is_read, created_at DESC);
```

The index on `(user_id, is_read, created_at DESC)` optimizes the common query: "get all unread notifications for user X, newest first".

---

### `projects` + `project_members` + `project_tasks`
```sql
CREATE TABLE projects (
  id          SERIAL PRIMARY KEY,
  created_by  INT REFERENCES users(id),
  title       VARCHAR(500) NOT NULL,
  description TEXT,
  deadline    TIMESTAMPTZ,
  progress    DECIMAL(5,2) DEFAULT 0.00,  -- 0.00 to 100.00
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE project_members (
  id         SERIAL PRIMARY KEY,
  project_id INT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  user_id    INT NOT NULL REFERENCES users(id),
  role       VARCHAR(50) DEFAULT 'member',
  UNIQUE (project_id, user_id)
);

CREATE TABLE project_tasks (
  id          SERIAL PRIMARY KEY,
  project_id  INT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  title       VARCHAR(500) NOT NULL,
  description TEXT,
  status      VARCHAR(20) DEFAULT 'todo',  -- 'todo', 'in_progress', 'done'
  assigned_to INT REFERENCES users(id),
  due_date    TIMESTAMPTZ,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
```

`progress DECIMAL(5,2)` — 5 total digits, 2 decimal places. Range: 0.00 to 999.99 (effectively 0-100).

---

### `academic_events`
```sql
CREATE TABLE academic_events (
  id          SERIAL PRIMARY KEY,
  title       VARCHAR(500) NOT NULL,
  description TEXT,
  start_date  TIMESTAMPTZ NOT NULL,
  end_date    TIMESTAMPTZ,
  type        VARCHAR(50) DEFAULT 'general',  -- 'exam', 'holiday', 'event'
  created_by  INT REFERENCES users(id),
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 5. 🔐 Row Level Security (RLS)

From `rls_security_migration.sql`, RLS policies are applied to prevent direct Supabase client access:

```sql
-- Enable RLS on all sensitive tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
-- ... all tables

-- Default: no access via Supabase client
CREATE POLICY "Deny all direct client access to users"
  ON users FOR ALL USING (false);

CREATE POLICY "Deny all direct client access to messages"
  ON messages FOR ALL USING (false);
```

**What this achieves:**
- Direct Supabase SDK calls from any frontend → **blocked**
- Only the backend (using the service role key) can access tables
- Forces all data access to go through the authenticated Node.js API
- Prevents students from bypassing the backend to read other students' data

---

## 6. 🔗 Foreign Key Relationship Map

```
faculties (1) ──< programmes (N)
programmes (1) ──< batches (N)
batches (1) ──< channels (N)
channels (1) ──< messages (N)
channels (1) ──< assignments (N)
channels (1) ──< announcements (N)
channels (1) ──< notes (N)
channels (1) ──< enrollments (N)
users (1) ──< enrollments (N)
assignments (1) ──< assignment_submissions (N)
users (1) ──< assignment_submissions (N)
users (1) ──< notifications (N)
projects (1) ──< project_members (N)
projects (1) ──< project_tasks (N)
users (1) ──< project_members (N)
messages (1) ──< messages (N)  [self-referencing: thread replies]
```

---

## 7. 📊 Normalization Assessment

| Form | Compliance | Notes |
|---|---|---|
| 1NF | ✅ | All columns atomic, no repeating groups |
| 2NF | ✅ | No partial dependencies on composite keys |
| 3NF | ⚠️ | `batch_year` on `users` is denormalized (not FK to batches) |
| BCNF | ⚠️ | `channel_name` contains redundant information from `subject_name` |

The denormalization is intentional — it's a performance tradeoff avoiding additional JOINs on the most common query paths.

---

## 8. ⚡ Key SQL Query Patterns

### Channel Message Fetch with Cursor Pagination
```sql
SELECT m.*, u.name AS sender_name, u.role AS sender_role,
       p.content AS parent_content, pu.name AS parent_sender_name
FROM messages m
INNER JOIN users u ON m.sender_id = u.id
LEFT JOIN messages p ON m.parent_id = p.id
LEFT JOIN users pu ON p.sender_id = pu.id
WHERE m.channel_id = $1 AND m.id < $2
ORDER BY m.id DESC LIMIT 50;
```

### Enrolled Channels for User
```sql
SELECT c.*, u.name AS teacher_name, u.id AS teacher_id
FROM channels c
INNER JOIN enrollments e ON c.id = e.channel_id
LEFT JOIN users u ON c.created_by = u.id
WHERE e.user_id = $1
ORDER BY c.semester_number, c.subject_name;
```

### Assignments with Submission Status (per student)
```sql
SELECT a.*, u.name AS created_by_name,
       s.marks, s.feedback, s.submitted_at AS submission_status
FROM assignments a
LEFT JOIN users u ON a.created_by = u.id
LEFT JOIN assignment_submissions s 
  ON s.assignment_id = a.id AND s.student_id = $2
WHERE a.channel_id = $1
ORDER BY a.due_date;
```

---

## 9. ✅ Final Summary

The database design is **clean, normalized, and well-indexed** for an academic platform. The academic hierarchy (faculties → programmes → batches → channels) maps naturally to the real-world university structure. The `enrollments` M2M table is the access control backbone — it determines what every student can see. RLS policies ensure no data leaks occur even if the service key were somehow misused. The message table's self-referencing FK for thread replies is a particularly elegant design choice.
