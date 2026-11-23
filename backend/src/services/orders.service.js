const pool = require('../config/database');
const { randomUUID } = require('node:crypto');
const simulation = require('./simulation.service');
const { simulationEnabled } = require('../config/env');
exports.list = async userId => {
  const result = await pool.query('SELECT * FROM orders WHERE user_id=$1 ORDER BY created_at DESC', [userId]);
  for (const order of result.rows) {
    order.items = (await pool.query('SELECT * FROM order_items WHERE order_id=$1', [order.id])).rows;
  }
  return result.rows;
};
exports.create = async user => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    // Serialize purchases of the same account, including an accidental double submit.
    await client.query('SELECT id FROM users WHERE id=$1 FOR UPDATE', [user.user_id]);
    const cart = (await client.query(
      'SELECT c.quantity,p.id,p.name,p.price,p.stock FROM cart c JOIN products p ON c.product_id=p.id WHERE c.user_id=$1 ORDER BY p.id FOR UPDATE OF c,p', [user.user_id])).rows;
    if (!cart.length) throw simulation.fail(400, 'El carrito está vacío');
    const unavailable = cart.find(item => item.quantity <= 0 || item.stock < item.quantity);
    if (unavailable) throw simulation.fail(409, 'Stock insuficiente o cantidad inválida para ' + unavailable.name);
    const total = cart.reduce((sum, item) => sum + Number(item.price) * item.quantity, 0);
    const id = 'ORD-' + randomUUID().replaceAll('-', '').slice(0, 8).toUpperCase();
    const order = (await client.query('INSERT INTO orders (id,user_id,total,status) VALUES ($1,$2,$3,$4) RETURNING *', [id,user.user_id,total.toFixed(2),'pending'])).rows[0];
    for (const item of cart) {
      await client.query('INSERT INTO order_items (order_id,product_id,product_name,product_price,quantity) VALUES ($1,$2,$3,$4,$5)', [id,item.id,item.name,item.price,item.quantity]);
      await client.query('UPDATE products SET stock=stock-$1 WHERE id=$2', [item.quantity,item.id]);
    }
    const courier = (await client.query("SELECT id FROM couriers WHERE name='Trackos Express' ORDER BY id LIMIT 1")).rows[0];
    const address = simulationEnabled ? 'Destino ficticio — sector América Norte, Trujillo (demo)' : (user.address || 'Dirección por confirmar');
    await client.query('INSERT INTO shipments (order_id,courier_id,tracking_code,delivery_address) VALUES ($1,$2,$3,$4)', [id,courier.id,'TRK-' + randomUUID().replaceAll('-', '').slice(0,10).toUpperCase(),address]);
    if (simulationEnabled) await simulation.initialize(client, id);
    else await client.query("INSERT INTO tracking_events (order_id,status,description,location) VALUES ($1,'pending','Pedido confirmado.','Trujillo')", [id]);
    await client.query('DELETE FROM cart WHERE user_id=$1', [user.user_id]);
    order.items = (await client.query('SELECT * FROM order_items WHERE order_id=$1', [id])).rows;
    await client.query('COMMIT');
    return order;
  } catch (error) { await client.query('ROLLBACK'); throw error; }
  finally { client.release(); }
};
