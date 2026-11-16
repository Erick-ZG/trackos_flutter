const express = require('express');
const { Pool } = require('pg');
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

// Mantiene el backend ejecutable también si ya existe un volumen PostgreSQL
// creado antes de agregar las tablas de seguimiento.
async function ensureSchema() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS order_items (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(), order_id VARCHAR(30) NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
      product_id VARCHAR(10) REFERENCES products(id), product_name VARCHAR(150) NOT NULL,
      product_price DECIMAL(10,2) NOT NULL, quantity INTEGER NOT NULL
    );
    ALTER TABLE products ALTER COLUMN color_value TYPE BIGINT;
    CREATE TABLE IF NOT EXISTS couriers (
      id SERIAL PRIMARY KEY, name VARCHAR(100) NOT NULL,
      phone VARCHAR(30) NOT NULL DEFAULT '', email VARCHAR(120) NOT NULL DEFAULT ''
    );
    CREATE TABLE IF NOT EXISTS shipments (
      order_id VARCHAR(30) PRIMARY KEY REFERENCES orders(id) ON DELETE CASCADE,
      courier_id INTEGER REFERENCES couriers(id), tracking_code VARCHAR(40) UNIQUE NOT NULL,
      delivery_address TEXT NOT NULL DEFAULT '', delivered_at TIMESTAMP, delivery_photo_url TEXT
    );
    CREATE TABLE IF NOT EXISTS tracking_events (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(), order_id VARCHAR(30) NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
      status VARCHAR(30) NOT NULL, description TEXT NOT NULL, location VARCHAR(150) NOT NULL DEFAULT '',
      occurred_at TIMESTAMP NOT NULL DEFAULT NOW(), UNIQUE(order_id, status)
    );
    ALTER TABLE order_items ALTER COLUMN product_id DROP NOT NULL;
    INSERT INTO couriers (name, phone, email)
    SELECT 'Trackos Express', '+51 900 000 001', 'demo@trackos.local'
    WHERE NOT EXISTS (SELECT 1 FROM couriers WHERE name='Trackos Express');
  `);
}

// ─── Middleware de autenticación ───────────────────────────────────────────
async function requireAuth(req, res, next) {
  const auth = req.headers.authorization;
  if (!auth || !auth.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'No autorizado' });
  }
  const token = auth.slice(7);
  try {
    const result = await pool.query(
      'SELECT s.user_id, u.name, u.email, u.phone, u.address FROM sessions s JOIN users u ON s.user_id = u.id WHERE s.token = $1',
      [token]
    );
    if (result.rows.length === 0) return res.status(401).json({ error: 'Token inválido' });
    req.user = result.rows[0];
    req.token = token;
    next();
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
}

// ─── AUTH ──────────────────────────────────────────────────────────────────

// POST /api/auth/register
app.post('/api/auth/register', async (req, res) => {
  const { name, email, password, phone = '', address = '' } = req.body;
  if (!name || !email || !password) return res.status(400).json({ error: 'Faltan campos requeridos' });
  try {
    const exists = await pool.query('SELECT id FROM users WHERE email = $1', [email]);
    if (exists.rows.length > 0) return res.status(409).json({ error: 'El email ya está registrado' });
    const hash = await bcrypt.hash(password, 10);
    const userId = uuidv4();
    await pool.query(
      'INSERT INTO users (id, name, email, password, phone, address) VALUES ($1,$2,$3,$4,$5,$6)',
      [userId, name, email, hash, phone, address]
    );
    const token = uuidv4();
    await pool.query('INSERT INTO sessions (token, user_id) VALUES ($1,$2)', [token, userId]);
    res.status(201).json({ token, user: { id: userId, name, email, phone, address } });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/auth/login
app.post('/api/auth/login', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) return res.status(400).json({ error: 'Faltan campos' });
  try {
    const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    if (result.rows.length === 0) return res.status(401).json({ error: 'Credenciales inválidas' });
    const user = result.rows[0];
    const valid = await bcrypt.compare(password, user.password);
    if (!valid) return res.status(401).json({ error: 'Credenciales inválidas' });
    const token = uuidv4();
    await pool.query('INSERT INTO sessions (token, user_id) VALUES ($1,$2)', [token, user.id]);
    res.json({ token, user: { id: user.id, name: user.name, email: user.email, phone: user.phone, address: user.address } });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/auth/logout
app.post('/api/auth/logout', requireAuth, async (req, res) => {
  try {
    await pool.query('DELETE FROM sessions WHERE token = $1', [req.token]);
    res.json({ message: 'Sesión cerrada' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/auth/me
app.get('/api/auth/me', requireAuth, (req, res) => {
  res.json({ user: req.user });
});

// ─── PRODUCTS ─────────────────────────────────────────────────────────────

// GET /api/products
app.get('/api/products', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM products ORDER BY category, name');
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/products/:id
app.get('/api/products/:id', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM products WHERE id = $1', [req.params.id]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'Producto no encontrado' });
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── CART ─────────────────────────────────────────────────────────────────

// GET /api/cart
app.get('/api/cart', requireAuth, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT c.quantity, p.id, p.name, p.description, p.category, p.price, p.stock, p.icon_name, p.color_value
       FROM cart c JOIN products p ON c.product_id = p.id WHERE c.user_id = $1`,
      [req.user.user_id]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/cart/add
app.post('/api/cart/add', requireAuth, async (req, res) => {
  const { productId, quantity = 1 } = req.body;
  try {
    await pool.query(
      `INSERT INTO cart (user_id, product_id, quantity) VALUES ($1,$2,$3)
       ON CONFLICT (user_id, product_id) DO UPDATE SET quantity = cart.quantity + $3`,
      [req.user.user_id, productId, quantity]
    );
    res.json({ message: 'Agregado al carrito' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/cart/item/:productId
app.put('/api/cart/item/:productId', requireAuth, async (req, res) => {
  const { quantity } = req.body;
  try {
    if (quantity <= 0) {
      await pool.query('DELETE FROM cart WHERE user_id=$1 AND product_id=$2', [req.user.user_id, req.params.productId]);
    } else {
      await pool.query('UPDATE cart SET quantity=$1 WHERE user_id=$2 AND product_id=$3', [quantity, req.user.user_id, req.params.productId]);
    }
    res.json({ message: 'Carrito actualizado' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE /api/cart/item/:productId
app.delete('/api/cart/item/:productId', requireAuth, async (req, res) => {
  try {
    await pool.query('DELETE FROM cart WHERE user_id=$1 AND product_id=$2', [req.user.user_id, req.params.productId]);
    res.json({ message: 'Eliminado del carrito' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE /api/cart
app.delete('/api/cart', requireAuth, async (req, res) => {
  try {
    await pool.query('DELETE FROM cart WHERE user_id=$1', [req.user.user_id]);
    res.json({ message: 'Carrito vaciado' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── ORDERS ───────────────────────────────────────────────────────────────

// GET /api/orders
app.get('/api/orders', requireAuth, async (req, res) => {
  try {
    const ordersResult = await pool.query(
      'SELECT * FROM orders WHERE user_id=$1 ORDER BY created_at DESC',
      [req.user.user_id]
    );
    const orders = [];
    for (const order of ordersResult.rows) {
      const itemsResult = await pool.query(
        'SELECT * FROM order_items WHERE order_id=$1',
        [order.id]
      );
      orders.push({ ...order, items: itemsResult.rows });
    }
    res.json(orders);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/orders
app.post('/api/orders', requireAuth, async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Get cart
    const cartResult = await client.query(
      `SELECT c.quantity, p.id, p.name, p.price, p.stock FROM cart c JOIN products p ON c.product_id = p.id WHERE c.user_id = $1 FOR UPDATE OF p`,
      [req.user.user_id]
    );
    if (cartResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'El carrito está vacío' });
    }

    const outOfStock = cartResult.rows.find((r) => r.stock < r.quantity);
    if (outOfStock) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: `Stock insuficiente para ${outOfStock.name}` });
    }

    const total = cartResult.rows.reduce((sum, r) => sum + (parseFloat(r.price) * r.quantity), 0);
    const orderId = 'ORD-' + uuidv4().replace(/-/g, '').slice(0, 8).toUpperCase();

    await client.query(
      'INSERT INTO orders (id, user_id, total, status) VALUES ($1,$2,$3,$4)',
      [orderId, req.user.user_id, total.toFixed(2), 'out_for_delivery']
    );

    for (const item of cartResult.rows) {
      await client.query(
        'INSERT INTO order_items (order_id, product_id, product_name, product_price, quantity) VALUES ($1,$2,$3,$4,$5)',
        [orderId, item.id, item.name, item.price, item.quantity]
      );
      await client.query('UPDATE products SET stock = stock - $1 WHERE id = $2', [item.quantity, item.id]);
    }

    const courier = await client.query("SELECT id FROM couriers WHERE name='Trackos Express' LIMIT 1");
    const trackingCode = 'TRK-' + uuidv4().replace(/-/g, '').slice(0, 10).toUpperCase();
    await client.query(
      'INSERT INTO shipments (order_id, courier_id, tracking_code, delivery_address) VALUES ($1,$2,$3,$4)',
      [orderId, courier.rows[0].id, trackingCode, req.user.address || 'Dirección por confirmar']
    );
    const events = [
      ['confirmed', 'Pedido confirmado y registrado.', 'Centro de preparación - Trujillo'],
      ['prepared', 'Pedido preparado para su despacho.', 'Almacén Trackos - Trujillo'],
      ['shipped', 'Paquete entregado al courier.', 'Centro de distribución - Trujillo'],
      ['in_transit', 'Pedido en tránsito hacia su destino.', 'Ruta de distribución - La Libertad'],
      ['out_for_delivery', 'Pedido en reparto para entrega.', 'Trujillo - La Libertad'],
    ];
    for (const [index, [status, description, location]] of events.entries()) {
      await client.query(
        'INSERT INTO tracking_events (order_id,status,description,location,occurred_at) VALUES ($1,$2,$3,$4,NOW() - ($5 * INTERVAL \'20 minutes\'))',
        [orderId, status, description, location, events.length - index - 1]
      );
    }

    await client.query('DELETE FROM cart WHERE user_id=$1', [req.user.user_id]);
    await client.query('COMMIT');

    const orderResult = await pool.query('SELECT * FROM orders WHERE id=$1', [orderId]);
    const itemsResult = await pool.query('SELECT * FROM order_items WHERE order_id=$1', [orderId]);
    res.status(201).json({ ...orderResult.rows[0], items: itemsResult.rows });
  } catch (err) {
    await client.query('ROLLBACK');
    res.status(500).json({ error: err.message });
  } finally {
    client.release();
  }
});

// GET /api/orders/:id/tracking - solo el dueño puede consultar el seguimiento.
app.get('/api/orders/:id/tracking', requireAuth, async (req, res) => {
  try {
    const order = await pool.query('SELECT id,status FROM orders WHERE id=$1 AND user_id=$2', [req.params.id, req.user.user_id]);
    if (!order.rows.length) return res.status(404).json({ error: 'Pedido no encontrado' });
    const shipment = await pool.query(
      `SELECT s.tracking_code, s.delivery_address, s.delivered_at, s.delivery_photo_url,
              c.name AS courier_name, c.phone AS courier_phone, c.email AS courier_email
       FROM shipments s LEFT JOIN couriers c ON c.id=s.courier_id WHERE s.order_id=$1`, [req.params.id]
    );
    const events = await pool.query('SELECT status,description,location,occurred_at FROM tracking_events WHERE order_id=$1 ORDER BY occurred_at,id', [req.params.id]);
    res.json({ orderId: req.params.id, status: order.rows[0].status, shipment: shipment.rows[0] || null, events: events.rows });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// ─── HEALTH ───────────────────────────────────────────────────────────────
app.get('/health', (req, res) => res.json({ status: 'ok', timestamp: new Date() }));

const PORT = process.env.PORT || 3000;
ensureSchema().then(() => app.listen(PORT, () => console.log(`Trackos API running on port ${PORT}`)))
  .catch((err) => { console.error('Database initialization failed:', err); process.exit(1); });
