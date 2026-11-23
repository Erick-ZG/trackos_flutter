const fs = require('node:fs/promises');
const path = require('node:path');
const pool = require('../config/database');
// Idempotent upgrade for existing volumes; never deletes orders or tracking history.
module.exports = async function migrate() {
  const sql = await fs.readFile(path.join(__dirname,'migrations/001_tracking_simulation.sql'),'utf8');
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('SELECT pg_advisory_xact_lock(71926001)');
    await client.query(sql);
    await client.query('COMMIT');
  } catch (error) { await client.query('ROLLBACK'); throw error; }
  finally { client.release(); }
};
