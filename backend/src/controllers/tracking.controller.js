const pool = require('../config/database');
const tracking = require('../services/tracking.service');
const simulation = require('../services/simulation.service');
const { simulationEnabled } = require('../config/env');
exports.get = async (req, res, next) => {
  try { res.json(await tracking(pool, req.params.id, req.user.user_id)); } catch (err) { next(err); }
};
for (const action of ['advance','reset']) {
  exports[action] = async (req, res, next) => {
    try {
      if (!simulationEnabled) throw simulation.fail(403, 'Prueba académica deshabilitada en este servidor');
      await simulation.mutate(pool, req.params.id, req.user.user_id, action, req.body.expectedVersion);
      res.json(await tracking(pool, req.params.id, req.user.user_id));
    } catch (err) { next(err); }
  };
}
