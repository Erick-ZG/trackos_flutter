const orders = require('../services/orders.service');

exports.list = async (req, res, next) => {
  try {
    res.json(await orders.list(req.user.user_id));
  } catch (err) {
    next(err);
  }
};

exports.create = async (req, res, next) => {
  try {
    res.status(201).json(await orders.create(req.user, req.body || {}));
  } catch (err) {
    next(err);
  }
};
