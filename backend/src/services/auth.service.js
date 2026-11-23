const pool = require('../config/database');
const bcrypt = require('bcryptjs');
const { randomUUID } = require('node:crypto');
const { fail } = require('./simulation.service');
function credentials(email, password) {
  if (typeof email !== 'string' || !email.includes('@') || typeof password !== 'string' || password.length < 6 || Buffer.byteLength(password) > 72) throw fail(400, 'Email o contraseña inválidos (6 a 72 bytes)');
}
function publicUser(user) { return { id: user.id,name: user.name,email: user.email,phone: user.phone,address: user.address }; }
exports.register = async ({ name, email, password, phone = '', address = '' }) => {
  credentials(email,password);
  if (typeof name !== 'string' || !name.trim() || typeof phone !== 'string' || typeof address !== 'string') throw fail(400, 'Datos de usuario inválidos');
  const hash = await bcrypt.hash(password,10);
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const user = (await client.query('INSERT INTO users (id,name,email,password,phone,address) VALUES ($1,$2,$3,$4,$5,$6) RETURNING *', [randomUUID(),name.trim(),email.trim().toLowerCase(),hash,phone,address])).rows[0];
    const token = randomUUID();
    await client.query('INSERT INTO sessions (token,user_id) VALUES ($1,$2)', [token,user.id]);
    await client.query('COMMIT');
    return { token,user: publicUser(user) };
  } catch (error) {
    await client.query('ROLLBACK');
    if (error.code === '23505') throw fail(409, 'El email ya está registrado');
    throw error;
  } finally { client.release(); }
};
exports.login = async ({ email, password }) => {
  credentials(email,password);
  const user = (await pool.query('SELECT * FROM users WHERE email=$1', [email.trim().toLowerCase()])).rows[0];
  if (!user || !await bcrypt.compare(password,user.password)) throw fail(401, 'Credenciales inválidas');
  const token = randomUUID();
  await pool.query('INSERT INTO sessions (token,user_id) VALUES ($1,$2)', [token,user.id]);
  return { token,user: publicUser(user) };
};
exports.logout = token => pool.query('DELETE FROM sessions WHERE token=$1', [token]);
