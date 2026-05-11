const jwt = require('jsonwebtoken');
const pool = require('../config/db');

const protect = async (req, res, next) => {
  let token;
  if (req.headers.authorization && req.headers.authorization.startsWith('Bearer ')) {
    token = req.headers.authorization.split(' ')[1];
  }
  if (!token) return res.status(401).json({ success: false, message: 'Not authorized, no token' });
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    // Use JWT claims directly — no DB round-trip needed on every request.
    // The token embeds id, role, name, and email at login time.
    // For legacy tokens (only have 'id'), fall back to a DB lookup.
    if ('role' in decoded) {
      req.user = decoded;
    } else {
      const result = await pool.query(
        'SELECT id, name, email, role, programme_id, batch_year, current_semester, roll_number, avatar_initials, avatar_url FROM users WHERE id = $1',
        [decoded.id]
      );
      if (result.rows.length === 0) return res.status(401).json({ success: false, message: 'User not found' });
      req.user = result.rows[0];
    }
    next();
  } catch (err) {
    return res.status(401).json({ success: false, message: 'Token invalid or expired' });
  }
};

const authorize = (...roles) => (req, res, next) => {
  if (!roles.includes(req.user.role))
    return res.status(403).json({ success: false, message: `Role '${req.user.role}' is not authorized` });
  next();
};

module.exports = { protect, authorize };
