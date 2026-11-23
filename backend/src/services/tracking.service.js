const { route, fail } = require('./simulation.service');
const { simulationEnabled } = require('../config/env');
// Read one consistent snapshot even when another request advances the order.
module.exports = async function tracking(pool, orderId, userId) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY');
    const owned = await client.query('SELECT id,status FROM orders WHERE id=$1 AND user_id=$2', [orderId,userId]);
    if (!owned.rows.length) throw fail(404, 'Pedido no encontrado');
    const shipment = await client.query(
      'SELECT s.*,c.name AS courier_name,c.phone AS courier_phone FROM shipments s LEFT JOIN couriers c ON c.id=s.courier_id WHERE s.order_id=$1', [orderId]);
    const state = (await client.query('SELECT * FROM order_simulations WHERE order_id=$1', [orderId])).rows[0];
    const events = await client.query(
      'SELECT status,description,location,occurred_at,node_index FROM tracking_events WHERE order_id=$1 AND (simulation_run_id=$2 OR $2::uuid IS NULL) ORDER BY occurred_at,node_index,id', [orderId,state?.run_id || null]);
    const valid = state && state.route_id === route.id;
    const result = { orderId, status: owned.rows[0].status, shipment: shipment.rows[0] || null, events: events.rows,
      simulation: valid ? { enabled: simulationEnabled, route, currentNodeIndex: state.current_node_index, version: state.version, runId: state.run_id, updatedAt: state.updated_at } : null };
    await client.query('COMMIT');
    return result;
  } catch (error) { await client.query('ROLLBACK'); throw error; }
  finally { client.release(); }
};
