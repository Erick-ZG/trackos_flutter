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
    ALTER TABLE tracking_events DROP CONSTRAINT IF EXISTS tracking_events_order_id_status_key;
    ALTER TABLE tracking_events ADD COLUMN IF NOT EXISTS simulation_run_id UUID;
    ALTER TABLE tracking_events ADD COLUMN IF NOT EXISTS node_index INTEGER;
    CREATE UNIQUE INDEX IF NOT EXISTS tracking_events_run_node_key
      ON tracking_events (order_id,simulation_run_id,node_index);
    CREATE TABLE IF NOT EXISTS order_simulations (
      order_id VARCHAR(30) PRIMARY KEY REFERENCES orders(id) ON DELETE CASCADE,
      route_id VARCHAR(60) NOT NULL,
      current_node_index INTEGER NOT NULL DEFAULT 0 CHECK (current_node_index >= 0),
      version INTEGER NOT NULL DEFAULT 0 CHECK (version >= 0),
      run_id UUID NOT NULL,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    INSERT INTO couriers (name, phone, email)
    SELECT 'Trackos Express', '+51 900 000 001', 'demo@trackos.local'
    WHERE NOT EXISTS (SELECT 1 FROM couriers WHERE name='Trackos Express');

-- Repair only the known invalid demo seed; preserve passwords changed by users.
UPDATE users SET password='$2a$10$jDlJ4UBdX/w.O0jD3zdlMOmFdeZ3w53SihhxJP3rQ16.ALPSZqAu2' WHERE id='a0000000-0000-0000-0000-000000000001' AND email='demo@test.com' AND password='$2a$10$YvlQVWvCzC0gON.OmC3oJOBvfM5kxFiJgm.rPMEMR8hFGHKMJWNou';
