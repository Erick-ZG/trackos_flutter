const pool = require('../config/database');
const { fail } = require('./simulation.service');
const { normalizePhone } = require('../utils/phone');

const closedStatuses = new Set(['delivered', 'cancelled', 'canceled']);

async function getOrderContact(orderId, user) {
  if (user.role !== 'customer' && user.role !== 'courier') {
    throw fail(403, 'Permisos insuficientes para esta acción');
  }

  const result = await pool.query(
    `SELECT o.id, o.status, o.courier_user_id,
            customer.name AS customer_name, customer.phone AS customer_phone,
            courier.name AS courier_name, courier.phone AS courier_phone
     FROM orders o
     JOIN users customer ON customer.id = o.user_id
     LEFT JOIN users courier ON courier.id = o.courier_user_id
     WHERE o.id = $1
       AND (($2 = 'customer' AND o.user_id = $3)
         OR ($2 = 'courier' AND o.courier_user_id = $3))`,
    [orderId, user.role, user.user_id]
  );
  const order = result.rows[0];
  if (!order) throw fail(404, 'Pedido no encontrado');

  const unavailable = reason => ({
    orderId: order.id,
    available: false,
    reason,
    contact: null,
  });

  if (closedStatuses.has(order.status)) return unavailable('order_closed');
  if (!order.courier_user_id) return unavailable('not_assigned');

  const contactRole = user.role === 'customer' ? 'courier' : 'customer';
  const phone = normalizePhone(order[`${contactRole}_phone`]);
  if (!phone) return unavailable('phone_missing');

  return {
    orderId: order.id,
    available: true,
    reason: null,
    contact: { name: order[`${contactRole}_name`], role: contactRole, phone },
  };
}

module.exports = { getOrderContact };
