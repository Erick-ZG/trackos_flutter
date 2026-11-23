const express = require('express');
const fs = require('node:fs');
const path = require('node:path');
const webRoot = path.resolve(__dirname, '../../seguimiento_de_pedidos_app/build/web');
if (!fs.existsSync(path.join(webRoot, 'index.html'))) {
  console.error('Primero ejecuta: cd seguimiento_de_pedidos_app && flutter build web');
  process.exit(1);
}
const app = express();
app.use(express.static(webRoot, { etag: true }));
app.get('*', (req, res) => res.sendFile(path.join(webRoot, 'index.html')));
const port = Number(process.env.WEB_PORT || 8080);
app.listen(port, '127.0.0.1', () => console.log('Trackos web: http://localhost:' + port));
