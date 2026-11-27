const { getOrderContact } = require('../services/order-contact.service');

exports.get = async (req, res, next) => {
  res.set('Cache-Control', 'no-store');
  try {
    res.json(await getOrderContact(req.params.id, req.user));
  } catch (err) {
    next(err);
  }
};
