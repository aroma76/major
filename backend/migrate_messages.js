const pool = require('./config/db');

async function migrate() {
    try {
        await pool.query('ALTER TABLE messages ADD COLUMN IF NOT EXISTS parent_id INT REFERENCES messages(id) ON DELETE SET NULL;');
        console.log('✅ Added parent_id column to messages table.');
        process.exit(0);
    } catch(err) {
        console.error('❌ Migration failed:', err.message);
        process.exit(1);
    }
}

migrate();
