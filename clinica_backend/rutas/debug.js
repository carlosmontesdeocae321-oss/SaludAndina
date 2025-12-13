const express = require('express');
const router = express.Router();
const { auth } = require('../middlewares/auth');

// Ruta para depuración: devuelve lo que el servidor ha identificado como req.user
router.get('/whoami', auth, async (req, res) => {
  try {
    res.json({ ok: true, user: req.user || null });
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message || e });
  }
});

module.exports = router;
