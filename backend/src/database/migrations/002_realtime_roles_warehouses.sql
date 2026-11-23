-- Warehouses / Sedes
CREATE TABLE IF NOT EXISTS branches (
  id VARCHAR(20) PRIMARY KEY,
  name VARCHAR(120) NOT NULL,
  address TEXT NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Per-branch inventory
CREATE TABLE IF NOT EXISTS branch_inventory (
  branch_id VARCHAR(20) NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  product_id VARCHAR(10) NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  stock INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (branch_id, product_id)
);

-- Extend users with role and optional branch assignment (for workers)
ALTER TABLE users ADD COLUMN IF NOT EXISTS role VARCHAR(20) NOT NULL DEFAULT 'customer';
ALTER TABLE users ADD COLUMN IF NOT EXISTS branch_id VARCHAR(20) REFERENCES branches(id);

-- Extend orders with delivery fee, branch pickup, dropoff coords, worker/courier, timings & proof
ALTER TABLE orders ALTER COLUMN status TYPE VARCHAR(40);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_fee DECIMAL(10,2) NOT NULL DEFAULT 5.00;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS branch_id VARCHAR(20) REFERENCES branches(id);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS pickup_address TEXT NOT NULL DEFAULT '';
ALTER TABLE orders ADD COLUMN IF NOT EXISTS pickup_lat DOUBLE PRECISION;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS pickup_lng DOUBLE PRECISION;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_address TEXT NOT NULL DEFAULT '';
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_lat DOUBLE PRECISION;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_lng DOUBLE PRECISION;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS worker_id UUID REFERENCES users(id);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS courier_user_id UUID REFERENCES users(id);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS courier_name VARCHAR(100);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS courier_lat DOUBLE PRECISION;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS courier_lng DOUBLE PRECISION;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS prepared_at TIMESTAMP;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS ready_at TIMESTAMP;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMP;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS arrived_store_at TIMESTAMP;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS picked_up_at TIMESTAMP;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS arrived_dest_at TIMESTAMP;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMP;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_duration_seconds INTEGER;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_proof_image TEXT;

-- Real-time chat messages between customer and courier
CREATE TABLE IF NOT EXISTS order_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id VARCHAR(30) NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  sender_name VARCHAR(100) NOT NULL,
  sender_role VARCHAR(20) NOT NULL,
  message TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_order_messages_order_id ON order_messages(order_id, created_at);

-- Seed 3 Trujillo warehouses / sedes
INSERT INTO branches (id, name, address, latitude, longitude) VALUES
  ('br-ovalo', 'Sede Óvalo Papal', 'Av. América Sur 1245, Óvalo Papal, Trujillo', -8.1205, -79.0355),
  ('br-centro', 'Sede Centro Histórico', 'Jr. Pizarro 480, Plaza de Armas, Trujillo', -8.1117, -79.0287),
  ('br-recreo', 'Sede El Recreo', 'Jr. Estete 612, Plazuela El Recreo, Trujillo', -8.1095, -79.0243)
ON CONFLICT (id) DO NOTHING;

-- Seed branch inventory from products catalog (split/available across branches)
INSERT INTO branch_inventory (branch_id, product_id, stock)
SELECT b.id, p.id, GREATEST(p.stock, 5)
FROM branches b
CROSS JOIN products p
ON CONFLICT (branch_id, product_id) DO NOTHING;

-- Seed 3 new role accounts (password: 123456)
INSERT INTO users (id, name, email, password, phone, address, role, branch_id) VALUES
  (
    'a0000000-0000-0000-0000-000000000002',
    'Lucía Paredes',
    'trabajador@test.com',
    '$2a$10$jDlJ4UBdX/w.O0jD3zdlMOmFdeZ3w53SihhxJP3rQ16.ALPSZqAu2',
    '+51 944 111 222',
    'Av. América Sur 1245, Óvalo Papal, Trujillo',
    'worker',
    'br-ovalo'
  ),
  (
    'a0000000-0000-0000-0000-000000000003',
    'Carlos Mendoza',
    'repartidor@test.com',
    '$2a$10$jDlJ4UBdX/w.O0jD3zdlMOmFdeZ3w53SihhxJP3rQ16.ALPSZqAu2',
    '+51 944 333 444',
    'Trujillo, Perú',
    'courier',
    NULL
  ),
  (
    'a0000000-0000-0000-0000-000000000004',
    'Admin Trackos',
    'admin@test.com',
    '$2a$10$jDlJ4UBdX/w.O0jD3zdlMOmFdeZ3w53SihhxJP3rQ16.ALPSZqAu2',
    '+51 944 555 666',
    'Trujillo, Perú',
    'admin',
    NULL
  )
ON CONFLICT (email) DO UPDATE SET
  role = EXCLUDED.role,
  branch_id = EXCLUDED.branch_id;
