const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../config/db');

const generateToken = (id) =>
  jwt.sign({ id }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN || '7d' });

/**
 * POST /api/auth/register
 * Creates a new user account.
 * Students register with Roll Number + Email + Password.
 * Faculty register with Email + Password.
 * Role is strictly defaulted to 'student' to prevent privilege escalation.
 */
const register = async (req, res) => {
  // [C1] Role is NEVER accepted from the request body — always default to 'student'.
  // Admin/faculty promotion must be done by an existing admin via a dedicated route.
  const { name, email, password, roll_number } = req.body;
  const role = 'student';

  if (!name || !email || !password)
    return res.status(400).json({ success: false, message: 'Name, email and password are required' });

  // [H1] Enforce stronger password: 8+ chars, at least one letter and one number
  const strongPassword = /^(?=.*[A-Za-z])(?=.*\d).{8,}$/;
  if (!strongPassword.test(password))
    return res.status(400).json({ success: false, message: 'Password must be at least 8 characters and include a letter and a number' });

  if (!roll_number)
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

/**
 * POST /api/auth/login
 * Authenticates a user and returns a JWT.
 * Allows login via either Email OR Roll Number.
 */
const login = async (req, res) => {
  const { identifier, password } = req.body;

  if (!identifier || !password)
    return res.status(400).json({ success: false, message: 'Roll Number/Email and password are required' });

  const isEmail = identifier.includes('@');
  const query = isEmail
    ? 'SELECT * FROM users WHERE email = $1'
    : 'SELECT * FROM users WHERE roll_number = $1';

  const result = await pool.query(query, [identifier]);
  
  // [L3] Generic message — do not reveal whether the account exists or not
  if (result.rows.length === 0)
    return res.status(401).json({ success: false, message: 'Invalid credentials' });

  const user = result.rows[0];
  const match = await bcrypt.compare(password, user.password);
  if (!match)
    return res.status(401).json({ success: false, message: 'Invalid credentials' });

  const { password: _, ...safeUser } = user;
  res.json({ success: true, token: generateToken(user.id), user: safeUser });
};

/**
 * GET /api/auth/me
 * Returns the currently authenticated user's profile based on the JWT token.
 * Populated by the `protect` middleware.
 */
const getMe = async (req, res) => res.json({ success: true, user: req.user });

/**
 * PUT /api/auth/profile
 * Updates the user's profile fields.
 * Automatically recalculates `avatar_initials` if the user's name changes.
 */
const updateProfile = async (req, res) => {
  const { name, dob } = req.body;
  const avatar_url = req.file?.path || null;
  const fields = []; const values = []; let idx = 1;
  
  if (name) {
    fields.push(`name = $${idx++}`);
    values.push(name);
    // Auto-update initials when name changes
    const initials = name.split(' ').map(w => w[0]).join('').toUpperCase().slice(0, 2);
    fields.push(`avatar_initials = $${idx++}`);
    values.push(initials);
  }
  if (dob)        { fields.push(`dob = $${idx++}`);        values.push(dob); }
  if (avatar_url) { fields.push(`avatar_url = $${idx++}`); values.push(avatar_url); }
  if (!fields.length) return res.status(400).json({ success: false, message: 'No fields to update' });
  
  values.push(req.user.id);
  const result = await pool.query(
    `UPDATE users SET ${fields.join(', ')} WHERE id = $${idx}
     RETURNING id, name, email, role, roll_number, avatar_url, avatar_initials, dob, batch_year, current_semester`,
    values
  );
  res.json({ success: true, user: result.rows[0] });
};

/**
 * POST /api/auth/change-password
 * Changes the user's password. Requires current password verification.
 */
const changePassword = async (req, res) => {
  const { currentPassword, newPassword } = req.body;

  if (!currentPassword || !newPassword) {
    return res.status(400).json({ success: false, message: 'Please provide both current and new passwords' });
  }

  // [H1] Same strong password policy as registration
  const strongPassword = /^(?=.*[A-Za-z])(?=.*\d).{8,}$/;
  if (!strongPassword.test(newPassword)) {
    return res.status(400).json({ success: false, message: 'New password must be at least 8 characters and include a letter and a number' });
  }

  // Get user from database
  const result = await pool.query('SELECT * FROM users WHERE id = $1', [req.user.id]);
  if (result.rows.length === 0) {
    return res.status(404).json({ success: false, message: 'User not found' });
  }

  const user = result.rows[0];

  // Verify current password
  const match = await bcrypt.compare(currentPassword, user.password);
  if (!match) {
    return res.status(401).json({ success: false, message: 'Incorrect current password' });
  }

  // Hash new password
  const hashedNewPassword = await bcrypt.hash(newPassword, 12);

  // Update password in database
  await pool.query('UPDATE users SET password = $1 WHERE id = $2', [hashedNewPassword, req.user.id]);

  res.json({ success: true, message: 'Password updated successfully' });
};

module.exports = { register, login, getMe, updateProfile, changePassword };
