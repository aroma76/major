const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.DATABASE_URL?.includes('localhost') ? false : { rejectUnauthorized: false },
  max: 5,                    // Supabase free tier safe — prevents "too many clients"
  idleTimeoutMillis: 30000,  // release idle connections after 30s
  connectionTimeoutMillis: 5000, // fail fast if no connection available in 5s
});

pool.on('connect', () => {
  console.log('✅ Connected to PostgreSQL database');
});

pool.on('error', (err) => {
  console.error('❌ Database error:', err.message);
});

module.exports = pool;
