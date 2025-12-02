const express = require('express');
const router = express.Router();
const planesModelo = require('../modelos/planesModelo');

// Obtener todos los planes
router.get('/', async (req, res) => {
  try {
    const planes = await planesModelo.obtenerPlanes();
    res.json(planes);
  } catch (err) {
    res.status(500).json({ error: 'Error al obtener planes' });
  }
});

// Crear un plan (solo admin)
router.post('/', async (req, res) => {
  try {
    const id = await planesModelo.crearPlan(req.body);
    res.status(201).json({ id });
  } catch (err) {
    res.status(500).json({ error: 'Error al crear plan' });
  }
});

module.exports = router;
