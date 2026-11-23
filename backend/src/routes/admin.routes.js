const router = require('express').Router();
const bcrypt = require('bcryptjs');
const { randomUUID } = require('node:crypto');
const pool = require('../config/database');
const requireAuth = require('../middleware/auth');
const { requireRole } = require('../middleware/auth');
const { fail } = require('../services/simulation.service');

router.use(requireAuth, requireRole('admin'));

router.get('/metrics', async (req, res, next) => {
  try {
    const summary = (
      await pool.query(`
        SELECT
          COUNT(*)::INTEGER AS total_orders,
          COUNT(*) FILTER (WHERE status = 'delivered')::INTEGER AS delivered_orders,
          COALESCE(SUM(total), 0)::NUMERIC(12,2) AS total_revenue,
          COALESCE(SUM(delivery_fee), 0)::NUMERIC(12,2) AS total_delivery_fees,
          COALESCE(AVG(delivery_duration_seconds) FILTER (WHERE delivery_duration_seconds IS NOT NULL), 0)::INTEGER AS avg_delivery_seconds
        FROM orders
      `)
    ).rows[0];

    const workerMetrics = (
      await pool.query(`
        SELECT
          u.id,
          u.name,
          u.email,
          b.name AS branch_name,
          COUNT(o.id)::INTEGER AS orders_handled,
          COALESCE(AVG(EXTRACT(EPOCH FROM (o.ready_at - o.created_at))) FILTER (WHERE o.ready_at IS NOT NULL), 0)::INTEGER AS avg_prep_seconds,
          COALESCE(AVG(o.delivery_duration_seconds) FILTER (WHERE o.delivery_duration_seconds IS NOT NULL), 0)::INTEGER AS avg_delivery_seconds
        FROM users u
        LEFT JOIN branches b ON u.branch_id = b.id
        LEFT JOIN orders o ON o.worker_id = u.id
        WHERE u.role = 'worker'
        GROUP BY u.id, u.name, u.email, b.name
        ORDER BY orders_handled DESC, u.name
      `)
    ).rows;

    const courierMetrics = (
      await pool.query(`
        SELECT
          u.id,
          u.name,
          u.email,
          COUNT(o.id) FILTER (WHERE o.status = 'delivered')::INTEGER AS deliveries_completed,
          COUNT(o.id) FILTER (WHERE o.status <> 'delivered')::INTEGER AS active_deliveries,
          COALESCE(SUM(o.delivery_fee) FILTER (WHERE o.status = 'delivered'), 0)::NUMERIC(12,2) AS total_earnings,
          COALESCE(AVG(o.delivery_duration_seconds) FILTER (WHERE o.delivery_duration_seconds IS NOT NULL), 0)::INTEGER AS avg_delivery_seconds
        FROM users u
        LEFT JOIN orders o ON o.courier_user_id = u.id
        WHERE u.role = 'courier'
        GROUP BY u.id, u.name, u.email
        ORDER BY deliveries_completed DESC, u.name
      `)
    ).rows;

    const products = (
      await pool.query(`
        SELECT p.*,
          COALESCE(
            json_agg(
              json_build_object(
                'branch_id', b.id,
                'branch_name', b.name,
                'stock', bi.stock
              ) ORDER BY b.id
            ) FILTER (WHERE b.id IS NOT NULL),
            '[]'::json
          ) AS branch_stocks
        FROM products p
        LEFT JOIN branch_inventory bi ON bi.product_id = p.id
        LEFT JOIN branches b ON b.id = bi.branch_id
        GROUP BY p.id
        ORDER BY p.stock ASC, p.name
      `)
    ).rows;

    res.json({
      summary: {
        total_orders: summary.total_orders,
        delivered_orders: summary.delivered_orders,
        total_revenue: Number(summary.total_revenue),
        total_delivery_fees: Number(summary.total_delivery_fees),
        avg_delivery_seconds: summary.avg_delivery_seconds,
      },
      workerMetrics,
      courierMetrics,
      products,
    });
  } catch (err) {
    next(err);
  }
});

router.get('/users', async (req, res, next) => {
  try {
    const users = (
      await pool.query(`
        SELECT u.id, u.name, u.email, u.phone, u.address, u.role, u.branch_id,
               b.name AS branch_name, u.created_at
        FROM users u
        LEFT JOIN branches b ON u.branch_id = b.id
        ORDER BY u.created_at DESC
      `)
    ).rows;
    res.json(users);
  } catch (err) {
    next(err);
  }
});

router.post('/users', async (req, res, next) => {
  try {
    const { name, email, password, role = 'customer', branchId = null, phone = '', address = '' } = req.body || {};
    if (!['customer', 'worker', 'courier', 'admin'].includes(role)) {
      throw fail(400, 'Rol inválido');
    }
    if (typeof name !== 'string' || !name.trim() || typeof email !== 'string' || !email.includes('@')) {
      throw fail(400, 'Nombre o email inválido');
    }
    if (typeof password !== 'string' || password.length < 6) {
      throw fail(400, 'La contraseña debe tener al menos 6 caracteres');
    }
    if (role === 'worker' && !branchId) {
      throw fail(400, 'Un trabajador debe tener una sede asignada');
    }

    const hash = await bcrypt.hash(password, 10);
    const created = (
      await pool.query(
        `INSERT INTO users (id, name, email, password, phone, address, role, branch_id)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         RETURNING id, name, email, phone, address, role, branch_id, created_at`,
        [
          randomUUID(),
          name.trim(),
          email.trim().toLowerCase(),
          hash,
          phone,
          address,
          role,
          role === 'worker' ? branchId : null,
        ]
      )
    ).rows[0];
    res.status(201).json(created);
  } catch (err) {
    if (err.code === '23505') return next(fail(409, 'El email ya está registrado'));
    next(err);
  }
});

router.patch('/users/:id/role', async (req, res, next) => {
  try {
    const { role, branchId = null } = req.body || {};
    if (!['customer', 'worker', 'courier', 'admin'].includes(role)) {
      throw fail(400, 'Rol inválido');
    }
    if (role === 'worker' && !branchId) {
      throw fail(400, 'Un trabajador debe tener una sede asignada');
    }
    const updated = (
      await pool.query(
        `UPDATE users
         SET role = $1, branch_id = $2
         WHERE id = $3
         RETURNING id, name, email, role, branch_id`,
        [role, role === 'worker' ? branchId : null, req.params.id]
      )
    ).rows[0];
    if (!updated) throw fail(404, 'Usuario no encontrado');
    res.json(updated);
  } catch (err) {
    next(err);
  }
});

router.patch('/products/:id/stock', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const { stock, branchId } = req.body || {};
    if (typeof stock !== 'number' || !Number.isInteger(stock) || stock < 0) {
      throw fail(400, 'Stock inválido');
    }
    await client.query('BEGIN');
    if (branchId) {
      await client.query(
        `INSERT INTO branch_inventory (branch_id, product_id, stock)
         VALUES ($1, $2, $3)
         ON CONFLICT (branch_id, product_id) DO UPDATE SET stock = EXCLUDED.stock`,
        [branchId, req.params.id, stock]
      );
      const totalRes = (
        await client.query('SELECT COALESCE(MAX(stock), 0)::INTEGER AS max_stock FROM branch_inventory WHERE product_id = $1', [req.params.id])
      ).rows[0];
      await client.query('UPDATE products SET stock = $1 WHERE id = $2', [totalRes.max_stock, req.params.id]);
    } else {
      await client.query('UPDATE products SET stock = $1 WHERE id = $2', [stock, req.params.id]);
      await client.query('UPDATE branch_inventory SET stock = $1 WHERE product_id = $2', [stock, req.params.id]);
    }
    const product = (await client.query('SELECT * FROM products WHERE id = $1', [req.params.id])).rows[0];
    if (!product) throw fail(404, 'Producto no encontrado');
    await client.query('COMMIT');
    res.json(product);
  } catch (err) {
    await client.query('ROLLBACK');
    next(err);
  } finally {
    client.release();
  }
});

module.exports = router;
