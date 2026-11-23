const auth = require('../services/auth.service');
exports.register = async (req, res, next) => {
  try { res.status(201).json(await auth.register(req.body)); } catch (err) { next(err); }
};
exports.login = async (req, res, next) => {
  try { res.json(await auth.login(req.body)); } catch (err) { next(err); }
};
exports.logout = async (req, res, next) => {
  try { await auth.logout(req.token); res.json({ message: 'Sesión cerrada' }); } catch (err) { next(err); }
};
exports.me = (req, res) => res.json({ user: req.user });
