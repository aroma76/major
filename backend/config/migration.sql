-- ============================================================
-- Migration: Add status + priority to assignments
-- Run this on your Supabase SQL editor
-- ============================================================

ALTER TABLE assignments
  ADD COLUMN IF NOT EXISTS status   VARCHAR(20) DEFAULT 'todo'   CHECK (status IN ('todo','in_progress','done')),
  ADD COLUMN IF NOT EXISTS priority VARCHAR(20) DEFAULT 'medium' CHECK (priority IN ('low','medium','high'));

-- ============================================================
-- Migration: Projects feature (new tables)
-- ============================================================

CREATE TABLE IF NOT EXISTS projects (
  id          SERIAL PRIMARY KEY,
  title       VARCHAR(255) NOT NULL,
  description TEXT,
  deadline    TIMESTAMPTZ,
  progress    INT DEFAULT 0 CHECK (progress >= 0 AND progress <= 100),
  created_by  INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS project_members (
  id         SERIAL PRIMARY KEY,
  project_id INT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  user_id    INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  joined_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (project_id, user_id)
);

CREATE TABLE IF NOT EXISTS project_tasks (
  id          SERIAL PRIMARY KEY,
  project_id  INT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  title       VARCHAR(255) NOT NULL,
  description TEXT,
  assigned_to INT REFERENCES users(id) ON DELETE SET NULL,
  created_by  INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  due_date    TIMESTAMPTZ,
  priority    VARCHAR(20) DEFAULT 'medium' CHECK (priority IN ('low','medium','high')),
  status      VARCHAR(20) DEFAULT 'todo'   CHECK (status IN ('todo','in_progress','done')),
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_projects_created_by    ON projects(created_by);
CREATE INDEX IF NOT EXISTS idx_project_members_user   ON project_members(user_id);
CREATE INDEX IF NOT EXISTS idx_project_members_proj   ON project_members(project_id);
CREATE INDEX IF NOT EXISTS idx_project_tasks_project  ON project_tasks(project_id);
CREATE INDEX IF NOT EXISTS idx_project_tasks_assigned ON project_tasks(assigned_to);

-- ============================================================
-- Migration: Add note_type to notes (supports 'note' and 'question')
-- ============================================================

ALTER TABLE notes
  ADD COLUMN IF NOT EXISTS note_type VARCHAR(20) DEFAULT 'note'
    CHECK (note_type IN ('note', 'question'));

CREATE INDEX IF NOT EXISTS idx_notes_type ON notes(note_type);
