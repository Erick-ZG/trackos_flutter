const pool = require('../config/database');

async function requireAuth(req, res, next) {
  const auth = req.headers.authorization;
  if (!auth || !auth.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'No autorizado' });
  }
  const token = auth.slice(7);
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(token)) {
    return res.status(401).json({ error: 'Token inválido' });
  }
  try {
    const result = await pool.query(
      `SELECT s.user_id, u.name, u.email, u.phone, u.address, u.role, u.branch_id,
              b.name AS branch_name, b.address AS branch_address,
              b.latitude AS branch_lat, b.longitude AS branch_lng
       FROM sessions s
       JOIN users u ON s.user_id = u.id
       LEFT JOIN branches b ON u.branch_id = b.id
       WHERE s.token = $1`,
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

function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Permisos insuficientes para esta acción' });
    }
    next();
  };
}

module.exports = requireAuth;
module.exports.requireRole = requireRole;
