const app = require('./src/app');
const pool = require('./src/config/database');
const migrate = require('./src/database/migrate');
const { port } = require('./src/config/env');
const wsHub = require('./src/realtime/wsHub');

async function start() {
  await migrate();
  const server = app.listen(port, () => console.log('Trackos API running on port ' + port));
  wsHub.attach(server);
  const shutdown = () => server.close(() => pool.end().then(() => process.exit(0)));
  process.once('SIGINT', shutdown);
  process.once('SIGTERM', shutdown);
  return server;
}

if (require.main === module) {
  start().catch((err) => {
    console.error('Database initialization failed:', err);
    pool.end().finally(() => {
      process.exitCode = 1;
    });
  });
}

module.exports = { start };
