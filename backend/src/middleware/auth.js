const pool = require('../config/database');
async function requireAuth(req, res, next) {
  const auth = req.headers.authorization;
  if (!auth || !auth.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'No autorizado' });
  }
  const token = auth.slice(7);
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(token)) return res.status(401).json({ error: 'Token inválido' });
  try {
    const result = await pool.query(
      'SELECT s.user_id, u.name, u.email, u.phone, u.address FROM sessions s JOIN users u ON s.user_id = u.id WHERE s.token = $1',
      [token]
    );
    if (result.rows.length === 0) return res.status(401).json({ error: 'Token inválido' });
    req.user = result.rows[0];
    req.token = token;
    next();
  } catch (err) {
    next(err);
  }
}


module.exports = requireAuth;
