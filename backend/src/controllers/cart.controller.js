const store = require('../services/store.service');
exports.list = async (req, res, next) => {
  try { res.json(await store.cart(req.user.user_id)); } catch (err) { next(err); }
};
exports.add = async (req, res, next) => {
  try { await store.add(req.user.user_id,req.body.productId,req.body.quantity); res.json({ message: 'Agregado al carrito' }); } catch (err) { next(err); }
};
exports.update = async (req, res, next) => {
  try { await store.update(req.user.user_id,req.params.productId,req.body.quantity); res.json({ message: 'Carrito actualizado' }); } catch (err) { next(err); }
};
exports.remove = async (req, res, next) => {
  try { await store.remove(req.user.user_id,req.params.productId); res.json({ message: 'Eliminado del carrito' }); } catch (err) { next(err); }
};
exports.clear = async (req, res, next) => {
  try { await store.clear(req.user.user_id); res.json({ message: 'Carrito vaciado' }); } catch (err) { next(err); }
};
