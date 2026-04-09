-- Academic Events Table for University Academic Calendar
CREATE TABLE IF NOT EXISTS academic_events (
  id SERIAL PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  event_type VARCHAR(50) NOT NULL DEFAULT 'other'
    CHECK (event_type IN ('holiday', 'exam', 'semester', 'fest', 'workshop', 'deadline', 'other')),
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  colour VARCHAR(20) DEFAULT '#3b82f6',
  is_important BOOLEAN DEFAULT FALSE,
  created_by INT REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_academic_events_start ON academic_events(start_date);
CREATE INDEX IF NOT EXISTS idx_academic_events_type ON academic_events(event_type);
