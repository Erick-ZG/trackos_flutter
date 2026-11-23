const router = require('express').Router();
const pool = require('../config/database');
const requireAuth = require('../middleware/auth');

router.get('/', requireAuth, async (req, res, next) => {
  try {
    const branches = (await pool.query('SELECT * FROM branches ORDER BY id')).rows;
    res.json(branches);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
