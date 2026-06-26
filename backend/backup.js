/**
 * backup.js  — EduSync Database Backup Tool
 * ──────────────────────────────────────────
 * Dumps all Neon PostgreSQL tables to a timestamped SQL file.
 *
 * Usage:
 *   node backup.js                        # saves to ./backups/
 *   node backup.js --out ./my-backups/    # custom output directory
 *   node backup.js --schema-only          # schema only (no row data)
 *   node backup.js --table users          # single table
 *
 * Requirements:  node backup.js  (no extra packages — uses 'pg' already in deps)
 */

require('dotenv').config();
const { Pool }  = require('pg');
const fs        = require('fs');
const path      = require('path');

// ─── CLI args ─────────────────────────────────────────────────────────────────
const args        = process.argv.slice(2);
const schemaOnly  = args.includes('--schema-only');
const outIdx      = args.indexOf('--out');
const outDir      = outIdx !== -1 ? args[outIdx + 1] : path.join(__dirname, 'backups');
const tableIdx    = args.indexOf('--table');
const onlyTable   = tableIdx !== -1 ? args[tableIdx + 1] : null;

// ─── Tables in dependency order (safe for restoring) ─────────────────────────
const ALL_TABLES = [
  'faculties',
  'programmes',
  'batches',
  'users',
  'channels',
  'enrollments',
  'messages',
  'notes',
  'assignments',
  'assignment_submissions',
  'announcements',
  'notifications',
  'projects',
  'project_members',
  'project_tasks',
  'academic_events',
];

const TABLES = onlyTable ? [onlyTable] : ALL_TABLES;

// ─── DB pool ──────────────────────────────────────────────────────────────────
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
  max: 3,
});

// ─── Helpers ──────────────────────────────────────────────────────────────────
function timestamp() {
  return new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
}

function escapeValue(val) {
  if (val === null || val === undefined) return 'NULL';
  if (typeof val === 'boolean')          return val ? 'TRUE' : 'FALSE';
  if (typeof val === 'number')           return String(val);
  if (val instanceof Date)               return `'${val.toISOString()}'`;
  // Escape single quotes
  return `'${String(val).replace(/'/g, "''")}'`;
}

async function getTableDDL(client, table) {
  // Fetch column info
  const colRes = await client.query(`
    SELECT column_name, data_type, character_maximum_length,
           is_nullable, column_default, udt_name
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = $1
    ORDER BY ordinal_position
  `, [table]);

  if (colRes.rows.length === 0) return null; // table doesn't exist

  const cols = colRes.rows.map(c => {
    let type = c.data_type.toUpperCase();
    if (type === 'CHARACTER VARYING' && c.character_maximum_length) {
      type = `VARCHAR(${c.character_maximum_length})`;
    } else if (type === 'USER-DEFINED') {
      type = c.udt_name.toUpperCase();
    }
    const nullable  = c.is_nullable === 'YES' ? '' : ' NOT NULL';
    const def       = c.column_default ? ` DEFAULT ${c.column_default}` : '';
    return `  ${c.column_name} ${type}${nullable}${def}`;
  });

  return `-- Table: ${table}\nCREATE TABLE IF NOT EXISTS ${table} (\n${cols.join(',\n')}\n);\n`;
}

async function getTableData(client, table) {
  const { rows } = await client.query(`SELECT * FROM ${table} ORDER BY 1`);
  if (rows.length === 0) return `-- (no rows in ${table})\n`;

  const lines = rows.map(row => {
    const cols = Object.keys(row).join(', ');
    const vals = Object.values(row).map(escapeValue).join(', ');
    return `INSERT INTO ${table} (${cols}) VALUES (${vals}) ON CONFLICT DO NOTHING;`;
  });

  return lines.join('\n') + '\n';
}

// ─── Main ─────────────────────────────────────────────────────────────────────
(async () => {
  fs.mkdirSync(outDir, { recursive: true });

  const ts       = timestamp();
  const label    = onlyTable ? `_${onlyTable}` : '';
  const mode     = schemaOnly ? '_schema' : '';
  const filename = `edusync_backup${label}${mode}_${ts}.sql`;
  const outFile  = path.join(outDir, filename);

  const client = await pool.connect();
  const lines  = [];

  lines.push(`-- ================================================================`);
  lines.push(`-- EduSync Database Backup`);
  lines.push(`-- Generated : ${new Date().toISOString()}`);
  lines.push(`-- Tables    : ${TABLES.join(', ')}`);
  lines.push(`-- Mode      : ${schemaOnly ? 'SCHEMA ONLY' : 'SCHEMA + DATA'}`);
  lines.push(`-- ================================================================\n`);
  lines.push(`SET client_encoding = 'UTF8';`);
  lines.push(`SET standard_conforming_strings = on;\n`);

  try {
    for (const table of TABLES) {
      console.log(`  ⏳  Backing up table: ${table} ...`);

      const ddl = await getTableDDL(client, table);
      if (!ddl) {
        console.warn(`  ⚠️  Table "${table}" not found — skipping.`);
        continue;
      }

      lines.push(`-- ────────────────────────────────────────────────────────────`);
      lines.push(ddl);

      if (!schemaOnly) {
        const data = await getTableData(client, table);
        lines.push(data);
      }
    }

    lines.push(`\n-- ================================================================`);
    lines.push(`-- End of backup`);
    lines.push(`-- ================================================================`);

    fs.writeFileSync(outFile, lines.join('\n'), 'utf8');

    console.log(`\n✅  Backup complete!`);
    console.log(`   File : ${outFile}`);
    console.log(`   Size : ${(fs.statSync(outFile).size / 1024).toFixed(1)} KB`);
  } finally {
    client.release();
    await pool.end();
  }
})();
