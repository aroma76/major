-- ADTU Academic Collaboration System — Seed Data
-- Run schema.sql first, then this file

-- Admin (password: Admin@1234)
INSERT INTO users (name, email, password, role, department) VALUES
('Admin ADTU', 'admin@adtu.in', '$2a$12$K8HFS.kMqnJqFWQ.Ggo9HOXIfnr8b7EpFyuX8TPG8F5l0bWH.g9HS', 'admin', 'Engineering');

-- Faculty (password: Faculty@1234)
INSERT INTO users (name, email, password, role, department) VALUES
('Dr. Priya Sharma', 'priya@adtu.in', '$2a$12$K8HFS.kMqnJqFWQ.Ggo9HOXIfnr8b7EpFyuX8TPG8F5l0bWH.g9HS', 'faculty', 'Engineering'),
('Prof. Aman Das',   'aman@adtu.in',  '$2a$12$K8HFS.kMqnJqFWQ.Ggo9HOXIfnr8b7EpFyuX8TPG8F5l0bWH.g9HS', 'faculty', 'Management'),
('Dr. Nisha Borah',  'nisha@adtu.in', '$2a$12$K8HFS.kMqnJqFWQ.Ggo9HOXIfnr8b7EpFyuX8TPG8F5l0bWH.g9HS', 'faculty', 'Pharmacy');

-- Student Records (School Database Mock)
INSERT INTO student_records (roll_number, name, semester, department) VALUES
('ADTU-CS-21-001', 'Rahul Barua', 5, 'Engineering'),
('ADTU-CS-21-002', 'Sneha Kalita', 5, 'Engineering'),
('ADTU-CS-21-003', 'Biplab Gogoi', 5, 'Engineering'),
('ADTU-MG-22-010', 'Ritu Das', 3, 'Management'),
('ADTU-PH-20-005', 'Kamal Ahmed', 7, 'Pharmacy');

-- Students (password: Student@1234)
INSERT INTO users (name, email, password, role, department, semester, roll_number) VALUES
('Rahul Barua',  'rahul@adtu.in',  '$2a$12$K8HFS.kMqnJqFWQ.Ggo9HOXIfnr8b7EpFyuX8TPG8F5l0bWH.g9HS', 'student', 'Engineering', 5, 'ADTU-CS-21-001'),
('Sneha Kalita', 'sneha@adtu.in',  '$2a$12$K8HFS.kMqnJqFWQ.Ggo9HOXIfnr8b7EpFyuX8TPG8F5l0bWH.g9HS', 'student', 'Engineering', 5, 'ADTU-CS-21-002'),
('Biplab Gogoi', 'biplab@adtu.in', '$2a$12$K8HFS.kMqnJqFWQ.Ggo9HOXIfnr8b7EpFyuX8TPG8F5l0bWH.g9HS', 'student', 'Engineering', 5, 'ADTU-CS-21-003'),
('Ritu Das',     'ritu@adtu.in',   '$2a$12$K8HFS.kMqnJqFWQ.Ggo9HOXIfnr8b7EpFyuX8TPG8F5l0bWH.g9HS', 'student', 'Management', 3, 'ADTU-MG-22-010'),
('Kamal Ahmed',  'kamal@adtu.in',  '$2a$12$K8HFS.kMqnJqFWQ.Ggo9HOXIfnr8b7EpFyuX8TPG8F5l0bWH.g9HS', 'student', 'Pharmacy', 7, 'ADTU-PH-20-005');

-- Subjects
INSERT INTO subjects (name, code, department, semester, faculty_id) VALUES
('Data Structures and Algorithms', 'CS501', 'Engineering', 5, 2),
('Database Management Systems',    'CS502', 'Engineering', 5, 2),
('Computer Networks',              'CS503', 'Engineering', 5, 3),
('Principles of Management',       'MB301', 'Management',  3, 3),
('Pharmaceutical Chemistry',       'PH701', 'Pharmacy',    7, 4);

-- Enrollments
INSERT INTO enrollments (user_id, subject_id) VALUES
(5,1),(5,2),(5,3),(6,1),(6,2),(6,3),(7,1),(7,2),(7,3),(8,4),(9,5);

-- Sample messages
INSERT INTO messages (subject_id, sender_id, content) VALUES
(1, 2, 'Welcome to Data Structures and Algorithms! Please check the syllabus.'),
(1, 5, 'Thank you Dr. Priya! When will we start sorting algorithms?'),
(1, 2, 'We will cover sorting in Week 3. Make sure you review recursion first.'),
(2, 2, 'Please install PostgreSQL on your laptops before next class.');

-- Announcements
INSERT INTO announcements (subject_id, created_by, title, content, is_important) VALUES
(1, 2, 'Mid-Semester Exam Schedule', 'Mid-semester examination for CS501 will be held on April 15 at 10:00 AM in Hall B.', TRUE),
(2, 2, 'Lab Session Rescheduled',    'The lab session on April 5 has been rescheduled to April 7 at 2:00 PM.', FALSE);

-- Assignments
INSERT INTO assignments (subject_id, created_by, title, description, deadline, max_marks) VALUES
(1, 2, 'Assignment 1: Linked List Implementation', 'Implement a doubly linked list with insert, delete, and search in C++.', NOW() + INTERVAL '7 days', 100),
(2, 2, 'ER Diagram Design', 'Design an ER diagram for a Library Management System. Submit as PDF.', NOW() + INTERVAL '5 days', 50);
