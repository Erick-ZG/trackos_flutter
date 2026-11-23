const { WebSocketServer } = require('ws');
const url = require('node:url');
const pool = require('../config/database');

const clients = new Set();

function attach(server) {
  const wss = new WebSocketServer({ server, path: '/ws' });

  wss.on('connection', async (ws, req) => {
    try {
      const parsed = url.parse(req.url, true);
      const token = parsed.query?.token;
      if (!token || typeof token !== 'string') {
        ws.close(4001, 'Missing token');
        return;
      }

      const result = await pool.query(
        `SELECT s.user_id, u.name, u.email, u.role, u.branch_id
         FROM sessions s JOIN users u ON s.user_id = u.id
         WHERE s.token = $1`,
        [token]
      );
      if (result.rows.length === 0) {
        ws.close(4001, 'Invalid token');
        return;
      }

      ws.user = result.rows[0];
      ws.subscribedOrders = new Set();
      clients.add(ws);

      ws.send(JSON.stringify({ type: 'connected', user: ws.user }));

      ws.on('message', (raw) => {
        try {
          const msg = JSON.parse(raw.toString());
          if (msg.type === 'subscribe' && msg.orderId) {
            ws.subscribedOrders.add(String(msg.orderId));
          } else if (msg.type === 'unsubscribe' && msg.orderId) {
            ws.subscribedOrders.delete(String(msg.orderId));
          }
        } catch (_) {
          // Ignore malformed client frames
        }
      });

      ws.on('close', () => clients.delete(ws));
      ws.on('error', () => clients.delete(ws));
    } catch (err) {
      clients.delete(ws);
      ws.close(1011, 'Server error');
    }
  });

  return wss;
}

function broadcast(type, payload, { orderId, roles, branchId, userIds } = {}) {
  const frame = JSON.stringify({ type, payload, timestamp: new Date().toISOString() });
  for (const ws of clients) {
    if (ws.readyState !== 1 || !ws.user) continue;
    let match = false;
    if (orderId && ws.subscribedOrders?.has(String(orderId))) match = true;
    if (userIds && userIds.includes(ws.user.user_id)) match = true;
    if (roles && roles.includes(ws.user.role)) {
      if (ws.user.role === 'worker' && branchId && ws.user.branch_id !== branchId) {
        match = false;
      } else {
        match = true;
      }
    }
    if (!orderId && !roles && !userIds) match = true;
    if (match) {
      try {
        ws.send(frame);
      } catch (_) {}
    }
  }
}

module.exports = { attach, broadcast };
