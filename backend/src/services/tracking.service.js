const { route, fail } = require('./simulation.service');
const { simulationEnabled } = require('../config/env');

// Read one consistent snapshot even when another request advances the order.
module.exports = async function tracking(pool, orderId, user) {
  const userId = typeof user === 'string' ? user : user.user_id;
  const userRole = typeof user === 'string' ? 'customer' : user.role;
  const userBranch = typeof user === 'string' ? null : user.branch_id;

  const client = await pool.connect();
  try {
    await client.query('BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY');
    const owned = await client.query(
      `SELECT o.*, b.name AS branch_name
       FROM orders o
       LEFT JOIN branches b ON o.branch_id = b.id
       WHERE o.id = $1`,
      [orderId]
    );
    if (!owned.rows.length) throw fail(404, 'Pedido no encontrado');
    const order = owned.rows[0];

    const allowed =
      order.user_id === userId ||
      order.courier_user_id === userId ||
      userRole === 'admin' ||
      (userRole === 'worker' && order.branch_id === userBranch);

    if (!allowed) throw fail(404, 'Pedido no encontrado');

    const shipment = await client.query(
      'SELECT s.*, c.name AS demo_courier_name FROM shipments s LEFT JOIN couriers c ON c.id = s.courier_id WHERE s.order_id = $1',
      [orderId]
    );
    const state = (
      await client.query('SELECT * FROM order_simulations WHERE order_id = $1', [orderId])
    ).rows[0];
    const events = await client.query(
      'SELECT status, description, location, occurred_at, node_index FROM tracking_events WHERE order_id = $1 ORDER BY occurred_at ASC, id ASC',
      [orderId]
    );

    const shipRow = shipment.rows[0] || {};
    if (order.courier_name) {
      shipRow.courier_name = order.courier_name;
    } else if (shipRow.demo_courier_name) {
      shipRow.courier_name = shipRow.demo_courier_name;
    }
    if (order.delivery_proof_image) {
      shipRow.delivery_photo_url = order.delivery_proof_image;
    }
    if (order.delivered_at) {
      shipRow.delivered_at = order.delivered_at;
    }

    const valid = state && state.route_id === route.id;
    const result = {
      orderId,
      status: order.status,
      order: {
        id: order.id,
        total: Number(order.total),
        delivery_fee: Number(order.delivery_fee || 0),
        branch_id: order.branch_id,
        branch_name: order.branch_name,
        pickup_address: order.pickup_address,
        pickup_lat: order.pickup_lat,
        pickup_lng: order.pickup_lng,
        delivery_address: order.delivery_address,
        delivery_lat: order.delivery_lat,
        delivery_lng: order.delivery_lng,
        courier_user_id: order.courier_user_id,
        courier_name: order.courier_name,
        courier_lat: order.courier_lat,
        courier_lng: order.courier_lng,
        accepted_at: order.accepted_at,
        picked_up_at: order.picked_up_at,
        delivered_at: order.delivered_at,
        delivery_duration_seconds: order.delivery_duration_seconds,
        delivery_proof_image: order.delivery_proof_image,
      },
      shipment: shipRow,
      events: events.rows,
      simulation: valid
        ? {
            enabled: simulationEnabled,
            route,
            currentNodeIndex: state.current_node_index,
            version: state.version,
            runId: state.run_id,
            updatedAt: state.updated_at,
          }
        : null,
    };
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
};
