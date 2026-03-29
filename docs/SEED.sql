-- ADTU Academic Collaboration System — Seed Data
-- Run schema.sql first, then this file

-- Admin (password: Admin@1234)
INSERT INTO users (name, email, password, role, department) VALUES
('Admin ADTU', 'admin@adtu.in', '$2a$12$K8HFS.kMqnJqFWQ.Ggo9HOXIfnr8b7EpFyuX8TPG8F5l0bWH.g9HS', 'admin', 'Faculty of Engineering & Technology');

-- Faculty (password: Faculty@1234)
INSERT INTO users (name, email, password, role, department) VALUES
('Dr. Priya Sharma', 'priya@adtu.in', '$2a$12$K8HFS.kMqnJqFWQ.Ggo9HOXIfnr8b7EpFyuX8TPG8F5l0bWH.g9HS', 'faculty', 'Faculty of Engineering & Technology'),
('Prof. Aman Das',   'aman@adtu.in',  '$2a$12$K8HFS.kMqnJqFWQ.Ggo9HOXIfnr8b7EpFyuX8TPG8F5l0bWH.g9HS', 'faculty', 'Faculty of Commerce and Management'),
('Dr. Nisha Borah',  'nisha@adtu.in', '$2a$12$K8HFS.kMqnJqFWQ.Ggo9HOXIfnr8b7EpFyuX8TPG8F5l0bWH.g9HS', 'faculty', 'Faculty of Pharmaceutical Science');

-- Student Records (School Database Mock)
INSERT INTO student_records (roll_number, name, semester, department) VALUES
('ADTU/202125/BTECH/014', 'Aarav Sharma', 5, 'Faculty of Engineering & Technology'),
('ADTU/202125/BTECH/015', 'Sneha Kalita', 5, 'Faculty of Engineering & Technology'),
('ADTU/202125/BTECH/016', 'Biplab Gogoi', 5, 'Faculty of Engineering & Technology'),
('ADTU/202124/BBA/045', 'Ritu Das', 3, 'Faculty of Commerce and Management'),
('ADTU/202226/BPHARM/022', 'Kamal Ahmed', 7, 'Faculty of Pharmaceutical Science');

-- Students (password: Student@1234)
INSERT INTO users (name, email, password, role, department, semester, roll_number) VALUES
('Aarav Sharma',  'aarav@adtu.in',  '$2a$12$K8HFS.kMqnJqFWQ.Ggo9HOXIfnr8b7EpFyuX8TPG8F5l0bWH.g9HS', 'student', 'Faculty of Engineering & Technology', 5, 'ADTU/202125/BTECH/014'),
('Sneha Kalita',  'sneha@adtu.in',  '$2a$12$K8HFS.kMqnJqFWQ.Ggo9HOXIfnr8b7EpFyuX8TPG8F5l0bWH.g9HS', 'student', 'Faculty of Engineering & Technology', 5, 'ADTU/202125/BTECH/015'),
('Biplab Gogoi',  'biplab@adtu.in', '$2a$12$K8HFS.kMqnJqFWQ.Ggo9HOXIfnr8b7EpFyuX8TPG8F5l0bWH.g9HS', 'student', 'Faculty of Engineering & Technology', 5, 'ADTU/202125/BTECH/016'),
('Ritu Das',      'ritu@adtu.in',   '$2a$12$K8HFS.kMqnJqFWQ.Ggo9HOXIfnr8b7EpFyuX8TPG8F5l0bWH.g9HS', 'student', 'Faculty of Commerce and Management', 3, 'ADTU/202124/BBA/045'),
('Kamal Ahmed',   'kamal@adtu.in',  '$2a$12$K8HFS.kMqnJqFWQ.Ggo9HOXIfnr8b7EpFyuX8TPG8F5l0bWH.g9HS', 'student', 'Faculty of Pharmaceutical Science', 7, 'ADTU/202226/BPHARM/022');

-- Subjects
INSERT INTO subjects (name, code, department, semester, faculty_id) VALUES
('Data Structures and Algorithms', 'CS501', 'Faculty of Engineering & Technology', 5, 2),
('Database Management Systems',    'CS502', 'Faculty of Engineering & Technology', 5, 2),
('Computer Networks',              'CS503', 'Faculty of Engineering & Technology', 5, 3),
('Principles of Management',       'MB301', 'Faculty of Commerce and Management',  3, 3),
('Pharmaceutical Chemistry',       'PH701', 'Faculty of Pharmaceutical Science',    7, 4);

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
