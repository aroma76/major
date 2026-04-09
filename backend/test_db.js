const pool = require('./config/db');
pool.query("SELECT roll_number FROM users WHERE roll_number LIKE '%BTECH-CSE%' LIMIT 5")
  .then(res => { console.log(res.rows); process.exit(0); })
  .catch(err => { console.error(err); process.exit(1); });
