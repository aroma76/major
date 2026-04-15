const bcrypt = require('bcryptjs');
const pool = require('./config/db.js');
const hash = bcrypt.hashSync('password', 10);
pool.query("INSERT INTO users (name, email, roll_number, password, role) VALUES ('Test User', 'test@adtu.in', 'TEST001', '" + hash + "', 'student') ON CONFLICT (email) DO UPDATE SET password = EXCLUDED.password", (err) => {
  if (err) console.error(err);
  else console.log('Test user ready: test@adtu.in / password');
  process.exit(0);
});
