-- ============================================================
-- Cleanup: Drop unused tables from Supabase
-- Run this in: Supabase Dashboard → SQL Editor
-- ============================================================
-- Tables ACTIVELY USED by the backend (DO NOT DROP):
--   users, channels, batches, programmes, faculties,
--   enrollments, messages, notes, assignments,
--   assignment_submissions, announcements, notifications,
--   projects, project_members, project_tasks, academic_events
-- ============================================================

-- Drop 'files' table — replaced by Supabase Storage bucket.
-- File URLs are stored directly in messages.file_url and
-- assignment_submissions.file_url (no separate files table needed).
DROP TABLE IF EXISTS files CASCADE;

-- Drop 'departments' table if it exists (legacy/unused).
DROP TABLE IF EXISTS departments CASCADE;

-- Add any other unused table names below as needed:
-- DROP TABLE IF EXISTS <table_name> CASCADE;
