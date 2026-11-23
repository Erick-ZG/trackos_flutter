const router = require('express').Router({ mergeParams: true });
const pool = require('../config/database');
const requireAuth = require('../middleware/auth');
const { fail } = require('../services/simulation.service');
const wsHub = require('../realtime/wsHub');

router.use(requireAuth);

async function checkAccess(orderId, user) {
  const row = (await pool.query('SELECT * FROM orders WHERE id = $1', [orderId])).rows[0];
  if (!row) throw fail(404, 'Pedido no encontrado');
  const allowed =
    row.user_id === user.user_id ||
    row.courier_user_id === user.user_id ||
    user.role === 'admin';
  if (!allowed) throw fail(403, 'No tienes acceso al chat de este pedido');
  return row;
}

router.get('/:id/messages', async (req, res, next) => {
  try {
    await checkAccess(req.params.id, req.user);
    const rows = (
      await pool.query(
        'SELECT * FROM order_messages WHERE order_id = $1 ORDER BY created_at ASC',
        [req.params.id]
      )
    ).rows;
    res.json(rows);
  } catch (err) {
    next(err);
  }
});

router.post('/:id/messages', async (req, res, next) => {
  try {
    const order = await checkAccess(req.params.id, req.user);
    const text = typeof req.body?.message === 'string' ? req.body.message.trim() : '';
    if (!text || text.length > 500) {
      throw fail(400, 'El mensaje debe tener entre 1 y 500 caracteres');
    }

    const msg = (
      await pool.query(
        `INSERT INTO order_messages (order_id, sender_id, sender_name, sender_role, message)
         VALUES ($1, $2, $3, $4, $5) RETURNING *`,
        [order.id, req.user.user_id, req.user.name, req.user.role, text]
      )
    ).rows[0];

    const targets = [order.user_id, order.courier_user_id].filter(Boolean);
    wsHub.broadcast('chat_message', msg, { orderId: order.id, userIds: targets });
    res.status(201).json(msg);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
