const store = require('../services/store.service');
exports.list = async (req, res, next) => {
  try { res.json(await store.products()); } catch (err) { next(err); }
};
exports.get = async (req, res, next) => {
  try { res.json(await store.product(req.params.id)); } catch (err) { next(err); }
};
