const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../config/db');

const generateToken = (id) =>
  jwt.sign({ id }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN || '7d' });

// ─── Register ──────────────────────────────────────────────────────────────────
// Students register with Roll Number + Email + their own chosen password.
// Faculty register with Email + chosen password.
const register = async (req, res) => {
  const { name, email, password, role = 'student', roll_number } = req.body;

  if (!name || !email || !password)
    return res.status(400).json({ success: false, message: 'Name, email and password are required' });

  if (password.length < 6)
    return res.status(400).json({ success: false, message: 'Password must be at least 6 characters' });

  if (role === 'student' && !roll_number)
    return res.status(400).json({ success: false, message: 'Roll Number is required for students' });

  // Check for duplicate email
  const existing = await pool.query('SELECT id FROM users WHERE email = $1', [email]);
  if (existing.rows.length > 0)
    return res.status(400).json({ success: false, message: 'This email is already registered' });

  // Check for duplicate Roll Number (students only)
  if (roll_number) {
    const rollExist = await pool.query('SELECT id FROM users WHERE roll_number = $1', [roll_number]);
    if (rollExist.rows.length > 0)
      return res.status(400).json({ success: false, message: 'This Roll Number is already registered' });
  }

  const hashed = await bcrypt.hash(password, 12);
  const initials = name.split(' ').map(w => w[0]).join('').toUpperCase().slice(0, 2);

  const result = await pool.query(
    `INSERT INTO users (name, email, password, role, roll_number, avatar_initials)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING id, name, email, role, roll_number, avatar_initials`,
    [name, email, hashed, role, roll_number || null, initials]
  );

  const user = result.rows[0];
  res.status(201).json({ success: true, token: generateToken(user.id), user });
};

// ─── Login ──────────────────────────────────────────────────────────────────
// Accepts Roll Number OR email + user's custom password.
const login = async (req, res) => {
  const { identifier, password } = req.body;

  if (!identifier || !password)
    return res.status(400).json({ success: false, message: 'Roll Number/Email and password are required' });

  const isEmail = identifier.includes('@');
  const query = isEmail
    ? 'SELECT * FROM users WHERE email = $1'
    : 'SELECT * FROM users WHERE roll_number = $1';

  const result = await pool.query(query, [identifier]);
  if (result.rows.length === 0)
    return res.status(401).json({ success: false, message: 'No account found with that Roll Number / Email' });

  const user = result.rows[0];
  const match = await bcrypt.compare(password, user.password);
  if (!match)
    return res.status(401).json({ success: false, message: 'Incorrect password' });

  const { password: _, ...safeUser } = user;
  res.json({ success: true, token: generateToken(user.id), user: safeUser });
};

// ─── Get Me ─────────────────────────────────────────────────────────────────
const getMe = async (req, res) => res.json({ success: true, user: req.user });

// ─── Update Profile ──────────────────────────────────────────────────────────
const updateProfile = async (req, res) => {
  const { name } = req.body;
  const avatar_url = req.file?.path || null;
  const fields = []; const values = []; let idx = 1;
  if (name)       { fields.push(`name = $${idx++}`);       values.push(name); }
  if (avatar_url) { fields.push(`avatar_url = $${idx++}`); values.push(avatar_url); }
  if (!fields.length) return res.status(400).json({ success: false, message: 'No fields to update' });
  values.push(req.user.id);
  const result = await pool.query(
    `UPDATE users SET ${fields.join(', ')} WHERE id = $${idx}
     RETURNING id, name, email, role, roll_number, avatar_url, avatar_initials`,
    values
  );
  res.json({ success: true, user: result.rows[0] });
};

module.exports = { register, login, getMe, updateProfile };
