-- ============================================================
-- [H4] Supabase Row Level Security (RLS) Migration
-- Run this in your Supabase SQL Editor (Dashboard → SQL Editor)
-- ============================================================
-- PURPOSE:
--   Your Node.js backend connects via a service-role DB connection which
--   bypasses RLS, so your backend logic is unaffected.
--   This protects against anyone who tries to bypass your backend and
--   directly query Supabase's auto-generated REST/GraphQL API endpoints.
-- ============================================================

-- Enable RLS on all sensitive tables
ALTER TABLE users                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages               ENABLE ROW LEVEL SECURITY;
ALTER TABLE assignment_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE assignments            ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications          ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects               ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_tasks          ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_members        ENABLE ROW LEVEL SECURITY;
ALTER TABLE enrollments            ENABLE ROW LEVEL SECURITY;
ALTER TABLE files                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE notes                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE announcements          ENABLE ROW LEVEL SECURITY;
ALTER TABLE channels               ENABLE ROW LEVEL SECURITY;
ALTER TABLE academic_events        ENABLE ROW LEVEL SECURITY;

-- Block ALL direct access via Supabase REST/GraphQL for all tables
-- (your backend uses a raw pg connection/service role, so it bypasses RLS)
CREATE POLICY "block_direct_access_users"                  ON users                  USING (false);
CREATE POLICY "block_direct_access_messages"               ON messages               USING (false);
CREATE POLICY "block_direct_access_submissions"            ON assignment_submissions  USING (false);
CREATE POLICY "block_direct_access_assignments"            ON assignments             USING (false);
CREATE POLICY "block_direct_access_notifications"          ON notifications           USING (false);
CREATE POLICY "block_direct_access_projects"               ON projects                USING (false);
CREATE POLICY "block_direct_access_project_tasks"          ON project_tasks           USING (false);
CREATE POLICY "block_direct_access_project_members"        ON project_members         USING (false);
CREATE POLICY "block_direct_access_enrollments"            ON enrollments             USING (false);
CREATE POLICY "block_direct_access_files"                  ON files                   USING (false);
CREATE POLICY "block_direct_access_notes"                  ON notes                   USING (false);
CREATE POLICY "block_direct_access_announcements"          ON announcements           USING (false);
CREATE POLICY "block_direct_access_channels"               ON channels                USING (false);
CREATE POLICY "block_direct_access_academic_events"        ON academic_events         USING (false);

-- ============================================================
-- [L2] Add parent_id FK column to messages if not already present
-- ============================================================
ALTER TABLE messages
  ADD COLUMN IF NOT EXISTS parent_id INT REFERENCES messages(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_messages_parent ON messages(parent_id);
