const router = require('express').Router();
const controller = require('../controllers/cart.controller');
const requireAuth = require('../middleware/auth');
router.get('/', requireAuth, controller.list);
router.post('/add', requireAuth, controller.add);
router.put('/item/:productId', requireAuth, controller.update);
router.delete('/item/:productId', requireAuth, controller.remove);
router.delete('/', requireAuth, controller.clear);
module.exports = router;
