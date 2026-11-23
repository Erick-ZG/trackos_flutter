const { randomUUID: uuidv4 } = require('node:crypto');
const route = require('../data/trujillo-route.json');
function fail(status, message) { return Object.assign(new Error(message), { status }); }
function nextIndex(index) {
  if (!Number.isInteger(index) || index < 0 || index >= route.nodes.length - 1) {
    throw fail(409, 'El pedido ya llegó al destino o su posición es inválida');
  }
  return index + 1;
}
function checkVersion(actual, expected) {
  if (!Number.isInteger(expected) || expected < 0) throw fail(400, 'expectedVersion debe ser un entero no negativo');
  if (actual !== expected) throw fail(409, 'El seguimiento cambió. Actualiza antes de continuar.');
}
async function recordNode(client, orderId, runId, index) {
  const node = route.nodes[index];
  await client.query(
    'INSERT INTO tracking_events (order_id,status,description,location,simulation_run_id,node_index) VALUES ($1,$2,$3,$4,$5,$6)',
    [orderId, node.status, index === 0 ? 'Simulación iniciada. Pedido pendiente de despacho.' : 'Pedido simulado en: ' + node.name, node.name, runId, index]
  );
}
async function initialize(client, orderId) {
  const run = uuidv4();
  await client.query('INSERT INTO order_simulations (order_id,route_id,run_id) VALUES ($1,$2,$3)', [orderId, route.id, run]);
  await recordNode(client, orderId, run, 0);
}
async function mutate(pool, orderId, userId, action, expectedVersion) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const owned = await client.query('SELECT id FROM orders WHERE id=$1 AND user_id=$2 FOR UPDATE', [orderId, userId]);
    if (!owned.rows.length) throw fail(404, 'Pedido no encontrado');
    const result = await client.query('SELECT * FROM order_simulations WHERE order_id=$1 FOR UPDATE', [orderId]);
    const current = result.rows[0];
    if (!current) throw fail(409, 'Este pedido anterior no tiene ruta simulada. Crea un pedido nuevo.');
    if (current.route_id !== route.id) throw fail(409, 'La ruta de este pedido no está disponible');
    checkVersion(current.version, expectedVersion);
    const index = action === 'reset' ? 0 : nextIndex(current.current_node_index);
    const run = action === 'reset' ? uuidv4() : current.run_id;
    await client.query('UPDATE order_simulations SET current_node_index=$2,run_id=$3,version=version+1,updated_at=NOW() WHERE order_id=$1', [orderId,index,run]);
    await client.query('UPDATE orders SET status=$2 WHERE id=$1', [orderId,route.nodes[index].status]);
    await client.query("UPDATE shipments SET delivered_at=CASE WHEN $2 THEN NOW() ELSE NULL END WHERE order_id=$1", [orderId,index === route.nodes.length-1]);
    await recordNode(client, orderId, run, index);
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally { client.release(); }
}
module.exports = { route, fail, nextIndex, checkVersion, initialize, mutate };
