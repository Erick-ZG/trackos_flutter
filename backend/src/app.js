const path = require('node:path');
const express = require('express');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json({ limit: '8mb' }));
app.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));

for (const resource of ['auth', 'products', 'cart', 'orders', 'branches', 'worker', 'courier', 'admin']) {
  app.use('/api/' + resource, require('./routes/' + resource + '.routes'));
}
app.use('/api/orders', require('./routes/messages.routes'));

app.get('/health', (req, res) => res.json({ status: 'ok', timestamp: new Date() }));
app.use((req, res) => res.status(404).json({ error: 'Ruta no encontrada' }));
app.use((err, req, res, next) => {
  if (!err.status || err.status >= 500) console.error(err);
  res.status(err.status || 500).json({ error: err.status ? err.message : 'Error interno del servidor' });
});

module.exports = app;
