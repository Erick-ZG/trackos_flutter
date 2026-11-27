const fs = require('node:fs/promises');
const path = require('node:path');
const router = require('express').Router();
const pool = require('../config/database');
const requireAuth = require('../middleware/auth');
const { requireRole } = require('../middleware/auth');
const { fail } = require('../services/simulation.service');
const wsHub = require('../realtime/wsHub');
const { normalizePhone } = require('../utils/phone');

router.use(requireAuth, requireRole('courier', 'admin'));

router.get('/orders', async (req, res, next) => {
  try {
    const available = (
      await pool.query(
        `SELECT o.*, u.name AS customer_name, b.name AS branch_name
         FROM orders o
         JOIN users u ON o.user_id = u.id
         LEFT JOIN branches b ON o.branch_id = b.id
         WHERE o.status = 'ready_for_pickup' AND o.courier_user_id IS NULL
         ORDER BY o.created_at DESC`
      )
    ).rows;

    const mine = (
      await pool.query(
        `SELECT o.*, u.name AS customer_name, b.name AS branch_name
         FROM orders o
         JOIN users u ON o.user_id = u.id
         LEFT JOIN branches b ON o.branch_id = b.id
         WHERE o.courier_user_id = $1
         ORDER BY o.created_at DESC`,
        [req.user.user_id]
      )
    ).rows;

    for (const order of [...available, ...mine]) {
      order.items = (
        await pool.query('SELECT * FROM order_items WHERE order_id = $1', [order.id])
      ).rows;
    }

    res.json({ available, mine });
  } catch (err) {
    next(err);
  }
});

router.post('/orders/:id/accept', async (req, res, next) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const account = (
      await client.query('SELECT phone FROM users WHERE id = $1 FOR SHARE', [req.user.user_id])
    ).rows[0];
    if (!account || !normalizePhone(account.phone)) {
      throw fail(400, 'Completa un teléfono válido en Perfil antes de aceptar un pedido');
    }
    const row = (
      await client.query('SELECT * FROM orders WHERE id = $1 FOR UPDATE', [req.params.id])
    ).rows[0];
    if (!row) throw fail(404, 'Pedido no encontrado');
    if (row.status !== 'ready_for_pickup' || row.courier_user_id) {
      throw fail(409, 'Este pedido ya fue aceptado o no está listo para recojo');
    }

    const startLat =
      typeof req.body?.lat === 'number'
        ? req.body.lat
        : (row.pickup_lat || -8.1205) - 0.004;
    const startLng =
      typeof req.body?.lng === 'number'
        ? req.body.lng
        : (row.pickup_lng || -79.0355) - 0.003;

    const updated = (
      await client.query(
        `UPDATE orders
         SET courier_user_id = $1,
             courier_name = $2,
             accepted_at = NOW(),
             courier_lat = $3,
             courier_lng = $4
         WHERE id = $5 RETURNING *`,
        [req.user.user_id, req.user.name, startLat, startLng, row.id]
      )
    ).rows[0];

    await client.query(
      `INSERT INTO tracking_events (order_id, status, description, location)
       VALUES ($1, 'courier_accepted', $2, $3)`,
      [row.id, `${req.user.name} aceptó tu pedido y va hacia la tienda`, row.pickup_address || 'Trujillo']
    );

    await client.query('COMMIT');
    wsHub.broadcast(
      'order_updated',
      {
        orderId: row.id,
        status: updated.status,
        courierName: req.user.name,
        courierLat: startLat,
        courierLng: startLng,
      },
      { orderId: row.id, userIds: [row.user_id], roles: ['courier', 'admin'] }
    );
    res.json(updated);
  } catch (err) {
    await client.query('ROLLBACK');
    next(err);
  } finally {
    client.release();
  }
});

router.post('/orders/:id/arrived-store', async (req, res, next) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const row = (
      await client.query('SELECT * FROM orders WHERE id = $1 FOR UPDATE', [req.params.id])
    ).rows[0];
    if (!row || row.courier_user_id !== req.user.user_id) {
      throw fail(404, 'Pedido asignado no encontrado');
    }

    const lat = row.pickup_lat ?? row.courier_lat;
    const lng = row.pickup_lng ?? row.courier_lng;
    const updated = (
      await client.query(
        `UPDATE orders
         SET status = 'courier_arrived_store',
             arrived_store_at = NOW(),
             courier_lat = $1,
             courier_lng = $2
         WHERE id = $3 RETURNING *`,
        [lat, lng, row.id]
      )
    ).rows[0];

    await client.query(
      `INSERT INTO tracking_events (order_id, status, description, location)
       VALUES ($1, 'courier_arrived_store', $2, $3)`,
      [row.id, `${req.user.name} llegó a la tienda`, row.pickup_address || 'Sede']
    );

    await client.query('COMMIT');
    wsHub.broadcast(
      'order_updated',
      { orderId: row.id, status: 'courier_arrived_store', courierLat: lat, courierLng: lng },
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

router.post('/orders/:id/pickup', async (req, res, next) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const row = (
      await client.query('SELECT * FROM orders WHERE id = $1 FOR UPDATE', [req.params.id])
    ).rows[0];
    if (!row || row.courier_user_id !== req.user.user_id) {
      throw fail(404, 'Pedido asignado no encontrado');
    }

    const updated = (
      await client.query(
        `UPDATE orders
         SET status = 'in_transit', picked_up_at = NOW()
         WHERE id = $1 RETURNING *`,
        [row.id]
      )
    ).rows[0];

    await client.query(
      `INSERT INTO tracking_events (order_id, status, description, location)
       VALUES ($1, 'in_transit', $2, $3)`,
      [row.id, `${req.user.name} está en camino hacia tu dirección`, row.pickup_address || 'En ruta']
    );

    await client.query('COMMIT');
    wsHub.broadcast(
      'order_updated',
      { orderId: row.id, status: 'in_transit' },
      { orderId: row.id, userIds: [row.user_id], roles: ['admin'] }
    );
    res.json(updated);
  } catch (err) {
    await client.query('ROLLBACK');
    next(err);
  } finally {
    client.release();
  }
});

router.post('/orders/:id/location', async (req, res, next) => {
  try {
    const { lat, lng } = req.body || {};
    if (typeof lat !== 'number' || typeof lng !== 'number') {
      throw fail(400, 'Coordenadas inválidas');
    }
    const updated = (
      await pool.query(
        `UPDATE orders
         SET courier_lat = $1, courier_lng = $2
         WHERE id = $3 AND courier_user_id = $4
         RETURNING id, user_id, courier_lat, courier_lng, status`,
        [lat, lng, req.params.id, req.user.user_id]
      )
    ).rows[0];
    if (!updated) throw fail(404, 'Pedido asignado no encontrado');

    wsHub.broadcast(
      'courier_location',
      { orderId: updated.id, lat, lng, status: updated.status },
      { orderId: updated.id, userIds: [updated.user_id] }
    );
    res.json(updated);
  } catch (err) {
    next(err);
  }
});

router.post('/orders/:id/arrived-destination', async (req, res, next) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const row = (
      await client.query('SELECT * FROM orders WHERE id = $1 FOR UPDATE', [req.params.id])
    ).rows[0];
    if (!row || row.courier_user_id !== req.user.user_id) {
      throw fail(404, 'Pedido asignado no encontrado');
    }

    const lat = row.delivery_lat ?? row.courier_lat;
    const lng = row.delivery_lng ?? row.courier_lng;
    const updated = (
      await client.query(
        `UPDATE orders
         SET status = 'arrived_destination',
             arrived_dest_at = NOW(),
             courier_lat = $1,
             courier_lng = $2
         WHERE id = $3 RETURNING *`,
        [lat, lng, row.id]
      )
    ).rows[0];

    await client.query(
      `INSERT INTO tracking_events (order_id, status, description, location)
       VALUES ($1, 'arrived_destination', 'El repartidor llegó al punto de entrega', $2)`,
      [row.id, row.delivery_address || 'Punto de entrega']
    );

    await client.query('COMMIT');
    wsHub.broadcast(
      'order_updated',
      { orderId: row.id, status: 'arrived_destination', courierLat: lat, courierLng: lng },
      { orderId: row.id, userIds: [row.user_id], roles: ['admin'] }
    );
    res.json(updated);
  } catch (err) {
    await client.query('ROLLBACK');
    next(err);
  } finally {
    client.release();
  }
});

router.post('/orders/:id/deliver', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const { proofImageBase64, mimeType = 'image/jpeg' } = req.body || {};
    if (typeof proofImageBase64 !== 'string' || proofImageBase64.length < 32) {
      throw fail(400, 'Debes subir una imagen de evidencia de entrega');
    }

    const cleanBase64 = proofImageBase64.replace(/^data:image\/[a-zA-Z0-9+.-]+;base64,/, '');
    const buffer = Buffer.from(cleanBase64, 'base64');
    if (buffer.length === 0 || buffer.length > 6 * 1024 * 1024) {
      throw fail(400, 'Imagen inválida o supera 6MB');
    }

    const ext = mimeType.includes('png') ? 'png' : 'jpg';
    const uploadsDir = path.join(__dirname, '..', '..', 'uploads');
    await fs.mkdir(uploadsDir, { recursive: true });
    const filename = `proof-${req.params.id}-${Date.now()}.${ext}`;
    await fs.writeFile(path.join(uploadsDir, filename), buffer);
    const proofUrl = `/uploads/${filename}`;

    await client.query('BEGIN');
    const row = (
      await client.query('SELECT * FROM orders WHERE id = $1 FOR UPDATE', [req.params.id])
    ).rows[0];
    if (!row || row.courier_user_id !== req.user.user_id) {
      throw fail(404, 'Pedido asignado no encontrado');
    }

    const updated = (
      await client.query(
        `UPDATE orders
         SET status = 'delivered',
             delivered_at = NOW(),
             delivery_proof_image = $1,
             delivery_duration_seconds = GREATEST(1, EXTRACT(EPOCH FROM (NOW() - COALESCE(accepted_at, created_at)))::INTEGER)
         WHERE id = $2 RETURNING *`,
        [proofUrl, row.id]
      )
    ).rows[0];

    await client.query(
      'UPDATE shipments SET delivered_at = NOW(), delivery_photo_url = $1 WHERE order_id = $2',
      [proofUrl, row.id]
    );

    await client.query(
      `INSERT INTO tracking_events (order_id, status, description, location)
       VALUES ($1, 'delivered', $2, $3)`,
      [row.id, `Pedido entregado con evidencia fotográfica por ${req.user.name}`, row.delivery_address || 'Entregado']
    );

    await client.query('COMMIT');
    wsHub.broadcast(
      'order_updated',
      {
        orderId: row.id,
        status: 'delivered',
        deliveryProofImage: proofUrl,
        deliveryDurationSeconds: updated.delivery_duration_seconds,
      },
      { orderId: row.id, userIds: [row.user_id], roles: ['admin', 'worker'], branchId: row.branch_id }
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
