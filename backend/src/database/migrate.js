const fs = require('node:fs/promises');
const path = require('node:path');
const pool = require('../config/database');

// Idempotent upgrade for existing volumes; never deletes orders or tracking history.
module.exports = async function migrate() {
  const migrations = [
    '001_tracking_simulation.sql',
    '002_realtime_roles_warehouses.sql',
  ];
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('SELECT pg_advisory_xact_lock(71926001)');
    for (const file of migrations) {
      const sql = await fs.readFile(path.join(__dirname, 'migrations', file), 'utf8');
      await client.query(sql);
    }
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
};
