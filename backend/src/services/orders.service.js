const pool = require('../config/database');
const { randomUUID } = require('node:crypto');
const simulation = require('./simulation.service');
const { simulationEnabled } = require('../config/env');
const wsHub = require('../realtime/wsHub');

function haversineKm(lat1, lon1, lat2, lon2) {
  const toRad = (deg) => (deg * Math.PI) / 180;
  const R = 6371;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function calculateDeliveryFee(branchLat, branchLng, delLat, delLng) {
  const km = haversineKm(branchLat, branchLng, delLat, delLng);
  const raw = 4.0 + km * 1.5;
  const rounded = Math.round(raw * 2) / 2;
  return Math.min(15.0, Math.max(5.0, rounded));
}

exports.list = async (userId) => {
  const result = await pool.query(
    `SELECT o.*, b.name AS branch_name
     FROM orders o
     LEFT JOIN branches b ON o.branch_id = b.id
     WHERE o.user_id = $1
     ORDER BY o.created_at DESC`,
    [userId]
  );
  for (const order of result.rows) {
    order.items = (
      await pool.query('SELECT * FROM order_items WHERE order_id = $1', [order.id])
    ).rows;
  }
  return result.rows;
};

exports.create = async (user, payload = {}) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    // Serialize purchases of the same account, including an accidental double submit.
    await client.query('SELECT id FROM users WHERE id = $1 FOR UPDATE', [user.user_id]);
    const cart = (
      await client.query(
        `SELECT c.quantity, p.id, p.name, p.price, p.stock
         FROM cart c JOIN products p ON c.product_id = p.id
         WHERE c.user_id = $1 ORDER BY p.id FOR UPDATE OF c, p`,
        [user.user_id]
      )
    ).rows;
    if (!cart.length) throw simulation.fail(400, 'El carrito está vacío');

    const unavailable = cart.find((item) => item.quantity <= 0 || item.stock < item.quantity);
    if (unavailable) {
      throw simulation.fail(409, 'Stock insuficiente o cantidad inválida para ' + unavailable.name);
    }

    // Find a warehouse / sede that has stock for all items in the cart
    const branches = (
      await client.query("SELECT * FROM branches ORDER BY CASE WHEN id = 'br-ovalo' THEN 0 ELSE 1 END, id")
    ).rows;

    let selectedBranch = null;
    for (const branch of branches) {
      const invRows = (
        await client.query(
          'SELECT product_id, stock FROM branch_inventory WHERE branch_id = $1 FOR UPDATE',
          [branch.id]
        )
      ).rows;
      const invMap = new Map(invRows.map((r) => [r.product_id, r.stock]));
      const hasAll = cart.every((item) => (invMap.get(item.id) ?? 0) >= item.quantity);
      if (hasAll) {
        selectedBranch = branch;
        break;
      }
    }

    if (!selectedBranch) {
      throw simulation.fail(409, 'Ningún almacén cuenta con stock suficiente para todo el carrito');
    }

    const deliveryLat =
      typeof payload.deliveryLat === 'number' && Number.isFinite(payload.deliveryLat)
        ? payload.deliveryLat
        : -8.1065;
    const deliveryLng =
      typeof payload.deliveryLng === 'number' && Number.isFinite(payload.deliveryLng)
        ? payload.deliveryLng
        : -79.0205;
    const deliveryAddress =
      typeof payload.deliveryAddress === 'string' && payload.deliveryAddress.trim()
        ? payload.deliveryAddress.trim()
        : user.address && user.address.trim()
          ? user.address.trim()
          : 'Sector América Norte, Trujillo, Perú';

    const subtotal = cart.reduce((sum, item) => sum + Number(item.price) * item.quantity, 0);
    const deliveryFee = calculateDeliveryFee(
      selectedBranch.latitude,
      selectedBranch.longitude,
      deliveryLat,
      deliveryLng
    );
    const total = subtotal + deliveryFee;

    const id = 'ORD-' + randomUUID().replaceAll('-', '').slice(0, 8).toUpperCase();
    const order = (
      await client.query(
        `INSERT INTO orders (
           id, user_id, total, delivery_fee, status,
           branch_id, pickup_address, pickup_lat, pickup_lng,
           delivery_address, delivery_lat, delivery_lng
         )
         VALUES ($1, $2, $3, $4, 'stock_verified', $5, $6, $7, $8, $9, $10, $11)
         RETURNING *`,
        [
          id,
          user.user_id,
          total.toFixed(2),
          deliveryFee.toFixed(2),
          selectedBranch.id,
          selectedBranch.address,
          selectedBranch.latitude,
          selectedBranch.longitude,
          deliveryAddress,
          deliveryLat,
          deliveryLng,
        ]
      )
    ).rows[0];

    for (const item of cart) {
      await client.query(
        'INSERT INTO order_items (order_id, product_id, product_name, product_price, quantity) VALUES ($1, $2, $3, $4, $5)',
        [id, item.id, item.name, item.price, item.quantity]
      );
      await client.query('UPDATE products SET stock = stock - $1 WHERE id = $2', [
        item.quantity,
        item.id,
      ]);
      await client.query(
        'UPDATE branch_inventory SET stock = stock - $1 WHERE branch_id = $2 AND product_id = $3',
        [item.quantity, selectedBranch.id, item.id]
      );
    }

    const courier = (
      await client.query("SELECT id FROM couriers WHERE name='Trackos Express' ORDER BY id LIMIT 1")
    ).rows[0];

    await client.query(
      'INSERT INTO shipments (order_id, courier_id, tracking_code, delivery_address) VALUES ($1, $2, $3, $4)',
      [
        id,
        courier ? courier.id : null,
        'TRK-' + randomUUID().replaceAll('-', '').slice(0, 10).toUpperCase(),
        deliveryAddress,
      ]
    );

    if (simulationEnabled) {
      await simulation.initialize(client, id);
    }
    await client.query(
      `INSERT INTO tracking_events (order_id, status, description, location)
       VALUES ($1, 'stock_verified', $2, $3)`,
      [id, `Stock verificado en ${selectedBranch.name}`, selectedBranch.address]
    );

    await client.query('DELETE FROM cart WHERE user_id = $1', [user.user_id]);
    order.items = (await client.query('SELECT * FROM order_items WHERE order_id = $1', [id])).rows;
    order.branch_name = selectedBranch.name;
    await client.query('COMMIT');

    wsHub.broadcast(
      'new_order',
      { orderId: id, branchId: selectedBranch.id, status: order.status },
      { roles: ['worker', 'admin'], branchId: selectedBranch.id, orderId: id }
    );
    return order;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
};
