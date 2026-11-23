const router = require('express').Router();
const controller = require('../controllers/products.controller');
const requireAuth = require('../middleware/auth');
router.get('/', controller.list);
router.get('/:id', controller.get);
module.exports = router;
