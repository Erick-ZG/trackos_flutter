const pool = require('../config/database');
const { fail } = require('./simulation.service');
exports.products = async () => (await pool.query('SELECT * FROM products ORDER BY category,name')).rows;
exports.product = async id => {
  const product = (await pool.query('SELECT * FROM products WHERE id=$1', [id])).rows[0];
  if (!product) throw fail(404, 'Producto no encontrado');
  return product;
};
exports.cart = async userId => (await pool.query(
  'SELECT c.quantity,p.* FROM cart c JOIN products p ON c.product_id=p.id WHERE c.user_id=$1 ORDER BY p.id', [userId])).rows;
exports.add = async (userId, productId, quantity = 1) => {
  if (typeof productId !== 'string' || !Number.isInteger(quantity) || quantity <= 0 || quantity > 10000) throw fail(400, 'Producto o cantidad inválidos');
  await exports.product(productId);
  await pool.query('INSERT INTO cart (user_id,product_id,quantity) VALUES ($1,$2,$3) ON CONFLICT (user_id,product_id) DO UPDATE SET quantity=cart.quantity+$3', [userId,productId,quantity]);
};
exports.update = async (userId, productId, quantity) => {
  if (!Number.isInteger(quantity) || quantity < 0 || quantity > 10000) throw fail(400, 'Cantidad inválida');
  if (quantity === 0) return exports.remove(userId,productId);
  await pool.query('UPDATE cart SET quantity=$1 WHERE user_id=$2 AND product_id=$3', [quantity,userId,productId]);
};
exports.remove = (userId, productId) => pool.query('DELETE FROM cart WHERE user_id=$1 AND product_id=$2', [userId,productId]);
exports.clear = userId => pool.query('DELETE FROM cart WHERE user_id=$1', [userId]);
