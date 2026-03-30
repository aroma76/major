const pool = require('./config/db');
const bcrypt = require('bcryptjs');

async function test() {
  try {
    // 1. Check if users exist
    const users = await pool.query(`SELECT id, name, email, roll_number, role, LEFT(password, 10) as pass_prefix FROM users LIMIT 10`);
    console.log('\n=== USERS IN DB ===');
    users.rows.forEach(u => console.log(u));

    if (users.rows.length === 0) {
      console.log('\n❌ NO USERS IN DATABASE! Run node seed.js first.');
      process.exit(0);
    }

    // 2. Pick the first user and test password
    const testUser = await pool.query(`SELECT * FROM users WHERE roll_number = 'ADTU/2024/BTECH-CSE/001' LIMIT 1`);
    if (testUser.rows.length === 0) {
      console.log('\n❌ Student ADTU/2024/BTECH-CSE/001 NOT FOUND. Seed may not have run.');

      // Try admin
      const admin = await pool.query(`SELECT * FROM users WHERE role = 'admin' LIMIT 1`);
      if (admin.rows.length > 0) {
        console.log('\n✅ Found admin:', admin.rows[0].email);
        const match = await bcrypt.compare('2004-05-15', admin.rows[0].password);
        console.log('  Password "2004-05-15" matches admin:', match);
      }
    } else {
      const user = testUser.rows[0];
      console.log('\n✅ Found student:', user.roll_number, user.name);
      const match = await bcrypt.compare('2004-05-15', user.password);
      console.log('  Password "2004-05-15" matches:', match);
    }

    // 3. Check faculty
    const faculty = await pool.query(`SELECT * FROM users WHERE email = 'manoj.sarma.fct@adtu.in' LIMIT 1`);
    if (faculty.rows.length > 0) {
      const match = await bcrypt.compare('2004-05-15', faculty.rows[0].password);
      console.log('\n✅ Found faculty:', faculty.rows[0].email);
      console.log('  Password "2004-05-15" matches:', match);
    } else {
      console.log('\n❌ Faculty manoj.sarma.fct@adtu.in NOT FOUND');
    }

  } catch (err) {
    console.error('Error:', err.message);
  } finally {
    process.exit(0);
  }
}

test();
