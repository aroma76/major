const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../config/db');

const generateToken = (id) =>
  jwt.sign({ id }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN || '7d' });

const register = async (req, res) => {
  let { name, email, password, role = 'student', department, semester, roll_number } = req.body;
  if (!name || !email || !password)
    return res.status(400).json({ success: false, message: 'Name, email and password are required' });

  // Roll Number Automation
  if (role === 'student') {
    if (!roll_number) return res.status(400).json({ success: false, message: 'Roll number is required for students' });
    
    // Check school records
    const record = await pool.query('SELECT * FROM student_records WHERE roll_number = $1', [roll_number]);
    if (record.rows.length === 0) {
      return res.status(400).json({ success: false, message: 'Invalid Roll Number. Details not found in university records.' });
    }
    
    // Check if duplicate user
    const rollExist = await pool.query('SELECT id FROM users WHERE roll_number = $1', [roll_number]);
    if (rollExist.rows.length > 0) {
      return res.status(400).json({ success: false, message: 'This Roll Number is already registered.' });
    }
    
    // Set user metadata from university records
    semester = record.rows[0].semester;
    department = record.rows[0].department;
  }

  const existing = await pool.query('SELECT id FROM users WHERE email = $1', [email]);
  if (existing.rows.length > 0)
    return res.status(400).json({ success: false, message: 'Email already registered' });
  const hashed = await bcrypt.hash(password, 12);
  const result = await pool.query(
    `INSERT INTO users (name, email, password, role, department, semester, roll_number)
     VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id, name, email, role, department, semester, roll_number, avatar_url`,
    [name, email, hashed, role, department, semester, roll_number || null]
  );
  const user = result.rows[0];
  res.status(201).json({ success: true, token: generateToken(user.id), user });
};

const login = async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password)
    return res.status(400).json({ success: false, message: 'Email and password are required' });
  const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
  if (result.rows.length === 0)
    return res.status(401).json({ success: false, message: 'Invalid credentials' });
  const user = result.rows[0];
  const match = await bcrypt.compare(password, user.password);
  if (!match) return res.status(401).json({ success: false, message: 'Invalid credentials' });
  const { password: _, ...safeUser } = user;
  res.json({ success: true, token: generateToken(user.id), user: safeUser });
};

const getMe = async (req, res) => res.json({ success: true, user: req.user });

const updateProfile = async (req, res) => {
  const { name, department, semester } = req.body;
  const avatar_url = req.file?.path || null;
  const fields = []; const values = []; let idx = 1;
  if (name)       { fields.push(`name = $${idx++}`);       values.push(name); }
  if (department) { fields.push(`department = $${idx++}`); values.push(department); }
  if (semester)   { fields.push(`semester = $${idx++}`);   values.push(semester); }
  if (avatar_url) { fields.push(`avatar_url = $${idx++}`); values.push(avatar_url); }
  if (!fields.length) return res.status(400).json({ success: false, message: 'No fields to update' });
  values.push(req.user.id);
  const result = await pool.query(
    `UPDATE users SET ${fields.join(', ')} WHERE id = $${idx}
     RETURNING id, name, email, role, department, semester, avatar_url`,
    values
  );
  res.json({ success: true, user: result.rows[0] });
};

module.exports = { register, login, getMe, updateProfile };
