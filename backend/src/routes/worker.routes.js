const router = require('express').Router();
const pool = require('../config/database');
const requireAuth = require('../middleware/auth');
const { requireRole } = require('../middleware/auth');
const { fail } = require('../services/simulation.service');
const wsHub = require('../realtime/wsHub');

router.use(requireAuth, requireRole('worker', 'admin'));

router.get('/orders', async (req, res, next) => {
  try {
    const branchId = req.user.branch_id;
    const query =
      req.user.role === 'admin'
        ? `SELECT o.*, u.name AS customer_name, b.name AS branch_name
           FROM orders o
           JOIN users u ON o.user_id = u.id
           LEFT JOIN branches b ON o.branch_id = b.id
           ORDER BY o.created_at DESC`
        : `SELECT o.*, u.name AS customer_name, b.name AS branch_name
           FROM orders o
           JOIN users u ON o.user_id = u.id
           LEFT JOIN branches b ON o.branch_id = b.id
           WHERE o.branch_id = $1 OR o.branch_id IS NULL
           ORDER BY o.created_at DESC`;
    const params = req.user.role === 'admin' ? [] : [branchId];
    const orders = (await pool.query(query, params)).rows;

    for (const order of orders) {
      order.items = (
        await pool.query('SELECT * FROM order_items WHERE order_id = $1', [order.id])
      ).rows;
    }
    res.json(orders);
  } catch (err) {
    next(err);
  }
});

router.post('/orders/:id/prepare', async (req, res, next) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const row = (
      await client.query('SELECT * FROM orders WHERE id = $1 FOR UPDATE', [req.params.id])
    ).rows[0];
    if (!row) throw fail(404, 'Pedido no encontrado');
    if (req.user.role === 'worker' && row.branch_id && row.branch_id !== req.user.branch_id) {
      throw fail(403, 'Este pedido pertenece a otra sede');
    }
    if (!['pending', 'stock_verified'].includes(row.status)) {
      throw fail(409, 'El pedido no está en estado verificable/pendiente');
    }

    const updated = (
      await client.query(
        `UPDATE orders
         SET status = 'preparing', worker_id = $1, prepared_at = NOW()
         WHERE id = $2 RETURNING *`,
        [req.user.user_id, row.id]
      )
    ).rows[0];

    await client.query(
      `INSERT INTO tracking_events (order_id, status, description, location)
       VALUES ($1, 'preparing', $2, $3)`,
      [row.id, `Pedido preparado por ${req.user.name}`, row.pickup_address || req.user.branch_address || 'Sede']
    );

    await client.query('COMMIT');
    wsHub.broadcast(
      'order_updated',
      { orderId: row.id, status: 'preparing' },
      { orderId: row.id, userIds: [row.user_id], roles: ['worker', 'admin'], branchId: row.branch_id }
    );
    res.json(updated);
  } catch (err) {
    await client.query('ROLLBACK');
    next(err);
  } finally {
    client.release();
  }
});

router.post('/orders/:id/ready', async (req, res, next) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const row = (
      await client.query('SELECT * FROM orders WHERE id = $1 FOR UPDATE', [req.params.id])
    ).rows[0];
    if (!row) throw fail(404, 'Pedido no encontrado');
    if (req.user.role === 'worker' && row.branch_id && row.branch_id !== req.user.branch_id) {
      throw fail(403, 'Este pedido pertenece a otra sede');
    }
    if (!['preparing', 'stock_verified', 'pending'].includes(row.status)) {
      throw fail(409, 'El pedido debe estar preparado antes de marcarlo listo para recojo');
    }

    const updated = (
      await client.query(
        `UPDATE orders
         SET status = 'ready_for_pickup',
             worker_id = COALESCE(worker_id, $1),
             prepared_at = COALESCE(prepared_at, NOW()),
             ready_at = NOW()
         WHERE id = $2 RETURNING *`,
        [req.user.user_id, row.id]
      )
    ).rows[0];

    await client.query(
      `INSERT INTO tracking_events (order_id, status, description, location)
       VALUES ($1, 'ready_for_pickup', 'Pedido listo para recojo en tienda', $2)`,
      [row.id, row.pickup_address || req.user.branch_address || 'Sede']
    );

    await client.query('COMMIT');
    wsHub.broadcast(
      'order_updated',
      { orderId: row.id, status: 'ready_for_pickup' },
      { orderId: row.id, userIds: [row.user_id], roles: ['courier', 'worker', 'admin'] }
    );
    res.json(updated);
  } catch (err) {
    await client.query('ROLLBACK');
    next(err);
  } finally {
    client.release();
  }
});

module.exports = router;
