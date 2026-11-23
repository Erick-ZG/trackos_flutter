-- Users
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL,
  email VARCHAR(100) UNIQUE NOT NULL,
  password VARCHAR(255) NOT NULL,
  phone VARCHAR(30) DEFAULT '',
  address TEXT DEFAULT '',
  created_at TIMESTAMP DEFAULT NOW()
);

-- Sessions (token auth)
CREATE TABLE IF NOT EXISTS sessions (
  token UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Products
CREATE TABLE IF NOT EXISTS products (
  id VARCHAR(10) PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  description TEXT DEFAULT '',
  category VARCHAR(50) NOT NULL,
  price DECIMAL(10,2) NOT NULL,
  stock INTEGER DEFAULT 0,
  icon_name VARCHAR(50) DEFAULT 'shopping_bag',
  color_value BIGINT DEFAULT 4280391411
);

ALTER TABLE products ALTER COLUMN color_value TYPE BIGINT;

-- Cart
CREATE TABLE IF NOT EXISTS cart (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  product_id VARCHAR(10) NOT NULL REFERENCES products(id),
  quantity INTEGER NOT NULL DEFAULT 1,
  UNIQUE(user_id, product_id)
);

-- Orders
CREATE TABLE IF NOT EXISTS orders (
  id VARCHAR(30) PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  total DECIMAL(10,2) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT NOW()
);

-- Order Items
CREATE TABLE IF NOT EXISTS order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id VARCHAR(30) NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id VARCHAR(10) REFERENCES products(id),
  product_name VARCHAR(150) NOT NULL,
  product_price DECIMAL(10,2) NOT NULL,
  quantity INTEGER NOT NULL
);

-- Datos de envío y seguimiento ficticios para la demostración académica.
CREATE TABLE IF NOT EXISTS couriers (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  phone VARCHAR(30) NOT NULL DEFAULT '',
  email VARCHAR(120) NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS shipments (
  order_id VARCHAR(30) PRIMARY KEY REFERENCES orders(id) ON DELETE CASCADE,
  courier_id INTEGER REFERENCES couriers(id),
  tracking_code VARCHAR(40) UNIQUE NOT NULL,
  delivery_address TEXT NOT NULL DEFAULT '',
  delivered_at TIMESTAMP,
  delivery_photo_url TEXT
);

CREATE TABLE IF NOT EXISTS tracking_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id VARCHAR(30) NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  status VARCHAR(30) NOT NULL,
  description TEXT NOT NULL,
  location VARCHAR(150) NOT NULL DEFAULT '',
  occurred_at TIMESTAMP NOT NULL DEFAULT NOW(),
  UNIQUE(order_id, status)
);

ALTER TABLE order_items ALTER COLUMN product_id DROP NOT NULL;

-- Demo user (password: 123456)
INSERT INTO users (id, name, email, password, phone, address)
VALUES (
  'a0000000-0000-0000-0000-000000000001',
  'Usuario Demo',
  'demo@test.com',
  '$2a$10$jDlJ4UBdX/w.O0jD3zdlMOmFdeZ3w53SihhxJP3rQ16.ALPSZqAu2',
  '+51 900 000 000',
  'Destino ficticio de demostración, Trujillo, Perú'
) ON CONFLICT DO NOTHING;

-- Products seed
INSERT INTO products (id, name, description, category, price, stock, icon_name, color_value) VALUES
('p001', 'Laptop Pro 15"', 'Potente laptop con procesador de última generación, 16GB RAM, SSD 512GB y pantalla Full HD de 15 pulgadas. Perfecta para trabajo y entretenimiento.', 'Electrónica', 1299.99, 10, 'laptop', 4280391411),
('p002', 'Smartphone X15', 'Smartphone de alta gama con cámara triple de 108MP, batería de 5000mAh, pantalla AMOLED 6.7" y 5G integrado.', 'Electrónica', 999.99, 15, 'phone_android', 4283215696),
('p003', 'Auriculares BT Pro', 'Auriculares inalámbricos con cancelación activa de ruido, autonomía de 30 horas, carga rápida y sonido Hi-Fi premium.', 'Electrónica', 89.99, 25, 'headphones', 4284513675),
('p004', 'Smart Watch Series 5', 'Reloj inteligente con monitor cardíaco, GPS integrado, resistencia al agua IP68, pantalla AMOLED.', 'Electrónica', 249.99, 20, 'watch', 4278219733),
('p005', 'Camiseta Casual', 'Camiseta 100% algodón orgánico, corte moderno y cómodo, disponible en múltiples colores.', 'Ropa', 24.99, 50, 'checkroom', 4294940672),
('p006', 'Jeans Slim Fit', 'Pantalón vaquero de corte slim fit, tejido resistente con elasticidad. Combinación perfecta de estilo y confort.', 'Ropa', 59.99, 30, 'straighten', 4284927175),
('p007', 'Arroz Integral 5kg', 'Arroz integral de grano largo, cultivo ecológico certificado, alto contenido en fibra y nutrientes esenciales.', 'Alimentos', 12.99, 100, 'eco', 4278228616),
('p008', 'Aceite de Oliva Extra Virgen', 'Aceite de oliva extra virgen de primera prensada en frío, acidez máxima 0.3%, sabor intenso y afrutado.', 'Alimentos', 18.99, 80, 'local_dining', 4292929712),
('p009', 'Lámpara LED Inteligente', 'Lámpara LED regulable con control de temperatura de color, compatible con asistentes de voz, ahorro energético del 80%.', 'Hogar', 34.99, 40, 'lightbulb', 4294967040),
('p010', 'Silla Ergonómica', 'Silla de oficina ergonómica con soporte lumbar ajustable, reposabrazos en 4D, asiento de espuma viscoelástica.', 'Hogar', 299.99, 12, 'chair', 4294901760),
('p011', 'Teclado Mecánico RGB', 'Teclado mecánico con switches Cherry MX Red, retroiluminación RGB personalizable, layout TKL y construcción en aluminio.', 'Electrónica', 149.99, 18, 'keyboard', 4278216959),
('p012', 'Monitor 27" 4K', 'Monitor 4K UHD de 27 pulgadas, panel IPS con 99% sRGB, tiempo de respuesta 1ms, compatible con HDR10.', 'Electrónica', 399.99, 8, 'monitor', 4283716944),
('p013', 'Zapatillas Running', 'Zapatillas para running con amortiguación reactiva, suela de goma resistente y upper de malla transpirable ultraligera.', 'Ropa', 79.99, 35, 'directions_run', 4290544928),
('p014', 'Cafetera Espresso', 'Cafetera de espresso con bomba de 15 bares de presión, vaporizador de leche integrado, depósito extraíble de 1.8L.', 'Hogar', 189.99, 22, 'coffee', 4284527175)
ON CONFLICT DO NOTHING;
